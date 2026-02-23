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

  final favoritesService = UseFirebase<Favorite>(
    fromJson: (data, id) => Favorite.fromJson(data, id),
    toJson: (fav) => fav.toJson(),
  );

  @override
  void initState() {
    super.initState();
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

  Future<void> _fetchDistance() async {
    try {
      final distance =
          await _getDistanceInKm(widget.userLocation, widget.coordinates);
      setState(() {
        _distanceKm = distance;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error getting distance: $e");
      setState(() {
        _isLoading = false;
      });
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black54),
          ),
          color: Colors.white,
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(widget.imageUrl, fit: BoxFit.cover),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                child: Row(
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
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (widget.onDirections != null ||
                                    widget.onFavorite != null)
                                ? (_isLoading
                                    ? 'Distance: ...'
                                    : _distanceKm != null
                                        ? 'Distance: ${_distanceKm!.toStringAsFixed(2)} km'
                                        : 'Distance: N/A')
                                : widget.shortDescription,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDirections != null ||
                        widget.onFavorite != null)
                      Row(
                        children: [
                          BadgeButton(
                            text: 'Directions',
                            backgroundColor: const Color(0xFF64B5F6),
                            onPressed: widget.onDirections,
                          ),
                          const SizedBox(width: 8),
                          BadgeButton(
                            text: _isFavorited ? 'Favorited' : 'Favorite',
                            backgroundColor: _isFavorited
                                ? Colors.redAccent
                                : const Color(0xFFFFB300),
                            onPressed: _toggleFavorite,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (widget.showMeta)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 25, right: 30, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.blue, size: 20),
                          const SizedBox(width: 4),
                          Text(widget.rating.toString(),
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      _isLoading
                          ? const Text('Distance: ...')
                          : Text(
                              _distanceKm != null
                                  ? 'Distance: ${_distanceKm!.toStringAsFixed(2)} km'
                                  : 'Distance: N/A',
                              style: const TextStyle(fontSize: 16),
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
