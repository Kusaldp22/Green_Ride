import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:green_ride/dropoff.dart' as dropoff;
import 'package:green_ride/pages/offer_rides/ride_model.dart' as ride_model;
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

  Future<List<ride_model.RideModel>> fetchMyOfferedRides() async {
    if (currentUserId == null) return [];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('offered_rides')
        .where('user_id', isEqualTo: currentUserId)
        .get();

    return querySnapshot.docs
        .map((doc) => ride_model.RideModel.fromFirestore(doc))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  Text(
                    'My Offered Rides',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ride_model.RideModel>>(
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
                      child: Text(
                        "You haven't offered any rides yet.",
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      final int bookedSeats = ride.joinedUsers?.length ?? 0;
                      final bool allSeatsFilled = bookedSeats >= ride.seats;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCEACC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipOval(
                              child: Image.network(
                                ride.profileImageUrl.isNotEmpty
                                    ? ride.profileImageUrl
                                    : 'https://i.pinimg.com/736x/ea/3f/2f/ea3f2f888a79f5e19dfd5e368f3262b0.jpg',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ride.carName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${ride.type} | $bookedSeats/${ride.seats} seats booked | ⭐ ${ride.rating}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  allSeatsFilled
                                      ? ride.status == 'completed'
                                          ? const Text(
                                              'Completed',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : ElevatedButton(
                                              onPressed: () async {
                                                final result =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        dropoff.DropoffScreen(
                                                            ride: ride),
                                                  ),
                                                );

                                                if (result == true) {
                                                  setState(() {
                                                    ride.status = 'completed';
                                                  });

                                                  // Update in Firestore
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                          'offered_rides')
                                                      .doc(ride.id)
                                                      .update({
                                                    'status': 'completed',
                                                  });
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color.fromARGB(
                                                        255, 6, 96, 199),
                                              ),
                                              child: const Text(
                                                'Ride Now',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            )
                                      : const Text(
                                          "Waiting for bookings",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
