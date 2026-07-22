// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:projectrack1/database/database.dart' as db;
import 'package:projectrack1/constants/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/auth_service.dart';
import '../service/biometric_service.dart';
import '../service/secure_storage_service.dart';

// Keys for profile data in SharedPreferences (used by profile/dashboard)
const String _prefUserName = 'user_profile_name';
const String _prefUserEmail = 'user_profile_email';
const String _prefUserAvatarUrl = 'user_profile_avatar_url';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthProvider extends ChangeNotifier {
  final db.AppDatabase _database;
  final SecureStorageService _secureStorage = SecureStorageService();
  final BiometricService _biometricService = BiometricService();

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;
  bool _isBiometricAvailable = false;
  bool _biometricEnabled = false;
  bool _needsBiometricUnlock = false;
  bool _hasStoredBiometricAccount = false;
  String? _lastBiometricEmail;
  /// Camera/gallery and system biometric sheets background the app; skip
  /// resume-lock while those activities are in flight (and briefly after).
  int _biometricLockSuppressCount = 0;
  DateTime? _biometricLockGraceUntil;

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
  bool get needsBiometricUnlock => _needsBiometricUnlock;
  bool get hasStoredBiometricAccount => _hasStoredBiometricAccount;
  String? get lastBiometricEmail => _lastBiometricEmail;

  /// True while camera/gallery/biometric UI is open, or in a short grace window.
  bool get shouldSuppressBiometricLock {
    if (_biometricLockSuppressCount > 0) return true;
    final until = _biometricLockGraceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Run [action] without treating app backgrounding as a lock trigger.
  /// Use around camera/gallery picks and system biometric prompts.
  Future<T> runWithoutBiometricLock<T>(Future<T> Function() action) async {
    _biometricLockSuppressCount++;
    try {
      return await action();
    } finally {
      _biometricLockSuppressCount =
          (_biometricLockSuppressCount - 1).clamp(0, 1 << 30);
      // Cover the brief resumed race after the picker/sheet closes.
      _biometricLockGraceUntil =
          DateTime.now().add(const Duration(seconds: 2));
    }
  }

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
      final biometricUserId = await _secureStorage.getBiometricUserId();
      final biometricUserEmail = await _secureStorage.getBiometricUserEmail();
      final biometricPref = await _secureStorage.getBiometricPreference();

      _biometricEnabled = biometricPref ?? false;
      _hasStoredBiometricAccount =
          _biometricEnabled && biometricUserId != null;
      _lastBiometricEmail = biometricUserEmail;

      if (token != null && userId != null) {
        // Validate token with backend or check local session
        await _loadUserFromDatabase(userId);

        if (_currentUser != null) {
          _needsBiometricUnlock = _biometricEnabled && _isBiometricAvailable;
          setStatus(AuthStatus.authenticated);
        } else {
          await _secureStorage.clearSession();
          await _clearUserPrefs();
          _currentUser = null;
          _needsBiometricUnlock = false;
          setStatus(AuthStatus.unauthenticated);
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
      final userData = await (_database.select(
        _database.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

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
      final userData = await (_database.select(
        _database.users,
      )..where((t) => t.email.equals(email))).getSingleOrNull();

      if (userData != null &&
          AuthService.verifyPassword(password, userData.passwordHash)) {
        await _migratePasswordHashIfNeeded(
          userId: userData.id,
          password: password,
          storedHash: userData.passwordHash,
        );
        _currentUser = User.fromDrift(userData);
        await _secureStorage.saveAuthToken(
          'session_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _secureStorage.saveUserId(_currentUser!.id);
        await _secureStorage.saveUserEmail(_currentUser!.email);
        if (_biometricEnabled) {
          await _secureStorage.saveBiometricUserId(_currentUser!.id);
          await _secureStorage.saveBiometricUserEmail(_currentUser!.email);
        }
        await _saveUserToPrefs(_currentUser!);
        _hasStoredBiometricAccount = _biometricEnabled;
        _lastBiometricEmail = _currentUser!.email;
        _needsBiometricUnlock = false;
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
    return runWithoutBiometricLock(() => _loginWithBiometricsInternal());
  }

  Future<bool> _loginWithBiometricsInternal() async {
    if (!_isBiometricAvailable) {
      setError(
        _biometricService.lastError ??
            'Biometric authentication is not available on this device',
      );
      return false;
    }

    final hadSession = _currentUser != null;
    setStatus(AuthStatus.loading);

    try {
      final authenticated = await _biometricService.authenticate();

      if (authenticated) {
        // Get stored user ID
        final userId = await _secureStorage.getBiometricUserId();

        if (userId != null) {
          await _loadUserFromDatabase(userId);

          if (_currentUser != null) {
            await _secureStorage.saveAuthToken(
              'session_${DateTime.now().millisecondsSinceEpoch}',
            );
            await _secureStorage.saveUserId(_currentUser!.id);
            await _secureStorage.saveUserEmail(_currentUser!.email);
            await _secureStorage.saveBiometricUserId(_currentUser!.id);
            await _secureStorage.saveBiometricUserEmail(_currentUser!.email);
            await _saveUserToPrefs(_currentUser!);
            _hasStoredBiometricAccount = true;
            _lastBiometricEmail = _currentUser!.email;
            _needsBiometricUnlock = false;
            setStatus(AuthStatus.authenticated);
            return true;
          }
        }

        setError('No user data found');
        setStatus(AuthStatus.unauthenticated);
        return false;
      } else {
        final message =
            _biometricService.lastError ?? 'Biometric authentication failed';
        if (hadSession) {
          _errorMessage = message;
          _needsBiometricUnlock = true;
          _status = AuthStatus.authenticated;
          notifyListeners();
        } else {
          setError(message);
          setStatus(AuthStatus.unauthenticated);
        }
        return false;
      }
    } catch (e) {
      final message = 'Biometric authentication error: $e';
      if (hadSession) {
        _errorMessage = message;
        _needsBiometricUnlock = true;
        _status = AuthStatus.authenticated;
        notifyListeners();
      } else {
        setError(message);
        setStatus(AuthStatus.unauthenticated);
      }
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
      final existingUser = await (_database.select(
        _database.users,
      )..where((t) => t.email.equals(email))).getSingleOrNull();

      if (existingUser != null) {
        setError('Email already registered');
        setStatus(AuthStatus.unauthenticated);
        return false;
      }

      // Create new user with bcrypt (per-user salt embedded in hash)
      final now = DateTime.now();
      final newUser = db.UsersCompanion.insert(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        passwordHash: AuthService.hashPassword(password),
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
      await _secureStorage.clearSession();
      if (!_biometricEnabled) {
        await _secureStorage.clearBiometricLoginIdentity();
      }
      await _clearUserPrefs();
      _currentUser = null;
      _needsBiometricUnlock = false;
      _hasStoredBiometricAccount = _biometricEnabled;
      if (!_biometricEnabled) {
        _lastBiometricEmail = null;
      }
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

      await (_database.update(
        _database.users,
      )..where((t) => t.id.equals(_currentUser!.id))).write(
        db.UsersCompanion(
          name: drift.Value(updatedUser.name),
          email: drift.Value(updatedUser.email),
          avatarUrl: updatedUser.avatarUrl != null
              ? drift.Value(updatedUser.avatarUrl)
              : const drift.Value.absent(),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

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
      final userRow = await (_database.select(
        _database.users,
      )..where((t) => t.id.equals(_currentUser!.id))).getSingleOrNull();
      if (userRow == null ||
          !AuthService.verifyPassword(oldPassword, userRow.passwordHash)) {
        setError('Current password is incorrect');
        setStatus(AuthStatus.authenticated);
        return false;
      }

      await (_database.update(
        _database.users,
      )..where((t) => t.id.equals(_currentUser!.id))).write(
        db.UsersCompanion(
          passwordHash: drift.Value(AuthService.hashPassword(newPassword)),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      setStatus(AuthStatus.authenticated);
      return true;
    } catch (e) {
      setError('Password change failed: $e');
      setStatus(AuthStatus.authenticated);
      return false;
    }
  }

  // Biometric preference
  Future<bool> toggleBiometric(bool enabled) async {
    if (enabled && !_isBiometricAvailable) {
      setError(
        _biometricService.lastError ??
            'Biometric authentication is not available on this device',
      );
      return false;
    }
    if (enabled) {
      final verified = await runWithoutBiometricLock(
        () => _biometricService.authenticate(),
      );
      if (!verified) {
        setError(
          _biometricService.lastError ??
              'Biometric verification is required before enabling app lock.',
        );
        return false;
      }
    }
    _biometricEnabled = enabled;
    await _secureStorage.saveBiometricPreference(enabled);
    if (enabled && _currentUser != null) {
      await _secureStorage.saveBiometricUserId(_currentUser!.id);
      await _secureStorage.saveBiometricUserEmail(_currentUser!.email);
      _hasStoredBiometricAccount = true;
      _lastBiometricEmail = _currentUser!.email;
    } else if (!enabled) {
      await _secureStorage.clearBiometricLoginIdentity();
      _hasStoredBiometricAccount = false;
      _lastBiometricEmail = null;
    }
    // User just verified (or disabled); do not force lock screen immediately.
    _needsBiometricUnlock = false;
    notifyListeners();
    return true;
  }

  Future<void> requireBiometricUnlock() async {
    if (shouldSuppressBiometricLock) return;
    if (_biometricEnabled && _currentUser != null && _isBiometricAvailable) {
      _needsBiometricUnlock = true;
      notifyListeners();
    }
  }

  Future<void> dismissBiometricLock() async {
    _needsBiometricUnlock = false;
    notifyListeners();
  }

  /// Upgrade legacy SHA-256 hashes to bcrypt after a successful verify.
  Future<void> _migratePasswordHashIfNeeded({
    required String userId,
    required String password,
    required String storedHash,
  }) async {
    if (!AuthService.needsBcryptMigration(storedHash)) return;
    try {
      await (_database.update(
        _database.users,
      )..where((t) => t.id.equals(userId))).write(
        db.UsersCompanion(
          passwordHash: drift.Value(AuthService.hashPassword(password)),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (e) {
      debugPrint('Password hash migration failed for $userId: $e');
    }
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
