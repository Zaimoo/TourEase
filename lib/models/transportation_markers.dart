import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransportationMarkers {
  final String id;
  final String vehicleType;
  final GeoPoint coordinates;

  TransportationMarkers(
      {required this.id, required this.vehicleType, required this.coordinates});

  LatLng get latLng => LatLng(coordinates.latitude, coordinates.longitude);

  factory TransportationMarkers.fromJson(Map<String, dynamic> data, String id) {
    return TransportationMarkers(
      id: id,
      vehicleType: (data['vehicleType'] as String?) ?? 'unknown',
      coordinates: data['coordinates'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleType': vehicleType,
      'coordinates': coordinates,
    };
  }
}
