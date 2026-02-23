class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String profileUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.profileUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      name: data['name'] as String? ?? "",
      email: data['email'] as String? ?? "",
      password: data['password'] as String? ?? "",
      phone: data['phone'] as String? ?? "",
      profileUrl: data['profileUrl'] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'profileUrl': profileUrl,
    };
  }
}
