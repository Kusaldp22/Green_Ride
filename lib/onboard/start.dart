import 'package:flutter/material.dart';
import 'package:green_ride/onboard/onboard_1.dart';

void main() {
  runApp(const GreenRideApp());
}

class GreenRideApp extends StatelessWidget {
  const GreenRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GREEN RIDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Car Image
            Image.asset(
              'assets/images/splash.gif',
              height: 300,
              width: 300,
              fit: BoxFit.contain,
            ),

            // Logo Text
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'GREEN ',
                    style: TextStyle(
                      color: Color.fromARGB(255, 26, 211, 1),
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'RIDE',
                    style: TextStyle(
                      color: Color.fromARGB(255, 6, 96, 199),
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Underline
            Container(
              height: 2,
              width: 200,
              color: Color.fromARGB(255, 26, 211, 1),
              margin: const EdgeInsets.only(left: 24),
            ),

            const Spacer(flex: 3),

            // Start Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const OnboardScreen1()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 6, 96, 199),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'GREEN ',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'RIDE',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const Center(
        child: Text('Welcome to GREEN RIDE!'),
      ),
    );
  }
}
