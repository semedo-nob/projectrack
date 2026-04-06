// lib/constants/models/unit_model.dart
import '../../service/unit_service.dart';

/// App-level unit model (UI / suggestions). Backed by [UnitOption] + DB seeds.
class Unit {
  const Unit({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    required this.toBaseFactor,
    required this.baseUnit,
    this.isDefault = false,
    this.keywords = const [],
    this.icon,
  });

  final String id;
  final String name;
  final String displayName;
  final String category;
  final double toBaseFactor;
  final String baseUnit;
  final bool isDefault;
  final List<String> keywords;
  final String? icon;

  factory Unit.fromUnitOption(
    UnitOption o, {
    bool isDefault = false,
    List<String> keywords = const [],
    String? icon,
  }) {
    return Unit(
      id: o.id,
      name: o.name,
      displayName: o.displayName,
      category: o.category,
      toBaseFactor: o.toBaseFactor,
      baseUnit: o.baseUnit,
      isDefault: isDefault,
      keywords: keywords,
      icon: icon,
    );
  }

  UnitOption toUnitOption() => UnitOption(
        id: id,
        name: name,
        displayName: displayName,
        category: category,
        toBaseFactor: toBaseFactor,
        baseUnit: baseUnit,
      );
}
