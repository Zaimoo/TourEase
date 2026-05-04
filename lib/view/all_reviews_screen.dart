import 'package:flutter/material.dart';
import 'package:tourease/models/review.dart';
import 'package:tourease/models/trip.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/widgets/review_card.dart';
import 'add_review_screen.dart';

class AllReviewsScreen extends StatefulWidget {
  final String destinationName;
  final AppUser currentUser;

  const AllReviewsScreen(
      {super.key, required this.destinationName, required this.currentUser});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

// all_reviews_screen.dart

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final reviewService = UseFirebase<Review>(
    fromJson: (data, id) => Review.fromJson(data, id),
    toJson: (review) => review.toJson(),
  );

  final tripService = UseFirebase<Trip>(
    fromJson: (data, id) => Trip.fromJson(data, id),
    toJson: (trip) => trip.toJson(),
  );

  // 1. Define your placeholder URL asset path.
  // Make sure this path is correct and the asset is in your pubspec.yaml
  final String placeholderProfileUrl = 'assets/placeholder-profile.png';

  bool _hasVisited = false;
  bool _checkingVisit = true;

  @override
  void initState() {
    super.initState();
    _checkIfVisited();
  }

  Future<void> _checkIfVisited() async {
    try {
      final trips = await tripService.getSubcollection(
        'users',
        widget.currentUser.id,
        'trips',
      );
      final visited = trips.any(
        (trip) =>
            trip.destinationName.toLowerCase() ==
            widget.destinationName.toLowerCase(),
      );
      setState(() {
        _hasVisited = visited;
        _checkingVisit = false;
      });
    } catch (e) {
      print("Error checking visit history: $e");
      setState(() {
        _checkingVisit = false;
      });
    }
  }

  Stream<List<Review>> getReviews() {
    return reviewService.streamAll('reviews').map(
          (reviews) => reviews
              .where((r) => r.destination == widget.destinationName)
              .toList(),
        );
  }

  void _showVisitRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Visit Required'),
          ],
        ),
        content: const Text(
          'You can only review places you\'ve visited.\n\n'
          'Navigate to this destination first and complete your trip to unlock the review feature.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
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

      // Floating Add Review Button - only enabled for verified visitors
      floatingActionButton: _checkingVisit
          ? null
          : FloatingActionButton.extended(
              backgroundColor:
                  _hasVisited ? const Color(0xFF00BFA6) : Colors.grey[400],
              icon: Icon(
                _hasVisited ? Icons.rate_review : Icons.lock_outline,
                color: Colors.white,
              ),
              label: Text(
                _hasVisited ? "Add Review" : "Visit to Review",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                if (_hasVisited) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddReviewScreen(
                        destination: widget.destinationName,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                } else {
                  _showVisitRequiredDialog();
                }
              },
            ),
    );
  }
}
