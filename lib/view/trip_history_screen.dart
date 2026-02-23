import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/trip.dart';
import '../services/use_firebase.dart';

class TripHistoryScreen extends StatefulWidget {
  final AppUser? currentUser;

  const TripHistoryScreen({super.key, this.currentUser});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final tripService = UseFirebase<Trip>(
    fromJson: (data, id) => Trip.fromJson(data, id),
    toJson: (trip) => trip.toJson(),
  );

  List<Trip> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTripHistory();
  }

  Future<void> _fetchTripHistory() async {
    if (widget.currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final fetchedTrips = await tripService.getSubcollection(
        'users',
        widget.currentUser!.id,
        'trips',
      );

      // Sort trips by date (most recent first)
      fetchedTrips.sort((a, b) => b.visitedDate.compareTo(a.visitedDate));

      setState(() {
        trips = fetchedTrips;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching trip history: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            const Text("Trip History", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFB6DCFE),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
              ? const Center(
                  child: Text(
                    "No trip history yet.\nStart exploring!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: trip.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  trip.imageUrl!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.place,
                                          color: Colors.blueAccent, size: 40),
                                ),
                              )
                            : const Icon(Icons.place,
                                color: Colors.blueAccent, size: 40),
                        title: Text(
                          trip.destinationName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("Visited on ${_formatDate(trip.visitedDate)}"),
                            if (trip.distance != null)
                              Text(
                                  "Distance: ${trip.distance!.toStringAsFixed(2)} km"),
                            if (trip.transportMode != null)
                              Text("Mode: ${trip.transportMode}"),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: Navigate to trip details or destination info
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
