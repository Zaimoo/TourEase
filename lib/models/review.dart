import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String name;
  final String email;
  final String destination;
  final String title;
  final String review;
  final double rating;
  final String profileUrl;

  /// Cloudinary URLs of photos the reviewer attached. Empty for text-only
  /// reviews.
  final List<String> photoUrls;

  /// When the review was submitted. Nullable so legacy reviews (written before
  /// this field existed) still parse; they sort last.
  final DateTime? createdAt;

  /// Moderation state set by an admin. New reviews start [statusPending] and
  /// must be approved by an admin to become verified. A declined review is
  /// [statusRejected]: it stays unverified and leaves the verification queue
  /// but is kept in Firestore.
  final String status;

  /// A review is "verified" only once an admin approves it. Derived from
  /// [status] so the two can never disagree.
  bool get verified => status == statusApproved;

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  Review({
    required this.id,
    required this.name,
    required this.email,
    required this.title,
    required this.review,
    required this.rating,
    required this.destination,
    required this.profileUrl,
    this.photoUrls = const [],
    this.createdAt,
    this.status = statusPending,
  });

  factory Review.fromJson(Map<String, dynamic> data, String id) {
    final photoUrls =
        (data['photoUrls'] as List<dynamic>?)?.whereType<String>().toList() ??
            const <String>[];
    // Legacy docs predate `status`: map their stored `verified` flag onto the
    // new states so old photo-verified reviews stay approved.
    final legacyStatus = (data['verified'] as bool? ?? false)
        ? statusApproved
        : statusPending;
    return Review(
      id: id,
      name: data['name'] as String,
      email: data['email'] as String,
      title: data['title'] as String,
      review: data['review'] as String,
      rating: (data['rating'] as num).toDouble(),
      destination: data['destination'] as String,
      profileUrl: data['profileUrl'] as String,
      photoUrls: photoUrls,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? legacyStatus,
    );
  }

  Review copyWith({String? status}) {
    return Review(
      id: id,
      name: name,
      email: email,
      title: title,
      review: review,
      rating: rating,
      destination: destination,
      profileUrl: profileUrl,
      photoUrls: photoUrls,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'title': title,
      'review': review,
      'rating': rating,
      'destination': destination,
      'profileUrl': profileUrl,
      'photoUrls': photoUrls,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'status': status,
      // Kept for backward-compatible readers / queries; derived from status.
      'verified': verified,
    };
  }
}
