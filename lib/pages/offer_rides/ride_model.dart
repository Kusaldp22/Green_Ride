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
  });

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RideModel(
      id: doc.id, // ✅ Use Firestore document ID
      userId: data['user_id'] ?? '', // 🔹 Ensure this matches Firestore's actual field name
      carName: '${data['start_point']} to ${data['destination']}',
      type: data['category'] ?? 'Standard',
      seats: data['seat_capacity'] ?? 4,
      rating: (data['rating'] ?? 4.0).toDouble(),
      location: data['start_point'],
      imageUrl: 'assets/images/bmw.png', // Default placeholder
      profileImageUrl: data['profileImage'] ?? '', // Profile image
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, // Ensure Firestore saves the correct field
      'start_point': location,
      'destination': carName,
      'category': type,
      'seat_capacity': seats,
      'rating': rating,
      'profileImage': profileImageUrl,
    };
  }
}
