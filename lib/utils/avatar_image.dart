// lib/utils/avatar_image.dart
import 'dart:io';
import 'package:flutter/material.dart';

/// Returns an [ImageProvider] for the given avatar URL.
/// Supports local file paths (persisted profile photos) and network URLs.
ImageProvider? avatarImageProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
  final trimmed = avatarUrl.trim();
  final isLocal = trimmed.startsWith('/') || trimmed.startsWith('file:');
  if (isLocal) {
    final path = trimmed.startsWith('file:') ? Uri.parse(trimmed).path : trimmed;
    if (File(path).existsSync()) return FileImage(File(path));
    return null;
  }
  return NetworkImage(trimmed);
}
