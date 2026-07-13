import 'package:drift/drift.dart';
import 'package:projectrack1/constants/models/inventory_model.dart';
import 'package:projectrack1/database/database.dart';
import 'package:projectrack1/service/unit_service.dart';

class InventoryException implements Exception {
  InventoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stock tracking: purchases add inventory, usage subtracts, with low-stock levels.
class InventoryService {
  InventoryService(this._db);

  final AppDatabase _db;

  Stream<List<InventoryItem>> watchProjectInventory(String projectId) {
    return _db.watchInventoryForProject(projectId).map(
      (rows) => rows.map(InventoryItem.fromDrift).toList(),
    );
  }

  Future<List<InventoryItem>> getProjectInventory(String projectId) async {
    final rows = await _db.getInventoryForProject(projectId);
    return rows.map(InventoryItem.fromDrift).toList();
  }

  Future<List<InventoryItem>> getLowStockItems(String projectId) async {
    final items = await getProjectInventory(projectId);
    return items.where((i) => i.isLowStock || i.isOutOfStock).toList();
  }

  Future<InventoryItem?> getItem(String id) async {
    final row = await _db.getInventoryItem(id);
    return row == null ? null : InventoryItem.fromDrift(row);
  }

  /// Create or update a catalog item without changing quantity.
  Future<InventoryItem> upsertCatalogItem({
    required String projectId,
    required String name,
    required String unitBase,
    String? preferredUnitId,
    double reorderLevel = 0,
    String? notes,
    String? existingId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw InventoryException('Material name is required');
    }
    final key = InventoryItem.normalizeNameKey(trimmed);
    final now = DateTime.now();

    if (existingId != null) {
      final existing = await _db.getInventoryItem(existingId);
      if (existing == null) throw InventoryException('Item not found');
      await _db.updateInventoryItem(
        InventoryItemsCompanion(
          id: Value(existing.id),
          projectId: Value(existing.projectId),
          name: Value(trimmed),
          nameKey: Value(key),
          quantityBase: Value(existing.quantityBase),
          unitBase: Value(unitBase),
          preferredUnitId: Value(preferredUnitId),
          reorderLevel: Value(reorderLevel),
          notes: Value(notes),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(now),
        ),
      );
      return (await getItem(existingId))!;
    }

    final clash = await _db.findInventoryByNameKey(projectId, key);
    if (clash != null) {
      throw InventoryException('An item named "$trimmed" already exists');
    }

    final id = 'inv_${now.millisecondsSinceEpoch}';
    await _db.insertInventoryItem(
      InventoryItemsCompanion.insert(
        id: id,
        projectId: projectId,
        name: trimmed,
        nameKey: key,
        quantityBase: const Value(0),
        unitBase: unitBase,
        preferredUnitId: Value(preferredUnitId),
        reorderLevel: Value(reorderLevel),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await getItem(id))!;
  }

  /// Add stock from a purchase (e.g. daily material expense).
  Future<InventoryItem> recordPurchase({
    required String projectId,
    required String materialName,
    required double quantityOriginal,
    required UnitOption unit,
    String? expenseId,
    String? notes,
    DateTime? occurredAt,
    double? reorderLevel,
  }) async {
    if (quantityOriginal <= 0) {
      throw InventoryException('Purchase quantity must be greater than zero');
    }
    final base = UnitService.toBase(
      quantityOriginal: quantityOriginal,
      unit: unit,
    );
    final key = InventoryItem.normalizeNameKey(materialName);
    final now = DateTime.now();
    var item = await _db.findInventoryByNameKey(projectId, key);

    if (item == null) {
      final id = 'inv_${now.millisecondsSinceEpoch}';
      await _db.insertInventoryItem(
        InventoryItemsCompanion.insert(
          id: id,
          projectId: projectId,
          name: materialName.trim(),
          nameKey: key,
          quantityBase: Value(base.quantityBase),
          unitBase: base.unitBase,
          preferredUnitId: Value(unit.id),
          reorderLevel: Value(reorderLevel ?? 0),
          createdAt: now,
          updatedAt: now,
        ),
      );
      item = await _db.getInventoryItem(id);
    } else {
      if (item.unitBase != base.unitBase) {
        throw InventoryException(
          'Unit mismatch for "${item.name}": stock is in ${item.unitBase}, '
          'purchase is in ${base.unitBase}',
        );
      }
      await _db.updateInventoryItem(
        InventoryItemsCompanion(
          id: Value(item.id),
          projectId: Value(item.projectId),
          name: Value(item.name),
          nameKey: Value(item.nameKey),
          quantityBase: Value(item.quantityBase + base.quantityBase),
          unitBase: Value(item.unitBase),
          preferredUnitId: Value(item.preferredUnitId ?? unit.id),
          reorderLevel: Value(item.reorderLevel),
          notes: Value(item.notes),
          createdAt: Value(item.createdAt),
          updatedAt: Value(now),
        ),
      );
      item = await _db.getInventoryItem(item.id);
    }

    final row = item!;
    await _db.insertMaterialUsage(
      MaterialUsagesCompanion.insert(
        id: 'mov_${now.millisecondsSinceEpoch}',
        projectId: projectId,
        inventoryItemId: row.id,
        kind: MaterialMovementKind.purchase.storageValue,
        quantityBase: base.quantityBase,
        unitBase: base.unitBase,
        quantityOriginal: Value(quantityOriginal),
        unitOriginal: Value(unit.id),
        notes: Value(notes),
        expenseId: Value(expenseId),
        occurredAt: occurredAt ?? now,
        createdAt: now,
      ),
    );

    return InventoryItem.fromDrift(row);
  }

  /// Consume stock on site.
  Future<InventoryItem> recordUsage({
    required String inventoryItemId,
    required double quantityOriginal,
    required UnitOption unit,
    String? notes,
    DateTime? occurredAt,
  }) async {
    if (quantityOriginal <= 0) {
      throw InventoryException('Usage quantity must be greater than zero');
    }
    final existing = await _db.getInventoryItem(inventoryItemId);
    if (existing == null) throw InventoryException('Item not found');

    final base = UnitService.toBase(
      quantityOriginal: quantityOriginal,
      unit: unit,
    );
    if (existing.unitBase != base.unitBase) {
      throw InventoryException(
        'Unit mismatch: stock is in ${existing.unitBase}, usage is in ${base.unitBase}',
      );
    }
    if (base.quantityBase > existing.quantityBase + 1e-9) {
      throw InventoryException(
        'Not enough stock for ${existing.name} '
        '(have ${existing.quantityBase.toStringAsFixed(2)} ${existing.unitBase})',
      );
    }

    final now = DateTime.now();
    final newQty = existing.quantityBase - base.quantityBase;
    await _db.updateInventoryItem(
      InventoryItemsCompanion(
        id: Value(existing.id),
        projectId: Value(existing.projectId),
        name: Value(existing.name),
        nameKey: Value(existing.nameKey),
        quantityBase: Value(newQty < 0 ? 0 : newQty),
        unitBase: Value(existing.unitBase),
        preferredUnitId: Value(existing.preferredUnitId),
        reorderLevel: Value(existing.reorderLevel),
        notes: Value(existing.notes),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    await _db.insertMaterialUsage(
      MaterialUsagesCompanion.insert(
        id: 'mov_${now.millisecondsSinceEpoch}',
        projectId: existing.projectId,
        inventoryItemId: existing.id,
        kind: MaterialMovementKind.usage.storageValue,
        quantityBase: base.quantityBase,
        unitBase: base.unitBase,
        quantityOriginal: Value(quantityOriginal),
        unitOriginal: Value(unit.id),
        notes: Value(notes),
        occurredAt: occurredAt ?? now,
        createdAt: now,
      ),
    );

    return (await getItem(existing.id))!;
  }

  Future<void> deleteItem(String id) => _db.deleteInventoryItem(id);

  Future<List<MaterialMovement>> getItemHistory(String inventoryItemId) async {
    final rows = await _db.getUsagesForItem(inventoryItemId);
    return rows.map(MaterialMovement.fromDrift).toList();
  }
}
