// lib/service/backup_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

/// Offline JSON backup/restore with optional embedded receipt images (base64).
class BackupService {
  BackupService._();

  static const int supportedFormatVersion = 1;

  /// Builds a full backup map and writes JSON via system save dialog.
  static Future<String?> exportToFile(AppDatabase db, {required String userId}) async {
    final raw = await db.exportUserBackup(userId);
    final pkg = await PackageInfo.fromPlatform();
    final expenses = <Map<String, dynamic>>[];
    final rawList = raw['expenses'] as List<dynamic>? ?? const [];
    for (final e in rawList) {
      final map = Map<String, dynamic>.from(e as Map);
      final path = map['receiptImage'] as String?;
      if (path != null && path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            if (bytes.length <= 12 * 1024 * 1024) {
              map['receiptImageBase64'] = base64Encode(bytes);
            }
          }
        } catch (_) {}
      }
      expenses.add(map);
    }

    final payload = <String, dynamic>{
      'version': supportedFormatVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': pkg.version,
      ...raw,
      'expenses': expenses,
    };

    final name =
        'projectrack_backup_${_stamp()}.json';
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final outPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );

    if (outPath == null) return null;
    try {
      final f = File(outPath);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsBytes(bytes, flush: true);
      }
    } catch (_) {
      return null;
    }
    return outPath;
  }

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}_'
        '${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}'
        '${n.second.toString().padLeft(2, '0')}';
  }

  /// Validates structure before destructive restore.
  static String? validateBackupJson(String? source) {
    if (source == null || source.trim().isEmpty) {
      return 'File is empty.';
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return 'Backup must be a JSON object.';
      }
      final v = decoded['version'];
      if (v != null) {
        if (v is! int || v < 1 || v > supportedFormatVersion) {
          return 'Unsupported backup version.';
        }
      } else if (decoded['schemaVersion'] == null) {
        return 'Unsupported backup format (missing version).';
      }
      if (decoded['projects'] is! List || decoded['expenses'] is! List) {
        return 'Backup is missing projects or expenses.';
      }
    } catch (e) {
      return 'Invalid JSON: $e';
    }
    return null;
  }

  /// Expands base64 receipt blobs into app storage paths, then replaces all user data.
  static Future<void> restoreFromJsonString(
    AppDatabase db, {
    required String userId,
    required String jsonSource,
  }) async {
    final decoded = jsonDecode(jsonSource) as Map<String, dynamic>;
    final dir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory(p.join(dir.path, 'receipts_backup'));
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }

    final expenses = (decoded['expenses'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (var i = 0; i < expenses.length; i++) {
      final map = expenses[i];
      final b64 = map.remove('receiptImageBase64') as String?;
      if (b64 != null && b64.isNotEmpty) {
        try {
          final bytes = base64Decode(b64);
          final id = map['id'] as String? ?? 'exp_$i';
          final path = p.join(receiptDir.path, '$id.jpg');
          await File(path).writeAsBytes(bytes, flush: true);
          map['receiptImage'] = path;
        } catch (_) {}
      }
    }

    decoded['expenses'] = expenses;

    await db.wipeUserDataForRestore(userId);
    await db.importUserBackup(decoded, userId: userId);
  }

  /// Pick a .json file and return its UTF-8 contents (for validation UI).
  static Future<String?> pickAndReadBackupFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: kIsWeb,
    );
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.single;
    if (kIsWeb && f.bytes != null) {
      return utf8.decode(f.bytes!);
    }
    final path = f.path;
    if (path == null) return null;
    return File(path).readAsString();
  }
}
