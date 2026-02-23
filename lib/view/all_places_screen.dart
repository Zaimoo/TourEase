import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user.dart';
import '../models/destination.dart';
import '../services/use_firebase.dart';
import '../widgets/destination_card.dart';

class AllPlacesScreen extends StatefulWidget {
  final AppUser? currentUser;
  final LatLng? userLocation;

  const AllPlacesScreen(
      {super.key, required this.currentUser, required this.userLocation});

  @override
  State<AllPlacesScreen> createState() => _AllPlacesScreenState();
}

class _AllPlacesScreenState extends State<AllPlacesScreen> {
  final destinationsService = UseFirebase<Destination>(
    fromJson: (data, id) => Destination.fromJson(data, id),
    toJson: (dest) => dest.toJson(),
  );

  List<Destination> allDestinations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllDestinations();
  }

  Future<void> _fetchAllDestinations() async {
    try {
      final destinations = await destinationsService.getAll('destinations');
      setState(() {
        allDestinations = destinations;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching destinations: $e");
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
        title: const Text("All Places", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFB6DCFE),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allDestinations.isEmpty
              ? const Center(
                  child: Text(
                    "No destinations found.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allDestinations.length,
                  itemBuilder: (context, index) {
                    final dest = allDestinations[index];
                    return DestinationCard(
                      currentUser: widget.currentUser,
                      name: dest.name,
                      shortDescription: dest.shortDescription,
                      longDescription: dest.longDescription,
                      imageUrl: dest.imageUrl,
                      openHours: dest.openHours,
                      rating: (dest.rating as num).toDouble(),
                      entranceFee: (dest.entranceFee as num).toDouble(),
                      fareCost: (dest.fareCost as num).toDouble(),
                      coordinates: LatLng(dest.coordinates.latitude,
                          dest.coordinates.longitude),
                      userLocation: widget.userLocation ?? const LatLng(0, 0),
                      showMeta: true,
                    );
                  },
                ),
    );
  }
}
