// lib/models/user_model.dart
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// Creates a User from a Drift database row (e.g. from AppDatabase users table).
  factory User.fromDrift(dynamic data) {
    return User(
      id: data.id as String,
      name: data.name as String,
      email: data.email as String,
      avatarUrl: data.avatarUrl as String?,
      createdAt: data.createdAt as DateTime,
      updatedAt: data.updatedAt as DateTime,
    );
  }

  User copyWith({
    String? name,
    String? email,
    String? avatarUrl,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// Note: UsersCompanion for database writes is generated in database.g.dart.
// Use the one from package:projectrack1/database/database.dart when updating users.