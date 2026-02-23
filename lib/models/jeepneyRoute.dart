import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class JeepneyRoute {
  final String id;
  final String name;
  final List<GeoPoint> points;

  JeepneyRoute({
    required this.id,
    required this.name,
    required this.points,
  });

  factory JeepneyRoute.fromJson(Map<String, dynamic> data, String id) {
    return JeepneyRoute(
      id: id,
      name: data['name'] ?? '',
      points: List<GeoPoint>.from(data['points'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'points': points,
    };
  }

  List<LatLng> get latLngPoints {
    return points
        .map((geoPoint) => LatLng(geoPoint.latitude, geoPoint.longitude))
        .toList();
  }
}
