import 'package:flutter/material.dart';
import 'package:tourease/models/review.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/widgets/review_card.dart';
import 'add_review_screen.dart';

class AllReviewsScreen extends StatefulWidget {
  final String destinationName;
  final AppUser currentUser;

  const AllReviewsScreen({super.key, required this.destinationName, required this.currentUser});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

// all_reviews_screen.dart

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final reviewService = UseFirebase<Review>(
    fromJson: (data, id) => Review.fromJson(data, id),
    toJson: (review) => review.toJson(),
  );

  // 1. Define your placeholder URL asset path.
  // Make sure this path is correct and the asset is in your pubspec.yaml
  final String placeholderProfileUrl = 'assets/placeholder-profile.png';

  Stream<List<Review>> getReviews() {
    return reviewService.streamAll('reviews').map(
          (reviews) => reviews
          .where((r) => r.destination == widget.destinationName)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.destinationName} Reviews',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFB6DCFE),
      ),
      body: StreamBuilder<List<Review>>(
        stream: getReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No reviews yet. Be the first to add one!'),
            );
          }

          final reviews = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];

              // 2. Check if the profileUrl is null or empty, and use the placeholder if it is.
              final imageUrl = (review.profileUrl.isNotEmpty)
                  ? review.profileUrl
                  : placeholderProfileUrl;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ReviewCard(
                  name: review.name,
                  reviewTitle: review.title,
                  review: review.review,
                  rating: review.rating,
                  // 3. Pass the determined URL to the ReviewCard.
                  profileUrl: imageUrl,
                ),
              );
            },
          );
        },
      ),

      // Floating Add Review Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00BFA6),
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: const Text(
          "Add Review",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddReviewScreen(
                destination: widget.destinationName,
                currentUser: widget.currentUser,
              ),
            ),
          );
        },
      ),
    );
  }
}
