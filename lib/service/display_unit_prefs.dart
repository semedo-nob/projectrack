// lib/service/display_unit_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

import 'unit_service.dart';

/// Default unit id per category for new material entries (and optional display hints).
class DisplayUnitPrefs {
  DisplayUnitPrefs._();

  static const _kWeight = 'pref_default_unit_weight';
  static const _kVolume = 'pref_default_unit_volume';
  static const _kCount = 'pref_default_unit_count';
  static const _kSmart = 'pref_smart_unit_suggestions';

  static Future<bool> smartSuggestionsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSmart) ?? true;
  }

  static Future<void> setSmartSuggestionsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmart, value);
  }

  static Future<String> defaultUnitIdForCategory(String category) async {
    final p = await SharedPreferences.getInstance();
    switch (category) {
      case 'weight':
        return p.getString(_kWeight) ?? 'u_kg';
      case 'volume':
        return p.getString(_kVolume) ?? 'u_litre';
      case 'count':
        return p.getString(_kCount) ?? 'u_piece';
      default:
        return 'u_piece';
    }
  }

  static Future<void> setDefaultUnitForCategory(
    String category,
    String unitId,
  ) async {
    final p = await SharedPreferences.getInstance();
    switch (category) {
      case 'weight':
        await p.setString(_kWeight, unitId);
        break;
      case 'volume':
        await p.setString(_kVolume, unitId);
        break;
      case 'count':
        await p.setString(_kCount, unitId);
        break;
    }
  }

  static Future<Map<String, String>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    return {
      'weight': p.getString(_kWeight) ?? 'u_kg',
      'volume': p.getString(_kVolume) ?? 'u_litre',
      'count': p.getString(_kCount) ?? 'u_piece',
    };
  }

  /// Validates that [unitId] exists; otherwise returns category default.
  static String validatedDefault(String category, String? unitId) {
    final id = unitId ?? '';
    if (UnitService.byId(id) != null) return id;
    switch (category) {
      case 'weight':
        return 'u_kg';
      case 'volume':
        return 'u_litre';
      case 'count':
        return 'u_piece';
      default:
        return 'u_piece';
    }
  }
}
