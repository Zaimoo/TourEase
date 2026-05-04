import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tourease/services/use_auth.dart';
import 'package:tourease/view/destination_info_screen.dart';
import 'package:tourease/widgets/badge_button.dart';

import '../models/favorite.dart';
import '../models/user.dart';
import '../services/use_firebase.dart';

class DestinationCard extends StatefulWidget {
  final AppUser? currentUser;
  final String name;
  final String shortDescription;
  final String longDescription;
  final String imageUrl;
  final String openHours;
  final double rating;
  final double entranceFee;
  final double fareCost;
  final LatLng coordinates;
  final LatLng userLocation;
  final bool showMeta;
  final VoidCallback? onDirections;
  final VoidCallback? onFavorite;
  final double? cachedDistance; // Pre-fetched distance from parent

  const DestinationCard({
    super.key,
    required this.currentUser,
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.imageUrl,
    required this.openHours,
    required this.entranceFee,
    required this.fareCost,
    required this.coordinates,
    required this.userLocation,
    this.rating = 0,
    this.onDirections,
    this.onFavorite,
    this.showMeta = true,
    this.cachedDistance,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<DestinationCard> {
  double? _distanceKm;
  bool _isLoading = true;
  bool _isFavorited = false;
  double _liveRating = 0;
  int _reviewCount = 0;

  final favoritesService = UseFirebase<Favorite>(
    fromJson: (data, id) => Favorite.fromJson(data, id),
    toJson: (fav) => fav.toJson(),
  );

  @override
  void initState() {
    super.initState();
    _fetchAverageRating();
    // Use cached distance if available, otherwise fetch
    if (widget.cachedDistance != null) {
      _distanceKm = widget.cachedDistance;
      _isLoading = false;
    } else {
      _fetchDistance();
    }
  }

  @override
  void didUpdateWidget(DestinationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update distance if cached distance changed
    if (widget.cachedDistance != oldWidget.cachedDistance) {
      if (widget.cachedDistance != null) {
        setState(() {
          _distanceKm = widget.cachedDistance;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAverageRating() async {
    try {
      print("🔎 Fetching reviews for destination: ${widget.name}");
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('destination', isEqualTo: widget.name)
          .get();
      print("🔎 Found ${snapshot.docs.length} reviews for ${widget.name}");
      if (mounted) {
        double total = 0;
        int validCount = 0;
        for (final doc in snapshot.docs) {
          final rating = doc['rating'];
          print(
              "🔎 Review destination: ${doc['destination']}, rating: $rating");
          if (rating != null && rating is num && rating > 0) {
            total += rating.toDouble();
            validCount++;
          }
        }
        setState(() {
          _liveRating = validCount > 0 ? total / validCount : 0;
          _reviewCount = validCount;
        });
      }
    } catch (e) {
      print("⚠️ Could not fetch live rating: $e");
    }
  }

  Future<double?> _getDistanceInKm(LatLng origin, LatLng destination) async {
    const String apiKey = 'AIzaSyALUtzfv48mrHdqP1PuSk36jwPKlddxSYk';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey&mode=driving';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'].isNotEmpty) {
          final distanceMeters =
              data['routes'][0]['legs'][0]['distance']['value'];
          return distanceMeters / 1000.0;
        }
      }
    } catch (e) {
      print("❌ Error fetching distance from API: $e");
    }
    return null;
  }

  Future<void> _fetchDistance() async {
    try {
      final distance =
          await _getDistanceInKm(widget.userLocation, widget.coordinates);
      if (mounted) {
        setState(() {
          _distanceKm = distance;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error getting distance: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Check if this destination is already favorited
  Future<void> _checkIfFavorited() async {
    if (widget.currentUser == null) return;

    final favs = await favoritesService.getSubcollection(
      'users',
      widget.currentUser!.id,
      'favorites',
    );

    setState(() {
      _isFavorited = favs
          .any((fav) => fav.id == widget.name); // use unique ID if you have one
    });
  }

  // Toggle favorite
  Future<void> _toggleFavorite() async {
    if (widget.currentUser == null) return;

    final userId = widget.currentUser!.id;
    final docId =
        widget.name; // use unique ID of destination instead if possible

    if (_isFavorited) {
      // Remove favorite
      await favoritesService.deleteFromSubcollection(
        'users',
        userId,
        'favorites',
        docId,
      );
      setState(() => _isFavorited = false);
    } else {
      // Add favorite
      final favorite = Favorite(
        id: widget.name,
        name: widget.name,
        coordinates:
            GeoPoint(widget.coordinates.latitude, widget.coordinates.latitude),
      );

      await favoritesService.addToSubcollection(
        'users',
        userId,
        'favorites',
        docId,
        favorite,
      );

      setState(() => _isFavorited = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DestinationInfoScreen(
                  currentUser: widget.currentUser!,
                  name: widget.name,
                  longDescription: widget.longDescription,
                  imageUrl: widget.imageUrl,
                  openHours: widget.openHours,
                  rating: widget.rating,
                  distance: _distanceKm ?? 0,
                  entranceFee: widget.entranceFee,
                  fareCost: widget.fareCost,
                  coordinates: widget.coordinates,
                ),
              ));
        },
        child: Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with favorite overlay
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(widget.imageUrl, fit: BoxFit.cover),
                  ),
                  // Favorite button on top-right of image
                  if (widget.onFavorite != null || widget.onDirections != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _toggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                      scale: animation, child: child),
                              child: Icon(
                                _isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(_isFavorited),
                                color: _isFavorited
                                    ? Colors.red
                                    : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Rating badge on top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _liveRating > 0
                                ? _liveRating.toStringAsFixed(1)
                                : 'New',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (widget.onDirections != null ||
                                              widget.onFavorite != null)
                                          ? (_isLoading
                                              ? 'Calculating distance...'
                                              : _distanceKm != null
                                                  ? '${_distanceKm!.toStringAsFixed(2)} km away'
                                                  : 'Distance: N/A')
                                          : widget.shortDescription,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Directions CTA button - prominent and clearly a button
                    if (widget.onDirections != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: widget.onDirections,
                            icon: const Icon(Icons.navigation_rounded,
                                color: Colors.white, size: 22),
                            label: const Text(
                              'Get Directions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 4,
                              shadowColor:
                                  const Color(0xFF1E88E5).withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.showMeta)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                              _liveRating > 0
                                  ? _liveRating.toStringAsFixed(1)
                                  : 'New',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      _isLoading
                          ? Text('Calculating...',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]))
                          : Row(
                              children: [
                                Icon(Icons.straighten,
                                    size: 16, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  _distanceKm != null
                                      ? '${_distanceKm!.toStringAsFixed(2)} km'
                                      : 'N/A',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
