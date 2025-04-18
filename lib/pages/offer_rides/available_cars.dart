import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/pages/payments/confirm.dart';
import 'package:green_ride/pages/waiting_screen.dart'; // Import ConfirmationScreen

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
      setState(() {
        currentUserId = user.uid;
      });
    }
  }

  Future<List<RideModel>> fetchRides() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('offered_rides')
        .where('start_point', isEqualTo: widget.startPoint)
        .where('destination', isEqualTo: widget.destination)
        .get();

    return querySnapshot.docs
        .map((doc) => RideModel.fromFirestore(doc))
        .toList();
  }

  Future<void> joinRide(String rideId, List<String>? joinedUsers, int seats,
      RideModel ride) async {
    if (currentUserId == null) return;

    joinedUsers ??= []; // Ensure it's not null
    if (!joinedUsers.contains(currentUserId)) {
      joinedUsers.add(currentUserId!);

      await FirebaseFirestore.instance
          .collection('offered_rides')
          .doc(rideId)
          .update({
        'joined_users': joinedUsers,
      });

      // Navigate to Confirmation screen with vehicle number
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(
            ride: ride,
            vehicleNumber:
                ride.vehicleNumber, // Pass vehicleNumber from RideModel
          ),
        ),
      );
    }
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
              final joinedUsers = ride.joinedUsers ?? [];
              final bool isJoined = joinedUsers.contains(currentUserId);
              final bool isUserRide =
                  currentUserId != null && ride.userId == currentUserId;

              // Calculate remaining seats
              num availableSeats = ride.seats - joinedUsers.length;

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
                        ? NetworkImage(ride.profileImageUrl) as ImageProvider
                        : const AssetImage("assets/images/profile.jpeg"),
                  ),
                  title: Text(ride.carName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${ride.type} | $availableSeats seats left | ⭐ ${ride.rating}'),

                  // Hide "Join Ride" for ride owner
                  trailing: isUserRide
                      ? const SizedBox.shrink()
                      : isJoined
                          ? ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to map screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RideMapScreen(ride: ride),
                                  ),
                                );
                              },
                              icon: Icon(Icons.map),
                              label: Text('View Map'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: ride.isFull
                                  ? null
                                  : () => joinRide(
                                      ride.id, joinedUsers, ride.seats, ride),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Join Ride'),
                            ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
