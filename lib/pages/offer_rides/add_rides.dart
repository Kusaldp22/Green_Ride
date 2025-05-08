import 'package:flutter/material.dart';
import 'package:green_ride/pages/offer_rides/offer_ride.dart';
import 'package:green_ride/pages/offer_rides/share_ride.dart';

class AddRides extends StatelessWidget {
  const AddRides({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Choose Your Ride Experience',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 50),

              // Share Ride Option
              _buildRideCard(
                title: 'Share Ride',
                icon: Icons.people_outlined,
                backgroundColor: Color(0xFFE8F5E9),
                borderColor: Colors.green.shade500,
                iconColor: Colors.green.shade500,
                onTap: () {
                  // Handle Share Ride tap
                  Navigator.push(context, MaterialPageRoute(builder:  (context) => PlanRideScreen()));
                },
              ),

              const SizedBox(height: 20),

              // Offer Ride Option
              _buildRideCard(
                title: 'Offer Ride',
                icon: Icons.directions_car_outlined,
                backgroundColor: Color(0xFFE3F2FD),
                borderColor: Color.fromARGB(255, 6, 96, 199),
                iconColor: Color.fromARGB(255, 6, 96, 199),
                onTap: () {
                  // Handle Offer Ride tap
                  Navigator.push(context, MaterialPageRoute(builder:  (context) => ShareRideScreen()));
                  
                },
              ),

              const Spacer(),

              // Bottom Navigation Bar
              
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  
}
