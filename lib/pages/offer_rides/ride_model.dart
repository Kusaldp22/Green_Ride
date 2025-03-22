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
  final List<String>? joinedUsers; // ✅ Ensure joinedUsers is a List<String>?

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
    this.joinedUsers, // Allow null values
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
      joinedUsers: (data['joined_users'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [], // ✅ Convert dynamic list to List<String>
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
      'joined_users': joinedUsers ?? [], // Ensure it's always a list
    };
  }
}
