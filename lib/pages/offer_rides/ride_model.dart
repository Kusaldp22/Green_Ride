import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String id;
  final String userId;
  final String carName;
  final String type;
  final int seats;
  final double rating;
  final String location;
  final String imageUrl;
  final String profileImageUrl;
  final String vehicleNumber;
  final List<String>? joinedUsers;
  final String uniId;
  final String vehicleType;
  final String rideId;
  String status; // <-- ✅ NEW FIELD

  RideModel({
    required this.id,
    required this.userId,
    required this.carName,
    required this.type,
    required this.seats,
    required this.rating,
    required this.location,
    required this.imageUrl,
    required this.profileImageUrl,
    required this.vehicleNumber,
    this.joinedUsers,
    required this.uniId,
    required this.vehicleType,
    required this.rideId,
    this.status = 'pending', // <-- ✅ Default status
  });

  bool get isFull => (joinedUsers?.length ?? 0) >= seats;

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RideModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      carName: '${data['start_point']} to ${data['destination']}',
      type: data['category'] ?? 'Standard',
      seats: data['seat_capacity'] ?? 4,
      rating: (data['rating'] ?? 4.0).toDouble(),
      location: data['start_point'] ?? '',
      imageUrl: 'assets/images/bmw.png',
      profileImageUrl: data['profileImage'] ?? '',
      vehicleNumber: data['vehicle_number'] ?? '',
      joinedUsers: (data['joined_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      uniId: data['driver_id'] ?? '',
      vehicleType: data['car_type'] ?? '',
      rideId: doc.id,
      status: data['status'] ?? 'pending', // <-- ✅ Firestore status field
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'start_point': location,
      'destination': carName,
      'category': type,
      'seat_capacity': seats,
      'rating': rating,
      'profileImage': profileImageUrl,
      'vehicle_number': vehicleNumber,
      'joined_users': joinedUsers ?? [],
      'driver_id': uniId,
      'car_type': vehicleType,
      'ride_id': rideId,
      'status': status, // <-- ✅ Include status in Firestore
    };
  }
}
