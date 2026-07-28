// lib/service/unit_service.dart
/// In-memory unit definitions (must match seeded rows in [UnitDefs] / `units` table).
class UnitOption {
  const UnitOption({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    required this.toBaseFactor,
    required this.baseUnit,
  });

  final String id;
  final String name;
  final String displayName;
  final String category;
  final double toBaseFactor;
  final String baseUnit;
}

class UnitService {
  UnitService._();

  static const List<UnitOption> all = [
    UnitOption(
      id: 'u_kg',
      name: 'kg',
      displayName: 'Kilogram',
      category: 'weight',
      toBaseFactor: 1.0,
      baseUnit: 'kg',
    ),
    UnitOption(
      id: 'u_g',
      name: 'g',
      displayName: 'Gram',
      category: 'weight',
      toBaseFactor: 0.001,
      baseUnit: 'kg',
    ),
    UnitOption(
      id: 'u_bag',
      name: 'bag',
      displayName: 'Bag',
      category: 'weight',
      toBaseFactor: 50.0,
      baseUnit: 'kg',
    ),
    UnitOption(
      id: 'u_tonne',
      name: 'tonne',
      displayName: 'Tonne',
      category: 'weight',
      toBaseFactor: 1000.0,
      baseUnit: 'kg',
    ),
    UnitOption(
      id: 'u_litre',
      name: 'litre',
      displayName: 'Litre',
      category: 'volume',
      toBaseFactor: 1.0,
      baseUnit: 'litre',
    ),
    UnitOption(
      id: 'u_ml',
      name: 'ml',
      displayName: 'Millilitre',
      category: 'volume',
      toBaseFactor: 0.001,
      baseUnit: 'litre',
    ),
    UnitOption(
      id: 'u_gallon',
      name: 'gallon',
      displayName: 'Gallon (US)',
      category: 'volume',
      toBaseFactor: 3.785,
      baseUnit: 'litre',
    ),
    UnitOption(
      id: 'u_m3',
      name: 'm3',
      displayName: 'Cubic metre',
      category: 'volume',
      toBaseFactor: 1000.0,
      baseUnit: 'litre',
    ),
    UnitOption(
      id: 'u_piece',
      name: 'piece',
      displayName: 'Piece',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_dozen',
      name: 'dozen',
      displayName: 'Dozen',
      category: 'count',
      toBaseFactor: 12.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_pack',
      name: 'pack',
      displayName: 'Pack',
      category: 'count',
      toBaseFactor: 6.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_box',
      name: 'box',
      displayName: 'Box',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_set',
      name: 'set',
      displayName: 'Set',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_bundle',
      name: 'bundle',
      displayName: 'Bundle',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_roll',
      name: 'roll',
      displayName: 'Roll',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_sheet',
      name: 'sheet',
      displayName: 'Sheet',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_load',
      name: 'load',
      displayName: 'Load / Trip',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_m',
      name: 'm',
      displayName: 'Metre',
      category: 'length',
      toBaseFactor: 1.0,
      baseUnit: 'm',
    ),
    UnitOption(
      id: 'u_cm',
      name: 'cm',
      displayName: 'Centimetre',
      category: 'length',
      toBaseFactor: 0.01,
      baseUnit: 'm',
    ),
    UnitOption(
      id: 'u_ft',
      name: 'ft',
      displayName: 'Foot',
      category: 'length',
      toBaseFactor: 0.3048,
      baseUnit: 'm',
    ),
    UnitOption(
      id: 'u_m2',
      name: 'm2',
      displayName: 'Square metre',
      category: 'area',
      toBaseFactor: 1.0,
      baseUnit: 'm2',
    ),
    UnitOption(
      id: 'u_acre',
      name: 'acre',
      displayName: 'Acre',
      category: 'area',
      toBaseFactor: 4046.86,
      baseUnit: 'm2',
    ),
    UnitOption(
      id: 'u_hectare',
      name: 'hectare',
      displayName: 'Hectare',
      category: 'area',
      toBaseFactor: 10000.0,
      baseUnit: 'm2',
    ),
    UnitOption(
      id: 'u_crate',
      name: 'crate',
      displayName: 'Crate',
      category: 'count',
      toBaseFactor: 1.0,
      baseUnit: 'piece',
    ),
    UnitOption(
      id: 'u_hour',
      name: 'hour',
      displayName: 'Hour',
      category: 'time',
      toBaseFactor: 1.0,
      baseUnit: 'hour',
    ),
    UnitOption(
      id: 'u_day',
      name: 'day',
      displayName: 'Day',
      category: 'time',
      toBaseFactor: 8.0,
      baseUnit: 'hour',
    ),
  ];

  static UnitOption? byId(String id) {
    for (final u in all) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Resolves stored [unitOriginal] which may be a row id (`u_bag`) or legacy name (`bag`).
  static UnitOption? optionForStoredUnit(String unitOriginal) {
    final direct = byId(unitOriginal);
    if (direct != null) return direct;
    for (final u in all) {
      if (u.name == unitOriginal) return u;
    }
    return null;
  }

  static List<UnitOption> forCategory(String category) =>
      all.where((u) => u.category == category).toList();

  static ({double quantityBase, String unitBase}) toBase({
    required double quantityOriginal,
    required UnitOption unit,
  }) {
    return (
      quantityBase: quantityOriginal * unit.toBaseFactor,
      unitBase: unit.baseUnit,
    );
  }

  static String formatQuantity(double qty, UnitOption unit) {
    final q = _formatQty(qty);
    final label = qty == 1.0 ? _singularLabel(unit.displayName) : _pluralLabel(unit.displayName);
    return '$q $label';
  }

  static String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    final s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _singularLabel(String displayName) => displayName.toLowerCase();

  static String _pluralLabel(String displayName) {
    final lower = displayName.toLowerCase();
    if (lower.endsWith('s')) return lower;
    return '${lower}s';
  }

  static List<UnitOption> sortedForDropdown() {
    final copy = List<UnitOption>.from(all);
    copy.sort((a, b) {
      final c = a.category.compareTo(b.category);
      if (c != 0) return c;
      return a.displayName.compareTo(b.displayName);
    });
    return copy;
  }
}
