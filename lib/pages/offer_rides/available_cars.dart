import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ride_model.dart';

class AvailableRidesScreen extends StatefulWidget {
  final String startPoint;
  final String destination;

  AvailableRidesScreen({
    required this.startPoint,
    required this.destination,
    Key? key,
  }) : super(key: key);

  @override
  _AvailableRidesScreenState createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    getCurrentUserId();
  }

  Future<void> getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print("Fetched Current User ID: ${user.uid}"); // Debugging output
      setState(() {
        currentUserId = user.uid;
      });
    } else {
      print("No user logged in!"); // Debugging output
    }
  }

  Future<List<RideModel>> fetchRides() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('offered_rides')
        .where('start_point', isEqualTo: widget.startPoint)
        .where('destination', isEqualTo: widget.destination)
        .get();

    List<RideModel> rides = querySnapshot.docs.map((doc) {
      final data = doc.data();
      print("Fetched Ride Data: $data"); // Debugging output
      return RideModel.fromFirestore(doc);
    }).toList();

    for (var ride in rides) {
      print("Processed Ride ID: ${ride.userId}"); // Debugging output
    }

    return rides;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Available Rides for your Route',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: FutureBuilder<List<RideModel>>(
        future: fetchRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rides = snapshot.data ?? [];
          if (rides.isEmpty) {
            return const Center(
              child: Text(
                'No rides available for this route.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];

              // Debugging output
              print("Ride Owner ID: ${ride.userId}, Current User ID: $currentUserId");

              bool isUserRide = currentUserId != null && ride.userId == currentUserId;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: ride.profileImageUrl.isNotEmpty
                        ? NetworkImage(ride.profileImageUrl) as ImageProvider
                        : const AssetImage("assets/images/profile.jpeg"),
                  ),
                  title: Text(ride.carName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: Text('${ride.type} | ${ride.seats} seats | ⭐ ${ride.rating}'),

                  // Hiding the "Ride Now" button for the ride owner
                  trailing: isUserRide
                      ? const SizedBox.shrink() // Hides the button completely
                      : ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ride request sent!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Ride Now', style: TextStyle(color: Colors.white)),
                        ),
                  onTap: () {
                    // Navigate to ride details or booking page
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
