import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String destinationName;
  final String destinationId;
  final DateTime visitedDate;
  final String? imageUrl;
  final double? distance;
  final String? transportMode;

  /// True only if the user's GPS position was confirmed inside the
  /// destination geofence (and not mocked) when the trip completed.
  /// Reviews are gated on this flag to prevent paid/remote reviews.
  final bool verifiedOnSite;

  Trip({
    required this.id,
    required this.destinationName,
    required this.destinationId,
    required this.visitedDate,
    this.imageUrl,
    this.distance,
    this.transportMode,
    this.verifiedOnSite = false,
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
      // Trips recorded before on-site verification existed have no
      // `verifiedOnSite` field at all. Grandfather those legacy trips as
      // verified so existing users aren't locked out of reviewing. New trips
      // always write the field explicitly, so a present `false` is a real
      // failed on-site check and still correctly blocks reviewing.
      verifiedOnSite: json.containsKey('verifiedOnSite')
          ? (json['verifiedOnSite'] ?? false)
          : true,
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
      'verifiedOnSite': verifiedOnSite,
    };
  }
}
