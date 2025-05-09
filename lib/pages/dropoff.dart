import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/bottom_nav/dashboard.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  Completer<GoogleMapController> _controller = Completer();
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};
  LatLng? startLocation;
  LatLng? endLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDriverUsername();
    fetchTotalPayment();
    fetchPassengers();
    _setMapData();
  }

  Future<void> _setMapData() async {
    if (widget.ride.startLatLng != null && widget.ride.endLatLng != null) {
      setState(() {
        startLocation = LatLng(
          widget.ride.startLatLng!.latitude,
          widget.ride.startLatLng!.longitude,
        );
        endLocation = LatLng(
          widget.ride.endLatLng!.latitude,
          widget.ride.endLatLng!.longitude,
        );
      });

      await _getPolylinePoints();

      if (_controller.isCompleted) {
        final controller = await _controller.future;
        _fitMapToMarkers(controller);
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getPolylinePoints() async {
    if (startLocation == null || endLocation == null) return;

    const String apiKey = "AIzaSyBk1wlKR68wI-IDMzsbLPf1YiEZCetZDHU";
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${startLocation!.latitude},${startLocation!.longitude}&destination=${endLocation!.latitude},${endLocation!.longitude}&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["routes"].isNotEmpty) {
        var points = PolylinePoints().decodePolyline(
          data["routes"][0]["overview_polyline"]["points"],
        );
        polylineCoordinates.clear();
        polylineCoordinates.addAll(
          points.map((e) => LatLng(e.latitude, e.longitude)),
        );

        setState(() {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.green,
              points: polylineCoordinates,
              width: 5,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Error getting polyline points: $e");
    }
  }

  Future<void> _fitMapToMarkers(GoogleMapController controller) async {
    if (startLocation == null || endLocation == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(startLocation!.latitude, endLocation!.latitude),
        min(startLocation!.longitude, endLocation!.longitude),
      ),
      northeast: LatLng(
        max(startLocation!.latitude, endLocation!.latitude),
        max(startLocation!.longitude, endLocation!.longitude),
      ),
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  Future<void> _openGoogleMapsDirections() async {
    if (startLocation == null || endLocation == null) return;

    final String origin =
        '${startLocation!.latitude},${startLocation!.longitude}';
    final String destination =
        '${endLocation!.latitude},${endLocation!.longitude}';
    final String url =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: startLocation ?? const LatLng(0, 0),
                    zoom: 12,
                  ),
                  polylines: polylines,
                  markers: {
                    if (startLocation != null)
                      Marker(
                        markerId: const MarkerId('start'),
                        position: startLocation!,
                        infoWindow: InfoWindow(
                          title: 'Start Location',
                          snippet: widget.ride.location,
                        ),
                      ),
                    if (endLocation != null)
                      Marker(
                        markerId: const MarkerId('end'),
                        position: endLocation!,
                        infoWindow: InfoWindow(
                          title: 'End Location',
                          snippet: widget.ride.carName.split(' to ')[1],
                        ),
                      ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions, color: Colors.white),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 26, 211, 1),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _openGoogleMapsDirections,
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
