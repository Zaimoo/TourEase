import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tourease/models/destination.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/view/login_screen.dart';
import 'package:tourease/view/profile_screen.dart';
import 'package:tourease/view/settings_screen.dart';
import 'package:tourease/view/trip_history_screen.dart';
import 'package:tourease/widgets/custom_drawer.dart';
import 'package:tourease/widgets/destination_card.dart';
import 'package:tourease/services/use_auth.dart';

import 'favorites_screen.dart';
import 'all_places_screen.dart';
import 'search_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final destinationService = UseFirebase<Destination>(
    fromJson: (data, id) => Destination.fromJson(data, id),
    toJson: (dest) => dest.toJson(),
  );
  final _userService = UseFirebase<AppUser>(
    fromJson: (data, id) => AppUser.fromJson(data, id),
    toJson: (user) => user.toJson(),
  );

  List<Destination> _destinations = [];
  List<Destination> _filteredDestinations = [];
  Map<String, double> _destinationDistances = {}; // Cache API distances
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isDrawerOpen = false;
  AppUser? _currentUser;
  LatLng? _userLocation;
  final _authServices = UseAuth();

  @override
  void initState() {
    super.initState();
    loadDestinations();
    loadUserLocation();
    loadUserProfile();
  }

  Future<void> loadUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });

    // Fetch distances for all destinations after getting location
    if (_destinations.isNotEmpty) {
      await _fetchAllDistances();
    }
  }

  Future<void> loadDestinations() async {
    final destinations = await destinationService.getAll('destinations');
    setState(() {
      _destinations = destinations;
      _isLoading = false;
    });

    // Fetch distances if user location is already available
    if (_userLocation != null) {
      await _fetchAllDistances();
    }
  }

  Future<void> _fetchAllDistances() async {
    if (_userLocation == null) return;

    print(
        "🚗 Fetching driving distances for ${_destinations.length} destinations...");

    for (var destination in _destinations) {
      final distance = await _getDistanceFromAPI(
        _userLocation!,
        destination.latLng,
      );
      if (distance != null) {
        _destinationDistances[destination.id] = distance;
        print("   ${destination.name}: ${distance.toStringAsFixed(2)}km");
      }
    }

    setState(() {}); // Trigger rebuild with new distances
    print("✅ Finished fetching all distances");
  }

  Future<double?> _getDistanceFromAPI(LatLng origin, LatLng destination) async {
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
          return distanceMeters / 1000.0; // Convert to km
        }
      }
    } catch (e) {
      print("❌ Error fetching distance: $e");
    }
    return null;
  }

  double _calculateDistance(LatLng destination) {
    if (_userLocation == null) return double.infinity;
    return Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  Future<void> loadUserProfile() async {
    final uid = _authServices.user!.uid;
    print("uid:$uid");
    final user = await _userService.getById("users", uid);
    setState(() {
      _currentUser = user;
    });
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
    });
  }

  void _handleLogout() {
    _toggleDrawer();
    // Show logout confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _authServices.signOut();
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => LoginScreen()));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error logging out: $e')),
                  );
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB6DCFE),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location and Profile Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.location_on, size: 20),
                            SizedBox(width: 4),
                            Text("Tibanga, Iligan City",
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _toggleDrawer,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: (_currentUser != null &&
                                    _currentUser!.profileUrl != null &&
                                    _currentUser!.profileUrl!.isNotEmpty)
                                ? NetworkImage(_currentUser!.profileUrl!)
                                : const NetworkImage(
                                    'https://i.imgur.com/BoN9kdC.png'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar (opens search screen)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              currentUser: _currentUser,
                              userLocation: _userLocation,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              'Search all destinations...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navButton(Icons.place, 'All Places'),
                      _navButton(Icons.favorite_rounded, 'Favourites'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Categories & Destinations
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_selectedCategory != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = null;
                                    _filteredDestinations = _destinations;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close,
                                          size: 14, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text('Clear',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _categoryItem(
                                'Natural Wonders', 'assets/natural-wonders.png',
                                displayLabel: 'Natural',
                                gradient: const [
                                  Color(0xFF43A047),
                                  Color(0xFF66BB6A)
                                ],
                                icon: Icons.park_rounded),
                            _categoryItem('Cultural', 'assets/cultural.png',
                                gradient: const [
                                  Color(0xFFE65100),
                                  Color(0xFFFF8A65)
                                ],
                                icon: Icons.account_balance_rounded),
                            _categoryItem(
                                'Recreational', 'assets/recreational.png',
                                gradient: const [
                                  Color(0xFF1565C0),
                                  Color(0xFF42A5F5)
                                ],
                                icon: Icons.sports_soccer_rounded),
                            _categoryItem(
                                'Entertainment', 'assets/entertainment.png',
                                gradient: const [
                                  Color(0xFF6A1B9A),
                                  Color(0xFFAB47BC)
                                ],
                                icon: Icons.celebration_rounded),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Places Near You',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        (_isLoading || _userLocation == null)
                            ? SizedBox(
                                height: MediaQuery.of(context).size.height *
                                    0.4, // fills space visibly
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.lightBlue,
                                    strokeWidth: 4,
                                  ),
                                ),
                              )
                            : Column(
                                children: () {
                                  final filteredList = _destinations
                                      .where((destination) =>
                                          _selectedCategory == null ||
                                          destination.category.toLowerCase() ==
                                              _selectedCategory!.toLowerCase())
                                      .toList();

                                  // Sort by distance from user location using cached API distances
                                  if (_userLocation != null) {
                                    filteredList.sort((a, b) {
                                      final distanceA =
                                          _destinationDistances[a.id] ??
                                              double.infinity;
                                      final distanceB =
                                          _destinationDistances[b.id] ??
                                              double.infinity;
                                      return distanceA.compareTo(distanceB);
                                    });
                                  }

                                  return filteredList.map((destination) {
                                    return DestinationCard(
                                      key: ValueKey(destination.name),
                                      currentUser: _currentUser,
                                      name: destination.name,
                                      shortDescription:
                                          destination.shortDescription,
                                      longDescription:
                                          destination.longDescription,
                                      imageUrl: destination.imageUrl,
                                      rating: destination.rating.toDouble(),
                                      openHours: destination.openHours,
                                      entranceFee:
                                          destination.entranceFee.toDouble(),
                                      fareCost: destination.fareCost.toDouble(),
                                      coordinates: destination.latLng,
                                      userLocation: _userLocation!,
                                      cachedDistance:
                                          _destinationDistances[destination.id],
                                    );
                                  }).toList();
                                }(),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleDrawer,
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right:
                _isDrawerOpen ? 0 : -MediaQuery.of(context).size.width * 0.75,
            child: CustomDrawer(
              currentUser: _currentUser,
              onClose: () {
                _toggleDrawer();
              },
              onSettings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
              onLogout: _handleLogout,
              onItemTap: (String page) {
                _toggleDrawer();
                switch (page) {
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(currentUser: _currentUser!)),
                    );
                    break;

                  case 'favorites':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => FavoritesScreen(
                                currentUser: _currentUser,
                                userLocation: _userLocation,
                              )),
                    );
                    break;

                  case 'history':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              TripHistoryScreen(currentUser: _currentUser)),
                    );
                    break;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'Favourites') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FavoritesScreen(
                currentUser: _currentUser,
                userLocation: _userLocation,
              ),
            ),
          );
        } else if (label == 'All Places') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllPlacesScreen(
                currentUser: _currentUser,
                userLocation: _userLocation,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: label == 'Favourites'
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: label == 'Favourites' ? Colors.redAccent : Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryItem(String label, String assetPath,
      {required List<Color> gradient,
      required IconData icon,
      String? displayLabel}) {
    final bool isSelected = _selectedCategory == label;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_selectedCategory == label) {
              _selectedCategory = null;
              _filteredDestinations = _destinations;
            } else {
              _selectedCategory = label;
              _filteredDestinations = _destinations
                  .where((destination) =>
                      destination.category.toLowerCase() == label.toLowerCase())
                  .toList();
            }
          });
        },
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white,
                  border: Border.all(
                    color: isSelected ? gradient.first : Colors.grey[300]!,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: gradient.first.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    assetPath,
                    width: 40,
                    height: 40,
                    color: isSelected ? Colors.white : null,
                    colorBlendMode: isSelected ? BlendMode.srcIn : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                displayLabel ?? label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? gradient.first : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
