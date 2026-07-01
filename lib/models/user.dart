class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String profileUrl;

  /// Admins can verify pending reviews and access admin-only screens. Promoted
  /// manually by setting `isAdmin: true` on the user's Firestore doc (no in-app
  /// promotion UI). Defaults to false for everyone else.
  final bool isAdmin;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.profileUrl,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      name: data['name'] as String? ?? "",
      email: data['email'] as String? ?? "",
      password: data['password'] as String? ?? "",
      phone: data['phone'] as String? ?? "",
      profileUrl: data['profileUrl'] as String? ?? "",
      isAdmin: data['isAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'profileUrl': profileUrl,
      'isAdmin': isAdmin,
    };
  }
}
