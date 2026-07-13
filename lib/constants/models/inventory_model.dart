import 'package:projectrack1/database/database.dart' as db;
import 'package:projectrack1/service/unit_service.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:flutter/material.dart';

enum MaterialMovementKind {
  purchase,
  usage,
  adjustment;

  String get storageValue => name;

  String get displayName {
    switch (this) {
      case MaterialMovementKind.purchase:
        return 'Purchase';
      case MaterialMovementKind.usage:
        return 'Used';
      case MaterialMovementKind.adjustment:
        return 'Adjustment';
    }
  }

  Color get color {
    switch (this) {
      case MaterialMovementKind.purchase:
        return AppColors.success;
      case MaterialMovementKind.usage:
        return AppColors.warning;
      case MaterialMovementKind.adjustment:
        return AppColors.info;
    }
  }

  static MaterialMovementKind fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'usage':
      case 'used':
        return MaterialMovementKind.usage;
      case 'adjustment':
        return MaterialMovementKind.adjustment;
      case 'purchase':
      default:
        return MaterialMovementKind.purchase;
    }
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.projectId,
    required this.name,
    required this.nameKey,
    required this.quantityBase,
    required this.unitBase,
    this.preferredUnitId,
    required this.reorderLevel,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String name;
  final String nameKey;
  final double quantityBase;
  final String unitBase;
  final String? preferredUnitId;
  final double reorderLevel;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock =>
      reorderLevel > 0 && quantityBase <= reorderLevel;

  bool get isOutOfStock => quantityBase <= 0;

  UnitOption get displayUnit {
    if (preferredUnitId != null) {
      final u = UnitService.byId(preferredUnitId!);
      if (u != null) return u;
    }
    return UnitService.all.firstWhere(
      (u) => u.baseUnit == unitBase && u.toBaseFactor == 1.0,
      orElse: () => UnitService.byId('u_kg')!,
    );
  }

  double get quantityInDisplayUnit {
    final unit = displayUnit;
    if (unit.toBaseFactor == 0) return quantityBase;
    return quantityBase / unit.toBaseFactor;
  }

  String get quantityLabel =>
      UnitService.formatQuantity(quantityInDisplayUnit, displayUnit);

  factory InventoryItem.fromDrift(db.InventoryItemRow row) {
    return InventoryItem(
      id: row.id,
      projectId: row.projectId,
      name: row.name,
      nameKey: row.nameKey,
      quantityBase: row.quantityBase,
      unitBase: row.unitBase,
      preferredUnitId: row.preferredUnitId,
      reorderLevel: row.reorderLevel,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static String normalizeNameKey(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

class MaterialMovement {
  const MaterialMovement({
    required this.id,
    required this.projectId,
    required this.inventoryItemId,
    required this.kind,
    required this.quantityBase,
    required this.unitBase,
    this.quantityOriginal,
    this.unitOriginal,
    this.notes,
    this.expenseId,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String inventoryItemId;
  final MaterialMovementKind kind;
  final double quantityBase;
  final String unitBase;
  final double? quantityOriginal;
  final String? unitOriginal;
  final String? notes;
  final String? expenseId;
  final DateTime occurredAt;
  final DateTime createdAt;

  factory MaterialMovement.fromDrift(db.MaterialUsageRow row) {
    return MaterialMovement(
      id: row.id,
      projectId: row.projectId,
      inventoryItemId: row.inventoryItemId,
      kind: MaterialMovementKind.fromString(row.kind),
      quantityBase: row.quantityBase,
      unitBase: row.unitBase,
      quantityOriginal: row.quantityOriginal,
      unitOriginal: row.unitOriginal,
      notes: row.notes,
      expenseId: row.expenseId,
      occurredAt: row.occurredAt,
      createdAt: row.createdAt,
    );
  }
}
