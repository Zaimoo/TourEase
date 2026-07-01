import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_auth.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/view/map_screen.dart';
import 'package:tourease/view/discover_screen.dart';
import 'package:tourease/view/review_verification_screen.dart';

class RootPage extends StatefulWidget {
  final int initialTab;
  final Map<String, dynamic>? destinationData;
  final LatLng? initialCameraTarget;
  final LatLng? userLocation;

  const RootPage({
    super.key,
    this.initialTab = 0,
    this.destinationData,
    this.initialCameraTarget,
    this.userLocation,
  });

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late int _selectedIndex;

  Map<String, dynamic>? _destinationData;
  LatLng? _cameraTarget;

  final _authServices = UseAuth();
  final _userService = UseFirebase<AppUser>(
    fromJson: (data, id) => AppUser.fromJson(data, id),
    toJson: (user) => user.toJson(),
  );
  AppUser? _currentUser;

  bool get _isAdmin => _currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _destinationData = widget.destinationData;
    _cameraTarget = widget.initialCameraTarget;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = _authServices.user?.uid;
    if (uid == null) return;
    final user = await _userService.getById('users', uid);
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  Widget _buildDiscover() => const DiscoverScreen();

  Widget _buildMap() {
    final showDestination = _destinationData != null && _cameraTarget != null;
    return MapScreen(
      showDestinationCard: showDestination,
      destinationData: _destinationData,
      initialCameraTarget: _cameraTarget,
      userLocation: widget.userLocation,
      onConsumed: () {
        setState(() {
          _destinationData = null;
          _cameraTarget = null;
        });
      },
    );
  }

  /// Pages in display order. The admin-only Verify page is appended last so its
  /// index lines up with the matching nav destination below.
  List<Widget> get _pages => [
        _buildDiscover(),
        _buildMap(),
        if (_isAdmin) const ReviewVerificationScreen(),
      ];

  List<NavigationDestination> get _navDestinations => [
        const NavigationDestination(icon: Icon(Icons.home), label: 'Discover'),
        const NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
        if (_isAdmin)
          const NavigationDestination(
              icon: Icon(Icons.verified_user), label: 'Verify'),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    // Clamp in case admin state changed (or a non-admin landed on a stale tab).
    final index = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFB6DCFE),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _navDestinations,
      ),
    );
  }
}
