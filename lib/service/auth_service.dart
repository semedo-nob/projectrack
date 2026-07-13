import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

/// Password hashing and verification for ProjectRack.
///
/// New passwords use bcrypt (salt embedded in the hash).
/// Legacy SHA-256 hashes (app-wide salt) are verified once, then upgraded
/// to bcrypt on successful login / password change.
/// Plaintext storage is no longer accepted.
class AuthService {
  AuthService._();

  static const int bcryptRounds = 12;

  /// Previous SHA-256 scheme — kept only to verify and migrate old rows.
  static const String legacySha256Salt = 'projectrack_v1_salt';

  /// bcrypt hashes look like `$2a$12$...` / `$2b$...` / `$2y$...`.
  static bool isBcryptHash(String hash) {
    if (hash.length < 59) return false;
    return RegExp(r'^\$2[aby]\$\d{2}\$').hasMatch(hash);
  }

  /// Legacy format: SHA-256 hex digest (64 lowercase hex chars).
  static bool isLegacySha256Hash(String hash) {
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hash);
  }

  static String hashPassword(String password) {
    final salt = BCrypt.gensalt(logRounds: bcryptRounds);
    return BCrypt.hashpw(password, salt);
  }

  /// Verify [password] against [storedHash].
  /// Returns false for empty / plaintext / unknown formats.
  static bool verifyPassword(String password, String storedHash) {
    if (password.isEmpty || storedHash.isEmpty) return false;

    if (isBcryptHash(storedHash)) {
      try {
        return BCrypt.checkpw(password, storedHash);
      } catch (_) {
        return false;
      }
    }

    if (isLegacySha256Hash(storedHash)) {
      return _legacySha256Hash(password) == storedHash;
    }

    // Plaintext and any other format: reject (no fallback).
    return false;
  }

  /// True when the stored value should be re-hashed to bcrypt after a
  /// successful verify (legacy SHA-256 only).
  static bool needsBcryptMigration(String storedHash) {
    return isLegacySha256Hash(storedHash);
  }

  static String _legacySha256Hash(String password) {
    final bytes = utf8.encode('$legacySha256Salt$password');
    return sha256.convert(bytes).toString();
  }
}

class AuthException implements Exception {
  AuthException(this.message, {this.requirePasswordReset = false});

  final String message;
  final bool requirePasswordReset;

  @override
  String toString() => message;
}
