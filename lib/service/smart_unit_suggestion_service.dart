// lib/service/smart_unit_suggestion_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'display_unit_prefs.dart';
import 'unit_service.dart';

/// Keyword-based and learned unit suggestions. Only references units in [UnitService.all].
class SmartUnitSuggestionService {
  SmartUnitSuggestionService._();

  static const _prefsKey = 'material_unit_learned_v1';

  /// materialKey (lowercase) -> unit `name` (e.g. bag, litre).
  static final Map<String, String> _learned = {};

  static bool _loaded = false;

  /// Maps a substring of material name → preferred unit **names** (must exist in [UnitService]).
  static final Map<String, List<String>> _materialUnitKeywords = {
    'cement': ['bag', 'kg', 'tonne'],
    'sand': ['tonne', 'm3', 'kg', 'load'],
    'ballast': ['tonne', 'm3', 'load'],
    'aggregate': ['tonne', 'm3', 'load'],
    'gravel': ['tonne', 'm3', 'load'],
    'stone': ['tonne', 'piece', 'm3'],
    'brick': ['piece', 'pack', 'dozen'],
    'block': ['piece', 'pack'],
    'timber': ['piece', 'm', 'bundle'],
    'lumber': ['piece', 'm', 'bundle'],
    'wood': ['piece', 'm', 'sheet'],
    'plywood': ['sheet', 'piece'],
    'board': ['sheet', 'piece', 'm'],
    'rebar': ['piece', 'kg', 'tonne'],
    'iron': ['piece', 'kg', 'm'],
    'steel': ['piece', 'kg', 'm'],
    'wire': ['roll', 'm', 'kg'],
    'cable': ['roll', 'm', 'piece'],
    'nail': ['kg', 'box', 'piece'],
    'screw': ['box', 'piece', 'pack'],
    'bolt': ['piece', 'box', 'set'],
    'paint': ['litre', 'gallon', 'ml'],
    'primer': ['litre', 'gallon'],
    'thinner': ['litre', 'ml'],
    'pipe': ['piece', 'm', 'litre'],
    'pvc': ['piece', 'm'],
    'tile': ['piece', 'm2', 'box'],
    'flooring': ['m2', 'piece', 'box'],
    'cement board': ['sheet', 'piece'],
    'gypsum': ['sheet', 'piece'],
    'mesh': ['roll', 'm2', 'piece'],
    'membrane': ['roll', 'm2'],
    'insulation': ['roll', 'sheet', 'm2'],
    'concrete': ['m3', 'tonne', 'load'],
    'mortar': ['bag', 'kg', 'm3'],
    'plaster': ['bag', 'kg'],
    'glue': ['litre', 'ml', 'piece'],
    'adhesive': ['litre', 'kg', 'piece'],
    'sealant': ['piece', 'ml', 'litre'],
    'fuel': ['litre', 'gallon'],
    'diesel': ['litre', 'gallon'],
    'petrol': ['litre', 'gallon'],
    'labor': ['hour', 'day'],
    'labour': ['hour', 'day'],
    'worker': ['hour', 'day'],
    'hire': ['hour', 'day'],
    'rental': ['hour', 'day'],
    'transport': ['load', 'day', 'hour'],
    'delivery': ['load', 'piece'],
    'trip': ['load', 'piece'],
    'maize': ['kg', 'bag', 'acre', 'hectare'],
    'corn': ['kg', 'bag', 'acre'],
    'wheat': ['kg', 'bag', 'acre', 'hectare'],
    'rice': ['kg', 'pack', 'bag', 'acre'],
    'fertilizer': ['kg', 'bag', 'tonne'],
    'fertiliser': ['kg', 'bag', 'tonne'],
    'seed': ['kg', 'g', 'pack', 'bag'],
    'harvest': ['kg', 'bag', 'crate', 'tonne'],
    'produce': ['kg', 'crate', 'bag'],
    'acre': ['acre', 'hectare'],
    'hectare': ['hectare', 'acre'],
    'farm': ['acre', 'hectare', 'hour'],
    'field': ['acre', 'hectare', 'hour'],
    'irrigation': ['litre', 'hour', 'day'],
    'pesticide': ['litre', 'ml', 'kg'],
    'herbicide': ['litre', 'ml'],
    'livestock': ['piece', 'day'],
    'feed': ['kg', 'bag', 'tonne'],
  };

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) {
          _learned[k] = v.toString();
        });
      } catch (_) {}
    }
    _loaded = true;
  }

  static Future<void> recordUnitPreference(String materialName, String unitName) async {
    final key = _normKey(materialName);
    if (key.isEmpty) return;
    _learned[key] = unitName;
    await _persist();
  }

  static Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(_learned));
  }

  static String _normKey(String materialName) =>
      materialName.toLowerCase().trim();

  static UnitOption? _byName(String name) {
    final n = name.toLowerCase();
    for (final u in UnitService.all) {
      if (u.name == n) return u;
    }
    return null;
  }

  /// Top suggestions (max [limit]) for chips / quick-pick.
  static Future<List<UnitOption>> suggestUnitsForMaterial(
    String materialName, {
    int limit = 4,
  }) async {
    await ensureLoaded();
    if (!(await DisplayUnitPrefs.smartSuggestionsEnabled())) {
      return _fallbackCommon(limit);
    }

    final materialLower = _normKey(materialName);
    if (materialLower.length < 2) {
      return _fallbackCommon(limit);
    }

    final suggestions = <UnitOption>[];
    final seen = <String>{};

    void add(UnitOption? u) {
      if (u == null || seen.contains(u.id)) return;
      suggestions.add(u);
      seen.add(u.id);
    }

    // 1. Learned preference
    final learnedName = _learned[materialLower];
    if (learnedName != null) {
      add(_byName(learnedName));
    }

    // 2. Keyword rows (first matching key wins for ordering)
    for (final e in _materialUnitKeywords.entries) {
      if (materialLower.contains(e.key)) {
        for (final un in e.value) {
          add(_byName(un));
        }
        break;
      }
    }

    // 3. Defaults by category (weight-first for construction)
    for (final u in UnitService.all) {
      if (u.id == 'u_kg' || u.id == 'u_litre' || u.id == 'u_piece') {
        add(u);
      }
    }

    // 4. Common backup
    for (final n in ['piece', 'kg', 'litre']) {
      add(_byName(n));
    }

    if (suggestions.length > limit) {
      return suggestions.take(limit).toList();
    }
    if (suggestions.isEmpty) {
      return _fallbackCommon(limit);
    }
    return suggestions.take(limit).toList();
  }

  static List<UnitOption> _fallbackCommon(int limit) {
    final out = <UnitOption>[];
    final seen = <String>{};
    for (final id in ['u_kg', 'u_bag', 'u_litre', 'u_piece']) {
      final u = UnitService.byId(id);
      if (u != null && !seen.contains(u.id)) {
        out.add(u);
        seen.add(u.id);
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Whether [materialName] triggered a keyword row (used for optional auto-pick).
  static bool keywordMatchForMaterial(String materialName) {
    final materialLower = _normKey(materialName);
    if (materialLower.length < 2) return false;
    for (final k in _materialUnitKeywords.keys) {
      if (materialLower.contains(k)) return true;
    }
    return false;
  }
}
