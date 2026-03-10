// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:projectrack1/database/database.dart' as db;
import 'package:projectrack1/constants/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/biometric_service.dart';
import '../service/secure_storage_service.dart';

// Keys for profile data in SharedPreferences (used by profile/dashboard)
const String _prefUserName = 'user_profile_name';
const String _prefUserEmail = 'user_profile_email';
const String _prefUserAvatarUrl = 'user_profile_avatar_url';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthProvider extends ChangeNotifier {
  final db.AppDatabase _database;
  final SecureStorageService _secureStorage = SecureStorageService();
  final BiometricService _biometricService = BiometricService();

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;
  bool _isBiometricAvailable = false;
  bool _biometricEnabled = false;

  AuthProvider({required db.AppDatabase database}) : _database = database {
    _init();
  }

  // Getters
  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get biometricEnabled => _biometricEnabled;

  Future<void> _init() async {
    await _checkBiometricAvailability();
    await _checkStoredCredentials();
  }

  Future<void> _checkBiometricAvailability() async {
    _isBiometricAvailable = await _biometricService.isAvailable();
    notifyListeners();
  }

  Future<void> _checkStoredCredentials() async {
    setStatus(AuthStatus.loading);

    try {
      final token = await _secureStorage.getAuthToken();
      final userId = await _secureStorage.getUserId();
      final biometricPref = await _secureStorage.getBiometricPreference();

      _biometricEnabled = biometricPref ?? false;

      if (token != null && userId != null) {
        // Validate token with backend or check local session
        await _loadUserFromDatabase(userId);

        if (_currentUser != null) {
          setStatus(AuthStatus.authenticated);
        } else {
          await logout();
        }
      } else {
        setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      setError('Failed to restore session: $e');
      setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadUserFromDatabase(String userId) async {
    try {
      final userData = await (_database.select(_database.users)
        ..where((t) => t.id.equals(userId))).getSingleOrNull();

      if (userData != null) {
        _currentUser = User.fromDrift(userData);
        await _saveUserToPrefs(_currentUser!);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  Future<void> _saveUserToPrefs(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserName, user.name);
      await prefs.setString(_prefUserEmail, user.email);
      if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
        await prefs.setString(_prefUserAvatarUrl, user.avatarUrl!);
      } else {
        await prefs.remove(_prefUserAvatarUrl);
      }
    } catch (e) {
      debugPrint('Failed to save user to prefs: $e');
    }
  }

  Future<void> _clearUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserName);
      await prefs.remove(_prefUserEmail);
      await prefs.remove(_prefUserAvatarUrl);
    } catch (e) {
      debugPrint('Failed to clear user prefs: $e');
    }
  }

  // Login methods
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setStatus(AuthStatus.loading);

    try {
      final userData = await (_database.select(_database.users)
        ..where((t) => t.email.equals(email))).getSingleOrNull();

      if (userData != null && _verifyPassword(password, userData.passwordHash)) {
        _currentUser = User.fromDrift(userData);
        await _secureStorage.saveAuthToken('session_${DateTime.now().millisecondsSinceEpoch}');
        await _secureStorage.saveUserId(_currentUser!.id);
        await _saveUserToPrefs(_currentUser!);
        setStatus(AuthStatus.authenticated);
        return true;
      }
      setError('Invalid email or password');
      setStatus(AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      setError('Login failed: $e');
      setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    if (!_isBiometricAvailable) {
      setError('Biometric authentication not available');
      return false;
    }

    setStatus(AuthStatus.loading);

    try {
      final authenticated = await _biometricService.authenticate();

      if (authenticated) {
        // Get stored user ID
        final userId = await _secureStorage.getUserId();

        if (userId != null) {
          await _loadUserFromDatabase(userId);

          if (_currentUser != null) {
            setStatus(AuthStatus.authenticated);
            return true;
          }
        }

        setError('No user data found');
        setStatus(AuthStatus.unauthenticated);
        return false;
      } else {
        setError('Biometric authentication failed');
        setStatus(AuthStatus.unauthenticated);
        return false;
      }
    } catch (e) {
      setError('Biometric authentication error: $e');
      setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    setStatus(AuthStatus.loading);

    try {
      // Check if user already exists
      final existingUser = await (_database.select(_database.users)
        ..where((t) => t.email.equals(email))).getSingleOrNull();

      if (existingUser != null) {
        setError('Email already registered');
        setStatus(AuthStatus.unauthenticated);
        return false;
      }

      // Create new user
      final now = DateTime.now();
      final newUser = db.UsersCompanion.insert(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        passwordHash: _hashPassword(password),
        createdAt: now,
        updatedAt: now,
      );

      await _database.into(_database.users).insert(newUser);

      // Auto-login after registration
      return await loginWithEmail(email: email, password: password);
    } catch (e) {
      setError('Registration failed: $e');
      setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    setStatus(AuthStatus.loading);
    try {
      await _secureStorage.clearAll();
      await _clearUserPrefs();
      _currentUser = null;
      setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      setError('Logout failed: $e');
      setStatus(AuthStatus.unauthenticated);
    }
  }

  // Profile management
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    setStatus(AuthStatus.loading);

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name,
        email: email,
        avatarUrl: avatarUrl,
      );

      await (_database.update(_database.users)
        ..where((t) => t.id.equals(_currentUser!.id))
      ).write(db.UsersCompanion(
        name: drift.Value(updatedUser.name),
        email: drift.Value(updatedUser.email),
        avatarUrl: updatedUser.avatarUrl != null
            ? drift.Value(updatedUser.avatarUrl)
            : const drift.Value.absent(),
        updatedAt: drift.Value(DateTime.now()),
      ));

      _currentUser = updatedUser;
      await _saveUserToPrefs(updatedUser);
      setStatus(AuthStatus.authenticated);
      notifyListeners();
      return true;
    } catch (e) {
      setError('Profile update failed: $e');
      setStatus(AuthStatus.authenticated); // Revert status
      return false;
    }
  }

  // Password management
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    setStatus(AuthStatus.loading);

    try {
      final userRow = await (_database.select(_database.users)
        ..where((t) => t.id.equals(_currentUser!.id))).getSingleOrNull();
      if (userRow == null || !_verifyPassword(oldPassword, userRow.passwordHash)) {
        setError('Current password is incorrect');
        setStatus(AuthStatus.authenticated);
        return false;
      }

      await (_database.update(_database.users)
        ..where((t) => t.id.equals(_currentUser!.id))
      ).write(db.UsersCompanion(
        passwordHash: drift.Value(_hashPassword(newPassword)),
        updatedAt: drift.Value(DateTime.now()),
      ));

      setStatus(AuthStatus.authenticated);
      return true;
    } catch (e) {
      setError('Password change failed: $e');
      setStatus(AuthStatus.authenticated);
      return false;
    }
  }

  // Biometric preference
  Future<void> toggleBiometric(bool enabled) async {
    _biometricEnabled = enabled;
    await _secureStorage.saveBiometricPreference(enabled);
    notifyListeners();
  }

  // Utility methods: SHA-256 with app salt (passwords never stored plain)
  static const String _passwordSalt = 'projectrack_v1_salt';

  String _hashPassword(String password) {
    final bytes = utf8.encode('$_passwordSalt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String plain, String storedHash) {
    if (storedHash.isEmpty) return false;
    // SHA-256 hex digest is 64 chars; legacy plain-text passwords are shorter
    if (storedHash.length == 64) return _hashPassword(plain) == storedHash;
    return plain == storedHash; // legacy plain-text (migrate on next password change)
  }

  void setStatus(AuthStatus newStatus) {
    _status = newStatus;
    if (newStatus != AuthStatus.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}