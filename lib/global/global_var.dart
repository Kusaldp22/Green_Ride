import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String username = '';
String studentId = '';

String? googleMapKey = dotenv.env['API_KEY'];

const CameraPosition goolglePlexInitialPosition = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);
