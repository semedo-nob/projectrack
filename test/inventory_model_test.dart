import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/constants/models/inventory_model.dart';

void main() {
  group('InventoryItem', () {
    test('normalizeNameKey collapses whitespace and case', () {
      expect(
        InventoryItem.normalizeNameKey('  Cement   Bags '),
        'cement bags',
      );
    });

    test('isLowStock respects reorder level', () {
      final item = InventoryItem(
        id: '1',
        projectId: 'p',
        name: 'Cement',
        nameKey: 'cement',
        quantityBase: 40,
        unitBase: 'kg',
        reorderLevel: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item.isLowStock, isTrue);
      expect(item.isOutOfStock, isFalse);
    });

    test('reorderLevel 0 disables low-stock alert', () {
      final item = InventoryItem(
        id: '1',
        projectId: 'p',
        name: 'Sand',
        nameKey: 'sand',
        quantityBase: 0,
        unitBase: 'kg',
        reorderLevel: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item.isLowStock, isFalse);
      expect(item.isOutOfStock, isTrue);
    });
  });
}
