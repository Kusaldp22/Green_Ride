import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:green_ride/authentication/login.dart';
import 'package:green_ride/global/global_var.dart';
import 'package:green_ride/methods/common_methods.dart';
import 'package:green_ride/pages/offer_rides/add_rides.dart';
import 'package:green_ride/pages/bottom_nav/profile.dart';
import 'package:green_ride/pages/offer_rides/available_cars.dart';
import 'package:green_ride/service/notification.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController =
      Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  Position? currentPositionOfUser;
  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();
  String? userProfileImage;
  String username = "";
  String studentId = "";

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.requestPermission();
    saveFcmToken();
    getUserProfile();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show a snackbar or dialog
        print('Notification: ${message.notification!.title}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Navigate to chat screen if needed
    });
  }

  getUserProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No user logged in!");
        return;
      }

      DatabaseReference userRef =
          FirebaseDatabase.instance.ref().child("users").child(user.uid);

      DatabaseEvent event = await userRef.once();
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        Map userData = event.snapshot.value as Map;
        setState(() {
          userProfileImage = userData['profileImage'] ?? "";
          username = userData['username'] ?? "";
          studentId = userData['studentId'] ?? "";
        });
      } else {
        debugPrint("Invalid user data or profileImage missing.");
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  getCurrentLiveLocationOfUser() async {
    try {
      Position positionOfUser = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      currentPositionOfUser = positionOfUser;

      LatLng positionOfUserInLatLng = LatLng(
          currentPositionOfUser!.latitude, currentPositionOfUser!.longitude);

      CameraPosition cameraPosition = CameraPosition(
        target: positionOfUserInLatLng,
        zoom: 14.4746,
      );
      controllerGoogleMap
          ?.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      await getUserInfoAndCheckBlockStatus();
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  getUserInfoAndCheckBlockStatus() async {
    DatabaseReference newUserRef = FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(FirebaseAuth.instance.currentUser!.uid);

    await newUserRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        if ((snap.snapshot.value as Map)["blockStatus"] == "unblocked") {
          setState(() {
            username = (snap.snapshot.value as Map)["username"];
          });
        } else {
          FirebaseAuth.instance.signOut();
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const Login()));
          CommonMethods.showSnackBar("You are blocked", context);
        }
      } else {
        FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const Login()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: sKey,
        drawer: Container(
          width: 255,
          color: Colors.white,
          child: Drawer(
            backgroundColor: Colors.white,
            child: ListView(
              children: [
                // Drawer Header
                Container(
                  color: Colors.green.shade500,
                  height: 165,
                  child: DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(3), // Space for the border
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color.fromARGB(
                                  255, 6, 96, 199), // Border color
                              width: 3, // Border width
                            ),
                          ),
                          child: ClipOval(
                            child: Container(
                              width: 75,
                              height: 75,
                              color: Colors.grey[200], // Background color
                              child: userProfileImage != null &&
                                      userProfileImage!.isNotEmpty
                                  ? Image.network(
                                      userProfileImage!,
                                      width: 75,
                                      height: 75,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 65,
                                        );
                                      },
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 65,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 16,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              studentId,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const Divider(
                  height: 1,
                  color: Colors.grey,
                  thickness: 1,
                ),

                const SizedBox(
                  height: 12,
                ),

                // Drawer Body
                ListTile(
                  leading: const Icon(
                    Icons.car_repair_sharp,
                    color: Colors.grey,
                  ),
                  title: const Text(
                    "Add ride",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const AddRides();
                    }));
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.taxi_alert,
                    color: Colors.grey,
                  ),
                  title: const Text(
                    "Trips",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return AvailableRidesScreen(
                        startPoint: '',
                        destination: '',
                      );
                    }));
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person,
                    color: Colors.grey,
                  ),
                  title: const Text(
                    "Profile",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const ProfilePage();
                    }));
                  },
                ),
                const SizedBox(
                  height: 270,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.green,
                  ),
                  title: const Text(
                    "LogOut",
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return const Login();
                    }));
                  },
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Google map
            GoogleMap(
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              initialCameraPosition: goolglePlexInitialPosition,
              onMapCreated: (GoogleMapController mapController) {
                controllerGoogleMap = mapController;
                googleMapCompleterController.complete(controllerGoogleMap);
                getCurrentLiveLocationOfUser();
              },
            ),

            // Drawer button
            Positioned(
              top: 63,
              left: 22,
              child: GestureDetector(
                onTap: () {
                  sKey.currentState?.openDrawer();
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black,
                            blurRadius: 6,
                            spreadRadius: 0.5,
                            offset: Offset(0.7, 0.7))
                      ]),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: Icon(
                      Icons.menu,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),

            // Current Location Button
            Positioned(
              bottom: 120,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  getCurrentLiveLocationOfUser();
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black,
                            blurRadius: 6,
                            spreadRadius: 0.5,
                            offset: Offset(0.7, 0.7))
                      ]),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: Icon(
                      Icons.my_location,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
