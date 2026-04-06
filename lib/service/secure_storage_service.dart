// lib/services/secure_storage_service.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _biometricKey = 'biometric_enabled';
  static const String _userEmailKey = 'user_email';
  static const String _biometricUserIdKey = 'biometric_user_id';
  static const String _biometricUserEmailKey = 'biometric_user_email';
  static const String _googleEmailKey = 'google_account_email';
  static const String _googleDriveFileIdKey = 'google_drive_file_id';
  static const String _googleSyncEnabledKey = 'google_sync_enabled';
  static const String _lastGoogleSyncAtKey = 'last_google_sync_at';
  static const String _dismissedNotificationsKey = 'dismissed_notifications';

  // Auth token
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }

  Future<void> clearAuthToken() async {
    await _storage.delete(key: _authTokenKey);
  }

  // User ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // User Email
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _userEmailKey, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  Future<void> clearStoredLoginIdentity() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
  }

  Future<void> saveBiometricUserId(String userId) async {
    await _storage.write(key: _biometricUserIdKey, value: userId);
  }

  Future<String?> getBiometricUserId() async {
    return await _storage.read(key: _biometricUserIdKey);
  }

  Future<void> saveBiometricUserEmail(String email) async {
    await _storage.write(key: _biometricUserEmailKey, value: email);
  }

  Future<String?> getBiometricUserEmail() async {
    return await _storage.read(key: _biometricUserEmailKey);
  }

  Future<void> clearBiometricLoginIdentity() async {
    await _storage.delete(key: _biometricUserIdKey);
    await _storage.delete(key: _biometricUserEmailKey);
  }

  // Google account email
  Future<void> saveGoogleAccountEmail(String email) async {
    await _storage.write(key: _googleEmailKey, value: email);
  }

  Future<String?> getGoogleAccountEmail() async {
    return await _storage.read(key: _googleEmailKey);
  }

  Future<void> clearGoogleAccountEmail() async {
    await _storage.delete(key: _googleEmailKey);
  }

  // Google Drive backup file id
  Future<void> saveGoogleDriveFileId(String fileId) async {
    await _storage.write(key: _googleDriveFileIdKey, value: fileId);
  }

  Future<String?> getGoogleDriveFileId() async {
    return await _storage.read(key: _googleDriveFileIdKey);
  }

  Future<void> clearGoogleDriveFileId() async {
    await _storage.delete(key: _googleDriveFileIdKey);
  }

  // Google sync preference
  Future<void> saveGoogleSyncEnabled(bool enabled) async {
    await _storage.write(key: _googleSyncEnabledKey, value: enabled.toString());
  }

  Future<bool> isGoogleSyncEnabled() async {
    final value = await _storage.read(key: _googleSyncEnabledKey);
    return value == 'true';
  }

  // Last Google sync timestamp
  Future<void> saveLastGoogleSyncAt(DateTime timestamp) async {
    await _storage.write(
      key: _lastGoogleSyncAtKey,
      value: timestamp.toIso8601String(),
    );
  }

  Future<DateTime?> getLastGoogleSyncAt() async {
    final value = await _storage.read(key: _lastGoogleSyncAtKey);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  // Biometric preference
  Future<void> saveBiometricPreference(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool?> getBiometricPreference() async {
    final value = await _storage.read(key: _biometricKey);
    return value != null ? value == 'true' : null;
  }

  Future<void> saveDismissedNotifications(Set<String> ids) async {
    await _storage.write(
      key: _dismissedNotificationsKey,
      value: jsonEncode(ids.toList()..sort()),
    );
  }

  Future<Set<String>> getDismissedNotifications() async {
    final value = await _storage.read(key: _dismissedNotificationsKey);
    if (value == null || value.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      // Ignore corrupt local dismissal data and reset to empty state.
    }
    return <String>{};
  }

  Future<void> clearDismissedNotifications() async {
    await _storage.delete(key: _dismissedNotificationsKey);
  }

  Future<void> clearSession() async {
    await clearAuthToken();
    await clearStoredLoginIdentity();
  }

  // Clear all
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
