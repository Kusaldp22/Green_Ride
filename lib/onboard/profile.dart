import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:green_ride/pages/bottom_nav/dashboard.dart';
import 'package:green_ride/splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  String? _selectedVehicleType;
  File? _imageFile;
  String? _profileImageUrl;

  final List<String> _vehicleTypes = ['Car', 'Motorcycle', 'Jeep', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _mobileController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child("users").child(user.uid);

      DatabaseEvent event = await userRef.once();
      if (event.snapshot.value != null) {
        Map<String, dynamic> userData =
            Map<String, dynamic>.from(event.snapshot.value as Map);

        setState(() {
          _nameController.text = userData["username"] ?? "";
          _emailController.text = userData["email"] ?? "";
          _mobileController.text = userData["mobile"] ?? "";
          _selectedVehicleType = userData["vehicleType"] ?? null;
          _vehicleNumberController.text = userData["vehicleNumber"] ?? "";
          _studentIdController.text = userData["studentId"] ?? "";
          _profileImageUrl = userData["profileImage"] ?? "";
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Show splash screen as a dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SplashScreen1(),
    );

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child("users").child(user.uid);

      if (_imageFile != null) {
        _profileImageUrl = await _uploadProfileImage(user.uid);
      }

      Map<String, dynamic> userData = {
        "username": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "mobile": _mobileController.text.trim(),
        "studentId": _studentIdController.text.trim(),
        "profileImage": _profileImageUrl,
      };

      bool isVehicleOwner =
          _selectedVehicleType != null && _selectedVehicleType!.isNotEmpty;

      if (isVehicleOwner) {
        userData["vehicleType"] = _selectedVehicleType;
        userData["vehicleNumber"] = _vehicleNumberController.text.trim();
      }

      await userRef.update(userData).then((_) {
        // Hide splash screen
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  isVehicleOwner ? const Dashboard() : const HomePage(),
            ),
          );
        }
      }).catchError((error) {
        // Hide splash screen
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error.toString()}")),
        );
      });
    } else {
      // Hide splash screen if user is null
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<String> _uploadProfileImage(String uid) async {
    Reference storageRef =
        FirebaseStorage.instance.ref().child("profileImages").child("$uid.jpg");
    UploadTask uploadTask = storageRef.putFile(_imageFile!);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  void _chooseImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (_profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty)
                                  ? NetworkImage(_profileImageUrl!)
                                      as ImageProvider
                                  : const AssetImage(
                                      "assets/images/profile.png"),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 26, 211, 1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: _chooseImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(_nameController, 'Name', Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(
                      _emailController, 'University E-mail', Icons.email,
                      enabled: false),
                  const SizedBox(height: 16),
                  _buildTextField(
                      _studentIdController, 'Student Id Number', Icons.numbers),
                  const SizedBox(height: 16),
                  _buildTextField(
                      _mobileController, 'Mobile Number', Icons.phone,
                      enabled: false),
                  const SizedBox(height: 24),
                  const Text(
                    'If You Own a Vehicle, Please Fill Below',
                    style: TextStyle(
                      color: Color.fromARGB(255, 26, 211, 1),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    items: _vehicleTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_vehicleNumberController, 'Vehicle Number',
                      Icons.car_rental),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
