// lib/providers/currency_provider.dart
import 'package:flutter/material.dart';
import 'package:projectrack1/database/database.dart' as db;

/// Supported currencies with code and display symbol.
/// Default is KES (Kenyan Shilling).
class CurrencyOption {
  final String code;
  final String symbol;
  final String label;
  const CurrencyOption({required this.code, required this.symbol, required this.label});
}

class CurrencyProvider extends ChangeNotifier {
  static const String _settingsKey = 'currency_code';
  static const String defaultCode = 'KES';

  db.AppDatabase? _database;
  String _currencyCode = defaultCode;
  bool _loaded = false;

  static const List<CurrencyOption> options = [
    CurrencyOption(code: 'KES', symbol: 'KSh', label: 'KES (KSh)'),
    CurrencyOption(code: 'USD', symbol: r'$', label: r'USD ($)'),
    CurrencyOption(code: 'EUR', symbol: '€', label: 'EUR (€)'),
    CurrencyOption(code: 'GBP', symbol: '£', label: 'GBP (£)'),
    CurrencyOption(code: 'JPY', symbol: '¥', label: 'JPY (¥)'),
    CurrencyOption(code: 'CAD', symbol: r'C$', label: r'CAD (C$)'),
  ];

  String get currencyCode => _currencyCode;
  bool get isLoaded => _loaded;

  String get symbol {
    final opt = options.cast<CurrencyOption?>().firstWhere(
      (o) => o?.code == _currencyCode,
      orElse: () => options.first,
    );
    return opt?.symbol ?? 'KSh';
  }

  String get displayLabel {
    final opt = options.cast<CurrencyOption?>().firstWhere(
      (o) => o?.code == _currencyCode,
      orElse: () => options.first,
    );
    return opt?.label ?? 'KES (KSh)';
  }

  void setDatabase(db.AppDatabase database) {
    _database = database;
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_database == null) return;
    try {
      final value = await _database!.getSetting(_settingsKey);
      if (value != null && value.isNotEmpty) {
        _currencyCode = value;
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    if (_currencyCode == code) return;
    _currencyCode = code;
    if (_database != null) {
      try {
        await _database!.insertOrUpdateSetting(_settingsKey, code);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Format amount with current currency symbol (e.g. "KSh 1,234.56").
  String format(double amount) {
    final sym = symbol;
    final str = amount.toStringAsFixed(2);
    return '$sym $str';
  }
}
