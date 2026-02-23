class Review {
  final String id;
  final String name;
  final String email;
  final String destination;
  final String title;
  final String review;
  final double rating;
  final String profileUrl;

  Review({
    required this.id,
    required this.name,
    required this.email,
    required this.title,
    required this.review,
    required this.rating,
    required this.destination,
    required this.profileUrl,
  });

  factory Review.fromJson(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      name: data['name'] as String,
      email: data['email'] as String,
      title: data['title'] as String,
      review: data['review'] as String,
      rating: (data['rating'] as num).toDouble(),
      destination: data['destination'] as String,
      profileUrl: data['profileUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'title': title,
      'review': review,
      'rating': rating,
      'destination': destination,
      'profileUrl': profileUrl,
    };
  }
}
