import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'available_cars.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class PlanRideScreen extends StatefulWidget {
  const PlanRideScreen({Key? key}) : super(key: key);

  @override
  State<PlanRideScreen> createState() => _PlanRideScreenState();
}

class _PlanRideScreenState extends State<PlanRideScreen> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  // Location autocomplete properties
  var uuid = const Uuid();
  List<dynamic> startLocationSuggestions = [];
  List<dynamic> destinationLocationSuggestions = [];
  String startSessionToken = '';
  String destinationSessionToken = '';
  bool isSearchingStart = true; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
  }

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
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

  void selectLocation(String placeDescription, bool isStart) {
    if (isStart) {
      setState(() {
        startController.text = placeDescription;
        startLocationSuggestions = []; // Clear suggestions
        startSessionToken = '';
      });
    } else {
      setState(() {
        destinationController.text = placeDescription;
        destinationLocationSuggestions = []; // Clear suggestions
        destinationSessionToken = '';
      });
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  void clearAllSuggestions() {
    setState(() {
      startLocationSuggestions = [];
      destinationLocationSuggestions = [];
    });
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
            'Plan Your Ride',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Location Input Fields
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // Start Point Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
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
                              controller: startController,
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
                    // Destination Input
                    Container(
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
                  ],
                ),
              ),

              // Location suggestions
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )
              else if (startLocationSuggestions.isNotEmpty && isSearchingStart)
                Expanded(
                  child: Container(
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
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade300),
                      itemCount: startLocationSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            startLocationSuggestions[index]['description'],
                            style: const TextStyle(
                                color: Colors.black), // Custom font color
                          ),
                          onTap: () {
                            // Use Future.delayed to ensure the UI can update
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
                )
              else if (destinationLocationSuggestions.isNotEmpty &&
                  !isSearchingStart)
                Expanded(
                  child: Container(
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
                                color: Colors.black), // Custom font color
                          ),
                          onTap: () {
                            // Use Future.delayed to ensure the UI can update
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
                )
              else
                const Spacer(),

              // Search Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    clearAllSuggestions();
                    String start = startController.text.trim();
                    String destination = destinationController.text.trim();

                    if (start.isNotEmpty && destination.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AvailableRidesScreen(
                            startPoint: start,
                            destination: destination,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("Please enter both Start and Destination"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Search for Rides',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
}
