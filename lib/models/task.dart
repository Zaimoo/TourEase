import 'package:google_maps_flutter/google_maps_flutter.dart';

class Task {
  final String name;            // e.g. "Walk", "Ride Habal", "Transfer"
  final String shortDescription;
  final String longDescription;
  final LatLng target;          // Target location for this task
  final String? transportMode;  // Optional: "walk", "habal", "jeepney"

  Task({
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.target,
    this.transportMode,
  });
}
