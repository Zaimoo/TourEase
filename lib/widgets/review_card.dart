import 'package:flutter/material.dart';

class ReviewCard extends StatelessWidget {
  final String name;
  final String review;
  final String reviewTitle;
  final double rating;
  final String profileUrl; // This can be a web URL or a local asset path

  const ReviewCard({
    super.key,
    required this.name,
    required this.reviewTitle,
    required this.review,
    required this.rating,
    required this.profileUrl,
  });

  // This helper widget determines whether to use Image.network or Image.asset
  Widget _buildProfileImage() {
    // Check if the URL is a network URL
    if (profileUrl.startsWith('http')) {
      return Image.network(
        profileUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        // Add an error builder for network images in case they fail to load
        errorBuilder: (context, error, stackTrace) {
          // You can return a placeholder asset here as a fallback for broken network links
          return Image.asset(
            'assets/images/placeholder.png', // Make sure you have a default placeholder here
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      // Otherwise, assume it's a local asset
      return Image.asset(
        profileUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // Call the helper widget to build the correct image type
          child: _buildProfileImage(),
        ),
        const SizedBox(width: 10),

        // Review Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(5, (index) {
                      if (index < rating.floor()) {
                        return const Icon(Icons.star, size: 16, color: Colors.blueGrey);
                      } else if (index == rating.floor() && rating % 1 != 0) {
                        return const Icon(Icons.star_half, size: 16, color: Colors.blueGrey);
                      } else {
                        return const Icon(Icons.star_border, size: 16, color: Colors.blueGrey);
                      }
                    }),
                  )
                ],
              ),

              const SizedBox(height: 4),

              // Review title
              Text(reviewTitle, style: const TextStyle(fontSize: 12)),

              // Review snippet
              Text(
                review,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }
}