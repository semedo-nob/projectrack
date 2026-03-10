// lib/models/expense_model.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../database/database.dart' as db;
import '../../themes/app_colors.dart';

// ===== DRIFT COMPANION CLASS FOR DATABASE OPERATIONS =====
/// This class is used for database operations with Drift
class ExpenseCompanion extends drift.Insertable<Expense> {
  final drift.Value<String> id;
  final drift.Value<String> projectId;
  final drift.Value<String> merchant;
  final drift.Value<double> amount;
  final drift.Value<DateTime> date;
  final drift.Value<String> category;
  final drift.Value<String?> notes;
  final drift.Value<String?> receiptImage;
  final drift.Value<String> status;
  final drift.Value<DateTime> createdAt;
  final drift.Value<DateTime> updatedAt;

  ExpenseCompanion({
    required this.id,
    required this.projectId,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.notes = const drift.Value.absent(),
    this.receiptImage = const drift.Value.absent(),
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<String>(id.value);
    map['project_id'] = drift.Variable<String>(projectId.value);
    map['merchant'] = drift.Variable<String>(merchant.value);
    map['amount'] = drift.Variable<double>(amount.value);
    map['date'] = drift.Variable<DateTime>(date.value);
    map['category'] = drift.Variable<String>(category.value);
    if (notes.present) map['notes'] = drift.Variable<String>(notes.value);
    if (receiptImage.present) map['receipt_image'] = drift.Variable<String>(receiptImage.value);
    map['status'] = drift.Variable<String>(status.value);
    map['created_at'] = drift.Variable<DateTime>(createdAt.value);
    map['updated_at'] = drift.Variable<DateTime>(updatedAt.value);
    return map;
  }

  // Factory constructor for creating a new expense
  factory ExpenseCompanion.insert({
    required String id,
    required String projectId,
    required String merchant,
    required double amount,
    required DateTime date,
    required String category,
    String? notes,
    String? receiptImage,
    required String status,
  }) {
    final now = DateTime.now();
    return ExpenseCompanion(
      id: drift.Value(id),
      projectId: drift.Value(projectId),
      merchant: drift.Value(merchant),
      amount: drift.Value(amount),
      date: drift.Value(date),
      category: drift.Value(category),
      notes: drift.Value(notes),
      receiptImage: drift.Value(receiptImage),
      status: drift.Value(status),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );
  }

  // Factory constructor for updating an existing expense
  factory ExpenseCompanion.update({
    required String id,
    String? projectId,
    String? merchant,
    double? amount,
    DateTime? date,
    String? category,
    String? notes,
    String? receiptImage,
    String? status,
  }) {
    final now = DateTime.now();
    return ExpenseCompanion(
      id: drift.Value(id),
      projectId: drift.Value(projectId ?? ''), // Will be ignored in update
      merchant: drift.Value(merchant ?? ''),
      amount: drift.Value(amount ?? 0),
      date: drift.Value(date ?? DateTime.now()),
      category: drift.Value(category ?? ''),
      notes: drift.Value(notes),
      receiptImage: drift.Value(receiptImage),
      status: drift.Value(status ?? ''),
      createdAt: const drift.Value.absent(), // Don't update createdAt
      updatedAt: drift.Value(now),
    );
  }
}

// ===== EXPENSE STATUS ENUM =====
enum ExpenseStatus {
  pending,
  verified,
  rejected,
  missing;

  String get displayName {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.verified:
        return 'Verified';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.missing:
        return 'Missing Receipt';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseStatus.pending:
        return AppColors.warning;
      case ExpenseStatus.verified:
        return AppColors.success;
      case ExpenseStatus.rejected:
        return AppColors.error;
      case ExpenseStatus.missing:
        return AppColors.error;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ExpenseStatus.pending:
        return AppColors.warning.withOpacity(0.1);
      case ExpenseStatus.verified:
        return AppColors.success.withOpacity(0.1);
      case ExpenseStatus.rejected:
        return AppColors.error.withOpacity(0.1);
      case ExpenseStatus.missing:
        return AppColors.error.withOpacity(0.1);
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseStatus.pending:
        return Icons.hourglass_empty_rounded;
      case ExpenseStatus.verified:
        return Icons.check_circle_rounded;
      case ExpenseStatus.rejected:
        return Icons.cancel_rounded;
      case ExpenseStatus.missing:
        return Icons.receipt_rounded;
    }
  }

  static ExpenseStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ExpenseStatus.pending;
      case 'verified':
        return ExpenseStatus.verified;
      case 'rejected':
        return ExpenseStatus.rejected;
      case 'missing':
      case 'missing receipt':
        return ExpenseStatus.missing;
      default:
        return ExpenseStatus.pending;
    }
  }
}

// ===== EXPENSE CATEGORY ENUM =====
enum ExpenseCategory {
  materials,
  labor,
  equipment,
  travel,
  permits,
  supplies,
  marketing,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.materials:
        return 'Materials';
      case ExpenseCategory.labor:
        return 'Labor';
      case ExpenseCategory.equipment:
        return 'Equipment';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.permits:
        return 'Permits & Fees';
      case ExpenseCategory.supplies:
        return 'Office Supplies';
      case ExpenseCategory.marketing:
        return 'Marketing';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.materials:
        return AppColors.primary;
      case ExpenseCategory.labor:
        return AppColors.secondary;
      case ExpenseCategory.equipment:
        return AppColors.info;
      case ExpenseCategory.travel:
        return AppColors.warning;
      case ExpenseCategory.permits:
        return AppColors.error;
      case ExpenseCategory.supplies:
        return AppColors.success;
      case ExpenseCategory.marketing:
        return Colors.purple;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.materials:
        return Icons.inventory_2_rounded;
      case ExpenseCategory.labor:
        return Icons.construction_rounded;
      case ExpenseCategory.equipment:
        return Icons.precision_manufacturing_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.permits:
        return Icons.description_rounded;
      case ExpenseCategory.supplies:
        return Icons.inventory_rounded;
      case ExpenseCategory.marketing:
        return Icons.campaign_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  static ExpenseCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'materials':
      case 'construction materials':
        return ExpenseCategory.materials;
      case 'labor':
        return ExpenseCategory.labor;
      case 'equipment':
      case 'equipment rental':
        return ExpenseCategory.equipment;
      case 'travel':
        return ExpenseCategory.travel;
      case 'permits':
      case 'permits & fees':
        return ExpenseCategory.permits;
      case 'supplies':
      case 'office supplies':
        return ExpenseCategory.supplies;
      case 'marketing':
        return ExpenseCategory.marketing;
      default:
        return ExpenseCategory.other;
    }
  }
}

// ===== MAIN EXPENSE MODEL =====
class Expense {
  final String id;
  final String projectId;
  final String merchant;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? notes;
  final String? receiptImage;
  final ExpenseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.projectId,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
    this.receiptImage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convenience constructor with string category/status
  factory Expense.withStrings({
    required String id,
    required String projectId,
    required String merchant,
    required double amount,
    required DateTime date,
    required String category,
    String? notes,
    String? receiptImage,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Expense(
      id: id,
      projectId: projectId,
      merchant: merchant,
      amount: amount,
      date: date,
      category: ExpenseCategory.fromString(category),
      notes: notes,
      receiptImage: receiptImage,
      status: ExpenseStatus.fromString(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Calculated getters
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  bool get hasReceipt => receiptImage != null && receiptImage!.isNotEmpty;

  bool get isVerified => status == ExpenseStatus.verified;

  bool get isPending => status == ExpenseStatus.pending;

  bool get isMissingReceipt => status == ExpenseStatus.missing;

  // Convert to JSON for API calls or sharing
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'merchant': merchant,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.displayName,
      'notes': notes,
      'receiptImage': receiptImage,
      'status': status.displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense.withStrings(
      id: json['id'],
      projectId: json['projectId'],
      merchant: json['merchant'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      category: json['category'],
      notes: json['notes'],
      receiptImage: json['receiptImage'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Create from Drift database row
  factory Expense.fromDrift(db.Expense data) {
    return Expense.withStrings(
      id: data.id,
      projectId: data.projectId,
      merchant: data.merchant,
      amount: data.amount,
      date: data.date,
      category: data.category,
      notes: data.notes,
      receiptImage: data.receiptImage,
      status: data.status,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  // Create a copy with updated fields
  Expense copyWith({
    String? merchant,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    String? notes,
    String? receiptImage,
    ExpenseStatus? status,
  }) {
    return Expense(
      id: id,
      projectId: projectId,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      receiptImage: receiptImage ?? this.receiptImage,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Mock data generator for UI testing
  static List<Expense> getMockExpenses(String projectId) {
    final now = DateTime.now();
    return [
      Expense.withStrings(
        id: 'exp1',
        projectId: projectId,
        merchant: 'Home Depot',
        amount: 1240.00,
        date: DateTime(now.year, now.month, now.day - 2),
        category: 'Materials',
        notes: 'Lumber and plywood for framing',
        receiptImage: 'receipt1.jpg',
        status: 'verified',
        createdAt: now,
        updatedAt: now,
      ),
      Expense.withStrings(
        id: 'exp2',
        projectId: projectId,
        merchant: 'ABC Supply',
        amount: 4850.00,
        date: DateTime(now.year, now.month, now.day - 5),
        category: 'Materials',
        notes: 'Roofing materials',
        receiptImage: 'receipt2.jpg',
        status: 'verified',
        createdAt: now,
        updatedAt: now,
      ),
      Expense.withStrings(
        id: 'exp3',
        projectId: projectId,
        merchant: 'Local Hardware',
        amount: 85.42,
        date: DateTime(now.year, now.month, now.day - 1),
        category: 'Supplies',
        notes: 'Screws and fasteners',
        receiptImage: null,
        status: 'missing',
        createdAt: now,
        updatedAt: now,
      ),
      Expense.withStrings(
        id: 'exp4',
        projectId: projectId,
        merchant: 'Starbucks',
        amount: 24.50,
        date: DateTime(now.year, now.month, now.day),
        category: 'Other',
        notes: 'Client meeting coffee',
        receiptImage: 'receipt4.jpg',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      ),
      Expense.withStrings(
        id: 'exp5',
        projectId: projectId,
        merchant: 'Tool Rental Co',
        amount: 450.00,
        date: DateTime(now.year, now.month, now.day - 3),
        category: 'Equipment',
        notes: 'Concrete mixer rental - 3 days',
        receiptImage: 'receipt5.jpg',
        status: 'verified',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  // Group expenses by category for charts
  static Map<ExpenseCategory, double> groupByCategory(List<Expense> expenses) {
    final Map<ExpenseCategory, double> result = {};
    for (var expense in expenses) {
      result[expense.category] = (result[expense.category] ?? 0) + expense.amount;
    }
    return result;
  }

  // Get total amount
  static double getTotalAmount(List<Expense> expenses) {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  // Filter by status
  static List<Expense> filterByStatus(List<Expense> expenses, ExpenseStatus status) {
    return expenses.where((e) => e.status == status).toList();
  }

  // Filter by date range
  static List<Expense> filterByDateRange(
      List<Expense> expenses, {
        required DateTime start,
        required DateTime end,
      }) {
    return expenses.where((e) =>
    e.date.isAfter(start.subtract(const Duration(days: 1))) &&
        e.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }
}