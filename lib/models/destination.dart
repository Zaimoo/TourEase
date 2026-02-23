import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Destination {
  final String id;
  final String name;
  final String shortDescription;
  final String longDescription;
  final String imageUrl;
  final String category;
  final String address;
  final String openHours;
  final int rating;
  final int entranceFee;
  final int fareCost;
  final GeoPoint coordinates;

  Destination({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.imageUrl,
    required this.address,
    required this.openHours,
    required this.rating,
    required this.entranceFee,
    required this.fareCost,
    required this.coordinates,
    required this.category,
  });

  LatLng get latLng => LatLng(coordinates.latitude, coordinates.longitude);

  factory Destination.fromJson(Map<String, dynamic> data, String id) {
    return Destination(
      id: id,
      name: data['name'],
      shortDescription: data['shortDescription'],
      longDescription: data['longDescription'],
      imageUrl: data['imageUrl'],
      address: data['address'],
      openHours: data['openHours'],
      rating: (data['rating'] as num).toInt(),
      entranceFee: (data['entranceFee'] as num).toInt(),
      fareCost: (data['fareCost'] as num).toInt(),
      coordinates: data['coordinates'],
      category:  data['category'],
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'imageUrl': imageUrl,
      'address': address,
      'openHours': openHours,
      'rating': rating,
      'entranceFee': entranceFee,
      'fareCost': fareCost,
      'coordinates': coordinates,
      'category': category,
    };
  }

}
