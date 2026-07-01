import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:tourease/models/jeepneyRoute.dart';
import 'package:tourease/services/use_firebase.dart';

class JeepneyRoutesScreen extends StatefulWidget {
  const JeepneyRoutesScreen({super.key});

  @override
  State<JeepneyRoutesScreen> createState() => _JeepneyRoutesScreenState();
}

class _JeepneyRoutesScreenState extends State<JeepneyRoutesScreen> {
  GoogleMapController? _mapController;
  final UseFirebase<JeepneyRoute> _routeService = UseFirebase<JeepneyRoute>(
    fromJson: (data, id) => JeepneyRoute.fromJson(data, id),
    toJson: (model) => model.toJson(),
  );

  StreamSubscription<List<JeepneyRoute>>? _routeSub;
  List<JeepneyRoute> _routes = [];
  JeepneyRoute? _selectedRoute;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  final LatLng _center = const LatLng(8.2280, 124.2452);

  @override
  void initState() {
    super.initState();
    _routeSub = _routeService.streamAll('jeepneyRoutes').listen((routes) {
      if (!mounted) return;
      setState(() {
        _routes = routes;
      });
      if (_selectedRoute == null && routes.isNotEmpty) {
        _selectRoute(routes.first);
      }
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
  }

  void _selectRoute(JeepneyRoute route) {
    final points = route.latLngPoints;
    final polyline = Polyline(
      polylineId: PolylineId(route.id),
      color: Colors.green,
      width: 6,
      points: points,
    );

    final markers = <Marker>{};
    if (points.isNotEmpty) {
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_start'),
          position: points.first,
          infoWindow: const InfoWindow(title: 'Start'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${route.id}_end'),
          position: points.last,
          infoWindow: const InfoWindow(title: 'End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {
      _selectedRoute = route;
      _polylines = {polyline};
      _markers = markers;
    });

    if (points.isNotEmpty && _mapController != null) {
      final bounds = _boundsFromLatLngList(points);
      if (bounds != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      }
    }
  }

  LatLngBounds? _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) return null;
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;
    for (final latLng in list) {
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

  String _formatLatLng(LatLng? point) {
    if (point == null) return '-';
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB6DCFE),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 13.5),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) async {
              _mapController = controller;
              final style =
                  await rootBundle.loadString('assets/map_style.json');
              _mapController?.setMapStyle(style);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedRoute?.name ?? 'DEBUG: ROUTE VIEWER',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.12,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          final route = _routes[index];
                          final isSelected = _selectedRoute?.id == route.id;
                          final points = route.latLngPoints;
                          final start = points.isNotEmpty ? points.first : null;
                          final end = points.isNotEmpty ? points.last : null;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.green.withOpacity(0.08),
                            leading: Icon(
                              Icons.alt_route,
                              color: isSelected ? Colors.green : Colors.grey,
                            ),
                            title: Text(route.name),
                            subtitle: Text(
                              'Stops: ${_formatLatLng(start)} -> ${_formatLatLng(end)}\n'
                              'Points: ${points.length}',
                            ),
                            isThreeLine: true,
                            onTap: () => _selectRoute(route),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
