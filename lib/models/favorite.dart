import 'package:cloud_firestore/cloud_firestore.dart';

class Favorite {
  final String id; // Usually the destination ID
  final String name;
  final GeoPoint coordinates;

  Favorite({
    required this.id,
    required this.name,
    required this.coordinates,

  });

  factory Favorite.fromJson(Map<String, dynamic> data, String id) {
    return Favorite(
      id: id,
      name: data['name'] ?? '',
      coordinates: data['coordinates'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'coordinates': coordinates,
    };
  }
}
