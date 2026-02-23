import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user.dart';
import '../models/favorite.dart';
import '../models/destination.dart';
import '../services/use_firebase.dart';
import '../widgets/destination_card.dart';

class FavoritesScreen extends StatefulWidget {
  final AppUser? currentUser;
  final LatLng? userLocation;

  const FavoritesScreen({super.key, required this.currentUser, required this.userLocation});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final favoritesService = UseFirebase<Favorite>(
    fromJson: (data, id) => Favorite.fromJson(data, id),
    toJson: (fav) => fav.toJson(),
  );

  final destinationsService = UseFirebase<Destination>(
    fromJson: (data, id) => Destination.fromJson(data, id),
    toJson: (dest) => dest.toJson(),
  );

  List<Destination> favoriteDestinations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteDestinations();
  }

  Future<void> _fetchFavoriteDestinations() async {
    try {
      // Step 1: Get all favorites of current user
      final favs = await favoritesService.getSubcollection(
        'users',
        widget.currentUser!.id,
        'favorites',
      );

      print("Favorites fetched successfully: $favs");

      // Step 2: Fetch destination data for each favorite
      final List<Destination> destinations = [];
      for (var fav in favs) {
        final destination = await destinationsService.getById('destinations', fav.id);
        if (destination != null) {
          destinations.add(destination);
        }
      }

      setState(() {
        favoriteDestinations = destinations;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching favorites: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Favorites", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFB6DCFE),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoriteDestinations.isEmpty
          ? const Center(
        child: Text(
          "You have no favorites yet.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favoriteDestinations.length,
        itemBuilder: (context, index) {
          final dest = favoriteDestinations[index];
          return DestinationCard(
            currentUser: widget.currentUser!,
            name: dest.name,
            shortDescription: dest.shortDescription,
            longDescription: dest.longDescription,
            imageUrl: dest.imageUrl,
            openHours: dest.openHours,
            rating: (dest.rating as num).toDouble(),
            entranceFee: (dest.entranceFee as num).toDouble(),
            fareCost: (dest.fareCost as num).toDouble(),
            coordinates: LatLng(dest.coordinates.latitude, dest.coordinates.longitude),
            userLocation: widget.userLocation!,
            showMeta: true,
          );
        },
      ),
    );
  }
}
