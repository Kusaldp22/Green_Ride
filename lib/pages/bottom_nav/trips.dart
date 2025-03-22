import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/splash_screen.dart';

class Trips extends StatefulWidget {
  const Trips({super.key});

  @override
  State<Trips> createState() => _TripsState();
}

class _TripsState extends State<Trips> {
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    getCurrentUserId();
  }

  Future<void> getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
    }
  }

  Future<List<RideModel>> fetchMyOfferedRides() async {
    if (currentUserId == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('offered_rides')
        .where('user_id', isEqualTo: currentUserId)
        .get();

    return querySnapshot.docs
        .map((doc) => RideModel.fromFirestore(doc))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<RideModel>>(
        future: fetchMyOfferedRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen1();
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rides = snapshot.data ?? [];
          if (rides.isEmpty) {
            return const Center(
                child: Text("You haven't offered any rides yet."));
          }

          return Column(
            children: [
              AppBar(
                title: const Text("My Trips"),
                backgroundColor: Colors.blueAccent,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    final int bookedSeats = ride.joinedUsers?.length ?? 0;
                    final bool allSeatsFilled = bookedSeats >= ride.seats;

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: ride.profileImageUrl.isNotEmpty
                              ? NetworkImage(ride.profileImageUrl)
                                  as ImageProvider
                              : const AssetImage("assets/images/profile.jpeg"),
                        ),
                        title: Text(
                          ride.carName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${ride.type} | $bookedSeats/${ride.seats} seats booked | ⭐ ${ride.rating}'),

                        // Show "Ride Now" button only if all seats are booked
                        trailing: allSeatsFilled
                            ? ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Ride started!')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Ride Now',
                                    style: TextStyle(color: Colors.white)),
                              )
                            : const Text("Waiting for bookings",
                                style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
