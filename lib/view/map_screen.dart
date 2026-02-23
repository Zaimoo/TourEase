import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:tourease/models/destination.dart';
import 'package:tourease/models/task.dart';
import 'package:tourease/models/transportation_markers.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/models/trip.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/services/use_auth.dart';
import 'package:tourease/view/login_screen.dart';
import 'package:tourease/view/profile_screen.dart';
import 'package:tourease/view/settings_screen.dart';
import 'package:tourease/view/trip_history_screen.dart';
import 'package:tourease/widgets/destination_card.dart';
import 'package:tourease/widgets/custom_drawer.dart';

import '../models/jeepneyRoute.dart';
import 'favorites_screen.dart';

class MapScreen extends StatefulWidget {
  final bool showDestinationCard;
  final Map<String, dynamic>? destinationData;
  final LatLng? initialCameraTarget;
  final LatLng? userLocation;
  final VoidCallback? onConsumed;

  const MapScreen({
    super.key,
    this.showDestinationCard = false,
    this.destinationData,
    this.initialCameraTarget,
    this.userLocation,
    this.onConsumed,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  bool _showDirectionsOptions = false;
  bool _showDestinationCard = false;
  bool _showDrawer = false;
  bool _focusOnDestination = false;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _tasks = [];
  int _currentTaskIndex = 0;

  String? _currentTask;
  String? _shortTaskDescription;
  String? _longTaskDescription;
  LatLng? _currentTaskTarget;
  bool _isTaskExpanded = false;

  StreamSubscription<Position>? _positionSubscription;
  bool _disposed = false;

  // Transportation preferences for multimodal routing
  Map<String, bool> _transportPreferences = {
    "walking": true,
    "jeepney": true,
    "habal": true,
    "sikad": false,
  };

  AppUser? _currentUser;

  final destinationService = UseFirebase<Destination>(
    fromJson: (data, id) => Destination.fromJson(data, id),
    toJson: (model) => model.toJson(),
  );
  final _userService = UseFirebase<AppUser>(
    fromJson: (data, id) => AppUser.fromJson(data, id),
    toJson: (user) => user.toJson(),
  );
  final transportationService = UseFirebase<TransportationMarkers>(
    fromJson: (data, id) => TransportationMarkers.fromJson(data, id),
    toJson: (model) => model.toJson(),
  );

  final jeepneyRouteService = UseFirebase<JeepneyRoute>(
    fromJson: (data, id) => JeepneyRoute.fromJson(data, id),
    toJson: (model) => model.toJson(),
  );

  final tripService = UseFirebase<Trip>(
    fromJson: (data, id) => Trip.fromJson(data, id),
    toJson: (trip) => trip.toJson(),
  );

  final UseAuth _authService = UseAuth();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Destination? _selectedDestination;
  LatLng _center = const LatLng(8.2280, 124.2452);

  // Search overlay state
  bool _showSearchOverlay = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Destination> _allDestinations = [];
  List<Destination> _searchResults = [];
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _focusOnDestination = widget.initialCameraTarget != null;
    if (widget.userLocation != null) {
      _userLocation = widget.userLocation;
    }
    _loadDestinations();
    _loadTransportationMarkers();
    loadUserProfile();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    _positionSubscription?.cancel();
    _taskCheckTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() {
      _showDrawer = !_showDrawer;
    });
  }

  Future<void> _checkLocationPermission() async {
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

    LatLng newCenter = LatLng(position.latitude, position.longitude);

    setState(() {
      _center = newCenter;
      LatLng? _userLocation;
    });

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newCenter, zoom: 15.0),
      ),
    );
  }

  Future<void> loadUserProfile() async {
    final uid = _authService.user!.uid;
    print("uid:$uid");
    final user = await _userService.getById("users", uid);
    setState(() {
      _currentUser = user;
    });
  }

  void _loadTransportationMarkers() {
    transportationService
        .streamAll('transportationMarkers')
        .listen((vehicles) async {
      final markerFutures = vehicles.map((vehicle) async {
        BitmapDescriptor icon;
        print("vehicleType: ${vehicle.vehicleType}");
        print(
            "coordinates: ${vehicle.latLng.latitude}, ${vehicle.latLng.longitude}");
        // Choose icon based on vehicle type
        switch (vehicle.vehicleType.toLowerCase()) {
          case 'jeepney':
            icon = await createBubbleMarker('assets/jeepney.png');
            break;
          case 'habal':
            icon = await createBubbleMarker('assets/habal.png');
            break;
          case 'sikad':
            icon = await createBubbleMarker('assets/sikad.png');
            break;
          default:
            icon = BitmapDescriptor.defaultMarker;
        }

        return Marker(
          markerId: MarkerId(vehicle.id),
          position: LatLng(
            vehicle.latLng.latitude,
            vehicle.latLng.longitude,
          ),
          icon: icon,
          infoWindow: InfoWindow(
            title: vehicle.vehicleType,
          ),
        );
      }).toList();

      final markers = await Future.wait(markerFutures);

      if (!_disposed && mounted) {
        setState(() {
          _markers = {
            ..._markers,
            ...markers
          }; // merge with existing destination markers
        });
      }
    });
  }

  void _loadDestinations() {
    destinationService.streamAll('destinations').listen((destinations) async {
      // Store all destinations for search
      print('📍 Loaded ${destinations.length} destinations for search');
      if (!_disposed && mounted) {
        setState(() {
          _allDestinations = destinations;
        });
      }

      final markerFutures = destinations.map((dest) async {
        final markerIcon = await createCustomMarkerBitmap(dest.name);

        return Marker(
          markerId: MarkerId(dest.id),
          position: dest.latLng,
          icon: markerIcon,
          onTap: () {
            if (!_disposed && mounted) {
              setState(() {
                if (_selectedDestination?.id == dest.id) {
                  _selectedDestination = null;
                  _showDestinationCard = false;
                } else {
                  _selectedDestination = dest;
                  _showDestinationCard = true;
                  mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(dest.latLng.latitude - 0.0035,
                            dest.latLng.longitude),
                        zoom: 15.0,
                      ),
                    ),
                  );
                }
              });
            }
          },
        );
      }).toList();

      final markers = await Future.wait(markerFutures);

      if (!_disposed && mounted) {
        setState(() {
          _markers = {..._markers, ...markers};
        });
      }
    });
  }

  Future<BitmapDescriptor> createBubbleMarker(String assetPath,
      {int size = 80}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double bubbleWidth = 120;
    const double bubbleHeight = 120;
    const double cornerRadius = 20.0;

    final Paint fillPaint = Paint()..color = Colors.white;
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4; // outline thickness

    // Draw rounded white box
    final RRect box = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bubbleWidth, bubbleHeight - 20),
      const Radius.circular(cornerRadius),
    );
    canvas.drawRRect(box, fillPaint);
    canvas.drawRRect(box, borderPaint); // black outline

    // Draw pointer triangle at bottom
    final Path pointer = Path()
      ..moveTo(bubbleWidth / 2 - 15, bubbleHeight - 20)
      ..lineTo(bubbleWidth / 2, bubbleHeight)
      ..lineTo(bubbleWidth / 2 + 15, bubbleHeight - 20)
      ..close();

    canvas.drawPath(pointer, fillPaint);
    canvas.drawPath(pointer, borderPaint); // black outline

    // Load vehicle icon
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();

    final double iconX = (bubbleWidth - size) / 2;
    final double iconY = ((bubbleHeight - 20) - size) / 2;

    canvas.drawImage(frameInfo.image, Offset(iconX, iconY), Paint());

    final ui.Image finalImage = await recorder.endRecording().toImage(
          bubbleWidth.toInt(),
          bubbleHeight.toInt(),
        );

    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> createCustomMarkerBitmap(String label) async {
    const double markerWidth = 250;
    const double iconSize = 100;
    const double textPaddingVertical = 16;
    const double textPaddingHorizontal = 24;

    final TextStyle textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 26,
      fontWeight: FontWeight.bold,
    );

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: markerWidth - 2 * textPaddingHorizontal);

    final double textHeight = textPainter.height + 2 * textPaddingVertical;
    final double totalHeight = textHeight + iconSize;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint paint = Paint()..color = Colors.white;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, markerWidth, textHeight),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);

    final double textX = (markerWidth - textPainter.width) / 2;
    final double textY = textPaddingVertical;
    textPainter.paint(canvas, Offset(textX, textY));

    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_pin.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.location_pin.fontFamily,
          color: Colors.red,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double iconX = (markerWidth - iconPainter.width) / 2;
    final double iconY = textHeight;
    iconPainter.paint(canvas, Offset(iconX, iconY));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      markerWidth.toInt(),
      totalHeight.toInt(),
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<BitmapDescriptor> getBytesFromAsset(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final Uint8List resized =
        (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
    return BitmapDescriptor.fromBytes(resized);
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    const String apiKey = "AIzaSyALUtzfv48mrHdqP1PuSk36jwPKlddxSYk";
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if ((data["routes"] as List).isNotEmpty) {
        final points = data["routes"][0]["overview_polyline"]["points"];

        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(points);

        final polylineCoordinates =
            result.map((e) => LatLng(e.latitude, e.longitude)).toList();

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("closest_route"),
              color: Colors.blue,
              width: 6,
              points: polylineCoordinates,
            ),
          };
        });

        LatLngBounds? bounds = _boundsFromLatLngList(polylineCoordinates);
        mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds!, 50));
      }
    } else {
      print("Failed to fetch directions: ${response.body}");
    }
  }

  LatLngBounds? _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) {
      print(
          "⚠️ _boundsFromLatLngList received an empty list — cannot calculate bounds.");
      return null;
    }

    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(x0, y0),
      northeast: LatLng(x1, y1),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    print("🗺️ _onMapCreated called");
    print("🗺️ _focusOnDestination: $_focusOnDestination");
    print("🗺️ initialCameraTarget: ${widget.initialCameraTarget}");
    print("UserLocation: ${widget.userLocation}");

    mapController = controller;
    String style = await DefaultAssetBundle.of(context)
        .loadString('assets/map_style.json');
    mapController?.setMapStyle(style);

    await Future.delayed(const Duration(milliseconds: 100));

    if (_focusOnDestination && widget.initialCameraTarget != null) {
      print("🗺️ Zooming to destination: ${widget.initialCameraTarget}");
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: widget.initialCameraTarget!,
            zoom: 16,
          ),
        ),
      );
      print("🗺️ Finished zooming to destination");

      // Consume the data AFTER using it
      if (widget.onConsumed != null) {
        widget.onConsumed!();
      }
    } else {
      print("🗺️ Checking user location permission");
      await _checkLocationPermission();
    }
  }

  void _closeDirectionsOptions() {
    setState(() {
      _showDirectionsOptions = false;
    });
  }

  void _handleSettings() {
    _toggleDrawer();
    // Navigate to settings page
    Navigator.pushNamed(context, '/settings');
  }

  void _handleLogout() {
    _toggleDrawer();
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
                  await _authService.signOut();
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

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // distance in kilometers
  }

  double _degToRad(double deg) => deg * (pi / 180);

  Future<TransportationMarkers?> _findNearestHabal(LatLng userLocation) async {
    final habalMarkers =
        await transportationService.getAll('transportationMarkers');
    final filtered =
        habalMarkers.where((m) => m.vehicleType.toLowerCase() == 'habal');

    double shortestDistance = double.infinity;
    TransportationMarkers? nearestHabal;

    for (final marker in filtered) {
      final dist = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        marker.coordinates.latitude,
        marker.coordinates.longitude,
      );

      if (dist < shortestDistance) {
        shortestDistance = dist;
        nearestHabal = marker;
      }
    }

    print(
        "Nearest habal: ${nearestHabal?.latLng}, distance: ${shortestDistance.toStringAsFixed(2)} km");
    return nearestHabal;
  }

  Future<List<LatLng>> _fetchPolyline(LatLng origin, LatLng destination) async {
    const String apiKey = "AIzaSyALUtzfv48mrHdqP1PuSk36jwPKlddxSYk";
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data["routes"] as List).isNotEmpty) {
        final points = data["routes"][0]["overview_polyline"]["points"];
        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(points);
        return result.map((e) => LatLng(e.latitude, e.longitude)).toList();
      }
    }
    return [];
  }

  StreamSubscription<Position>? _positionSub;
  Timer? _taskCheckTimer;
  bool _hasStartedMoving = false;
  DateTime? _lastRerouteTime; // Throttle rerouting to max once per 30s
  static const double _offRouteThresholdMeters = 100.0;

  void _startTaskTracking() {
    _positionSub?.cancel();
    _taskCheckTimer?.cancel();
    _hasStartedMoving = false;

    print("🎯 Starting task tracking for: $_currentTask");

    // Check immediately if already at location
    if (_userLocation != null) {
      _checkTaskCompletion(_userLocation!);
    }

    // Start GPS position updates (for live location tracking on map)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters for map display
      ),
    ).listen((position) {
      if (!_disposed && mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });

    // Periodic timer to check task completion + update polylines every 3 seconds
    _taskCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_disposed || !mounted || _userLocation == null) {
        timer.cancel();
        return;
      }
      _checkTaskCompletion(_userLocation!);
      _updatePolylinesForUserPosition(_userLocation!);
    });
  }

  void _checkTaskCompletion(LatLng userPos) {
    if (_currentTaskTarget == null ||
        _currentTask == null ||
        _currentTaskIndex >= _tasks.length) return;

    final distance = Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      _currentTaskTarget!.latitude,
      _currentTaskTarget!.longitude,
    );

    // Get radius based on current task
    final task = _tasks[_currentTaskIndex];
    final radius = task["radius"] ?? 50.0;

    print(
        "📍 Distance to target: ${distance.toStringAsFixed(1)}m, Radius: ${radius}m");

    // Complete task when within radius
    if (distance < radius) {
      print("✅ Task completed! Moving to next task.");

      // Cancel timers and immediately move to next task
      _taskCheckTimer?.cancel();

      if (!_disposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Task Completed: $_currentTask!')),
        );
      }

      _nextTask();
    }
  }

  void _nextTask() {
    _currentTaskIndex++;
    if (_currentTaskIndex < _tasks.length) {
      _hasStartedMoving = false;
      _setCurrentTask();
      _startTaskTracking();
    } else {
      _onFinalTaskCompleted();
    }
  }

  void _setCurrentTask() {
    if (_currentTaskIndex < _tasks.length) {
      final task = _tasks[_currentTaskIndex];
      if (!_disposed && mounted) {
        setState(() {
          _currentTask = task["title"];
          _shortTaskDescription = task["shortDescription"];
          _longTaskDescription = task["longDescription"];
          _currentTaskTarget = task["target"];
        });
      }
    } else {
      _onFinalTaskCompleted();
    }
  }

  void _onFinalTaskCompleted() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You’ve reached your destination!')),
    );
    // Save trip to history
    if (_currentUser != null && _selectedDestination != null) {
      try {
        // Calculate total distance traveled
        double? totalDistance;
        if (_userLocation != null) {
          totalDistance = Geolocator.distanceBetween(
                _userLocation!.latitude,
                _userLocation!.longitude,
                _selectedDestination!.latLng.latitude,
                _selectedDestination!.latLng.longitude,
              ) /
              1000; // Convert to km
        }

        // Determine transport mode from polyline colors or default
        String transportMode = 'Mixed';
        if (_polylines.isNotEmpty) {
          final colors = _polylines.map((p) => p.color).toSet();
          if (colors.length == 1) {
            final color = colors.first;
            if (color == Colors.orange)
              transportMode = 'Walking';
            else if (color == Colors.green)
              transportMode = 'Habal-Habal';
            else if (color == Colors.blue)
              transportMode = 'Direct';
            else if (color == Colors.purple || color == Colors.blueAccent)
              transportMode = 'Jeepney';
          }
        }

        final trip = Trip(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          destinationName: _selectedDestination!.name,
          destinationId: _selectedDestination!.name,
          visitedDate: DateTime.now(),
          imageUrl: _selectedDestination!.imageUrl,
          distance: totalDistance,
          transportMode: transportMode,
        );

        await tripService.addToSubcollection(
          'users',
          _currentUser!.id,
          'trips',
          trip.id,
          trip,
        );

        print('✅ Trip saved to history');
      } catch (e) {
        print('❌ Error saving trip: $e');
      }
    }
  }

  void _confirmStopTask() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Stop Task?"),
        content: const Text("Are you sure you want to stop the current task?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopCurrentTask();
            },
            child:
                const Text("Stop", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _stopCurrentTask() {
    setState(() {
      _tasks.clear();
      _polylines.clear();
      _currentTask = null;
      _shortTaskDescription = null;
      _longTaskDescription = null;
      _currentTaskTarget = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Task stopped. You can select a new destination.")),
    );

    // Optional: zoom back to user
    if (_userLocation != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 15),
      );
    }
  }

  // ========== POLYLINE UPDATE HELPERS ==========

  /// Trims the polyline to remove points the user has already passed.
  /// Returns a new list starting from the point nearest to the user.
  List<LatLng> _trimPolyline(List<LatLng> polyline, LatLng userLocation) {
    if (polyline.length < 2) return polyline;

    int nearestIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < polyline.length; i++) {
      final d = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        polyline[i].latitude,
        polyline[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearestIndex = i;
      }
    }

    return polyline.sublist(nearestIndex);
  }

  /// Checks if the user is more than [thresholdMeters] away from every point
  /// on the polyline (i.e. they've gone off-route).
  bool _isOffRoute(LatLng userLocation, List<LatLng> polyline,
      {double thresholdMeters = 100.0}) {
    for (final point in polyline) {
      final d = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < thresholdMeters) return false; // Still on route
    }
    return true; // Far from all points
  }

  /// Trims all current polylines to the user's position and, if off-route,
  /// re-fetches only the active walking segment (throttled to once per 30s).
  Future<void> _updatePolylinesForUserPosition(LatLng userPos) async {
    if (_polylines.isEmpty || _currentTaskTarget == null) return;

    // 1. Trim all polylines to remove passed points
    final trimmedPolylines = _polylines.map((polyline) {
      final trimmed = _trimPolyline(polyline.points, userPos);
      return polyline.copyWith(pointsParam: trimmed);
    }).toSet();

    // Remove any polylines that have been fully consumed (0-1 points left)
    trimmedPolylines.removeWhere((p) => p.points.length < 2);

    // 2. Check if user is off the first active polyline
    if (trimmedPolylines.isNotEmpty) {
      final activePolyline = trimmedPolylines.first;

      // Only reroute walking segments (dashed orange) or the first segment
      if (_isOffRoute(userPos, activePolyline.points,
          thresholdMeters: _offRouteThresholdMeters)) {
        // Throttle: max one reroute every 30 seconds
        final now = DateTime.now();
        if (_lastRerouteTime == null ||
            now.difference(_lastRerouteTime!).inSeconds >= 30) {
          _lastRerouteTime = now;
          print("🔄 Off-route detected — re-fetching active segment");

          try {
            final newPath = await _fetchPolyline(userPos, _currentTaskTarget!);
            if (newPath.isNotEmpty && !_disposed && mounted) {
              // Replace the first polyline with the rerouted one
              final updatedPolylines = trimmedPolylines.toList();
              updatedPolylines[0] = activePolyline.copyWith(
                pointsParam: newPath,
              );
              setState(() {
                _polylines = updatedPolylines.toSet();
              });
              return;
            }
          } catch (e) {
            print("❌ Reroute failed: $e");
          }
        }
      }
    }

    // 3. Apply trimmed polylines
    if (!_disposed && mounted) {
      setState(() {
        _polylines = trimmedPolylines;
      });
    }
  }

  // Helper to find nearest point in a route
  LatLng _findNearestPoint(List<LatLng> routePoints, LatLng target) {
    double minDist = double.infinity;
    LatLng? nearest;
    for (final p in routePoints) {
      final d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        target.latitude,
        target.longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearest = p;
      }
    }
    return nearest!;
  }

  // ========== FARE CALCULATION METHODS ==========

  double calculateJeepneyFare(double distanceKm) {
    if (distanceKm <= 4.0) {
      return 13.0;
    } else {
      double succeedingKm = distanceKm - 4.0;
      return (13.0 + (succeedingKm * 1.8)).roundToDouble();
    }
  }

  double calculateHabalFare(double distanceKm) {
    if (distanceKm <= 2.0) {
      return 50.0;
    } else if (distanceKm <= 8.0) {
      double succeedingKm = distanceKm - 2.0;
      return 50.0 + (9.0 * succeedingKm);
    } else {
      double succeedingKm = distanceKm - 8.0;
      return 50.0 + (9.0 * 6.0) + (15.0 * succeedingKm);
    }
  }

  double calculateSikadFare(double distanceKm) {
    return 15.0; // Placeholder
  }

  double calculateWalkingFare(double distanceKm) {
    return 0.0;
  }

  // Calculate weighted score with 6:4 ratio (fare:distance)
  // Mode-specific normalization for fair comparison
  double calculateRouteScore(double totalDistance, double totalFare,
      {String mode = "mixed"}) {
    // Set max fare based on transport mode for proper normalization
    // All max fares calculated for 25km trips
    double maxFare;
    switch (mode.toLowerCase()) {
      case "jeepney":
        maxFare = 60.0; // Jeepney max: ₱13 base + (21km × ₱1.8) = ₱51 for 25km
        break;
      case "habal":
        maxFare = 370.0; // Habal max: (14.19 × 25) + 16.43 = ₱371 for 25km
        break;
      case "sikad":
        maxFare = 15.0; // Sikad flat ₱15 (not for long distances)
        break;
      case "walking":
        maxFare = 1.0;
        break;
      case "jeepney+jeepney":
        maxFare = 120;
        break;
      case "jeepney+habal":
        maxFare = 450.0; // Mixed habal + jeepney: ₱371 + ₱51 = ₱422
        break;
      default:
        maxFare = 450.0; // Generic mixed routes (multiple transfers)
    }

    // Normalize fare to 0-10 scale based on mode
    double normalizedFare = totalFare > 0 ? (totalFare / maxFare) * 10 : 0;

    // Normalize distance to 0-10 scale (25km = max expected distance)
    double normalizedDistance = (totalDistance / 25.0) * 10;

    // Apply 6:4 weighting (fare gets 60%, distance gets 40%)
    // Lower score is better
    double score = (normalizedFare * 0.6) + (normalizedDistance * 0.4);

    return score;
  }

  Future<Map<String, dynamic>> _getJeepneyRoutes(
    LatLng userLocation,
    LatLng destination,
  ) async {
    final jeepneyRoutes = await jeepneyRouteService.getAll('jeepneyRoutes');

    if (jeepneyRoutes.isEmpty) {
      throw Exception("No jeepney routes found.");
    }

    // Helper to find the closest point on any route
    double _minDistanceToRoute(JeepneyRoute route, LatLng point) {
      double minDist = double.infinity;
      for (final routePoint in route.points) {
        final d = Geolocator.distanceBetween(
          routePoint.latitude,
          routePoint.longitude,
          point.latitude,
          point.longitude,
        );
        if (d < minDist) minDist = d;
      }
      return minDist / 1000; // Convert meters to kilometers
    }

    // Maximum acceptable distance from route (in km)
    const maxDistanceFromRoute = 3.0; // Increased to 3km for more flexibility

    // 1️⃣ Try to find a single route that can serve both points
    JeepneyRoute? bestSingleRoute;
    double bestSingleRouteScore = double.infinity;

    print(
        "🔍 Checking ${jeepneyRoutes.length} routes for single ride option...");
    print(
        "📍 User location: ${userLocation.latitude}, ${userLocation.longitude}");
    print("🎯 Destination: ${destination.latitude}, ${destination.longitude}");

    for (final route in jeepneyRoutes) {
      final distToUser = _minDistanceToRoute(route, userLocation);
      final distToDest = _minDistanceToRoute(route, destination);

      print("\n🚍 Checking ${route.name}:");
      print("   User distance: ${distToUser.toStringAsFixed(2)}km");
      print("   Dest distance: ${distToDest.toStringAsFixed(2)}km");

      // Both points must be reasonably close to the route
      if (distToUser < maxDistanceFromRoute &&
          distToDest < maxDistanceFromRoute) {
        print("   ✓ Both within ${maxDistanceFromRoute}km");

        // Calculate actual jeepney ride distance (approximate)
        // This is the distance user needs to travel on the jeepney
        final jeepneyRideDistance = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          destination.latitude,
          destination.longitude,
        );

        // Calculate fare for this jeepney ride
        final fare = calculateJeepneyFare(jeepneyRideDistance);

        // Score based on weighted fare + distance (6:4 ratio)
        final score = calculateRouteScore(
            distToUser + distToDest + jeepneyRideDistance, fare,
            mode: "jeepney");
        print("   💰 Fare: ₱${fare.toStringAsFixed(0)}");
        print("   📊 Score: ${score.toStringAsFixed(2)}");

        if (score < bestSingleRouteScore) {
          bestSingleRouteScore = score;
          bestSingleRoute = route;
          print("   ⭐ New best route!");
        }
      } else {
        print("   ✗ Too far from route");
      }
    }

    // If we found a valid single route, use it
    if (bestSingleRoute != null) {
      final distToUser = _minDistanceToRoute(bestSingleRoute, userLocation);
      final distToDest = _minDistanceToRoute(bestSingleRoute, destination);

      print("✅ Single jeepney ride: ${bestSingleRoute.name}");
      print("   📍 User distance: ${distToUser.toStringAsFixed(2)}km");
      print("   🎯 Dest distance: ${distToDest.toStringAsFixed(2)}km");

      return {
        "type": "single",
        "routes": [bestSingleRoute],
        "transferPoint": null,
      };
    }

    // 2️⃣ No single route works - find best double route combination
    print("⚠️ No single route found, calculating double ride...");

    // Find nearest route to user
    jeepneyRoutes.sort((a, b) => _minDistanceToRoute(a, userLocation)
        .compareTo(_minDistanceToRoute(b, userLocation)));
    final nearestUserRoute = jeepneyRoutes.first;

    // Find nearest route to destination
    jeepneyRoutes.sort((a, b) => _minDistanceToRoute(a, destination)
        .compareTo(_minDistanceToRoute(b, destination)));
    final nearestDestinationRoute = jeepneyRoutes.first;

    // Find connecting point between the two routes
    double shortestConnection = double.infinity;
    LatLng? transferPoint;

    for (final p1 in nearestUserRoute.points) {
      for (final p2 in nearestDestinationRoute.points) {
        final d = Geolocator.distanceBetween(
          p1.latitude,
          p1.longitude,
          p2.latitude,
          p2.longitude,
        );
        if (d < shortestConnection) {
          shortestConnection = d;
          transferPoint = LatLng(p1.latitude, p1.longitude);
        }
      }
    }

    print(
        "🔄 Double ride: ${nearestUserRoute.name} → ${nearestDestinationRoute.name}");
    print(
        "   🔄 Transfer distance: ${(shortestConnection / 1000).toStringAsFixed(2)}km");

    return {
      "type": "double",
      "routes": [nearestUserRoute, nearestDestinationRoute],
      "transferPoint": transferPoint,
    };
  }

  Future<void> _setupMultimodalRoute(
      LatLng userLocation, LatLng destination) async {
    _tasks.clear();

    // Calculate distance between user and destination
    final distance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    print("🌐 Multimodal: Distance = ${distance.toStringAsFixed(2)} km");

    // Short distance (< 1 km) - Just walk
    if (distance < 1.0) {
      await _setupWalkingRoute(userLocation, destination);
      return;
    }

    // Medium distance (1-3 km) - Choose best single mode
    if (distance < 3.0) {
      await _setupMediumDistanceRoute(userLocation, destination);
      return;
    }

    // Long distance (3+ km) - Try combined modes
    await _setupLongDistanceRoute(userLocation, destination);
  }

  Future<void> _setupWalkingRoute(
      LatLng userLocation, LatLng destination) async {
    print("🚶 Short distance - Walking route");

    final walkingPath = await _fetchPolyline(userLocation, destination);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("walking_route"),
          color: Colors.orange,
          width: 6,
          points: walkingPath,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    _tasks.add({
      "title": "Walk to Destination",
      "shortDescription": "Walk directly to your destination.",
      "longDescription":
          "Your destination is nearby. Follow the path on the map.",
      "target": destination,
      "radius": 20.0,
    });

    _currentTaskIndex = 0;
    _setCurrentTask();

    final bounds = _boundsFromLatLngList(walkingPath);
    if (bounds != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _setupDirectRoute(
      LatLng userLocation, LatLng destination) async {
    print("🚗 Direct route - Using Google Maps directions");

    final directPath = await _fetchPolyline(userLocation, destination);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("direct_route"),
          color: Colors.blue,
          width: 6,
          points: directPath,
        ),
      };
    });

    _tasks.clear();
    _tasks.add({
      "title": "Navigate to Destination",
      "shortDescription": "Follow the route to your destination.",
      "longDescription":
          "Follow the blue line on the map to reach your destination using the most direct route.",
      "target": destination,
      "radius": 20.0,
    });

    _currentTaskIndex = 0;
    _setCurrentTask();

    final bounds = _boundsFromLatLngList(directPath);
    if (bounds != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _setupMediumDistanceRoute(
      LatLng userLocation, LatLng destination) async {
    print("🚕 Medium distance - Choosing best single mode");

    // Calculate total trip distance
    final tripDistance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Check user preferences
    final canUseHabal = _transportPreferences["habal"] ?? false;
    final canUseJeepney = _transportPreferences["jeepney"] ?? false;

    // Option 1: Walking
    double walkingDistance = tripDistance;
    double walkingFare = calculateWalkingFare(walkingDistance);
    double walkingScore =
        calculateRouteScore(walkingDistance, walkingFare, mode: "walking");
    print(
        "🚶 Walking: ${walkingDistance.toStringAsFixed(2)}km, ₱${walkingFare.toStringAsFixed(0)}, Score: ${walkingScore.toStringAsFixed(2)}");

    // Option 2: Habal
    double habalScore = double.infinity;
    TransportationMarkers? nearestHabal;
    if (canUseHabal) {
      nearestHabal = await _findNearestHabal(userLocation);
      if (nearestHabal != null) {
        final walkToHabal = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          nearestHabal.latLng.latitude,
          nearestHabal.latLng.longitude,
        );
        final habalRide = calculateDistance(
          nearestHabal.latLng.latitude,
          nearestHabal.latLng.longitude,
          destination.latitude,
          destination.longitude,
        );
        final habalDistance = walkToHabal + habalRide;
        final habalFare = calculateHabalFare(habalRide);
        habalScore =
            calculateRouteScore(habalDistance, habalFare, mode: "habal");
        print(
            "🏍️ Habal: ${habalDistance.toStringAsFixed(2)}km, ₱${habalFare.toStringAsFixed(0)}, Score: ${habalScore.toStringAsFixed(2)}");
      }
    }

    // Option 3: Jeepney
    double jeepneyScore = double.infinity;
    Map<String, dynamic>? jeepneyResult;
    if (canUseJeepney) {
      try {
        jeepneyResult = await _getJeepneyRoutes(userLocation, destination);
        final jeepneyRoutes = jeepneyResult["routes"] as List<JeepneyRoute>;
        final firstRoute = jeepneyRoutes[0];

        final jeepneyPickup = _findNearestPoint(
          firstRoute.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          userLocation,
        );

        final walkToJeepney = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          jeepneyPickup.latitude,
          jeepneyPickup.longitude,
        );

        final jeepneyRide = calculateDistance(
          jeepneyPickup.latitude,
          jeepneyPickup.longitude,
          destination.latitude,
          destination.longitude,
        );

        final jeepneyDistance = walkToJeepney + jeepneyRide;
        final jeepneyFare = calculateJeepneyFare(jeepneyRide);
        jeepneyScore =
            calculateRouteScore(jeepneyDistance, jeepneyFare, mode: "jeepney");
        print(
            "🚎 Jeepney: ${jeepneyDistance.toStringAsFixed(2)}km, ₱${jeepneyFare.toStringAsFixed(0)}, Score: ${jeepneyScore.toStringAsFixed(2)}");
      } catch (e) {
        print("⚠️ No jeepney routes available");
      }
    }

    // Choose the option with the best score (lowest)
    if (jeepneyScore <= walkingScore && jeepneyScore <= habalScore) {
      print("✅ Best option: Jeepney");
      await _setupJeepneyRouteWithPolylines(userLocation, destination);
    } else if (habalScore <= walkingScore) {
      print("✅ Best option: Habal");
      await _setupHabalRouteWithPolylines(
          userLocation, nearestHabal!.latLng, destination);
    } else {
      print("✅ Best option: Walking");
      await _setupWalkingRoute(userLocation, destination);
    }
  }

  Future<void> _setupLongDistanceRoute(
      LatLng userLocation, LatLng destination) async {
    print("🚌 Long distance - Comparing all multimodal route options");

    final tripDistance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Check user preferences
    final canUseHabal = _transportPreferences["habal"] ?? false;
    final canUseJeepney = _transportPreferences["jeepney"] ?? false;

    // Store all route options with their scores
    Map<String, dynamic> bestOption = {
      "score": double.infinity,
      "name": "Walking",
      "action": () => _setupWalkingRoute(userLocation, destination),
    };

    // Get transport data upfront
    TransportationMarkers? nearestHabal;
    Map<String, dynamic>? jeepneyResult;
    LatLng? jeepneyPickup;
    LatLng? jeepneyDropoff;

    if (canUseHabal) {
      nearestHabal = await _findNearestHabal(userLocation);
    }

    if (canUseJeepney) {
      try {
        jeepneyResult = await _getJeepneyRoutes(userLocation, destination);
        final firstRoute = jeepneyResult["routes"][0] as JeepneyRoute;
        jeepneyPickup = _findNearestPoint(
          firstRoute.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          userLocation,
        );
        jeepneyDropoff = _findNearestPoint(
          firstRoute.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          destination,
        );
      } catch (e) {
        print("⚠️ Jeepney routes unavailable: $e");
      }
    }

    print(
        "\n🔍 Evaluating route options for ${tripDistance.toStringAsFixed(2)}km trip:\n");

    // === OPTION 1: Habal Only (Direct) ===
    if (canUseHabal && nearestHabal != null) {
      final walkToHabal = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        nearestHabal.latLng.latitude,
        nearestHabal.latLng.longitude,
      );
      final habalRide = calculateDistance(
        nearestHabal.latLng.latitude,
        nearestHabal.latLng.longitude,
        destination.latitude,
        destination.longitude,
      );
      final totalDistance = walkToHabal + habalRide;
      final fare = calculateHabalFare(habalRide);
      final score = calculateRouteScore(totalDistance, fare, mode: "habal");

      print(
          "🏍️ Habal Only: ${totalDistance.toStringAsFixed(2)}km, ₱${fare.toStringAsFixed(0)}, Score: ${score.toStringAsFixed(2)}");

      if (score < bestOption["score"]) {
        bestOption = {
          "score": score,
          "name": "Habal Only",
          "action": () => _setupHabalRouteWithPolylines(
              userLocation, nearestHabal!.latLng, destination),
        };
      }
    }

    // === OPTION 2: Walk + Jeepney (Basic) ===
    if (canUseJeepney && jeepneyPickup != null && jeepneyDropoff != null) {
      final walkToJeepney = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
      );
      final jeepneyRide = calculateDistance(
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
        jeepneyDropoff.latitude,
        jeepneyDropoff.longitude,
      );
      final walkFromJeepney = calculateDistance(
        jeepneyDropoff.latitude,
        jeepneyDropoff.longitude,
        destination.latitude,
        destination.longitude,
      );
      final totalDistance = walkToJeepney + jeepneyRide + walkFromJeepney;
      final fare = calculateJeepneyFare(jeepneyRide);

      // Check if it's single or double jeepney route
      final jeepneyType = jeepneyResult!["type"] as String;
      final jeepneyMode =
          jeepneyType == "single" ? "jeepney" : "jeepney+jeepney";
      final score = calculateRouteScore(totalDistance, fare, mode: jeepneyMode);

      print(
          "🚶+🚎 Walk+Jeepney: ${totalDistance.toStringAsFixed(2)}km, ₱${fare.toStringAsFixed(0)}, Score: ${score.toStringAsFixed(2)}");

      if (score < bestOption["score"]) {
        bestOption = {
          "score": score,
          "name": "Walk + Jeepney",
          "action": () =>
              _setupJeepneyRouteWithPolylines(userLocation, destination),
        };
      }

      // === OPTION 3: Walk + Jeepney + Habal (if final walk is long) ===
      if (canUseHabal && walkFromJeepney > 1.0 && nearestHabal != null) {
        // Check if there's a habal within 1km of jeepney dropoff
        final dropoffLocation = jeepneyDropoff; // Capture for null safety
        final habalMarkers =
            await transportationService.getAll('transportationMarkers');
        final habalsNearDropoff = habalMarkers.where((m) {
          if (m.vehicleType.toLowerCase() != 'habal') return false;

          final dist = calculateDistance(
            dropoffLocation.latitude,
            dropoffLocation.longitude,
            m.coordinates.latitude,
            m.coordinates.longitude,
          );
          return dist <= 1.0; // Within 1km
        }).toList();

        if (habalsNearDropoff.isNotEmpty) {
          // Find the closest habal to jeepney dropoff
          habalsNearDropoff.sort((a, b) {
            final distA = calculateDistance(
              dropoffLocation.latitude,
              dropoffLocation.longitude,
              a.coordinates.latitude,
              a.coordinates.longitude,
            );
            final distB = calculateDistance(
              dropoffLocation.latitude,
              dropoffLocation.longitude,
              b.coordinates.latitude,
              b.coordinates.longitude,
            );
            return distA.compareTo(distB);
          });

          final nearestDropoffHabal = habalsNearDropoff.first;
          final habalToDestination = calculateDistance(
            nearestDropoffHabal.latLng.latitude,
            nearestDropoffHabal.latLng.longitude,
            destination.latitude,
            destination.longitude,
          );
          final totalDistanceWithHabal =
              walkToJeepney + jeepneyRide + habalToDestination;
          final jeepneyFare = calculateJeepneyFare(jeepneyRide);
          final habalFare = calculateHabalFare(habalToDestination);
          final totalFare = jeepneyFare + habalFare;
          final scoreWithHabal = calculateRouteScore(
              totalDistanceWithHabal, totalFare,
              mode: "jeepney+habal");

          print(
              "🚶+🚎+🏍️ Walk+Jeepney+Habal: ${totalDistanceWithHabal.toStringAsFixed(2)}km, ₱${totalFare.toStringAsFixed(0)}, Score: ${scoreWithHabal.toStringAsFixed(2)}");

          if (scoreWithHabal < bestOption["score"]) {
            bestOption = {
              "score": scoreWithHabal,
              "name": "Walk + Jeepney + Habal",
              "action": () =>
                  _setupJeepneyRouteWithPolylines(userLocation, destination),
            };
          }
        } else {
          print(
              "⚠️ Walk+Jeepney+Habal excluded: No habal within 1km of jeepney dropoff");
        }
      }

      // === OPTION 4: Habal + Jeepney (if walk to jeepney is long) ===
      if (canUseHabal && walkToJeepney > 1.0 && nearestHabal != null) {
        final walkToHabal = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          nearestHabal.latLng.latitude,
          nearestHabal.latLng.longitude,
        );
        final habalToJeepney = calculateDistance(
          nearestHabal.latLng.latitude,
          nearestHabal.latLng.longitude,
          jeepneyPickup.latitude,
          jeepneyPickup.longitude,
        );
        final jeepneyRide = calculateDistance(
          jeepneyPickup.latitude,
          jeepneyPickup.longitude,
          jeepneyDropoff.latitude,
          jeepneyDropoff.longitude,
        );
        final walkFromJeepney = calculateDistance(
          jeepneyDropoff.latitude,
          jeepneyDropoff.longitude,
          destination.latitude,
          destination.longitude,
        );
        final totalDistance =
            walkToHabal + habalToJeepney + jeepneyRide + walkFromJeepney;
        final habalFare = calculateHabalFare(habalToJeepney);
        final jeepneyFare = calculateJeepneyFare(jeepneyRide);
        final totalFare = habalFare + jeepneyFare;
        final score = calculateRouteScore(totalDistance, totalFare,
            mode: "habal+jeepney");

        print(
            "🏍️+🚎 Habal+Jeepney: ${totalDistance.toStringAsFixed(2)}km, ₱${totalFare.toStringAsFixed(0)}, Score: ${score.toStringAsFixed(2)}");

        if (score < bestOption["score"]) {
          bestOption = {
            "score": score,
            "name": "Habal + Jeepney",
            "action": () => _setupHabalToJeepneyRoute(
                  userLocation,
                  nearestHabal!.latLng,
                  jeepneyPickup!,
                  destination,
                  jeepneyResult!,
                ),
          };
        }
      }
    }

    // Execute best option
    print(
        "\n✅ Best option: ${bestOption["name"]} (Score: ${bestOption["score"].toStringAsFixed(2)})\n");
    await bestOption["action"]();
  }

  Future<void> _showTransportPreferencesDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.settings, color: Colors.indigoAccent),
                  SizedBox(width: 8),
                  Text(
                    "Transport Preferences",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select which modes of transport you're willing to use:",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    _buildTransportToggle(
                      "Walking",
                      "walking",
                      Icons.directions_walk,
                      Colors.orange,
                      setState,
                    ),
                    const Divider(),
                    _buildTransportToggle(
                      "Jeepney",
                      "jeepney",
                      Icons.directions_bus,
                      Colors.green,
                      setState,
                    ),
                    const Divider(),
                    _buildTransportToggle(
                      "Habal-Habal (Motorcycle)",
                      "habal",
                      Icons.motorcycle,
                      Colors.blue,
                      setState,
                    ),
                    const Divider(),
                    _buildTransportToggle(
                      "Sikad (Tricycle)",
                      "sikad",
                      Icons.pedal_bike,
                      Colors.purple,
                      setState,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline,
                              size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Note: Walking is recommended for short distances.",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransportToggle(
    String label,
    String key,
    IconData icon,
    Color color,
    StateSetter setState,
  ) {
    final isEnabled = _transportPreferences[key] ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          this.setState(() {
            _transportPreferences[key] = !isEnabled;
          });
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isEnabled ? color.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isEnabled ? color : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isEnabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (value) {
                setState(() {
                  this.setState(() {
                    _transportPreferences[key] = value;
                  });
                });
              },
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setupHabalToJeepneyRoute(
    LatLng userLocation,
    LatLng habalLocation,
    LatLng jeepneyPickup,
    LatLng destination,
    Map<String, dynamic> jeepneyResult,
  ) async {
    _tasks.clear();
    final polylines = <Polyline>{};

    // Calculate habal ride distance
    final habalRideDistance = calculateDistance(
      habalLocation.latitude,
      habalLocation.longitude,
      jeepneyPickup.latitude,
      jeepneyPickup.longitude,
    );
    final habalFare = calculateHabalFare(habalRideDistance);

    // Calculate total jeepney fare for the walk to habal task
    final jeepneyType = jeepneyResult["type"] as String;
    final routes = jeepneyResult["routes"] as List<JeepneyRoute>;
    final firstRoute = routes[0];

    double totalJeepneyFare;
    if (jeepneyType == "single") {
      final nearestToDest = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );
      final jeepneyRideDistance = calculateDistance(
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      totalJeepneyFare = calculateJeepneyFare(jeepneyRideDistance);
    } else {
      // Double jeepney
      final transferPoint = jeepneyResult["transferPoint"] as LatLng;
      final secondRoute = routes[1];

      final firstLegDistance = calculateDistance(
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
        transferPoint.latitude,
        transferPoint.longitude,
      );
      final firstLegFare = calculateJeepneyFare(firstLegDistance);

      final secondRouteStart = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        transferPoint,
      );
      final nearestToDest = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );
      final secondLegDistance = calculateDistance(
        secondRouteStart.latitude,
        secondRouteStart.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final secondLegFare = calculateJeepneyFare(secondLegDistance);

      totalJeepneyFare = firstLegFare + secondLegFare;
    }

    final totalFare = habalFare + totalJeepneyFare;

    // 1️⃣ Walk to Habal
    final userToHabal = await _fetchPolyline(userLocation, habalLocation);
    polylines.add(
      Polyline(
        polylineId: const PolylineId("walk_to_habal"),
        color: Colors.orange,
        width: 6,
        points: userToHabal,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );

    _tasks.add({
      "title": "Walk to Habal",
      "shortDescription":
          "Walk to the nearest Habal station (₱${totalFare.toStringAsFixed(0)} total).",
      "longDescription":
          "Start by walking to the Habal pickup point. Total fare: ₱${habalFare.toStringAsFixed(0)} (Habal) + ₱${totalJeepneyFare.toStringAsFixed(0)} (Jeepney).",
      "target": habalLocation,
      "radius": 15.0,
    });

    // 2️⃣ Ride Habal to Jeepney
    final habalToJeepney = await _fetchPolyline(habalLocation, jeepneyPickup);
    polylines.add(
      Polyline(
        polylineId: const PolylineId("habal_to_jeepney"),
        color: Colors.green,
        width: 6,
        points: habalToJeepney,
      ),
    );

    _tasks.add({
      "title": "Ride Habal to Jeepney Stop",
      "shortDescription":
          "Take the Habal to the jeepney pickup point (₱${habalFare.toStringAsFixed(0)}).",
      "longDescription":
          "Ride the Habal to reach the jeepney route. Fare: ₱${habalFare.toStringAsFixed(0)} for ${habalRideDistance.toStringAsFixed(1)}km.",
      "target": jeepneyPickup,
      "radius": 25.0,
    });

    // 3️⃣ Add Jeepney segments
    if (jeepneyType == "single") {
      final nearestToDest = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );

      // Calculate jeepney ride distance
      final jeepneyRideDistance = calculateDistance(
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final jeepneyFare = calculateJeepneyFare(jeepneyRideDistance);

      final jeepneyRoute = await _fetchPolyline(jeepneyPickup, nearestToDest);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_route"),
          color: Colors.blue,
          width: 6,
          points: jeepneyRoute,
        ),
      );

      _tasks.add({
        "title": "Ride Jeepney",
        "shortDescription":
            "Ride ${firstRoute.name} to your destination (₱${jeepneyFare.toStringAsFixed(0)}).",
        "longDescription":
            "Take ${firstRoute.name} until you're near your destination. Fare: ₱${jeepneyFare.toStringAsFixed(0)} for ${jeepneyRideDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
        "radius": 30.0,
      });

      // Final walk if needed
      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (endDist > 50) {
        final finalWalk = await _fetchPolyline(nearestToDest, destination);
        polylines.add(
          Polyline(
            polylineId: const PolylineId("final_walk"),
            color: Colors.orange,
            width: 6,
            points: finalWalk,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );

        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the final distance to your destination.",
          "longDescription": "Complete your journey with a short walk.",
          "target": destination,
          "radius": 20.0,
        });
      }
    } else {
      // Double jeepney
      final transferPoint = jeepneyResult["transferPoint"] as LatLng;
      final secondRoute = routes[1];

      // Calculate first jeepney leg distance
      final firstLegDistance = calculateDistance(
        jeepneyPickup.latitude,
        jeepneyPickup.longitude,
        transferPoint.latitude,
        transferPoint.longitude,
      );
      final firstLegFare = calculateJeepneyFare(firstLegDistance);

      final firstLeg = await _fetchPolyline(jeepneyPickup, transferPoint);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_first_leg"),
          color: Colors.blue,
          width: 6,
          points: firstLeg,
        ),
      );

      _tasks.add({
        "title": "Ride ${firstRoute.name}",
        "shortDescription":
            "Take ${firstRoute.name} to the transfer point (₱${firstLegFare.toStringAsFixed(0)}).",
        "longDescription":
            "Ride ${firstRoute.name} until the transfer point. Fare: ₱${firstLegFare.toStringAsFixed(0)} for ${firstLegDistance.toStringAsFixed(1)}km.",
        "target": transferPoint,
        "radius": 30.0,
      });

      _tasks.add({
        "title": "Transfer Jeepney",
        "shortDescription": "Switch to ${secondRoute.name}.",
        "longDescription": "Wait for and board ${secondRoute.name}.",
        "target": transferPoint,
        "radius": 25.0,
      });

      final nearestToDest = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );

      // Calculate second jeepney leg distance
      final secondLegDistance = calculateDistance(
        transferPoint.latitude,
        transferPoint.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final secondLegFare = calculateJeepneyFare(secondLegDistance);

      final secondLeg = await _fetchPolyline(transferPoint, nearestToDest);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_second_leg"),
          color: Colors.purple,
          width: 6,
          points: secondLeg,
        ),
      );

      _tasks.add({
        "title": "Ride ${secondRoute.name}",
        "shortDescription":
            "Take ${secondRoute.name} to your destination (₱${secondLegFare.toStringAsFixed(0)}).",
        "longDescription":
            "Ride ${secondRoute.name} until you're near your destination. Fare: ₱${secondLegFare.toStringAsFixed(0)} for ${secondLegDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
        "radius": 30.0,
      });

      // Final walk if needed
      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (endDist > 50) {
        final finalWalk = await _fetchPolyline(nearestToDest, destination);
        polylines.add(
          Polyline(
            polylineId: const PolylineId("final_walk"),
            color: Colors.orange,
            width: 6,
            points: finalWalk,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );

        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the final distance to your destination.",
          "longDescription": "Complete your journey with a short walk.",
          "target": destination,
          "radius": 20.0,
        });
      }
    }

    setState(() {
      _polylines = polylines;
    });

    _currentTaskIndex = 0;
    _setCurrentTask();

    final allPoints = polylines.expand((p) => p.points).toList();
    final bounds = _boundsFromLatLngList(allPoints);
    if (bounds != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _setupHabalRouteWithPolylines(
    LatLng userLocation,
    LatLng habalLocation,
    LatLng destination,
  ) async {
    _tasks.clear();

    // Calculate habal ride distance
    final habalRideDistance = calculateDistance(
      habalLocation.latitude,
      habalLocation.longitude,
      destination.latitude,
      destination.longitude,
    );
    final habalFare = calculateHabalFare(habalRideDistance);

    final userToHabal = await _fetchPolyline(userLocation, habalLocation);
    final habalToDest = await _fetchPolyline(habalLocation, destination);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("user_to_habal"),
          color: Colors.orange,
          width: 6,
          points: userToHabal,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
        Polyline(
          polylineId: const PolylineId("habal_to_dest"),
          color: Colors.green,
          width: 6,
          points: habalToDest,
        ),
      };
    });

    _tasks.add({
      "title": "Walk to Habal",
      "shortDescription":
          "Walk to the nearest Habal station (₱${habalFare.toStringAsFixed(0)}).",
      "longDescription":
          "Head to the Habal pickup point to start your ride. Upcoming fare: ₱${habalFare.toStringAsFixed(0)} for ${habalRideDistance.toStringAsFixed(1)}km.",
      "target": habalLocation,
      "radius": 30.0,
    });

    _tasks.add({
      "title": "Ride Habal",
      "shortDescription":
          "Ride the Habal to your destination (₱${habalFare.toStringAsFixed(0)}).",
      "longDescription":
          "Take the Habal directly to your destination. Fare: ₱${habalFare.toStringAsFixed(0)} for ${habalRideDistance.toStringAsFixed(1)}km.",
      "target": destination,
      "radius": 2300.0,
    });

    _currentTaskIndex = 0;
    _setCurrentTask();

    final bounds = _boundsFromLatLngList(userToHabal);
    if (bounds != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _setupJeepneyRouteWithPolylines(
      LatLng userLocation, LatLng destination) async {
    _tasks.clear();

    final routeResult = await _getJeepneyRoutes(userLocation, destination);
    final firstRoute = routeResult["routes"][0] as JeepneyRoute;
    final startPoint = _findNearestPoint(
      firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      userLocation,
    );

    final userToJeepney = await _fetchPolyline(userLocation, startPoint);
    final polylines = <Polyline>{};

    polylines.add(
      Polyline(
        polylineId: const PolylineId("user_to_jeepney"),
        color: Colors.orange,
        width: 6,
        points: userToJeepney,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );

    // Calculate fare for the walk to jeepney task
    double totalJeepneyFare;
    String fareDescription;
    if (routeResult["type"] == "single") {
      final nearestToDest = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );
      final jeepneyRideDistance = calculateDistance(
        startPoint.latitude,
        startPoint.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      totalJeepneyFare = calculateJeepneyFare(jeepneyRideDistance);
      fareDescription = "${jeepneyRideDistance.toStringAsFixed(1)}km";
    } else {
      // Double jeepney - calculate both legs
      final transferPoint = routeResult["transferPoint"] as LatLng;
      final secondRoute = routeResult["routes"][1] as JeepneyRoute;

      final firstLegDistance = calculateDistance(
        startPoint.latitude,
        startPoint.longitude,
        transferPoint.latitude,
        transferPoint.longitude,
      );
      final firstLegFare = calculateJeepneyFare(firstLegDistance);

      final secondRouteStart = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        transferPoint,
      );
      final nearestToDest = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );
      final secondLegDistance = calculateDistance(
        secondRouteStart.latitude,
        secondRouteStart.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final secondLegFare = calculateJeepneyFare(secondLegDistance);

      totalJeepneyFare = firstLegFare + secondLegFare;
      fareDescription = "total";
    }

    _tasks.add({
      "title": "Walk to Jeepney Stop",
      "shortDescription":
          "Walk to the nearest pickup point for ${firstRoute.name} (₱${totalJeepneyFare.toStringAsFixed(0)}).",
      "longDescription":
          "Walk to ${firstRoute.name}'s pickup location to start your journey. Upcoming fare: ₱${totalJeepneyFare.toStringAsFixed(0)} $fareDescription.",
      "target": startPoint,
      "radius": 30.0,
    });

    if (routeResult["type"] == "single") {
      final nearestToDest = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );

      // Calculate jeepney ride distance
      final jeepneyRideDistance = calculateDistance(
        startPoint.latitude,
        startPoint.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final jeepneyFare = calculateJeepneyFare(jeepneyRideDistance);

      final jeepneyToNearest = await _fetchPolyline(startPoint, nearestToDest);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_route"),
          color: Colors.green,
          width: 6,
          points: jeepneyToNearest,
        ),
      );

      _tasks.add({
        "title": "Ride Jeepney",
        "shortDescription":
            "Ride ${firstRoute.name} to reach near your destination (₱${jeepneyFare.toStringAsFixed(0)}).",
        "longDescription":
            "Stay on ${firstRoute.name} until you're close to your destination. Fare: ₱${jeepneyFare.toStringAsFixed(0)} for ${jeepneyRideDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
        "radius": 30.0,
      });

      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (endDist > 50) {
        final finalWalk = await _fetchPolyline(nearestToDest, destination);
        polylines.add(
          Polyline(
            polylineId: const PolylineId("final_walk"),
            color: Colors.orange,
            width: 6,
            points: finalWalk,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );

        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the last few meters to your destination.",
          "longDescription":
              "You've reached near your destination — finish the last walk.",
          "target": destination,
          "radius": 20.0,
        });
      }
    } else {
      // Double jeepney
      final transferPoint = routeResult["transferPoint"] as LatLng;
      final secondRoute = routeResult["routes"][1] as JeepneyRoute;

      // Calculate first jeepney leg distance
      final firstLegDistance = calculateDistance(
        startPoint.latitude,
        startPoint.longitude,
        transferPoint.latitude,
        transferPoint.longitude,
      );
      final firstLegFare = calculateJeepneyFare(firstLegDistance);

      final firstLeg = await _fetchPolyline(startPoint, transferPoint);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_first_leg"),
          color: Colors.green,
          width: 6,
          points: firstLeg,
        ),
      );

      _tasks.add({
        "title": "Ride ${firstRoute.name}",
        "shortDescription":
            "Ride ${firstRoute.name} to the transfer point (₱${firstLegFare.toStringAsFixed(0)}).",
        "longDescription":
            "Take ${firstRoute.name} until the transfer point for your next jeepney. Fare: ₱${firstLegFare.toStringAsFixed(0)} for ${firstLegDistance.toStringAsFixed(1)}km.",
        "target": transferPoint,
        "radius": 30.0,
      });

      _tasks.add({
        "title": "Transfer Jeepney",
        "shortDescription": "Transfer to ${secondRoute.name}.",
        "longDescription":
            "Switch to ${secondRoute.name} to continue your journey.",
        "target": transferPoint,
        "radius": 25.0,
      });

      final nearestToDest = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        destination,
      );

      // Calculate second jeepney leg distance
      final secondLegDistance = calculateDistance(
        transferPoint.latitude,
        transferPoint.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final secondLegFare = calculateJeepneyFare(secondLegDistance);

      final secondLeg = await _fetchPolyline(transferPoint, nearestToDest);
      polylines.add(
        Polyline(
          polylineId: const PolylineId("jeepney_second_leg"),
          color: Colors.blue,
          width: 6,
          points: secondLeg,
        ),
      );

      _tasks.add({
        "title": "Ride ${secondRoute.name}",
        "shortDescription":
            "Ride ${secondRoute.name} near your destination (₱${secondLegFare.toStringAsFixed(0)}).",
        "longDescription":
            "Ride ${secondRoute.name} close to your destination stop. Fare: ₱${secondLegFare.toStringAsFixed(0)} for ${secondLegDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
        "radius": 30.0,
      });

      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (endDist > 50) {
        final finalWalk = await _fetchPolyline(nearestToDest, destination);
        polylines.add(
          Polyline(
            polylineId: const PolylineId("final_walk"),
            color: Colors.orange,
            width: 6,
            points: finalWalk,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );

        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the last few meters to your destination.",
          "longDescription":
              "You've reached near your destination — finish the last walk.",
          "target": destination,
          "radius": 20.0,
        });
      }
    }

    setState(() {
      _polylines = polylines;
    });

    _currentTaskIndex = 0;
    _setCurrentTask();

    final allPoints = polylines.expand((p) => p.points).toList();
    final bounds = _boundsFromLatLngList(allPoints);
    if (bounds != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _setupJeepneyTasks(LatLng userLocation, LatLng dest) async {
    _tasks.clear();
    final routeResult = await _getJeepneyRoutes(userLocation, dest);
    final routes = routeResult["routes"] as List<JeepneyRoute>;
    final type = routeResult["type"] as String;

    if (type == "single") {
      final firstRoute = routes[0];
      final startPoint = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        userLocation,
      );

      // Calculate jeepney ride distance and fare
      final nearestToDest = _findNearestPoint(
        firstRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        dest,
      );
      final jeepneyRideDistance = calculateDistance(
        startPoint.latitude,
        startPoint.longitude,
        nearestToDest.latitude,
        nearestToDest.longitude,
      );
      final jeepneyFare = calculateJeepneyFare(jeepneyRideDistance);

      // Walk to the jeepney stop
      _tasks.add({
        "title": "Walk to Jeepney Stop",
        "shortDescription":
            "Walk to the nearest pickup point for ${firstRoute.name}.",
        "longDescription":
            "Walk to ${firstRoute.name}’s pickup location to start your journey. \n\n Upcoming Fare: ₱${jeepneyFare.toStringAsFixed(0)}",
        "target": startPoint,
      });

      // Ride the jeepney
      _tasks.add({
        "title": "Ride Jeepney",
        "shortDescription":
            "Ride ${firstRoute.name} to reach near your destination.",
        "longDescription":
            "Stay on ${firstRoute.name} until you’re close to your destination. \n\nFare: ₱${jeepneyFare.toStringAsFixed(0)}\n Distance:${jeepneyRideDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
      });

      // 3️⃣ Final walk if far
      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        dest.latitude,
        dest.longitude,
      );
      if (endDist > 50) {
        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the last few meters to your destination.",
          "longDescription":
              "You’ve reached near your destination — finish the last walk.",
          "target": dest,
        });
      }
    } else {
      // 🚎 Double Jeepney

      final firstRoute = routes[0];
      final secondRoute = routes[1];
      final transferPoint = routeResult["transferPoint"] as LatLng;
      final startPoint = LatLng(
          firstRoute.points.first.latitude, firstRoute.points.first.longitude);

      final nearestToDest = _findNearestPoint(
        secondRoute.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        dest,
      );

      final firstRouteDistance = calculateDistance(
          startPoint.latitude,
          startPoint.longitude,
          transferPoint.latitude,
          transferPoint.longitude);

      final secondRouteDistance = calculateDistance(
          secondRoute.points.first.latitude,
          secondRoute.points.first.longitude,
          nearestToDest.latitude,
          nearestToDest.longitude);

      final firstJeepneyFare = calculateJeepneyFare(firstRouteDistance);
      final secondJeepneyFare = calculateJeepneyFare(secondRouteDistance);
      final totalFare = firstJeepneyFare + secondJeepneyFare;

      _tasks.add({
        "title": "Walk to First Jeepney Stop",
        "shortDescription":
            "Walk to the nearest pickup point for ${firstRoute.name}.",
        "longDescription":
            "Start by walking to ${firstRoute.name}’s pickup stop.\n\n Upcoming Fare: ₱${totalFare.toStringAsFixed(0)} (₱${firstJeepneyFare.toStringAsFixed(0)} for ${firstRouteDistance.toStringAsFixed(1)}km + ₱${secondJeepneyFare.toStringAsFixed(0)} for ${secondRouteDistance.toStringAsFixed(1)}km)",
        "target": startPoint,
      });

      _tasks.add({
        "title": "Ride First Jeepney",
        "shortDescription": "Ride ${firstRoute.name} to the transfer point.",
        "longDescription":
            "Take ${firstRoute.name} until the transfer point for your next jeepney.\n\n Fare: ₱${firstJeepneyFare.toStringAsFixed(0)}\n Distance: ${firstRouteDistance.toStringAsFixed(1)}km.",
        "target": transferPoint,
      });

      _tasks.add({
        "title": "Transfer Jeepney",
        "shortDescription": "Transfer to ${secondRoute.name}.",
        "longDescription":
            "Switch to ${secondRoute.name} to continue your journey.\n\n Upcoming Fare: ₱${secondJeepneyFare.toStringAsFixed(0)}",
        "target": transferPoint,
      });

      _tasks.add({
        "title": "Ride Second Jeepney",
        "shortDescription": "Ride ${secondRoute.name} near your destination.",
        "longDescription":
            "Ride ${secondRoute.name} close to your destination stop. \n\nFare: ₱${secondJeepneyFare.toStringAsFixed(0)}\n Distance: ${secondRouteDistance.toStringAsFixed(1)}km.",
        "target": nearestToDest,
      });

      final endDist = Geolocator.distanceBetween(
        nearestToDest.latitude,
        nearestToDest.longitude,
        dest.latitude,
        dest.longitude,
      );
      if (endDist > 50) {
        _tasks.add({
          "title": "Walk to Destination",
          "shortDescription": "Walk the last few meters to your destination.",
          "longDescription":
              "You’ve reached near your destination — finish the last walk.",
          "target": dest,
        });
      }
    }

    _currentTaskIndex = 0;
    _setCurrentTask();
  }

  void _setupHabalTasks(
      LatLng userLocation, LatLng nearestHabal, LatLng destination) {
    final distance = Geolocator.distanceBetween(
          nearestHabal.latitude,
          nearestHabal.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;

    print("Estimated Distance: $distance km");

    final fare = calculateHabalFare(distance);
    _tasks = [
      {
        "title": "Walk",
        "shortDescription": "Walk to the nearest Habal marker.",
        "longDescription":
            "Follow the suggested path on the map to reach the nearest Habal station. Once you arrive, your next task will start automatically. \n\n Upcoming Fare: ₱${fare.toStringAsFixed(0)}",
        "target": nearestHabal,
        "radius": 15.0,
      },
      {
        "title": "Ride",
        "shortDescription": "Ride the Habal until you reach your destination.",
        "longDescription":
            "Stay on the Habal until you reach your destination marker. You can monitor your progress in real-time. \n\n Fare: ₱${fare.toStringAsFixed(0)} \nDistance: ${distance.toStringAsFixed(1)}km.",
        "target": destination,
        "radius": 20.0,
      },
    ];

    _currentTaskIndex = 0;
    _setCurrentTask();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB6DCFE),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                const SizedBox(height: 20),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: widget.initialCameraTarget ?? _center,
                            zoom: 16.0,
                          ),
                          zoomControlsEnabled: false,
                          myLocationEnabled: true,
                          markers: _markers,
                          polylines: _polylines,
                        ),
                        if (_showDestinationCard &&
                            _selectedDestination != null)
                          Positioned(
                            bottom: 30,
                            left: 16,
                            right: 16,
                            child: DestinationCard(
                              currentUser: _currentUser!,
                              name: _selectedDestination!.name,
                              shortDescription:
                                  _selectedDestination!.shortDescription,
                              longDescription:
                                  _selectedDestination!.longDescription,
                              imageUrl: _selectedDestination!.imageUrl,
                              openHours: _selectedDestination!.openHours,
                              entranceFee:
                                  _selectedDestination!.entranceFee.toDouble(),
                              fareCost:
                                  _selectedDestination!.fareCost.toDouble(),
                              coordinates: _selectedDestination!.latLng,
                              userLocation: _userLocation!,
                              showMeta: false,
                              onDirections: () {
                                setState(() {
                                  _showDestinationCard = false;
                                  _showDirectionsOptions = true;
                                });
                              },
                              onFavorite: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Added to favorites')),
                                );
                              },
                            ),
                          ),
                        if (_showDirectionsOptions) _buildDirectionsOptions(),
                        if (!_showDirectionsOptions && _polylines.isNotEmpty)
                          Positioned(
                            bottom: 30,
                            right: 16,
                            child: FloatingActionButton.extended(
                              heroTag: "change_route",
                              onPressed: () {
                                setState(() {
                                  _showDirectionsOptions = true;
                                  _polylines.clear();
                                });

                                // Zoom back to the destination
                                if (_selectedDestination != null) {
                                  final dest =
                                      _selectedDestination!.coordinates;
                                  mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(dest.latitude, dest.longitude),
                                      16.5, // adjust zoom level if needed
                                    ),
                                  );
                                }
                              },
                              label: const Text("Change Route"),
                              icon: const Icon(Icons.swap_horiz),
                              backgroundColor: Colors.blueAccent,
                            ),
                          ),
                        if (_currentTask != null)
                          Positioned(
                            bottom: 50,
                            left: 0,
                            right: 0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Current Task",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentTask!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.indigoAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _shortTaskDescription ?? '',
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                            if (_isTaskExpanded &&
                                                _longTaskDescription != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Text(
                                                  _longTaskDescription!,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isTaskExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Colors.grey[700],
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isTaskExpanded = !_isTaskExpanded;
                                          });
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // 🛑 Stop Task Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _confirmStopTask, // Confirmation dialog below
                                      icon: const Icon(Icons.stop,
                                          color: Colors.white),
                                      label: const Text(
                                        "Stop Task",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sliding drawer
          if (_showDrawer)
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
            left: _showDrawer ? 0 : -MediaQuery.of(context).size.width * 0.75,
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
              onLogout: () {
                _authService.signOut();
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => LoginScreen()));
              },
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
                          builder: (context) => const TripHistoryScreen()),
                    );
                    break;
                }
              },
            ),
          ),

          // Search overlay - appears on top of everything with slide-up animation
          if (_showSearchOverlay)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset:
                        Offset(0, value * MediaQuery.of(context).size.height),
                    child: child,
                  );
                },
                child: _buildSearchOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
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
                  : const NetworkImage('https://i.imgur.com/BoN9kdC.png'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showSearchOverlay = true;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            _searchFocusNode.requestFocus();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                'Search destinations...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Debounce search for 300ms
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final lowercaseQuery = query.toLowerCase();

    print('🔍 Searching for: "$query"');
    print('📚 Total destinations available: ${_allDestinations.length}');

    final filtered = _allDestinations.where((dest) {
      final nameMatch = dest.name.toLowerCase().contains(lowercaseQuery);
      final addressMatch = dest.address.toLowerCase().contains(lowercaseQuery);
      final descMatch =
          dest.shortDescription.toLowerCase().contains(lowercaseQuery);

      return nameMatch || addressMatch || descMatch;
    }).toList();

    print('✅ Found ${filtered.length} results');
    if (filtered.isNotEmpty) {
      print('   First result: ${filtered[0].name}');
    }

    setState(() {
      _searchResults = filtered;
    });
  }

  void _selectDestination(Destination destination) {
    setState(() {
      _selectedDestination = destination;
      _showSearchOverlay = false;
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
    });

    // Animate camera to destination with smooth zoom animation
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: destination.latLng,
          zoom: 17,
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Search bar header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _showSearchOverlay = false;
                        _searchController.clear();
                        _searchQuery = '';
                        _searchResults = [];
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search destinations...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                    ),
                ],
              ),
            ),

            // Search results list
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildRecentOrPopular()
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No results found for "$_searchQuery"',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final dest = _searchResults[index];
                            return _buildSearchResultItem(dest);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(Destination destination) {
    // Calculate distance if user location is available
    String? distanceText;
    if (_userLocation != null) {
      final distance = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            destination.latLng.latitude,
            destination.latLng.longitude,
          ) /
          1000; // Convert to km
      distanceText = '${distance.toStringAsFixed(1)} km';
    }

    return InkWell(
      onTap: () => _selectDestination(destination),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            // Location icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.place, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(width: 12),

            // Destination info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Distance
            if (distanceText != null)
              Text(
                distanceText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrPopular() {
    // Show popular destinations when no search query
    final popularDestinations = _allDestinations.take(5).toList();

    if (popularDestinations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for destinations',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Popular Destinations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: popularDestinations.length,
            itemBuilder: (context, index) {
              return _buildSearchResultItem(popularDestinations[index]);
            },
          ),
        ),
      ],
    );
  }

  String? _selectedRouteType; // Add this to your state

  Widget _buildDirectionsOptions() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Choose Route Type",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _closeDirectionsOptions,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),

              // Route Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSelectableButton(
                      icon: Icons.alt_route,
                      label: "Multimodal",
                      color: Colors.blueAccent),
                  _buildSelectableButton(
                      icon: Icons.directions_bus,
                      label: "Jeepney",
                      color: Colors.orangeAccent),
                  _buildSelectableButton(
                      icon: Icons.motorcycle,
                      label: "Habal",
                      color: Colors.green),
                  _buildSelectableButton(
                      icon: Icons.location_searching,
                      label: "Closest",
                      color: Colors.purple),
                ],
              ),

              const SizedBox(height: 20),

              // Start button
              ElevatedButton.icon(
                onPressed: _selectedRouteType == null
                    ? null
                    : () async {
                        switch (_selectedRouteType) {
                          case "Multimodal":
                            print("🌐 Multimodal route started");

                            final userLocation = _userLocation;
                            final destination = _selectedDestination;

                            if (userLocation == null || destination == null)
                              return;

                            // Show transport preferences dialog first
                            await _showTransportPreferencesDialog();

                            // After user confirms preferences, start routing
                            await _setupMultimodalRoute(
                                userLocation, destination.latLng);
                            _startTaskTracking();

                            break;

                          case "Jeepney":
                            print("🚎 Jeepney route started");

                            final userLocation = _userLocation;
                            final destination = _selectedDestination;
                            if (userLocation == null || destination == null)
                              return;

                            final routeResult = await _getJeepneyRoutes(
                                userLocation, destination.latLng);
                            final firstRoute =
                                routeResult["routes"][0] as JeepneyRoute;
                            final startPoint = _findNearestPoint(
                              firstRoute.points
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList(),
                              userLocation,
                            );

                            final userToJeepney =
                                await _fetchPolyline(userLocation, startPoint);
                            final polylines = <Polyline>{};

                            // 🟠 1️⃣ User → Jeepney pickup
                            polylines.add(
                              Polyline(
                                polylineId: const PolylineId("user_to_jeepney"),
                                color: Colors.orange,
                                width: 6,
                                points: userToJeepney,
                              ),
                            );

                            LatLng? finalWalkStartPoint;

                            if (routeResult["type"] == "single") {
                              // ✅ Find actual nearest point on jeepney route to destination
                              final nearestToDest = _findNearestPoint(
                                firstRoute.points
                                    .map((p) => LatLng(p.latitude, p.longitude))
                                    .toList(),
                                destination.latLng,
                              );

                              // 🚍 Draw the jeepney route up to that point
                              final jeepneyToNearest = await _fetchPolyline(
                                  startPoint, nearestToDest);
                              polylines.add(
                                Polyline(
                                  polylineId: const PolylineId("jeepney_route"),
                                  color: Colors.green,
                                  width: 6,
                                  points: jeepneyToNearest,
                                ),
                              );

                              // 🧮 Check if destination is far from jeepney endpoint
                              final endDist = Geolocator.distanceBetween(
                                nearestToDest.latitude,
                                nearestToDest.longitude,
                                destination.latLng.latitude,
                                destination.latLng.longitude,
                              );

                              // 🟠 Add final walk if > 50 m away
                              if (endDist > 50) {
                                finalWalkStartPoint = nearestToDest;
                                final finalWalk = await _fetchPolyline(
                                    nearestToDest, destination.latLng);
                                polylines.add(
                                  Polyline(
                                    polylineId: const PolylineId("final_walk"),
                                    color: Colors.orange,
                                    width: 6,
                                    points: finalWalk,
                                    patterns: [
                                      PatternItem.dash(20),
                                      PatternItem.gap(10)
                                    ],
                                  ),
                                );
                              }
                            } else {
                              // 🚎 Double ride
                              final transferPoint =
                                  routeResult["transferPoint"] as LatLng;
                              final secondRoute =
                                  routeResult["routes"][1] as JeepneyRoute;

                              final firstLeg = await _fetchPolyline(
                                  startPoint, transferPoint);
                              final secondLeg = await _fetchPolyline(
                                  transferPoint, destination.latLng);

                              polylines.addAll([
                                Polyline(
                                  polylineId:
                                      const PolylineId("jeepney_first_leg"),
                                  color: Colors.green,
                                  width: 6,
                                  points: firstLeg,
                                ),
                                Polyline(
                                  polylineId:
                                      const PolylineId("jeepney_second_leg"),
                                  color: Colors.blue,
                                  width: 6,
                                  points: secondLeg,
                                ),
                              ]);

                              // ✅ Nearest point from second route to destination
                              final nearestToDest = _findNearestPoint(
                                secondRoute.points
                                    .map((p) => LatLng(p.latitude, p.longitude))
                                    .toList(),
                                destination.latLng,
                              );

                              final endDist = Geolocator.distanceBetween(
                                nearestToDest.latitude,
                                nearestToDest.longitude,
                                destination.latLng.latitude,
                                destination.latLng.longitude,
                              );

                              if (endDist > 50) {
                                finalWalkStartPoint = nearestToDest;
                                final finalWalk = await _fetchPolyline(
                                    nearestToDest, destination.latLng);
                                polylines.add(
                                  Polyline(
                                    polylineId: const PolylineId("final_walk"),
                                    color: Colors.orange,
                                    width: 6,
                                    points: finalWalk,
                                    patterns: [
                                      PatternItem.dash(20),
                                      PatternItem.gap(10),
                                    ],
                                  ),
                                );
                              }
                            }

                            // 🧩 Now set up dynamic tasks (Walk → Ride → maybe Walk again)
                            await _setupJeepneyTasks(
                                userLocation, destination.latLng);

                            // If there’s a final walk (distance > 50 m), add it dynamically
                            if (finalWalkStartPoint != null) {
                              _tasks.add({
                                "name": "Walk (Final)",
                                "shortDescription":
                                    "Walk from the last jeepney stop to your destination.",
                                "longDescription":
                                    "Final stretch — walk the remaining distance to your destination.",
                                "target": destination.latLng,
                              });
                            }

                            // 🧭 Start tracking user’s progress
                            _currentTaskIndex = 0;
                            _setCurrentTask();
                            _startTaskTracking();

                            // 🗺️ Update map polylines
                            setState(() {
                              _polylines = polylines;
                            });

                            final bounds = _boundsFromLatLngList(userToJeepney);
                            if (bounds != null) {
                              mapController?.animateCamera(
                                CameraUpdate.newLatLngBounds(bounds, 50),
                              );
                            }

                            break;

                          case "Habal":
                            final userLocation = _userLocation;
                            final destination = _selectedDestination;

                            if (userLocation == null || destination == null)
                              return;

                            final nearestHabal =
                                await _findNearestHabal(userLocation);
                            if (nearestHabal == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('No nearby Habal found')),
                              );
                              return;
                            }

                            // Fetch both polylines
                            final userToHabal = await _fetchPolyline(
                                userLocation, nearestHabal.latLng);
                            final habalToDest = await _fetchPolyline(
                                nearestHabal.latLng, destination.latLng);

                            setState(() {
                              _polylines = {
                                Polyline(
                                  polylineId: const PolylineId("user_to_habal"),
                                  color: Colors.orange,
                                  width: 6,
                                  points: userToHabal,
                                ),
                                Polyline(
                                  polylineId: const PolylineId("habal_to_dest"),
                                  color: Colors.green,
                                  width: 6,
                                  points: habalToDest,
                                ),
                              };
                            });

                            // 🧠 Setup the dynamic task list
                            _setupHabalTasks(userLocation, nearestHabal.latLng,
                                destination.latLng);

                            // Zoom to first polyline
                            final bounds = _boundsFromLatLngList(userToHabal);
                            if (bounds != null) {
                              mapController?.animateCamera(
                                CameraUpdate.newLatLngBounds(bounds, 50),
                              );
                            }

                            // Start tracking task progress
                            _startTaskTracking();
                            break;

                          case "Closest":
                            print("🚗 Closest/Direct route started");

                            final userLocation = _userLocation;
                            final destination = _selectedDestination;

                            if (userLocation == null || destination == null)
                              return;

                            // Setup direct route with task
                            await _setupDirectRoute(
                                userLocation, destination.latLng);
                            _startTaskTracking();
                            break;
                        }

                        _closeDirectionsOptions();
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  "Start",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final bool isSelected = _selectedRouteType == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRouteType = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
