import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/pages/bottom_nav/dashboard.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import

class ShareRideScreen extends StatefulWidget {
  const ShareRideScreen({super.key});

  @override
  State<ShareRideScreen> createState() => _ShareRideScreenState();
}

class _ShareRideScreenState extends State<ShareRideScreen> {
  int seatCapacity = 1;
  String? selectedCategory;
  String? _selectedVehicleType;
  String? selectedGender;
  String? studentId;
  double startLat = 0.0;
  double startLng = 0.0;
  double endLat = 0.0;
  double endLng = 0.0;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController startPointController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  // Location autocomplete properties
  var uuid = const Uuid();
  List<dynamic> startLocationSuggestions = [];
  List<dynamic> destinationLocationSuggestions = [];
  String startSessionToken = '';
  String destinationSessionToken = '';
  bool isSearchingStart = true; // To track which field is being searched
  bool _isLoading = false;

  @override
  void dispose() {
    startPointController.dispose();
    destinationController.dispose();
    nameController.dispose();
    studentIdController.dispose();
    super.dispose();
  }

  // This will be called manually when needed rather than using a listener
  Future<void> getSuggestions(String input, bool isStart) async {
    if (input.isEmpty) {
      setState(() {
        if (isStart) {
          startLocationSuggestions = [];
        } else {
          destinationLocationSuggestions = [];
        }
      });
      return;
    }

    // Generate session token if empty
    if (isStart && startSessionToken.isEmpty) {
      startSessionToken = uuid.v4();
    } else if (!isStart && destinationSessionToken.isEmpty) {
      destinationSessionToken = uuid.v4();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String apiKey = dotenv.env['API_KEY'] ?? '';
      const String baseUrl =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json";

      String sessionToken =
          isStart ? startSessionToken : destinationSessionToken;
      String requestUrl =
          '$baseUrl?input=$input&key=$apiKey&sessiontoken=$sessionToken';

      var response = await http.get(Uri.parse(requestUrl));
      var data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        setState(() {
          if (isStart) {
            startLocationSuggestions = data['predictions'];
          } else {
            destinationLocationSuggestions = data['predictions'];
          }
          _isLoading = false;
        });
      } else {
        if (kDebugMode) {
          print(
              "Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}");
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception: ${e.toString()}");
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> selectLocation(String placeDescription, bool isStart) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String apiKey = dotenv.env['API_KEY'] ?? '';
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent(placeDescription)}&inputtype=textquery&fields=geometry&key=$apiKey',
        ),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'OK') {
        final location = data['candidates'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];

        if (isStart) {
          setState(() {
            startPointController.text = placeDescription;
            startLat = lat;
            startLng = lng;
            startLocationSuggestions = [];
          });
        } else {
          setState(() {
            destinationController.text = placeDescription;
            endLat = lat;
            endLng = lng;
            destinationLocationSuggestions = [];
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get coordinates for location')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting coordinates: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      FocusScope.of(context).unfocus();
    }
  }

  void clearAllSuggestions() {
    setState(() {
      startLocationSuggestions = [];
      destinationLocationSuggestions = [];
    });
  }

  Future<void> addRideToFirestore() async {
    clearAllSuggestions();

    if (startPointController.text.isEmpty ||
        destinationController.text.isEmpty ||
        selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String profileImageUrl = "";
      String vehicleNumber = "No Vehicle";
      String uniId = "";
      String vehicleType = "";

      if (user != null) {
        // Fetch profile image, vehicle number, and uniId from Realtime Database
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref().child("users").child(user.uid);
        DatabaseEvent event = await userRef.once();

        if (event.snapshot.value != null) {
          Map<String, dynamic> userData =
              Map<String, dynamic>.from(event.snapshot.value as Map);
          profileImageUrl = userData["profileImage"] ?? "";
          vehicleNumber = userData["vehicleNumber"] ?? "No Vehicle";
          uniId = userData["studentId"] ?? "";
          vehicleType = userData["vehicleType"] ?? "";
        }
      }

      // Add ride to Firestore
      await FirebaseFirestore.instance.collection('offered_rides').add({
        'start_point': startPointController.text,
        'destination': destinationController.text,
        'seat_capacity': seatCapacity,
        'category': selectedCategory,
        'gender': selectedGender ?? '',
        'name': nameController.text.isEmpty ? null : nameController.text,
        'profileImage': profileImageUrl,
        'vehicle_number': vehicleNumber,
        'driver_id': uniId,
        'user_id': user?.uid,
        'student_id':
            studentIdController.text.isEmpty ? null : studentIdController.text,
        'car_type': vehicleType,
        'start_location': GeoPoint(startLat, startLng),
        'end_location': GeoPoint(endLat, endLng),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
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

      if (vehicleType.isNotEmpty || vehicleNumber != "No Vehicle") {
        // User is a vehicle owner, redirect to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
        );
      } else {
        // User is not a vehicle owner, redirect to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        clearAllSuggestions();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromARGB(255, 6, 96, 199),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                clearAllSuggestions();
                Navigator.pop(context);
              },
            ),
          ),
          title: const Text(
            'Offer a Ride to Your Friends',
            style: TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Point Input with Autocomplete
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: startPointController,
                          decoration: const InputDecoration(
                            hintText: 'Enter Start Point',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          onTap: () {
                            setState(() {
                              isSearchingStart = true;
                              // Clear other suggestions
                              destinationLocationSuggestions = [];
                            });
                          },
                          onChanged: (value) {
                            // Call for suggestions on text change
                            getSuggestions(value, true);
                          },
                        ),
                      ),
                      const Icon(Icons.my_location, color: Colors.grey),
                    ],
                  ),
                ),
                if (_isLoading && isSearchingStart)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (startLocationSuggestions.isNotEmpty &&
                    isSearchingStart)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade300),
                      itemCount: startLocationSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            startLocationSuggestions[index]['description'],
                            style: const TextStyle(
                                color: Colors
                                    .black), // Custom color for suggestion text
                          ),
                          onTap: () {
                            // Use Future.microtask to ensure the UI can update
                            Future.microtask(() {
                              selectLocation(
                                  startLocationSuggestions[index]
                                      ['description'],
                                  true);
                            });
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // Destination Input with Autocomplete
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: destinationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter Destination',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          onTap: () {
                            setState(() {
                              isSearchingStart = false;
                              // Clear other suggestions
                              startLocationSuggestions = [];
                            });
                          },
                          onChanged: (value) {
                            // Call for suggestions on text change
                            getSuggestions(value, false);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading && !isSearchingStart)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (destinationLocationSuggestions.isNotEmpty &&
                    !isSearchingStart)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade300),
                      itemCount: destinationLocationSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            destinationLocationSuggestions[index]
                                ['description'],
                            style: const TextStyle(
                                color: Colors
                                    .black), // Custom color for suggestion text
                          ),
                          onTap: () {
                            // Use Future.microtask to ensure the UI can update
                            Future.microtask(() {
                              selectLocation(
                                  destinationLocationSuggestions[index]
                                      ['description'],
                                  false);
                            });
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),
                _buildSeatCapacity(),
                const SizedBox(height: 16),
                _buildDropdown(
                    label: 'Category',
                    value: selectedCategory,
                    items: ['Boys', 'Girls'],
                    onChanged: (value) =>
                        setState(() => selectedCategory = value)),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Ride Status',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                    label: 'Gender',
                    value: selectedGender,
                    items: ['Male', 'Female', 'Other'],
                    onChanged: (value) =>
                        setState(() => selectedGender = value)),
                const SizedBox(height: 16),
                _buildTextField(
                    controller: nameController,
                    label: 'Name',
                    hintText: 'Enter your name'),
                const SizedBox(height: 16),
                _buildTextField(
                    controller: studentIdController,
                    label: 'Student ID',
                    hintText: 'Enter your student ID'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: addRideToFirestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Add Ride',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? label,
    IconData? icon,
    Color textColor = Colors.black,
  }) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: const Color.fromARGB(255, 6, 96, 199)),
          if (icon != null) const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatCapacity() {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('Seat Capacity',
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.grey),
            onPressed: () {
              if (seatCapacity > 1) {
                setState(() => seatCapacity--);
              }
            },
          ),
          Text('$seatCapacity',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    Color selectedItemColor =
        Colors.black87, // Added selected item color parameter
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            label,
            style: const TextStyle(
                color: Colors.black), // Make sure the label text is visible
          ),
          value: value,
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  color: Colors.grey, // Set dropdown items text color
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          selectedItemBuilder: (BuildContext context) {
            return items.map<Widget>((String item) {
              return Text(
                item,
                style: TextStyle(
                    color:
                        selectedItemColor), // Apply font color to selected item
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
