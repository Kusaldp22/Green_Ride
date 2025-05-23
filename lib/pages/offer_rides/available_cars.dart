import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/pages/payments/confirm.dart';
import 'package:green_ride/pages/waiting_screen.dart';

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

  Future<List<RideModel>> fetchRides() async {
    Query query = FirebaseFirestore.instance
        .collection('offered_rides')
        .where('status', isNotEqualTo: 'completed');

    if (widget.startPoint.isNotEmpty) {
      query = query.where('start_point', isEqualTo: widget.startPoint);
    }

    if (widget.destination.isNotEmpty) {
      query = query.where('destination', isEqualTo: widget.destination);
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => RideModel.fromFirestore(doc))
        .toList();
  }

  Future<void> joinRide(String rideId, List<String>? joinedUsers, int seats,
      RideModel ride) async {
    if (currentUserId == null) return;

    joinedUsers ??= [];
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
            vehicleNumber: ride.vehicleNumber,
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

          final rides = (snapshot.data ?? [])
              .where((ride) => ride.status != 'completed')
              .toList();

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

              return FutureBuilder<double>(
                future: getAverageRating(ride.id),
                builder: (context, snapshot) {
                  final avgRating = snapshot.data?.toStringAsFixed(1) ?? "0.0";

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
                      title: Text(ride.carName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${ride.type} | $availableSeats seats left | ⭐ $avgRating'),
                          const SizedBox(height: 5),
                          Center(
                            child: Text(
                              "Rider's Friend's Details",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      const Color.fromARGB(255, 5, 111, 197)),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          if (ride.name != null && ride.name!.isNotEmpty)
                            Text('Name: ${ride.name!}',
                                style: const TextStyle(fontSize: 13)),
                          if (ride.gender != null && ride.gender!.isNotEmpty)
                            Text('Gender: ${ride.gender!}',
                                style: const TextStyle(fontSize: 13)),
                          if (ride.studentId != null &&
                              ride.studentId!.isNotEmpty)
                            Text('Student ID: ${ride.studentId!}',
                                style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      trailing: isUserRide
                          ? const SizedBox.shrink()
                          : isJoined
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RideMapScreen(ride: ride),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('View Map'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: ride.isFull
                                      ? null
                                      : () => joinRide(ride.id, joinedUsers,
                                          ride.seats, ride),
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
          );
        },
      ),
    );
  }
}
