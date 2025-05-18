import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:green_ride/methods/common_methods.dart';
import 'package:green_ride/onboard/profile.dart';
import 'package:green_ride/onboard/welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _restoreSignUpState();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  Future<void> _saveSignUpState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSigningUp', true);
    await prefs.setString('signup_name', _nameController.text);
    await prefs.setString('signup_email', _emailController.text);
    await prefs.setString('signup_mobile', _mobileController.text);
    await prefs.setString('signup_password', _passwordController.text);
  }

  Future<void> _restoreSignUpState() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isSigningUp') ?? false) {
      _nameController.text = prefs.getString('signup_name') ?? '';
      _emailController.text = prefs.getString('signup_email') ?? '';
      _mobileController.text = prefs.getString('signup_mobile') ?? '';
      _passwordController.text = prefs.getString('signup_password') ?? '';
    }
  }

  Future<void> _clearSignUpState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isSigningUp');
    await prefs.remove('signup_name');
    await prefs.remove('signup_email');
    await prefs.remove('signup_mobile');
    await prefs.remove('signup_password');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return; // Ensure fields are valid

    bool hasInternet = await CommonMethods.checkInternetConnection(context);
    if (!hasInternet) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? userFirebase = userCredential.user;

      if (userFirebase != null) {
        await userFirebase.sendEmailVerification();
        _showEmailVerificationDialog(userFirebase);
      }
    } catch (e) {
      CommonMethods.showSnackBar(e.toString(), context);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Verify Your Email"),
          content: const Text(
            "A verification email has been sent to your email address. Please verify it before proceeding.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                bool isVerified = await _checkEmailVerification(user);
                if (isVerified) {
                  _saveUserToDatabase(user);
                } else {
                  CommonMethods.showSnackBar(
                      "Please verify your email first.", context);
                }
              },
              child: const Text("I Verified"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkEmailVerification(User user) async {
    await user.reload(); // Refresh user data
    User? updatedUser = FirebaseAuth.instance.currentUser; // Get updated user
    return updatedUser?.emailVerified ?? false;
  }

  Future<void> _saveUserToDatabase(User userFirebase) async {
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref().child("users").child(userFirebase.uid);
    await userRef.set({
      "username": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "mobile": _mobileController.text.trim(),
      "uid": userFirebase.uid,
      "blockStatus": "unblocked",
    }).then((_) {
      if (mounted) {
        CommonMethods.showSnackBar('Signup Successful', context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    }).catchError((error) {
      CommonMethods.showSnackBar(
          "Database Error: ${error.toString()}", context);
    });
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
                  const SizedBox(height: 32),
                  _buildBackButton(),
                  const SizedBox(height: 32),
                  _buildTitle(),
                  const SizedBox(height: 32),
                  _buildTextFields(),
                  const SizedBox(height: 24),
                  _buildSignUpButton(),
                  const SizedBox(height: 16),
                  _buildTermsAndPrivacy(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromARGB(255, 6, 96, 199),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join Us',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text('Using Your Preferred',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text('Sign-up Method',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        _buildTextField(
          _nameController,
          'Name',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Name is required";
            }
            if (value.length < 3) {
              return "Name must be at least 3 characters";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _emailController,
          'University E-mail',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Email is required";
            }
            if (!value.trim().endsWith('@students.nsbm.ac.lk')) {
              return "Please use a valid university email address (e.g., name@students.nsbm.ac.lk)";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _mobileController,
          'Mobile Number',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Mobile number is required";
            }
            if (!RegExp(r'^\d{10}$').hasMatch(value)) {
              return "Enter a valid 10-digit mobile number";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildPasswordTextField(),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(hint),
      validator: validator, // Add validation logic here
    );
  }

  Widget _buildPasswordTextField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: _inputDecoration('Password').copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: _togglePasswordVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Password is required";
        }
        if (value.length < 6) {
          return "Password must be at least 6 characters long";
        }
        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$')
            .hasMatch(value)) {
          return "Password must contain letters and numbers";
        }
        return null;
      },
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 6, 96, 199),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Sign Up',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTermsAndPrivacy() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 12),
        children: [
          const TextSpan(text: 'By Signing up, You agree to the '),
          _buildLink('Terms of Service'),
          const TextSpan(text: ' and '),
          _buildLink('Privacy Policy'),
        ],
      ),
    );
  }

  TextSpan _buildLink(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(
          color: Color.fromARGB(255, 26, 211, 1), fontWeight: FontWeight.bold),
      recognizer: TapGestureRecognizer()..onTap = () {/* Handle tap */},
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
  }
}
