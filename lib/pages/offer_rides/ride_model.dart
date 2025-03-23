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
  final String vehicleNumber; // Add vehicleNumber field
  final List<String>? joinedUsers; // ✅ Ensure joinedUsers is a List<String>?
  final String uniId;
  final String vehicleType;

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
    required this.vehicleNumber, // Add vehicleNumber to constructor
    this.joinedUsers, // Allow null values
    required this.uniId,
    required this.vehicleType,
  });

  // ✅ Check if the ride is full
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
      location: data['start_point'],
      imageUrl: 'assets/images/bmw.png',
      profileImageUrl: data['profileImage'] ?? '',
      vehicleNumber:
          data['vehicle_number'] ?? '', // Add vehicleNumber from Firestore
      joinedUsers: (data['joined_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [], // ✅ Convert dynamic list to List<String>
      uniId: data['driver_id'] ?? '',
      vehicleType: data['car_type'] ?? '',
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
      'vehicle_number': vehicleNumber, // Add vehicleNumber to Firestore
      'joined_users': joinedUsers ?? [], // Ensure it's always a list
      'driver_id': uniId,
      'car_type': vehicleType,
    };
  }
}
