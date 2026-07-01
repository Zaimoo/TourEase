import 'package:flutter/material.dart';
import 'package:tourease/models/review.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/widgets/review_card.dart';

/// Admin-only queue of reviews awaiting verification. Streams every review with
/// `status == pending` across all destinations. Approving marks it verified;
/// declining leaves it unverified (kept in Firestore) but removes it from the
/// queue. Only reachable from the admin "Verify" tab in [RootPage].
class ReviewVerificationScreen extends StatefulWidget {
  const ReviewVerificationScreen({super.key});

  @override
  State<ReviewVerificationScreen> createState() =>
      _ReviewVerificationScreenState();
}

class _ReviewVerificationScreenState extends State<ReviewVerificationScreen> {
  final reviewService = UseFirebase<Review>(
    fromJson: (data, id) => Review.fromJson(data, id),
    toJson: (review) => review.toJson(),
  );

  // Ids currently being written, to disable their buttons mid-update.
  final Set<String> _busy = {};

  Stream<List<Review>> _pendingReviews() {
    return reviewService
        .streamWhere(
          'reviews',
          (ref) => ref.where('status', isEqualTo: Review.statusPending),
        )
        .map((reviews) {
      // Oldest first so the longest-waiting reviews surface at the top.
      reviews.sort((a, b) => (a.createdAt ?? DateTime(0))
          .compareTo(b.createdAt ?? DateTime(0)));
      return reviews;
    });
  }

  Future<void> _setStatus(Review review, String status) async {
    setState(() => _busy.add(review.id));
    try {
      await reviewService.update(
        'reviews',
        review.id,
        review.copyWith(status: status),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == Review.statusApproved
              ? 'Review approved.'
              : 'Review declined.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update review: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(review.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Reviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFB6DCFE),
      ),
      body: StreamBuilder<List<Review>>(
        stream: _pendingReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final reviews = snapshot.data ?? const <Review>[];
          if (reviews.isEmpty) {
            return const Center(
              child: Text('No reviews awaiting verification.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final imageUrl = review.profileUrl.isNotEmpty
                  ? review.profileUrl
                  : 'assets/placeholder-profile.png';
              final busy = _busy.contains(review.id);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place,
                          size: 16, color: Color(0xFF1E88E5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          review.destination,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E88E5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ReviewCard(
                    name: review.name,
                    reviewTitle: review.title,
                    review: review.review,
                    rating: review.rating,
                    profileUrl: imageUrl,
                    verified: review.verified,
                    photoUrls: review.photoUrls,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _setStatus(
                                    review, Review.statusRejected),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _setStatus(
                                    review, Review.statusApproved),
                            icon: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BFA6),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
