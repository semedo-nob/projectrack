import '../constants/models/expense_model.dart';

/// Near-duplicate / repeat purchase detection for expenses and receipts.
class ExpenseDuplicateMatch {
  final Expense expense;
  final double similarity;
  final String reason;

  const ExpenseDuplicateMatch({
    required this.expense,
    required this.similarity,
    required this.reason,
  });

  bool get isExact => similarity >= 0.95;
  bool get isNearExact => similarity >= 0.8;
}

class ExpenseDuplicateService {
  const ExpenseDuplicateService();

  static String normalizeMerchant(String merchant) {
    return merchant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Finds expenses that look like the same purchase (or nearly the same).
  List<ExpenseDuplicateMatch> findMatches({
    required List<Expense> candidates,
    required String projectId,
    required String merchant,
    required double amount,
    required DateTime date,
    String? excludeExpenseId,
    int dayWindow = 2,
    double amountTolerance = 0.02,
  }) {
    final normalizedMerchant = normalizeMerchant(merchant);
    if (normalizedMerchant.isEmpty || amount <= 0) return const [];

    final matches = <ExpenseDuplicateMatch>[];
    final day = DateTime(date.year, date.month, date.day);

    for (final expense in candidates) {
      if (expense.projectId != projectId) continue;
      if (excludeExpenseId != null && expense.id == excludeExpenseId) continue;

      final otherDay = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      final dayDiff = day.difference(otherDay).inDays.abs();
      if (dayDiff > dayWindow) continue;

      final otherMerchant = normalizeMerchant(expense.merchant);
      final merchantSimilar = _merchantSimilarity(normalizedMerchant, otherMerchant);
      if (merchantSimilar < 0.72) continue;

      final amountDiff = (expense.amount - amount).abs();
      final amountRatio = amountDiff / (amount == 0 ? 1 : amount);
      if (amountRatio > amountTolerance && amountDiff > 1.0) continue;

      var similarity = 0.55 * merchantSimilar;
      if (amountDiff <= 0.01) {
        similarity += 0.35;
      } else if (amountRatio <= amountTolerance) {
        similarity += 0.25;
      }

      if (dayDiff == 0) {
        similarity += 0.1;
        // Same calendar day + close clock time strengthens the match.
        final minutes = expense.date.difference(date).inMinutes.abs();
        if (minutes <= 30) similarity += 0.05;
      } else {
        similarity += 0.03;
      }

      similarity = similarity.clamp(0.0, 1.0);
      if (similarity < 0.78) continue;

      final reason = _reason(
        dayDiff: dayDiff,
        amountDiff: amountDiff,
        merchantSimilar: merchantSimilar,
      );
      matches.add(
        ExpenseDuplicateMatch(
          expense: expense,
          similarity: similarity,
          reason: reason,
        ),
      );
    }

    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches;
  }

  /// Groups near-identical expenses for insights (same project/merchant/amount/day).
  List<List<Expense>> findRepeatGroups(List<Expense> expenses) {
    final used = <String>{};
    final groups = <List<Expense>>[];

    for (var i = 0; i < expenses.length; i++) {
      final a = expenses[i];
      if (used.contains(a.id)) continue;

      final group = <Expense>[a];
      for (var j = i + 1; j < expenses.length; j++) {
        final b = expenses[j];
        if (used.contains(b.id)) continue;
        final matches = findMatches(
          candidates: [b],
          projectId: a.projectId,
          merchant: a.merchant,
          amount: a.amount,
          date: a.date,
          dayWindow: 1,
          amountTolerance: 0.01,
        );
        if (matches.isNotEmpty) {
          group.add(b);
          used.add(b.id);
        }
      }

      if (group.length >= 2) {
        used.add(a.id);
        groups.add(group);
      }
    }

    groups.sort((a, b) => b.length.compareTo(a.length));
    return groups;
  }

  double _merchantSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.contains(b) || b.contains(a)) return 0.9;

    final aTokens = a.split(' ').where((t) => t.length > 1).toSet();
    final bTokens = b.split(' ').where((t) => t.length > 1).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0.0;

    final overlap = aTokens.intersection(bTokens).length;
    final union = aTokens.union(bTokens).length;
    return union == 0 ? 0.0 : overlap / union;
  }

  String _reason({
    required int dayDiff,
    required double amountDiff,
    required double merchantSimilar,
  }) {
    final parts = <String>[];
    if (merchantSimilar >= 0.95) {
      parts.add('same merchant');
    } else {
      parts.add('similar merchant');
    }
    if (amountDiff <= 0.01) {
      parts.add('same amount');
    } else {
      parts.add('almost same amount');
    }
    if (dayDiff == 0) {
      parts.add('same day');
    } else {
      parts.add('within $dayDiff day(s)');
    }
    return parts.join(' · ');
  }
}
