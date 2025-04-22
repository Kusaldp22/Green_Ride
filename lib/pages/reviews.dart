import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';

class RideRatingApp extends StatelessWidget {
  final String driverUid;
  const RideRatingApp({super.key, required this.driverUid});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ride Rating',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: RatingScreen(driverUid: driverUid),
    );
  }
}

class RatingScreen extends StatefulWidget {
  final String driverUid;
  const RatingScreen({super.key, required this.driverUid});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with SingleTickerProviderStateMixin {
  int _rating = 5;
  final TextEditingController _complimentController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isSubmitting = false;
  String? _profileImageUrl;
  String _username = "";

  // List of predefined compliments users can select from
  final List<String> _complimentSuggestions = [
    'Great conversation',
    'Clean vehicle',
    'Safe driving',
    'Punctual',
    'Friendly service'
  ];

  // Selected compliments
  final Set<String> _selectedCompliments = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchDriverProfile();
  }

  Future<void> _fetchDriverProfile() async {
    try {
      final DatabaseReference ref = FirebaseDatabase.instance
          .ref('users/${widget.driverUid}'); // Use the passed driverUid

      final DatabaseEvent event = await ref.once();
      final DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _profileImageUrl = data['profileImage']?.toString();
          _username = data['username']?.toString() ?? "Driver";
        });
      }
    } catch (e) {
      debugPrint("Error fetching driver profile: $e");
    }
  }

  Future<Map<String, String?>> _getCurrentUserData(String uid) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$uid');
      final snapshot = await ref.once();
      final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;

      final username = data?['username']?.toString();
      final profileImage = data?['profileImage']?.toString();

      return {
        'username': username,
        'profileImage': profileImage,
      };
    } catch (e) {
      debugPrint("Error fetching current user data: $e");
      return {
        'username': null,
        'profileImage': null,
      };
    }
  }

  void _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    // Combine selected compliments and custom compliment
    final List<String> allCompliments = List.from(_selectedCompliments);
    if (_complimentController.text.isNotEmpty) {
      allCompliments.add(_complimentController.text);
    }

    // Print for debugging - in a real app, you'd send this to your backend
    print('Rating: $_rating');
    print('Compliments: $allCompliments');

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      // Show success dialog and then navigate
      _showSuccessDialog();
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be logged in to submit a rating')),
        );
        return;
      }

      final List<String> allCompliments = List.from(_selectedCompliments);
      if (_complimentController.text.isNotEmpty) {
        allCompliments.add(_complimentController.text);
      }
      final raterData = await _getCurrentUserData(currentUser.uid);

      await FirebaseFirestore.instance.collection('ratings').add({
        'driverId': widget.driverUid,
        'raterId': currentUser.uid,
        'raterName': raterData['username'] ?? 'Anonymous',
        'raterImage': raterData['profileImage'] ?? '',
        'rating': _rating,
        'compliments': allCompliments,
        'driverName': _username,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _complimentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor() {
    switch (_rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleCompliment(String compliment) {
    setState(() {
      if (_selectedCompliments.contains(compliment)) {
        _selectedCompliments.remove(compliment);
      } else {
        _selectedCompliments.add(compliment);
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Thank You!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback has been submitted',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to home page after submission
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false,
                );
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(),
                  ));
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'How is your trip?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Rate $_username',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Driver avatar with subtle animation - using the sunglasses baby image
                Hero(
                  tag: 'driver-avatar',
                  child: GestureDetector(
                    onTapDown: (_) => _animationController.forward(),
                    onTapUp: (_) => _animationController.reverse(),
                    onTapCancel: () => _animationController.reverse(),
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: _profileImageUrl != null
                              ? Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/car.png',
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/car.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = starIndex;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.star,
                            size: 42,
                            color: starIndex <= _rating
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Rating text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _getRatingText(),
                    key: ValueKey<int>(_rating),
                    style: TextStyle(
                      color: _getRatingColor(),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick compliment chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Quick Compliments',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _complimentSuggestions.map((compliment) {
                    final isSelected =
                        _selectedCompliments.contains(compliment);
                    return GestureDetector(
                      onTap: () => _toggleCompliment(compliment),
                      child: Chip(
                        backgroundColor: isSelected
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        side: BorderSide(
                          color:
                              isSelected ? Colors.blue : Colors.grey.shade300,
                          width: 1,
                        ),
                        label: Text(
                          compliment,
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.black87,
                          ),
                        ),
                        avatar: isSelected
                            ? const Icon(Icons.check_circle,
                                size: 16, color: Colors.blue)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Compliment input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Add a Custom Compliment',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _complimentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Give a compliment',
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitRating,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
