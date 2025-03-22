import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:green_ride/authentication/login.dart';
import 'package:green_ride/pages/bottom_nav/dashboard.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';
import 'package:green_ride/splash_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await Permission.locationWhenInUse.isDenied.then((valueOfPermission) {
    if (valueOfPermission) {
      Permission.locationWhenInUse.request();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  Widget _initialScreen = const SplashScreen1();

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is not logged in → Show login screen
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _initialScreen = const Login();
        });
      });
      return;
    }

    // Fetch user data from Realtime Database
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref().child("users").child(user.uid);

    userRef.once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> userData =
            event.snapshot.value as Map<dynamic, dynamic>;

        bool isLiftOfferer = userData.containsKey('vehicleNumber') &&
            userData.containsKey('vehicleType');

        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _initialScreen =
                isLiftOfferer ? const Dashboard() : const HomePage();
          });
        });
      } else {
        // If user data is missing, log out
        FirebaseAuth.instance.signOut();
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _initialScreen = const Login();
          });
        });
      }
    }).catchError((error) {
      // If error occurs, go to login
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _initialScreen = const Login();
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _initialScreen;
  }
}
