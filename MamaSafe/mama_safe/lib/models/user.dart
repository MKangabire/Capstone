class User {
  final String email;
  final String role;
  final List<String> visits;

  User({required this.email, required this.role, List<String>? visits})
      : visits = visits ?? [];
}

// Mock database
List<User> users = [];
