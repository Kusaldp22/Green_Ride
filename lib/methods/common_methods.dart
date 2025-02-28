import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class CommonMethods {
  static void showSnackBar(String messageText, BuildContext context) {
    var snackBar = SnackBar(content: Text(messageText));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Check internet connection by making an HTTP request
  static Future<bool> checkInternetConnection(BuildContext context) async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'));

      if (result.statusCode == 200) {
        return true; // Internet is available
      } else {
        showSnackBar("No internet connection, please try again later!", context);
        return false;
      }
    } on SocketException catch (_) {
      showSnackBar("No internet connection, please try again!", context);
      return false;
    } catch (e) {
      showSnackBar("An error occurred. Please try again!", context);
      return false;
    }
  }
}
