import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String destinationName;
  final String destinationId;
  final DateTime visitedDate;
  final String? imageUrl;
  final double? distance;
  final String? transportMode;

  Trip({
    required this.id,
    required this.destinationName,
    required this.destinationId,
    required this.visitedDate,
    this.imageUrl,
    this.distance,
    this.transportMode,
  });

  factory Trip.fromJson(Map<String, dynamic> json, String id) {
    return Trip(
      id: id,
      destinationName: json['destinationName'] ?? '',
      destinationId: json['destinationId'] ?? '',
      visitedDate: (json['visitedDate'] as Timestamp).toDate(),
      imageUrl: json['imageUrl'],
      distance: json['distance']?.toDouble(),
      transportMode: json['transportMode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destinationName': destinationName,
      'destinationId': destinationId,
      'visitedDate': Timestamp.fromDate(visitedDate),
      'imageUrl': imageUrl,
      'distance': distance,
      'transportMode': transportMode,
    };
  }
}
