import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourease/models/favorite.dart';
import 'package:tourease/models/review.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/view/map_screen.dart';
import 'package:tourease/view/root_page.dart';
import 'package:tourease/widgets/big_text.dart';
import 'package:tourease/widgets/review_card.dart';

import 'add_review_screen.dart';
import 'all_reviews_screen.dart';

class DestinationInfoScreen extends StatefulWidget {
  const DestinationInfoScreen({
    super.key,
    required this.name,
    required this.currentUser,
    required this.longDescription,
    required this.imageUrl,
    required this.openHours,
    required this.rating,
    required this.distance,
    required this.entranceFee,
    required this.fareCost,
    required this.coordinates,
  });

  final AppUser currentUser;
  final String name;
  final String longDescription;
  final String imageUrl;
  final String openHours;
  final double rating;
  final double distance;
  final double entranceFee;
  final double fareCost;
  final LatLng coordinates;

  @override
  State<DestinationInfoScreen> createState() => _DestinationInfoScreenState();
}

const String placeholderProfileUrl = 'assets/placeholder-profile.png';

class _DestinationInfoScreenState extends State<DestinationInfoScreen> {
  final reviewService = UseFirebase<Review>(
    fromJson: (data, id) => Review.fromJson(data, id),
    toJson: (review) => review.toJson(),
  );

  final favoritesService = UseFirebase<Favorite>(
    fromJson: (data, id) => Favorite.fromJson(data, id),
    toJson: (fav) => fav.toJson(),
  );

  bool _isFavorited = false;
  double _liveRating = 0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _checkIfFavorited();
    _fetchAverageRating();
  }

  Future<void> _checkIfFavorited() async {
    try {
      final favs = await favoritesService.getSubcollection(
        'users',
        widget.currentUser.id,
        'favorites',
      );
      setState(() {
        _isFavorited = favs.any((fav) => fav.id == widget.name);
      });
    } catch (e) {
      print("Error checking favorite: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = widget.currentUser.id;
    final docId = widget.name;

    if (_isFavorited) {
      await favoritesService.deleteFromSubcollection(
          'users', userId, 'favorites', docId);
      setState(() => _isFavorited = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Removed from favorites'),
            duration: Duration(seconds: 1)),
      );
    } else {
      final favorite = Favorite(
        id: widget.name,
        name: widget.name,
        coordinates:
            GeoPoint(widget.coordinates.latitude, widget.coordinates.longitude),
      );
      await favoritesService.addToSubcollection(
          'users', userId, 'favorites', docId, favorite);
      setState(() => _isFavorited = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Added to favorites!'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _fetchAverageRating() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('destination', isEqualTo: widget.name)
          .get();
      double total = 0;
      int validCount = 0;
      for (final doc in snapshot.docs) {
        final rating = doc['rating'];
        if (rating != null && rating is num && rating > 0) {
          total += rating.toDouble();
          validCount++;
        }
      }
      setState(() {
        _liveRating = validCount > 0 ? total / validCount : 0;
        _reviewCount = validCount;
      });
    } catch (e) {
      print("⚠️ Could not fetch live rating: $e");
    }
  }

  Stream<List<Review>> getReviewsForDestination(String destination) {
    return reviewService.streamAll('reviews').map(
          (allReviews) => allReviews
              .where((review) => review.destination == destination)
              .take(3)
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // Prominent Get Directions CTA at bottom
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estimated fare preview
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB6DCFE), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 20, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 8),
                        Text(
                          'Est. Fare: ₱${widget.fareCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.straighten,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Big Get Directions button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Position position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high);
                    LatLng userLatLng =
                        LatLng(position.latitude, position.longitude);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RootPage(
                          initialTab: 1,
                          destinationData: {
                            'name': widget.name,
                            'shortDescription': 'Tap to learn more...',
                            'longDescription': widget.longDescription,
                            'imageUrl': widget.imageUrl,
                            'openHours': widget.openHours,
                            'entranceFee': widget.entranceFee,
                            'fareCost': widget.fareCost,
                          },
                          initialCameraTarget: widget.coordinates,
                          userLocation: userLatLng,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 26),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF1E88E5).withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: Text(widget.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFB6DCFE),
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [
              // Hero image with overlay info
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Favorite overlay on top-right of photo
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.white.withOpacity(0.9),
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggleFavorite,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              _isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              key: ValueKey(_isFavorited),
                              color:
                                  _isFavorited ? Colors.red : Colors.grey[600],
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Live rating overlay
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            _liveRating > 0
                                ? _liveRating.toStringAsFixed(1)
                                : 'New',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Description
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  widget.longDescription,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Info cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.confirmation_number_outlined,
                      'Entrance Fee',
                      widget.entranceFee > 0
                          ? '₱${widget.entranceFee.toStringAsFixed(0)}'
                          : 'Free',
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.payments_outlined,
                      'Estimated Fare',
                      '₱${widget.fareCost.toStringAsFixed(0)}',
                      const Color(0xFF1E88E5),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.straighten,
                      'Distance',
                      '${widget.distance.toStringAsFixed(1)} km',
                      const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.schedule,
                      'Open Hours',
                      widget.openHours,
                      const Color(0xFF9C27B0),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 6),

              // Reviews section
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const BigText(
                            text: 'Reviews',
                            fontWeight: FontWeight.w700,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllReviewsScreen(
                                      destinationName: widget.name,
                                      currentUser: widget.currentUser),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'View All',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Review>>(
                        stream: getReviewsForDestination(widget.name),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            print("Firestore error: ${snapshot.error}");
                            return Text(
                                'Error loading reviews: ${snapshot.error}');
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.rate_review_outlined,
                                      size: 40, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 15),
                                  ),
                                ],
                              ),
                            );
                          }

                          final reviews = snapshot.data!;
                          return Column(
                            children: reviews.map((r) {
                              final imageUrl = (r.profileUrl != null &&
                                      r.profileUrl.isNotEmpty)
                                  ? r.profileUrl
                                  : placeholderProfileUrl;

                              return ReviewCard(
                                name: r.name,
                                reviewTitle: r.title,
                                review: r.review,
                                rating: r.rating,
                                profileUrl: imageUrl,
                              );
                            }).toList(),
                          );
                        },
                      )
                    ],
                  )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
