import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/bottom_nav/dashboard.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';

class DropoffScreen extends StatelessWidget {
  final RideModel ride;
  const DropoffScreen({Key? key, required this.ride}) : super(key: key);

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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Dashboard()),
              );
            },
          ),
        ),
        title: const Center(
          child: Text(
            'Drop Off Passengers',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
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
  List<String> passengerNames = [];
  List<String> passengerCodes = [];

  @override
  void initState() {
    super.initState();
    fetchDriverUsername();
    fetchTotalPayment();
    fetchPassengers();
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
              'Payment Successful!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ride has been successfully completed.',
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
              onPressed: () async {
                // 🔁 UPDATE RIDE STATUS BEFORE NAVIGATING
                try {
                  await FirebaseFirestore.instance
                      .collection('offered_rides')
                      .doc(widget.ride.rideId)
                      .update({'status': 'completed'});
                } catch (e) {
                  debugPrint('Failed to update status: $e');
                }

                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                  (route) => false,
                );
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> fetchDriverUsername() async {
    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child("users")
          .child(widget.ride.userId);

      final event = await ref.once();

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final userData = event.snapshot.value as Map;
        setState(() {
          userProfileImage = userData['profileImage'] ?? "";
          username = userData['username'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error fetching driver profile: $e");
    }
  }

  Future<void> fetchTotalPayment() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('rideId', isEqualTo: widget.ride.rideId)
          .get();

      double total = 0.0;
      String? method;

      for (var doc in snapshot.docs) {
        total += (doc['amount'] as num).toDouble();
        method ??= doc['paymentMethod'] ?? "Cash";
      }

      setState(() {
        totalAmount = total > 0 ? total : 220.00;
        paymentMethod = method ?? "Cash";
      });
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    }
  }

  Future<void> fetchPassengers() async {
    try {
      List<String> joinedUserIds = widget.ride.joinedUsers ?? [];

      List<String> names = [];
      List<String> codes = [];

      for (String uid in joinedUserIds) {
        final ref = FirebaseDatabase.instance.ref().child("users").child(uid);
        final event = await ref.once();

        if (event.snapshot.exists && event.snapshot.value is Map) {
          final userData = event.snapshot.value as Map;
          names.add(userData['username'] ?? 'Unknown');
          codes.add(userData['studentId'] ?? 'N/A');
        } else {
          names.add('Unknown');
          codes.add('N/A');
        }
      }

      setState(() {
        passengerNames = names;
        passengerCodes = codes;
      });
    } catch (e) {
      debugPrint("Error fetching passengers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Container(color: const Color(0xFFF0F0F0)),
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width, double.infinity),
                painter: RoutePainter(),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Details of Passengers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(height: 1),
              for (int i = 0; i < passengerNames.length; i++)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${i + 1}. ${passengerNames[i]}",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "(${passengerCodes[i]})",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (i < passengerNames.length - 1)
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  ],
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    Text('Rs.${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Method',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(paymentMethod,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showSuccessDialog,
                    child: const Text('Done',
                        style: TextStyle(fontSize: 16, color: Colors.blue)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.15);
    path.lineTo(size.width * 0.5, size.height * 0.65);

    canvas.drawPath(path, paint);

    final redMarkerPaint = Paint()..color = Colors.red;
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.15),
      8,
      redMarkerPaint,
    );

    final carMarkerPaint = Paint()..color = Colors.green;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.65),
        width: 16,
        height: 16,
      ),
      carMarkerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
