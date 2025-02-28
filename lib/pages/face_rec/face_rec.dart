import 'package:flutter/material.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class VerifyIdentityScreen extends StatefulWidget {
  const VerifyIdentityScreen({super.key});

  @override
  State<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends State<VerifyIdentityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isFaceAvailable = false;
  bool _isFingerprintAvailable = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);

    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    try {
      // Request necessary permissions
      await Permission.camera.request();
      await Permission.sensors.request();

      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      setState(() {
        _canCheckBiometrics = canCheck;
        _availableBiometrics = availableBiometrics;
      });

      print('Can check biometrics: $canCheck');
      print('Device supported: $isDeviceSupported');
      print('Available biometrics: $_availableBiometrics');
    } on PlatformException catch (e) {
      print('Error initializing biometrics: ${e.message}');
    }
  }

  Future<void> _authenticate() async {
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Please scan to verify your identity',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true, // Shows system dialogs on failure
        ),
      );

      if (authenticated && mounted) {
        // Authentication successful, navigate to Home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomePage()), // Replace HomePage() with your actual home screen widget
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed! Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFaceId = _availableBiometrics.contains(BiometricType.face) ||
        _availableBiometrics.contains(BiometricType.strong);
    final hasFingerprint =
        _availableBiometrics.contains(BiometricType.fingerprint) ||
            _availableBiometrics.contains(BiometricType.strong);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromARGB(255, 6, 96, 199),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Verify your Identity',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Using Biometrics',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/face.gif',
                        fit: BoxFit.contain,
                      ),
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: FaceRecognitionPainter(
                              progress: _animation.value,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: hasFaceId ? _authenticate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.face, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      hasFaceId ? 'Scan My Face' : 'Face ID Not Available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: hasFingerprint ? _authenticate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 6, 96, 199),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      hasFingerprint
                          ? 'Scan My Fingerprint'
                          : 'Fingerprint Not Available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// [Previous FaceRecognitionPainter class remains the same]
class FaceRecognitionPainter extends CustomPainter {
  final double progress;

  FaceRecognitionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the actual image bounds (assuming the image is centered)
    final imageWidth =
        size.width * 0.8; // Adjust these values based on your image
    final imageHeight = size.height * 0.8;
    final imageLeft = (size.width - imageWidth) / 2;
    final imageTop = (size.height - imageHeight) / 2;
    final imageRect =
        Rect.fromLTWH(imageLeft, imageTop, imageWidth, imageHeight);

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw scanning line only within image bounds
    final scanLineY = imageTop + (imageHeight * progress);
    canvas.drawLine(
      Offset(imageLeft, scanLineY),
      Offset(imageLeft + imageWidth, scanLineY),
      paint..color = Colors.blue.withOpacity(0.8),
    );

    // Draw face detection rectangle within image bounds
    final rect = Rect.fromLTWH(
      imageLeft + imageWidth * 0.2,
      imageTop + imageHeight * 0.2,
      imageWidth * 0.6,
      imageHeight * 0.6,
    );
    canvas.drawRect(rect, paint);

    // Draw corner markers
    final cornerLength = imageWidth * 0.1;
    final corners = [
      // Top left
      [
        Offset(rect.left, rect.top + cornerLength),
        Offset(rect.left, rect.top),
        Offset(rect.left + cornerLength, rect.top)
      ],
      // Top right
      [
        Offset(rect.right - cornerLength, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + cornerLength)
      ],
      // Bottom right
      [
        Offset(rect.right, rect.bottom - cornerLength),
        Offset(rect.right, rect.bottom),
        Offset(rect.right - cornerLength, rect.bottom)
      ],
      // Bottom left
      [
        Offset(rect.left + cornerLength, rect.bottom),
        Offset(rect.left, rect.bottom),
        Offset(rect.left, rect.bottom - cornerLength)
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint..color = Colors.blue);
      canvas.drawLine(corner[1], corner[2], paint);
    }

    // Draw dots for facial features within image bounds
    final dotPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final features = [
      Offset(imageLeft + imageWidth * 0.4,
          imageTop + imageHeight * 0.35), // Left eye
      Offset(imageLeft + imageWidth * 0.6,
          imageTop + imageHeight * 0.35), // Right eye
      Offset(
          imageLeft + imageWidth * 0.5, imageTop + imageHeight * 0.45), // Nose
      Offset(
          imageLeft + imageWidth * 0.5, imageTop + imageHeight * 0.55), // Mouth
    ];

    for (final feature in features) {
      canvas.drawCircle(feature, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(FaceRecognitionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
