import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';
import 'package:green_ride/pages/offer_rides/ride_model.dart';
import 'package:green_ride/pages/payments/paypal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class ConfirmationScreen extends StatefulWidget {
  final RideModel ride;
  final String vehicleNumber;

  const ConfirmationScreen({
    Key? key,
    required this.ride,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  _ConfirmationScreenState createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  double totalAmount = 0.0;
  bool isLoading = true;
  String? selectedPaymentMethod;

  double avgRating = 0.0;
  int reviewCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTotalAmount();
      _fetchRatingAndReviewCount();
    });
  }

  Future<void> _fetchRatingAndReviewCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ratings')
        .where('rideId', isEqualTo: widget.ride.id)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        avgRating = 0.0;
        reviewCount = 0;
      });
      return;
    }

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc['rating'] ?? 0).toDouble();
    }

    setState(() {
      avgRating = total / snapshot.docs.length;
      reviewCount = snapshot.docs.length;
    });
  }

  Future<Map<String, dynamic>> _createPayPalPayment(double amount) async {
    // Step 1: Get OAuth token
    final String clientId = dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
    final String secret = dotenv.env['PAYPAL_SECRET'] ?? '';

    try {
      // Get access token first
      final tokenResponse = await http.post(
        Uri.parse('https://api.sandbox.paypal.com/v1/oauth2/token'),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$secret'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );

      if (tokenResponse.statusCode != 200) {
        print('Token error: ${tokenResponse.body}');
        return {'status': 'error', 'error': 'Failed to get auth token'};
      }

      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];

      // Step 2: Create payment
      final paymentResponse = await http.post(
        Uri.parse('https://api.sandbox.paypal.com/v1/payments/payment'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'intent': 'sale',
          'payer': {
            'payment_method': 'paypal',
          },
          'transactions': [
            {
              'amount': {
                'total': amount.toStringAsFixed(2),
                'currency': 'USD',
              },
              'description': 'Green Ride payment',
            },
          ],
          'redirect_urls': {
            'return_url':
                'https://example.com/success', // Replace with your app's success URL
            'cancel_url':
                'https://example.com/cancel', // Replace with your app's cancel URL
          },
        }),
      );

      if (paymentResponse.statusCode == 201) {
        final paymentData = json.decode(paymentResponse.body);

        // Extract approval URL
        String approvalUrl = '';
        for (var link in paymentData['links']) {
          if (link['rel'] == 'approval_url') {
            approvalUrl = link['href'];
            break;
          }
        }

        return {
          'status': 'success',
          'paymentId': paymentData['id'],
          'approvalUrl': approvalUrl,
        };
      } else {
        print('Payment error: ${paymentResponse.body}');
        return {
          'status': 'error',
          'error': 'Payment creation failed',
          'details': paymentResponse.body
        };
      }
    } catch (e) {
      print('Exception: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<double> calculateDistance(
      String startPoint, String destination, String apiKey) async {
    final String baseUrl =
        'https://maps.googleapis.com/maps/api/distancematrix/json';
    final String url =
        '$baseUrl?origins=$startPoint&destinations=$destination&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        // Get the distance in meters
        int distanceInMeters =
            data['rows'][0]['elements'][0]['distance']['value'];
        // Convert meters to kilometers
        double distanceInKm = distanceInMeters / 1000;
        return distanceInKm;
      } else {
        throw Exception('Failed to calculate distance: ${data['status']}');
      }
    } else {
      throw Exception('Failed to load data');
    }
  }

  double calculateTotalAmount(double distanceInKm, double costPerKm) {
    return ((distanceInKm * costPerKm) / widget.ride.seats);
  }

  Future<void> _calculateTotalAmount() async {
    final String apiKey = dotenv.env['API_KEY'] ?? '';
    const double costPerKm = 40; // Cost per kilometer

    try {
      double distanceInKm = await calculateDistance(
        widget.ride.location,
        widget.ride.carName.split(' to ')[1],
        apiKey,
      );

      setState(() {
        totalAmount = calculateTotalAmount(distanceInKm, costPerKm);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to calculate distance: $e')),
      );
    }
  }

  String _getVehicleImage(String vehicleType) {
    if (vehicleType.isEmpty) {
      return 'assets/images/other.png';
    }
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return 'assets/images/car.png';
      case 'motorcycle':
        return 'assets/images/motorbike.png';
      case 'jeep':
        return 'assets/images/jeep.png';
      case 'other':
        return 'assets/images/other.png';
      default:
        return 'assets/images/other.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String destination = widget.ride.carName.contains(' to ')
        ? widget.ride.carName.split(' to ')[1]
        : 'Destination';

    final int availableSeats =
        widget.ride.seats - (widget.ride.joinedUsers?.length ?? 0);

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
          'Share for Ride',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Route points
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ride.location,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          destination,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Car selection card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicleNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Student ID: ${widget.ride.uniId}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${avgRating.toStringAsFixed(1)} ($reviewCount reviews)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      _getVehicleImage(widget.ride.vehicleType),
                      width: 80,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Charges section
              const Text(
                'Charge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          '\Rs.${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),

              const SizedBox(height: 24),

              // Payment methods
              const Text(
                'Select payment method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // PayPal option
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedPaymentMethod = 'paypal';
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedPaymentMethod == 'paypal'
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: selectedPaymentMethod == 'paypal'
                        ? Colors.green.shade50
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/paypal.png',
                          width: 40, height: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'PayPal',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (selectedPaymentMethod == 'paypal')
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedPaymentMethod = 'cash';
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedPaymentMethod == 'cash'
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: selectedPaymentMethod == 'cash'
                        ? Colors.green.shade50
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/cash.png',
                          width: 40, height: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cash',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (selectedPaymentMethod == 'cash')
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton(
                  onPressed: selectedPaymentMethod == null
                      ? null
                      : () async {
                          try {
                            setState(() => isLoading = true);

                            // Check if user is logged in
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User not logged in')),
                              );
                              return;
                            }
                            // Inside your ElevatedButton onPressed function
                            if (selectedPaymentMethod == 'paypal') {
                              try {
                                // Show loading indicator
                                setState(() => isLoading = true);

                                // Create payment in PayPal
                                final response =
                                    await _createPayPalPayment(totalAmount);

                                if (response['status'] == 'success') {
                                  // Launch the PayPal approval URL in a WebView
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PayPalWebView(
                                        approvalUrl: response['approvalUrl'],
                                        paymentId: response['paymentId'],
                                      ),
                                    ),
                                  );

                                  if (result == 'success') {
                                    // Payment was successful, update Firestore
                                    await FirebaseFirestore.instance
                                        .collection('payments')
                                        .add({
                                      'userId': FirebaseAuth
                                          .instance.currentUser!.uid,
                                      'driverId': widget.ride.uniId,
                                      'vehicleNumber': widget.vehicleNumber,
                                      'paymentMethod': 'paypal',
                                      'amount': totalAmount,
                                      'timestamp': Timestamp.now(),
                                      'pickupLocation': widget.ride.location,
                                      'destination':
                                          widget.ride.carName.split(' to ')[1],
                                      'status': 'completed',
                                      'paymentId': response['paymentId'],
                                      'rideId': widget.ride.rideId,
                                    });

                                    // Show success message
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Payment Successful'),
                                        content: const Text(
                                            'Your payment was completed successfully.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                  context); // Close dialog
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          const HomePage())); // Close current screen
                                            },
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    // Payment was cancelled or failed
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Payment was not completed')),
                                    );
                                  }
                                } else {
                                  // Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error: ${response['error']}')),
                                  );
                                }

                                setState(() => isLoading = false);
                              } catch (e) {
                                setState(() => isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } else if (selectedPaymentMethod == 'cash') {
                              // Handle cash payment
                              try {
                                // Add payment record to Firestore
                                await FirebaseFirestore.instance
                                    .collection('payments')
                                    .add({
                                  'userId':
                                      FirebaseAuth.instance.currentUser!.uid,
                                  'driverId': widget.ride.uniId,
                                  'vehicleNumber': widget.vehicleNumber,
                                  'paymentMethod': 'cash',
                                  'amount': totalAmount,
                                  'timestamp': Timestamp.now(),
                                  'pickupLocation': widget.ride.location,
                                  'destination':
                                      widget.ride.carName.split(' to ')[1],
                                  'status':
                                      'pending', // Cash payment is pending until received
                                  'rideId': widget.ride.rideId,
                                });

                                // Show success message
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Ride Confirmed'),
                                    content: const Text(
                                        'Your ride has been confirmed. Please pay the driver in cash.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          // Navigator.pop(context); // Close dialog
                                          Navigator.push(context,
                                              MaterialPageRoute(
                                                  builder: (context) {
                                            return const HomePage();
                                          })); // Close current screen
                                        },
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }

                            setState(() => isLoading = false);
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  child: const Text(
                    'Confirm Ride',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
