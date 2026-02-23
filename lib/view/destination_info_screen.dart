import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourease/models/review.dart';
import 'package:tourease/models/user.dart';
import 'package:tourease/services/use_firebase.dart';
import 'package:tourease/view/map_screen.dart';
import 'package:tourease/view/root_page.dart';
import 'package:tourease/widgets/big_text.dart';
import 'package:tourease/widgets/review_card.dart';

import 'add_review_screen.dart';
import 'all_reviews_screen.dart';

class DestinationInfoScreen extends StatefulWidget {
  const DestinationInfoScreen({
    super.key,
    required this.name,
    required this.currentUser,
    required this.longDescription,
    required this.imageUrl,
    required this.openHours,
    required this.rating,
    required this.distance,
    required this.entranceFee,
    required this.fareCost,
    required this.coordinates,
  });

  final AppUser currentUser;
  final String name;
  final String longDescription;
  final String imageUrl;
  final String openHours;
  final double rating;
  final double distance;
  final double entranceFee;
  final double fareCost;
  final LatLng coordinates;

  @override
  State<DestinationInfoScreen> createState() => _DestinationInfoScreenState();
}

const String placeholderProfileUrl = 'assets/placeholder-profile.png';

class _DestinationInfoScreenState extends State<DestinationInfoScreen> {
  final reviewService = UseFirebase<Review>(
    fromJson: (data, id) => Review.fromJson(data, id),
    toJson: (review) => review.toJson(),
  );

  Stream<List<Review>> getReviewsForDestination(String destination) {
    return reviewService.streamAll('reviews').map(
          (allReviews) => allReviews
          .where((review) => review.destination == destination)
          .take(3)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        bottomNavigationBar: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ElevatedButton(
            onPressed: () async {
              Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              LatLng userLatLng = LatLng(position.latitude, position.longitude);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RootPage(
                    initialTab: 1,
                    destinationData: {
                      'name': widget.name,
                      'shortDescription': 'Tap to learn more...',
                      'longDescription': widget.longDescription,
                      'imageUrl': widget.imageUrl,
                      'openHours': widget.openHours,
                      'entranceFee': widget.entranceFee,
                      'fareCost': widget.fareCost,
                    },
                    initialCameraTarget: widget.coordinates,
                    // 👇 pass the user's location here
                    userLocation: userLatLng,
                  ),
                ),
              );
            },


            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00BFA6), // Teal green
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'See on Map',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        appBar: AppBar(
          title: Text(widget.name, style: TextStyle(
            fontWeight: FontWeight.bold
          ),),
          backgroundColor: Color(0xFFB6DCFE),
        ),
      
        body: SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 6,),
                
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(widget.longDescription),
              ),
                
              Container(
                decoration: BoxDecoration(
                   border: Border.fromBorderSide(BorderSide(width: 0.5)),
                ),
              ),
                
              SizedBox(height: 6,),
                
              Padding(
                padding: const EdgeInsets.only(left: 10.0, top: 10, bottom: 10, right: 50),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ENTRANCE FEE:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${widget.entranceFee.toStringAsFixed(0)} PHP',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ESTIMATED FARE COST:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${widget.fareCost.toStringAsFixed(0)} PHP',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DISTANCE:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${widget.distance}km ',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'OPEN HOURS:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          widget.openHours,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                
                  ],
                ),
              ),
              SizedBox(height: 6,),
              Container(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(BorderSide(width: 0.5)),
                ),
              ),
                
              SizedBox(height: 6,),

              Padding(padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BigText(
                        text: 'Reviews',
                        fontWeight: FontWeight.w700,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AllReviewsScreen(destinationName: widget.name, currentUser: widget.currentUser),
                            ),
                          );
                        },
                        child: Text(
                          'View More',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    ],
                  ),


                  StreamBuilder<List<Review>>(
                    stream: getReviewsForDestination(widget.name),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        print("🔥 Firestore error: ${snapshot.error}");
                        return Text('Error loading reviews: ${snapshot.error}');
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Text('No reviews yet.');
                      }

                      final reviews = snapshot.data!;
                      return Column(
                        children: reviews.map((r) {
                          // 2. Check if the profileUrl is null or empty, and assign the placeholder if it is.
                          final imageUrl = (r.profileUrl != null && r.profileUrl.isNotEmpty)
                              ? r.profileUrl
                              : placeholderProfileUrl;

                          return ReviewCard(
                            name: r.name,
                            reviewTitle: r.title,
                            review: r.review,
                            rating: r.rating,
                            // 3. Pass the determined URL to the ReviewCard.
                            profileUrl: imageUrl,
                          );
                        }).toList(),
                      );
                    },
                  )




                ],
                )
              )

            ],
          ),
        ),
      ),
    );
  }
}
