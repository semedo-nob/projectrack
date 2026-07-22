import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/constants/models/expense_model.dart';
import 'package:projectrack1/service/expense_duplicate_service.dart';
import 'package:projectrack1/service/receipt_validation_service.dart';

Expense _expense({
  required String id,
  required String merchant,
  required double amount,
  required DateTime date,
  String projectId = 'p1',
}) {
  final now = DateTime.now();
  return Expense(
    id: id,
    projectId: projectId,
    merchant: merchant,
    amount: amount,
    date: date,
    category: ExpenseCategory.receipt,
    status: ExpenseStatus.logged,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const duplicates = ExpenseDuplicateService();
  const validation = ReceiptValidationService();

  group('Receipt date/time parsing', () {
    test('parses receipt time with date', () {
      const text = '''
HOME DEPOT
Date: 03/15/2025
14:32
TOTAL \$45.00
Thank you
''';
      final result = validation.validate(text);
      expect(result.parsed.date, isNotNull);
      expect(result.parsed.hasTime, isTrue);
      expect(result.parsed.date!.hour, 14);
      expect(result.parsed.date!.minute, 32);
    });

    test('formats and parses user datetime round-trip', () {
      final dt = DateTime(2025, 7, 22, 14, 5);
      final formatted = validation.formatParsedDate(dt, includeTime: true);
      final parsed = validation.parseUserDateTime(formatted);
      expect(parsed, isNotNull);
      expect(parsed!.year, 2025);
      expect(parsed.month, 7);
      expect(parsed.day, 22);
      expect(parsed.hour, 14);
      expect(parsed.minute, 5);
    });
  });

  group('ExpenseDuplicateService', () {
    test('detects almost exact same purchase', () {
      final existing = [
        _expense(
          id: '1',
          merchant: 'Home Depot',
          amount: 120.50,
          date: DateTime(2025, 7, 20, 10, 0),
        ),
      ];
      final matches = duplicates.findMatches(
        candidates: existing,
        projectId: 'p1',
        merchant: 'HOME DEPOT',
        amount: 120.50,
        date: DateTime(2025, 7, 20, 10, 15),
      );
      expect(matches, isNotEmpty);
      expect(matches.first.isNearExact, isTrue);
    });

    test('groups repeat purchases', () {
      final expenses = [
        _expense(
          id: '1',
          merchant: 'Wickes',
          amount: 40,
          date: DateTime(2025, 7, 1),
        ),
        _expense(
          id: '2',
          merchant: 'Wickes',
          amount: 40,
          date: DateTime(2025, 7, 1, 9),
        ),
        _expense(
          id: '3',
          merchant: 'Other',
          amount: 10,
          date: DateTime(2025, 7, 2),
        ),
      ];
      final groups = duplicates.findRepeatGroups(expenses);
      expect(groups.length, 1);
      expect(groups.first.length, 2);
    });
  });
}
