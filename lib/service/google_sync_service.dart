import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../database/database.dart';
import 'secure_storage_service.dart';

class SyncResult {
  const SyncResult({
    required this.success,
    required this.message,
    this.accountEmail,
    this.syncedAt,
  });

  final bool success;
  final String message;
  final String? accountEmail;
  final DateTime? syncedAt;
}

class GoogleSyncService {
  GoogleSyncService._();

  static final GoogleSyncService instance = GoogleSyncService._();

  final SecureStorageService _storage = SecureStorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', drive.DriveApi.driveAppdataScope],
  );

  Future<String?> getLinkedAccountEmail() async {
    return _storage.getGoogleAccountEmail();
  }

  Future<DateTime?> getLastSyncAt() async {
    return _storage.getLastGoogleSyncAt();
  }

  Future<bool> isAutoSyncEnabled() async {
    return _storage.isGoogleSyncEnabled();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _storage.saveGoogleSyncEnabled(enabled);
  }

  Future<SyncResult> connectAccount() async {
    try {
      var user = await _googleSignIn.signInSilently();
      user ??= await _googleSignIn.signIn();
      if (user == null) {
        return const SyncResult(
          success: false,
          message: 'Google sign-in was cancelled.',
        );
      }
      await _storage.saveGoogleAccountEmail(user.email);
      await _storage.saveGoogleSyncEnabled(true);
      return SyncResult(
        success: true,
        message: 'Connected to ${user.email}.',
        accountEmail: user.email,
      );
    } catch (e) {
      final errorText = e.toString();
      if (errorText.contains('ApiException: 10') ||
          errorText.contains('sign_in_failed')) {
        return SyncResult(
          success: false,
          message: Platform.isIOS
              ? 'Google sign-in is not fully configured for iOS yet. Add the app bundle ID in Google Cloud, create the iOS OAuth client, and add the reversed client ID URL scheme to Info.plist.'
              : 'Google sign-in is not fully configured for this app yet. Add the exact Android package name plus SHA-1/SHA-256 fingerprints in Google Cloud, then create the matching OAuth client.',
        );
      }
      return SyncResult(
        success: false,
        message: 'Failed to connect Google account: $errorText',
      );
    }
  }

  Future<void> disconnectAccount() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
    await _storage.clearGoogleAccountEmail();
    await _storage.clearGoogleDriveFileId();
    await _storage.saveGoogleSyncEnabled(false);
  }

  Future<SyncResult> backupUserData({
    required AppDatabase database,
    required String userId,
    bool interactive = true,
  }) async {
    try {
      final signedInUser = await _getSignedInUser(interactive: interactive);
      if (signedInUser == null) {
        return const SyncResult(
          success: false,
          message: 'Connect a Google account before syncing.',
        );
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return const SyncResult(
          success: false,
          message: 'Google authorization was not granted.',
        );
      }

      final driveApi = drive.DriveApi(client);
      final backup = await database.exportUserBackup(userId);
      final content = jsonEncode(backup);
      final bytes = Uint8List.fromList(utf8.encode(content));
      final fileName = _backupFileName(signedInUser.email);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      final existing = await _findBackupFile(driveApi, signedInUser.email);
      final metadata = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];

      drive.File savedFile;
      if (existing != null) {
        savedFile = await driveApi.files.update(
          metadata,
          existing.id!,
          uploadMedia: media,
        );
      } else {
        savedFile = await driveApi.files.create(metadata, uploadMedia: media);
      }

      final now = DateTime.now();
      await _storage.saveGoogleAccountEmail(signedInUser.email);
      if (savedFile.id != null) {
        await _storage.saveGoogleDriveFileId(savedFile.id!);
      }
      await _storage.saveLastGoogleSyncAt(now);

      return SyncResult(
        success: true,
        message: 'Backup synced to Google Drive.',
        accountEmail: signedInUser.email,
        syncedAt: now,
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Google backup failed: $e');
    }
  }

  Future<SyncResult> restoreUserData({
    required AppDatabase database,
    required String userId,
    bool interactive = true,
  }) async {
    try {
      final signedInUser = await _getSignedInUser(interactive: interactive);
      if (signedInUser == null) {
        return const SyncResult(
          success: false,
          message: 'Connect a Google account before restoring.',
        );
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return const SyncResult(
          success: false,
          message: 'Google authorization was not granted.',
        );
      }

      final driveApi = drive.DriveApi(client);
      final file = await _findBackupFile(driveApi, signedInUser.email);
      if (file?.id == null) {
        return const SyncResult(
          success: false,
          message: 'No Google backup found for this account yet.',
        );
      }

      final media = await driveApi.files.get(
        file!.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (media is! drive.Media) {
        return const SyncResult(
          success: false,
          message: 'Failed to download backup content from Google Drive.',
        );
      }

      final chunks = await media.stream.toList();
      final bytes = Uint8List.fromList(
        chunks.expand((chunk) => chunk).toList(),
      );
      final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      await database.importUserBackup(payload, userId: userId);

      final now = DateTime.now();
      await _storage.saveGoogleAccountEmail(signedInUser.email);
      await _storage.saveGoogleDriveFileId(file.id!);
      await _storage.saveLastGoogleSyncAt(now);

      return SyncResult(
        success: true,
        message: 'Projects and account data restored from Google Drive.',
        accountEmail: signedInUser.email,
        syncedAt: now,
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Restore failed: $e');
    }
  }

  Future<void> backupIfEnabled({
    required AppDatabase database,
    required String userId,
  }) async {
    final enabled = await isAutoSyncEnabled();
    final linkedEmail = await getLinkedAccountEmail();
    if (!enabled || linkedEmail == null || linkedEmail.isEmpty) {
      return;
    }
    await backupUserData(
      database: database,
      userId: userId,
      interactive: false,
    );
  }

  String _backupFileName(String accountEmail) {
    final normalized = accountEmail.trim().toLowerCase();
    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    return 'projectrack_backup_$safe.json';
  }

  Future<drive.File?> _findBackupFile(
    drive.DriveApi api,
    String accountEmail,
  ) async {
    final escapedName = _backupFileName(accountEmail).replaceAll("'", r"\'");
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$escapedName' and trashed = false",
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    files.sort((a, b) {
      final left = a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return files.first;
  }

  Future<GoogleSignInAccount?> _getSignedInUser({
    required bool interactive,
  }) async {
    final silentUser = await _googleSignIn.signInSilently();
    if (silentUser != null) return silentUser;
    if (!interactive) return null;
    return _googleSignIn.signIn();
  }
}
