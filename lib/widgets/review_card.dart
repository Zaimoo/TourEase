import 'package:flutter/material.dart';

class ReviewCard extends StatelessWidget {
  final String name;
  final String review;
  final String reviewTitle;
  final double rating;
  final String profileUrl;

  const ReviewCard({
    super.key,
    required this.name,
    required this.reviewTitle,
    required this.review,
    required this.rating,
    required this.profileUrl,
  });

  Widget _buildProfileImage() {
    if (profileUrl.startsWith('http')) {
      return Image.network(
        profileUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 44,
            height: 44,
            color: Colors.grey[200],
            child: Icon(Icons.person, color: Colors.grey[400]),
          );
        },
      );
    } else {
      return Image.asset(
        profileUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _buildProfileImage(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        if (index < rating.floor()) {
                          return const Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber);
                        } else if (index == rating.floor() && rating % 1 != 0) {
                          return const Icon(Icons.star_half_rounded,
                              size: 16, color: Colors.amber);
                        } else {
                          return Icon(Icons.star_outline_rounded,
                              size: 16, color: Colors.grey[300]);
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (reviewTitle.isNotEmpty)
                  Text(
                    reviewTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  review,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
