import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/constants/models/task_model.dart';
import 'package:projectrack1/service/receipt_validation_service.dart';

void main() {
  const service = ReceiptValidationService();

  group('ReceiptValidationService', () {
    test('accepts a typical retail receipt', () {
      const text = '''
HOME DEPOT
123 Main Street
Date: 03/15/2025
Item 1  \$12.99
Item 2  \$8.50
Subtotal \$21.49
Tax \$1.72
TOTAL \$23.21
Thank you for your purchase
Visa **** 1234
''';

      final result = service.validate(text);

      expect(result.isValid, isTrue);
      expect(result.parsed.amount, 23.21);
      expect(result.parsed.merchant, 'Home Depot');
      expect(result.parsed.date, isNotNull);
    });

    test('accepts minimal thermal receipt layout', () {
      const text = '''
BUILDERS SUPPLY
03/02/25 14:32
CEMENT 2 x 450.00
TOTAL 900.00
''';

      final result = service.validate(text);

      expect(result.allowManualOverride || result.isValid, isTrue);
      expect(result.parsed.amount, 900.00);
    });

    test('accepts invoice-style receipt with reference number', () {
      const text = '''
INVOICE
Supplier: Wickes
Invoice No: INV-99231
Transaction Date: 2025-07-01
Materials delivery
Amount Due: GBP 145.60
''';

      final result = service.validate(text);

      expect(result.isValid, isTrue);
      expect(result.parsed.amount, 145.60);
      expect(result.parsed.merchant, 'Wickes');
    });

    test('rejects obvious non-receipt images', () {
      const text = 'instagram screenshot selfie wallpaper meme';

      final result = service.validate(text);

      expect(result.isValid, isFalse);
      expect(result.allowManualOverride, isFalse);
      expect(result.tier, ReceiptValidationTier.rejected);
    });

    test('allows manual override for ambiguous but plausible text', () {
      const text = '''
LOCAL SHOP
12/07/25
Paid 18.75
''';

      final result = service.validate(text);

      expect(result.allowManualOverride || result.isValid, isTrue);
    });
  });

  group('TaskStatus', () {
    test('fromString normalizes todo variants', () {
      expect(TaskStatus.fromString('todo'), TaskStatus.pending);
      expect(TaskStatus.fromString('Todo'), TaskStatus.pending);
      expect(TaskStatus.fromString('not started'), TaskStatus.pending);
    });
  });
}
