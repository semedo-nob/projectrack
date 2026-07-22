import 'package:intl/intl.dart';

/// How confidently OCR text looks like a real receipt.
enum ReceiptValidationTier {
  strong,
  probable,
  weak,
  rejected,
}

class ParsedReceiptData {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final bool hasTime;

  const ParsedReceiptData({
    this.amount,
    this.date,
    this.merchant,
    this.hasTime = false,
  });
}

class ReceiptValidationResult {
  final ReceiptValidationTier tier;
  final double confidence;
  final Map<String, bool> signals;
  final String? rejectionReason;
  final ParsedReceiptData parsed;

  const ReceiptValidationResult({
    required this.tier,
    required this.confidence,
    required this.signals,
    this.rejectionReason,
    required this.parsed,
  });

  /// Auto-accepted without user confirmation.
  bool get isValid =>
      tier == ReceiptValidationTier.strong ||
      tier == ReceiptValidationTier.probable;

  /// User may confirm save when OCR is ambiguous but not clearly wrong.
  bool get allowManualOverride =>
      tier == ReceiptValidationTier.probable ||
      tier == ReceiptValidationTier.weak;
}

/// Shared receipt OCR validation and field extraction.
///
/// Uses a scoring model so varied receipt layouts (thermal, invoice, POS,
/// construction supplier) can pass while obvious non-receipt images are rejected.
class ReceiptValidationService {
  const ReceiptValidationService();

  static const _receiptKeywords = [
    'receipt', 'invoice', 'bill', 'purchase', 'sale', 'payment', 'paid',
    'total', 'amount', 'subtotal', 'sub total', 'tax', 'vat', 'gst',
    'cash', 'change', 'balance', 'due', 'grand total', 'net total',
    'thank you', 'thanks', 'store', 'merchant', 'customer', 'order',
    'transaction', 'trans', 'card', 'visa', 'mastercard', 'amex', 'debit',
    'credit', 'cashier', 'register', 'terminal', 'authorization', 'auth',
    'qty', 'quantity', 'item', 'sku', 'ref', 'reference', 'invoice no',
    'receipt no', 'ticket', 'copy', 'original', 'supplier', 'vendor',
    'materials', 'hardware', 'lumber', 'concrete', 'delivery', 'po ',
    'purchase order', 'estimate', 'quote',
  ];

  static const _strongRejectionKeywords = [
    'selfie', 'profile picture', 'photo of me', 'my picture',
    'instagram', 'facebook', 'snapchat', 'tiktok', 'meme', 'wallpaper',
    'screenshot', 'screen capture',
  ];

  static const _commonMerchants = [
    'Walmart', 'Target', 'Costco', 'Home Depot', "Lowe's", 'Menards',
    'Ace Hardware', 'Starbucks', "McDonald's", 'Amazon', 'Uber', 'Lyft',
    'Shell', 'Exxon', 'CVS', 'Walgreens', 'Kroger', 'Safeway',
    'Whole Foods', "Trader Joe's", 'Best Buy', 'Apple Store',
    'Office Depot', 'Staples', 'Bunnings', 'Buildbase', 'Travis Perkins',
    'Jewson', 'Screwfix', 'Wickes', 'B&Q', 'IKEA', 'Carrefour', 'Tesco',
    'Lidl', 'Aldi', 'OBI', 'Hornbach', 'Bauhaus',
  ];

  static final _datePatterns = [
    RegExp(r'date:?\s*\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}', caseSensitive: false),
    RegExp(r'transaction\s+date:?\s*\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}', caseSensitive: false),
    RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}'),
    RegExp(r'\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2}'),
    RegExp(r'\w{3,9}\s+\d{1,2},?\s*\d{4}', caseSensitive: false),
    RegExp(r'\d{1,2}\s+\w{3,9}\s+\d{4}', caseSensitive: false),
  ];

  static final _amountPatterns = [
    RegExp(
      r'(?:total|amount|sum|balance|due|price|cost|grand total|amount due|net|subtotal|sub total|paid)[\s:]*[\$€£₹¥₦₩₱₨₪₴₵₸]?[\s]*[\d,]+\.?\d{0,2}',
      caseSensitive: false,
    ),
    RegExp(r'[\$€£₹¥₦₩₱₨₪₴₵₸]\s*[\d,]+\.\d{2}'),
    RegExp(r'[\d,]+\.\d{2}\s*(?:USD|EUR|GBP|KES|CAD|AUD|INR)?', caseSensitive: false),
  ];

  static final _currencyPattern = RegExp(r'[\$€£₹¥₦₩₱₨₪₴₵₸]|(?:USD|EUR|GBP|KES|CAD|AUD|INR)\b', caseSensitive: false);
  static final _lineItemPattern = RegExp(r'\d+\s*[xX×]\s*[\d,]+\.?\d*|[\d,]+\.?\d*\s*@\s*[\d,]+\.?\d*');
  static final _timePattern = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\b');
  static final _transactionIdPattern = RegExp(
    r'(?:trans(?:action)?|ref(?:erence)?|receipt|invoice|order|ticket|auth)\s*(?:#|no\.?|num(?:ber)?\.?|:)?\s*[A-Z0-9\-]{4,}',
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(r'(?:\+?\d{1,3}[\s\-]?)?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}');

  ReceiptValidationResult validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ReceiptValidationResult(
        tier: ReceiptValidationTier.rejected,
        confidence: 0,
        signals: const {'hasText': false},
        rejectionReason: 'No text detected in image.',
        parsed: const ParsedReceiptData(),
      );
    }

    final lowerText = trimmed.toLowerCase();
    final signals = <String, bool>{};

    for (final keyword in _strongRejectionKeywords) {
      if (lowerText.contains(keyword)) {
        return ReceiptValidationResult(
          tier: ReceiptValidationTier.rejected,
          confidence: 0,
          signals: {'rejectionKeyword': true},
          rejectionReason: 'Image appears to be a photo or screenshot, not a receipt.',
          parsed: const ParsedReceiptData(),
        );
      }
    }

    var keywordCount = 0;
    for (final keyword in _receiptKeywords) {
      if (lowerText.contains(keyword)) keywordCount++;
    }
    signals['receiptKeywords'] = keywordCount >= 1;
    signals['multipleReceiptKeywords'] = keywordCount >= 2;

    signals['hasDate'] = _datePatterns.any((p) => p.hasMatch(trimmed));
    signals['hasAmount'] = _amountPatterns.any((p) => p.hasMatch(trimmed));
    signals['hasCurrency'] = _currencyPattern.hasMatch(trimmed);

    final numberCount = RegExp(r'\d+').allMatches(trimmed).length;
    signals['hasNumbers'] = numberCount >= 4;
    signals['hasManyNumbers'] = numberCount >= 8;

    final lineCount = trimmed.split('\n').where((l) => l.trim().isNotEmpty).length;
    signals['hasMultipleLines'] = lineCount >= 3;
    signals['hasStructuredLines'] = lineCount >= 6;

    signals['hasMerchant'] = _commonMerchants.any(
      (m) => lowerText.contains(m.toLowerCase()),
    );
    signals['hasLineItems'] = _lineItemPattern.hasMatch(trimmed);
    signals['hasTime'] = _timePattern.hasMatch(trimmed);
    signals['hasTransactionId'] = _transactionIdPattern.hasMatch(trimmed);
    signals['hasPhone'] = _phonePattern.hasMatch(trimmed);

    final score = _computeScore(signals, keywordCount);
    final tier = _tierFromScore(score);
    final confidence = (score / 14).clamp(0.0, 1.0);
    final parsed = _parse(trimmed);

    // Minimal thermal receipt: short but has amount + (date or numbers).
    final minimalReceipt = (signals['hasAmount'] ?? false) &&
        ((signals['hasDate'] ?? false) || (signals['hasManyNumbers'] ?? false)) &&
        lineCount >= 2;

    final effectiveTier = minimalReceipt && tier == ReceiptValidationTier.weak
        ? ReceiptValidationTier.probable
        : tier;

    return ReceiptValidationResult(
      tier: effectiveTier,
      confidence: confidence,
      signals: signals,
      parsed: parsed,
    );
  }

  int _computeScore(Map<String, bool> signals, int keywordCount) {
    var score = 0;
    score += keywordCount.clamp(0, 3);
    if (signals['hasDate'] == true) score += 2;
    if (signals['hasAmount'] == true) score += 3;
    if (signals['hasCurrency'] == true) score += 2;
    if (signals['hasNumbers'] == true) score += 1;
    if (signals['hasManyNumbers'] == true) score += 1;
    if (signals['hasMultipleLines'] == true) score += 1;
    if (signals['hasStructuredLines'] == true) score += 1;
    if (signals['hasMerchant'] == true) score += 2;
    if (signals['hasLineItems'] == true) score += 2;
    if (signals['hasTime'] == true) score += 1;
    if (signals['hasTransactionId'] == true) score += 1;
    if (signals['hasPhone'] == true) score += 1;
    return score;
  }

  ReceiptValidationTier _tierFromScore(int score) {
    if (score >= 9) return ReceiptValidationTier.strong;
    if (score >= 6) return ReceiptValidationTier.probable;
    if (score >= 3) return ReceiptValidationTier.weak;
    return ReceiptValidationTier.rejected;
  }

  ParsedReceiptData _parse(String text) {
    final lines = text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final date = _parseDate(lines);
    final time = _parseTime(lines);
    DateTime? combined = date;
    var hasTime = false;
    if (date != null && time != null) {
      combined = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
      );
      hasTime = true;
    }

    return ParsedReceiptData(
      amount: _parseAmount(lines),
      date: combined,
      merchant: _parseMerchant(lines),
      hasTime: hasTime,
    );
  }

  /// Parses a clock time from receipt OCR lines (e.g. 14:32, 2:32 PM).
  DateTime? _parseTime(List<String> lines) {
    final patterns = [
      RegExp(
        r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\b',
      ),
    ];

    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;
        try {
          var hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          final second = int.tryParse(match.group(3) ?? '') ?? 0;
          final ampm = match.group(4)?.toUpperCase();
          if (minute > 59 || second > 59) continue;
          if (ampm != null) {
            if (hour < 1 || hour > 12) continue;
            if (ampm == 'PM' && hour < 12) hour += 12;
            if (ampm == 'AM' && hour == 12) hour = 0;
          } else if (hour > 23) {
            continue;
          }
          return DateTime(2000, 1, 1, hour, minute, second);
        } catch (_) {}
      }
    }
    return null;
  }

  double? _parseAmount(List<String> lines) {
    final labeledRegex = RegExp(
      r'(?:total|amount|sum|balance|due|price|cost|grand total|amount due|net total|paid)[\s:]*[\$€£₹¥₦₩₱₨₪₴₵₸]?\s*([\d,]+\.?\d{0,2})',
      caseSensitive: false,
    );
    final standaloneRegex = RegExp(
      r'[\$€£₹¥₦₩₱₨₪₴₵₸]\s*([\d,]+\.?\d{0,2})|([\d,]+\.\d{2})\s*$',
    );

    double? bestAmount;
    var bestScore = -1;

    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      final labeled = labeledRegex.firstMatch(line);
      if (labeled != null) {
        final value = _parseNumber(labeled.group(1));
        if (value != null) {
          var score = 5;
          if (lowerLine.contains('grand total') || lowerLine.contains('amount due')) {
            score = 12;
          } else if (RegExp(r'\btotal\b').hasMatch(lowerLine) &&
              !lowerLine.contains('subtotal') &&
              !lowerLine.contains('sub total')) {
            score = 10;
          } else if (lowerLine.contains('paid') || lowerLine.contains('balance')) {
            score = 8;
          }
          if (score > bestScore) {
            bestAmount = value;
            bestScore = score;
          }
        }
      }

      if (bestScore < 3) {
        final standalone = standaloneRegex.firstMatch(line);
        if (standalone != null) {
          final value = _parseNumber(standalone.group(1) ?? standalone.group(2));
          if (value != null) {
            bestAmount = value;
            bestScore = 3;
          }
        }
      }
    }

    return bestAmount;
  }

  double? _parseNumber(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null || value <= 0 || value >= 10000000) return null;
    return value;
  }

  DateTime? _parseDate(List<String> lines) {
    final capturePatterns = [
      RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})'),
      RegExp(r'(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})'),
      RegExp(r'(\w{3,9})\s+(\d{1,2}),?\s*(\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2})\s+(\w{3,9})\s+(\d{4})', caseSensitive: false),
    ];
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];

    for (final line in lines) {
      for (final format in capturePatterns) {
        final match = format.firstMatch(line);
        if (match == null) continue;

        try {
          if (format.pattern.startsWith(r'(\d{4})')) {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            final parsed = DateTime(year, month, day);
            if (_isPlausibleDate(parsed)) return parsed;
            continue;
          }

          if (format.pattern.contains('w{3,9}')) {
            if (format.pattern.startsWith(r'(\w{3,9})')) {
              final monthStr = match.group(1)!.toLowerCase();
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              final month = _monthFromName(monthStr, months);
              if (month != null) {
                final parsed = DateTime(year, month, day);
                if (_isPlausibleDate(parsed)) return parsed;
              }
            } else {
              final day = int.parse(match.group(1)!);
              final monthStr = match.group(2)!.toLowerCase();
              final year = int.parse(match.group(3)!);
              final month = _monthFromName(monthStr, months);
              if (month != null) {
                final parsed = DateTime(year, month, day);
                if (_isPlausibleDate(parsed)) return parsed;
              }
            }
            continue;
          }

          final a = int.parse(match.group(1)!);
          final b = int.parse(match.group(2)!);
          final c = int.parse(match.group(3)!);
          final year = c > 99 ? c : 2000 + c;

          DateTime? parsed;
          if (a > 12) {
            parsed = DateTime(year, b, a);
          } else if (b > 12) {
            parsed = DateTime(year, a, b);
          } else {
            final date1 = DateTime(year, a, b);
            final date2 = DateTime(year, b, a);
            if (_isPlausibleDate(date1)) {
              parsed = date1;
            } else if (_isPlausibleDate(date2)) {
              parsed = date2;
            }
          }
          if (parsed != null && _isPlausibleDate(parsed)) return parsed;
        } catch (_) {}
      }
    }
    return null;
  }

  int? _monthFromName(String monthStr, List<String> months) {
    for (var i = 0; i < months.length; i++) {
      if (months[i].startsWith(monthStr.substring(0, 3.clamp(0, monthStr.length)))) {
        return i + 1;
      }
    }
    return null;
  }

  bool _isPlausibleDate(DateTime date) {
    final now = DateTime.now();
    return date.year >= 2000 &&
        date.year <= now.year + 1 &&
        !date.isAfter(now.add(const Duration(days: 2)));
  }

  String? _parseMerchant(List<String> lines) {
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      for (final merchant in _commonMerchants) {
        if (lowerLine.contains(merchant.toLowerCase())) return merchant;
      }
    }

    for (final line in lines.take(6)) {
      if (_looksLikeMerchantLine(line)) {
        var merchant = line.replaceAll(RegExp(r"[^a-zA-Z0-9\s\.&'\-]"), '').trim();
        if (merchant.length > 50) merchant = merchant.substring(0, 50);
        if (merchant.length >= 2) return merchant;
      }
    }
    return null;
  }

  bool _looksLikeMerchantLine(String line) {
    if (line.length < 2 || line.length > 60) return false;
    if (RegExp(r'^\d+$').hasMatch(line)) return false;
    if (_amountPatterns.any((p) => p.hasMatch(line))) return false;
    if (_datePatterns.any((p) => p.hasMatch(line))) return false;
    if (RegExp(r'^(total|subtotal|tax|change|cash|card|visa|amount)\b', caseSensitive: false).hasMatch(line)) {
      return false;
    }
    final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
    return letterCount >= 2;
  }

  String signalLabel(String key) {
    switch (key) {
      case 'receiptKeywords':
        return 'Contains receipt keywords';
      case 'multipleReceiptKeywords':
        return 'Multiple receipt keywords';
      case 'hasDate':
        return 'Contains date';
      case 'hasAmount':
        return 'Contains amount';
      case 'hasMerchant':
        return 'Contains merchant name';
      case 'hasMultipleLines':
        return 'Has multiple lines';
      case 'hasStructuredLines':
        return 'Structured multi-line layout';
      case 'hasCurrency':
        return 'Contains currency';
      case 'hasNumbers':
        return 'Contains numbers';
      case 'hasManyNumbers':
        return 'Contains many numbers';
      case 'hasLineItems':
        return 'Contains line items';
      case 'hasTime':
        return 'Contains time stamp';
      case 'hasTransactionId':
        return 'Contains transaction/reference ID';
      case 'hasPhone':
        return 'Contains phone number';
      default:
        return key;
    }
  }

  String tierMessage(ReceiptValidationTier tier) {
    switch (tier) {
      case ReceiptValidationTier.strong:
        return 'Receipt detected with high confidence.';
      case ReceiptValidationTier.probable:
        return 'Receipt detected. Please verify the extracted details.';
      case ReceiptValidationTier.weak:
        return 'Possible receipt — review details before saving.';
      case ReceiptValidationTier.rejected:
        return 'This does not appear to be a valid receipt. Try a clearer photo.';
    }
  }

  String formatParsedDate(DateTime date, {bool includeTime = true}) {
    final hasClock = date.hour != 0 || date.minute != 0 || date.second != 0;
    if (includeTime && hasClock) {
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Parses user-entered receipt datetime strings from the OCR form.
  DateTime? parseUserDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final formats = [
      'MMM d, yyyy h:mm a',
      'MMM d, yyyy H:mm',
      'MMM d, yyyy',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ];
    for (final pattern in formats) {
      try {
        return DateFormat(pattern).parseStrict(text);
      } catch (_) {}
    }
    return DateTime.tryParse(text);
  }
}
