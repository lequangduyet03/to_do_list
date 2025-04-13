class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String? password;   
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.password,
    required this.createdAt,
    this.lastLogin,
  });

  // Chuyển từ JSON về object User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'], // Đổi key khớp với backend
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'], // Khớp đúng key full_name
      password: json['password'],
      createdAt: DateTime.parse(json['created_at']),
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
    );
  }

  // Chuyển từ object User sang JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'password': password,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}
