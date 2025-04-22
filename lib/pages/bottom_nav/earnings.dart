import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:green_ride/splash_screen.dart';

class Ratings extends StatelessWidget {
  const Ratings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Text(
                    'My Reviews',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Reviews list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ratings')
                    .where('driverId', isEqualTo: currentUser?.uid ?? '')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen1();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No reviews yet',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // Handle compliments which could be List<String> or String
                      String complimentsText = '';
                      if (data['compliments'] != null) {
                        if (data['compliments'] is List) {
                          complimentsText =
                              (data['compliments'] as List).join(', ');
                        } else if (data['compliments'] is String) {
                          complimentsText = data['compliments'];
                        }
                      }

                      return ReviewCard(
                        raterName: data['raterName'] ?? 'Anonymous',
                        rating: (data['rating'] as num?)?.toInt() ?? 0,
                        raterImageUrl: data['raterImage'] ??
                            'https://i.pinimg.com/736x/ea/3f/2f/ea3f2f888a79f5e19dfd5e368f3262b0.jpg',
                        reviewText: complimentsText,
                        timestamp: data['timestamp']?.toDate(),
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

class ReviewCard extends StatelessWidget {
  final String raterName;
  final int rating;
  final String reviewText;
  final String raterImageUrl;
  final DateTime? timestamp;

  const ReviewCard({
    Key? key,
    required this.raterName,
    required this.rating,
    required this.reviewText,
    required this.raterImageUrl,
    this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          // Profile picture
          ClipOval(
            child: Image.network(
              raterImageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // Review content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raterName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Star rating
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      color:
                          index < rating ? Colors.amber : Colors.grey.shade300,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Review text
                if (reviewText.isNotEmpty)
                  Text(
                    reviewText,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w400),
                  ),

                // Timestamp
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _formatDate(timestamp!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
