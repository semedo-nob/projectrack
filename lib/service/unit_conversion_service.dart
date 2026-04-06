// lib/service/unit_conversion_service.dart
import '../constants/models/unit_model.dart';
import 'unit_service.dart';

/// Conversion helpers using seeded [UnitService] definitions.
class UnitConversionService {
  UnitConversionService._();

  static List<Unit> _cache = [];

  static void initializeFromUnitService() {
    _cache = UnitService.all
        .map(
          (o) => Unit.fromUnitOption(
            o,
            isDefault: _isCategoryDefault(o),
          ),
        )
        .toList();
  }

  static bool _isCategoryDefault(UnitOption o) {
    return (o.category == 'weight' && o.id == 'u_kg') ||
        (o.category == 'volume' && o.id == 'u_litre') ||
        (o.category == 'count' && o.id == 'u_piece');
  }

  static Unit? unitByName(String name) {
    if (_cache.isEmpty) initializeFromUnitService();
    final n = name.toLowerCase();
    for (final u in _cache) {
      if (u.name == n) return u;
    }
    final o = UnitService.optionForStoredUnit(name);
    return o == null ? null : Unit.fromUnitOption(o);
  }

  static double convertToBase(double quantity, Unit unit) =>
      quantity * unit.toBaseFactor;

  static double convertFromBase(double baseQuantity, Unit unit) =>
      unit.toBaseFactor > 0 ? baseQuantity / unit.toBaseFactor : baseQuantity;

  static List<Unit> unitsByCategory(String category) {
    if (_cache.isEmpty) initializeFromUnitService();
    return _cache.where((u) => u.category == category).toList();
  }
}
