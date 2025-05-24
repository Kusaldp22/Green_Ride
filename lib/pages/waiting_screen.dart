import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/chat/chat_screen.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/pages/reviews.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Completer<GoogleMapController> _controller = Completer();
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};
  LatLng? startLocation;
  LatLng? endLocation;

  @override
  void initState() {
    super.initState();
    fetchDriverUsername();
    fetchTotalPayment();
    fetchAverageRating();
    _setMapData();

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

  Future<void> _setMapData() async {
    if (widget.ride.startLatLng != null && widget.ride.endLatLng != null) {
      setState(() {
        startLocation = LatLng(widget.ride.startLatLng!.latitude,
            widget.ride.startLatLng!.longitude);
        endLocation = LatLng(
            widget.ride.endLatLng!.latitude, widget.ride.endLatLng!.longitude);
      });

      await _getPolylinePoints();

      // Fit the map to markers immediately after getting coordinates
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        _fitMapToMarkers(controller);
      }

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
  }

  Future<void> _getPolylinePoints() async {
    if (startLocation == null || endLocation == null) return;

    final String apiKey = dotenv.env['API_KEY'] ?? '';
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
      }
    } catch (e) {
      debugPrint("Error getting polyline points: $e");
    }
  }

  double _calculateInitialZoom() {
    if (startLocation == null || endLocation == null) return 10.0;

    // Calculate distance between points in km
    double distance = Geolocator.distanceBetween(
          startLocation!.latitude,
          startLocation!.longitude,
          endLocation!.latitude,
          endLocation!.longitude,
        ) /
        1000;

    // Simple formula to determine zoom level based on distance
    if (distance > 100) return 8.0;
    if (distance > 50) return 9.0;
    if (distance > 20) return 10.0;
    if (distance > 10) return 11.0;
    if (distance > 5) return 12.0;
    if (distance > 2) return 13.0;
    return 14.0;
  }

  Future<void> _fitMapToMarkers(GoogleMapController controller) async {
    if (startLocation == null || endLocation == null) return;

    // Create bounds that include both markers with some padding
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

    // Calculate the ideal zoom level based on distance
    double distance = Geolocator.distanceBetween(
      startLocation!.latitude,
      startLocation!.longitude,
      endLocation!.latitude,
      endLocation!.longitude,
    );

    // Adjust padding based on distance (closer points need less padding)
    double padding = distance > 10000 ? 100 : 50; // in meters

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding.toDouble()),
    );
  }

  Future<void> _openGoogleMapsDirections() async {
    if (startLocation == null || endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location data not available')),
      );
      return;
    }

    final String origin =
        '${startLocation!.latitude},${startLocation!.longitude}';
    final String destination =
        '${endLocation!.latitude},${endLocation!.longitude}';
    final String url =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open Google Maps: $e')),
      );
    }
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
              isEqualTo: widget.ride.rideId) 
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

          
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool _isLoading = true;
    return Scaffold(
      body: Column(
        children: [
          // Map section
          Expanded(
            child: startLocation != null && endLocation != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: startLocation ?? LatLng(0, 0), // fallback if null
                      zoom: _calculateInitialZoom(), 
                    ),
                    polylines: polylines,
                    markers: {
                      Marker(
                        markerId: const MarkerId('start'),
                        position: startLocation!,
                        infoWindow: InfoWindow(
                          title: "Start Location",
                          snippet: widget
                              .ride.location, // Use the start point address
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('end'),
                        position: endLocation!,
                        infoWindow: InfoWindow(
                          title: "End Location",
                          snippet: widget.ride.carName
                              .split(' to ')[1], // Get destination from carName
                        ),
                      ),
                    },
                    onMapCreated: (GoogleMapController controller) async {
                      _controller.complete(controller);
                      // Fit the map to show both markers
                      await _fitMapToMarkers(controller);
                      setState(() => _isLoading = false);
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text(
                        'Get Directions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 26, 211, 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _openGoogleMapsDirections,
                    ),
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
