import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';

class ShareRideScreen extends StatefulWidget {
  const ShareRideScreen({super.key});

  @override
  State<ShareRideScreen> createState() => _ShareRideScreenState();
}

class _ShareRideScreenState extends State<ShareRideScreen> {
  int seatCapacity = 1;
  String? selectedCategory;
  String? selectedGender;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController startPointController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  Future<void> addRideToFirestore() async {
    if (startPointController.text.isEmpty ||
        destinationController.text.isEmpty ||
        selectedCategory == null ||
        selectedGender == null ||
        nameController.text.isEmpty ||
        studentIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String profileImageUrl = "";

      if (user != null) {
        DatabaseReference userRef = FirebaseDatabase.instance.ref().child("users").child(user.uid);
        DatabaseEvent event = await userRef.once();

        if (event.snapshot.value != null) {
          Map<String, dynamic> userData = Map<String, dynamic>.from(event.snapshot.value as Map);
          profileImageUrl = userData["profileImage"] ?? "";
        }
      }

      await FirebaseFirestore.instance.collection('offered_rides').add({
        'start_point': startPointController.text,
        'destination': destinationController.text,
        'seat_capacity': seatCapacity,
        'category': selectedCategory,
        'gender': selectedGender,
        'name': nameController.text,
        'student_id': studentIdController.text,
        'profileImage': profileImageUrl,
        'user_id': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride added successfully!')),
      );

      startPointController.clear();
      destinationController.clear();
      nameController.clear();
      studentIdController.clear();
      setState(() {
        seatCapacity = 1;
        selectedCategory = null;
        selectedGender = null;
      });

      Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offer a Ride to Your Friends',
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(controller: startPointController, label: 'Start Point', hintText: 'Enter Start Point', icon: Icons.navigation_outlined),
              const SizedBox(height: 16),
              _buildTextField(controller: destinationController, label: 'Destination', hintText: 'Enter Destination', icon: Icons.location_on_outlined),
              const SizedBox(height: 24),
              _buildSeatCapacity(),
              const SizedBox(height: 16),
              _buildDropdown(label: 'Category', value: selectedCategory, items: ['Boys', 'Girls'], onChanged: (value) => setState(() => selectedCategory = value)),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Ride Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdown(label: 'Gender', value: selectedGender, items: ['Male', 'Female', 'Other'], onChanged: (value) => setState(() => selectedGender = value)),
              const SizedBox(height: 16),
              _buildTextField(controller: nameController, label: 'Name', hintText: 'Enter your name'),
              const SizedBox(height: 16),
              _buildTextField(controller: studentIdController, label: 'Student ID', hintText: 'Enter your student ID'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: addRideToFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Add Ride',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hintText, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromARGB(255, 6, 96, 199)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(border: InputBorder.none, hintText: hintText, hintStyle: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatCapacity() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('Seat Capacity', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.grey),
            onPressed: () {
              if (seatCapacity > 1) {
                setState(() => seatCapacity--);
              }
            },
          ),
          Text('$seatCapacity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.grey),
            onPressed: () {
              if (seatCapacity < 4) {
                setState(() => seatCapacity++);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String label, required String? value, required List<String> items, required void Function(String?)? onChanged}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(label),
          value: value,
          isExpanded: true,
          items: items.map((String item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
