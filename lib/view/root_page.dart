import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourease/view/map_screen.dart';
import 'package:tourease/view/discover_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _destinationData = widget.destinationData;
    _cameraTarget = widget.initialCameraTarget;
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const DiscoverScreen();

      case 1:
        final showDestination =
            _destinationData != null && _cameraTarget != null;

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

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFB6DCFE),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => {
          _selectedIndex = index,
          setState(() {
            print('Selected Index: $_selectedIndex');
          })
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
        ],
      ),
    );
  }
}
