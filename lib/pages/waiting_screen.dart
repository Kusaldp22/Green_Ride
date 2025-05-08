import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/chat/chat_screen.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/pages/reviews.dart';
import 'package:url_launcher/url_launcher.dart';

class RideMapScreen extends StatelessWidget {
  final RideModel ride;
  const RideMapScreen({Key? key, required this.ride}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade200,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(255, 6, 96, 199),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        title: const Text(
          'Map to your destination',
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: RideScreen(ride: ride),
    );
  }
}

class RideScreen extends StatefulWidget {
  final RideModel ride;
  const RideScreen({Key? key, required this.ride}) : super(key: key);

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  String? userProfileImage;
  String username = "";
  double totalAmount = 0.0;
  String paymentMethod = "";
  String? phoneNumber;
  late String currentUserId;
  double averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    fetchDriverUsername();
    fetchTotalPayment();
    fetchAverageRating();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
    }
  }

  Future<void> fetchAverageRating() async {
    final avg = await getAverageRating(widget.ride.rideId);
    setState(() {
      averageRating = avg;
    });
  }

  Future<double> getAverageRating(String rideId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ratings')
        // .where('rideId', isEqualTo: rideId)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc['rating'] ?? 0).toDouble();
    }

    return total / snapshot.docs.length;
  }

  Future<void> fetchDriverUsername() async {
    try {
      String driverUid = widget.ride.userId;
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child("users").child(driverUid);

      DatabaseEvent event = await userRef.once();
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        Map userData = event.snapshot.value as Map;
        setState(() {
          userProfileImage = userData['profileImage'] ?? "";
          username = userData['username'] ?? "";
          phoneNumber = userData['mobile'] ?? "";
        });
      } else {
        debugPrint("Invalid user data or profileImage missing.");
      }
    } catch (e) {
      debugPrint("Error fetching driver profile: $e");
    }
  }

  Future<void> fetchTotalPayment() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('rideId',
              isEqualTo: widget.ride.rideId) // rideId from your RideModel
          .get();

      double total = 0.0;
      String? method;
      print("Documents found: ${snapshot.docs.length}");
      for (var doc in snapshot.docs) {
        double amount =
            (doc['amount'] as num).toDouble(); // handle int or double
        print("Amount in doc: $amount");
        total += amount;

        method ??= doc['paymentMethod'] ?? "Unknown";
      }

      setState(() {
        totalAmount = total;
        paymentMethod = method ?? "Unknown";
      });
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    }
  }

  void _callDriver() async {
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      try {
        final bool launched = await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw 'Could not launch $phoneUri';
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to call driver: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
    }
  }

  void _messageDriver() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          driverId: widget.ride.userId,
          driverName: username,
          driverImage: userProfileImage,
          currentUserId: currentUserId,

          // currentUserId: Get your current user ID from your auth system
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Map section
          Expanded(
            child: Stack(
              children: [
                Container(color: const Color(0xFFF0F0F0)),
                CustomPaint(
                  size:
                      Size(MediaQuery.of(context).size.width, double.infinity),
                  painter: RoutePainter(),
                ),
              ],
            ),
          ),

          // Bottom Sheet
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Details of the Ride',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Driver Info with Call and Message buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Driver profile image
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: userProfileImage != null &&
                                userProfileImage!.isNotEmpty
                            ? Image.network(
                                widget.ride.profileImageUrl,
                                width: 75,
                                height: 75,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 65,
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 65,
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Driver details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.ride.uniId,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(
                                  averageRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Call button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.call,
                              color: Colors.green, size: 20),
                          onPressed: _callDriver,
                          tooltip: 'Call driver',
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Message button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.message,
                              color: Colors.blue, size: 20),
                          onPressed: _messageDriver,
                          tooltip: 'Message driver',
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Payment Info
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        '\Rs.${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        paymentMethod.isNotEmpty
                            ? paymentMethod.capitalize()
                            : 'Loading...',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color.fromARGB(255, 6, 96, 199)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RideRatingApp(
                                    driverUid: widget.ride.userId)));
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 6, 96, 199)),
                      ),
                    ),
                  ),
                ),

                // Navigation bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.lineTo(size.width * 0.65, size.height * 0.65);

    canvas.drawPath(path, paint);

    final redMarkerPaint = Paint()..color = Colors.red;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.15),
      8,
      redMarkerPaint,
    );

    final carMarkerPaint = Paint()..color = Colors.green;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.65, size.height * 0.65),
        width: 16,
        height: 16,
      ),
      carMarkerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
