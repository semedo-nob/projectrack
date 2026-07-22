// lib/ui/receipts/receipt_upload.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projectrack1/constants/models/projects_model.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../service/expense_duplicate_service.dart';
import '../../service/receipt_validation_service.dart';

class ReceiptOcrScreen extends StatefulWidget {
  final String? initialImagePath;
  final String? initialProjectId;
  final String? projectId;
  final String? projectName;
  final String? expenseId;
  final String? initialMerchant;
  final double? initialAmount;
  final String? initialDate;
  final String? initialNotes;

  const ReceiptOcrScreen({
    super.key,
    this.initialImagePath,
    this.initialProjectId,
    this.projectId,
    this.projectName,
    this.expenseId,
    this.initialMerchant,
    this.initialAmount,
    this.initialDate,
    this.initialNotes,
  });

  @override
  State<ReceiptOcrScreen> createState() => _ReceiptOcrScreenState();
}

class _ReceiptOcrScreenState extends State<ReceiptOcrScreen> {
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Project> _projects = [];
  String? _selectedProjectId;
  String? _imagePath;
  bool _isProcessing = false;
  bool _isSaving = false;
  double? _ocrConfidence;
  String? _ocrErrorMessage;
  bool _isValidReceipt = false;
  bool _manualOverride = false;
  ReceiptValidationResult? _validationResult;
  String? _ocrRawText;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static const _validationService = ReceiptValidationService();
  static const _duplicateService = ExpenseDuplicateService();
  DateTime _receiptDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
      if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
        _imagePath = widget.initialImagePath;
        _runOcr(widget.initialImagePath!);
      }
      if (widget.initialProjectId != null) {
        _selectedProjectId = widget.initialProjectId;
      }
      if (widget.initialMerchant != null && widget.initialMerchant!.isNotEmpty) {
        _merchantController.text = widget.initialMerchant!;
      }
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(2);
      }
      if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
        _notesController.text = widget.initialNotes!;
      }
      if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
        try {
          final parsed = DateTime.parse(widget.initialDate!);
          _receiptDateTime = parsed;
          _dateController.text = _validationService.formatParsedDate(
            parsed,
            includeTime: true,
          );
        } catch (_) {
          final parsed = _validationService.parseUserDateTime(widget.initialDate!);
          if (parsed != null) {
            _receiptDateTime = parsed;
            _dateController.text = _validationService.formatParsedDate(parsed);
          } else {
            _dateController.text = widget.initialDate!;
          }
        }
      } else if (_dateController.text.isEmpty) {
        _receiptDateTime = DateTime.now();
        _dateController.text = _validationService.formatParsedDate(
          _receiptDateTime,
          includeTime: true,
        );
      }
      if (widget.expenseId != null &&
          widget.initialImagePath != null &&
          widget.initialImagePath!.isNotEmpty) {
        _isValidReceipt = true;
        _manualOverride = false;
      }
    });
  }

  Future<void> _loadProjects() async {
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final list = await db.getAllProjects();
    if (!mounted) return;
    setState(() {
      _projects = list;
      if (_selectedProjectId == null && list.isNotEmpty) {
        _selectedProjectId = list.first.id;
      }
      if (widget.initialProjectId != null && list.any((p) => p.id == widget.initialProjectId)) {
        _selectedProjectId = widget.initialProjectId;
      }
    });
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted && mounted) {
        _showPermissionDialog();
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    } else if (status.isGranted) {
      _pickCamera();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'Camera access is needed to scan receipts. '
                'Please enable it in settings to continue.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCamera() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ImagePicker picker = ImagePicker();
      final XFile? image = await auth.runWithoutBiometricLock(
        () => picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        ),
      );
      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
          _ocrConfidence = null;
          _ocrErrorMessage = null;
          _isValidReceipt = false;
          _manualOverride = false;
          _validationResult = null;
          _ocrRawText = null;
        });
        _runOcr(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickGallery() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ImagePicker picker = ImagePicker();
      final XFile? image = await auth.runWithoutBiometricLock(
        () => picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        ),
      );
      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
          _ocrConfidence = null;
          _ocrErrorMessage = null;
          _isValidReceipt = false;
          _manualOverride = false;
          _validationResult = null;
          _ocrRawText = null;
        });
        _runOcr(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _applyValidationResult(ReceiptValidationResult result) {
    _validationResult = result;
    _isValidReceipt = result.isValid;
    _ocrConfidence = result.confidence;

    final parsed = result.parsed;
    if (parsed.amount != null) {
      _amountController.text = parsed.amount!.toStringAsFixed(2);
    }
    if (parsed.date != null) {
      _receiptDateTime = parsed.date!;
      _dateController.text = _validationService.formatParsedDate(
        parsed.date!,
        includeTime: parsed.hasTime,
      );
    }
    if (parsed.merchant != null && _merchantController.text.isEmpty) {
      _merchantController.text = parsed.merchant!;
    }
  }

  Future<void> _runOcr(String path) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _ocrErrorMessage = null;
      _isValidReceipt = false;
      _manualOverride = false;
    });

    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;
      _ocrRawText = text;

      if (!mounted) return;

      final result = _validationService.validate(text);

      setState(() {
        _isProcessing = false;
        _applyValidationResult(result);
      });

      if (result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_validationService.tierMessage(result.tier)} (${(result.confidence * 100).toInt()}% confidence)',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result.allowManualOverride) {
        setState(() {
          _ocrErrorMessage = _validationService.tierMessage(result.tier);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_validationService.tierMessage(result.tier)),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _ocrErrorMessage = result.rejectionReason ??
              _validationService.tierMessage(result.tier);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ocrErrorMessage!),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isValidReceipt = false;
        _ocrErrorMessage = 'OCR failed: ${e.toString().substring(0, min(50, e.toString().length))}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR failed. Please try again with a clearer image.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool get _canSave =>
      !_isProcessing &&
      !_isSaving &&
      (_isValidReceipt || _manualOverride) &&
      _imagePath != null;

  Future<void> _confirmManualSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save without full validation?'),
        content: const Text(
          'This receipt could not be fully verified automatically. '
          'Only save if you have checked the merchant, date, and amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _manualOverride = true);
      await _saveExpense();
    }
  }

  Future<void> _pickReceiptDateTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _receiptDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_receiptDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? _receiptDateTime.hour,
      pickedTime?.minute ?? _receiptDateTime.minute,
    );
    setState(() {
      _receiptDateTime = combined;
      _dateController.text = _validationService.formatParsedDate(
        combined,
        includeTime: true,
      );
    });
  }

  Future<bool> _confirmDuplicatesIfNeeded({
    required String merchant,
    required double amount,
    required DateTime expenseDate,
  }) async {
    if (widget.expenseId != null) return true;
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final existing = await db.getExpensesByProject(_selectedProjectId!);
    final matches = _duplicateService.findMatches(
      candidates: existing,
      projectId: _selectedProjectId!,
      merchant: merchant,
      amount: amount,
      date: expenseDate,
    );
    if (matches.isEmpty || !mounted) return true;

    final top = matches.take(3).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          matches.length == 1
              ? 'Possible duplicate receipt'
              : '${matches.length} similar receipts found',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This looks like a purchase you may have logged already '
              '(same/similar merchant, amount, and date).',
            ),
            const SizedBox(height: 12),
            ...top.map((m) {
              final e = m.expense;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${e.merchant} · ${e.formattedAmount} · ${e.formattedDate}\n'
                  '  ${(m.similarity * 100).round()}% match · ${m.reason}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _saveExpense() async {
    // Validate inputs
    if (_selectedProjectId == null || _projects.isEmpty) {
      _showError('Please select a project.');
      return;
    }

    if (!_isValidReceipt && !_manualOverride) {
      if (_validationResult?.allowManualOverride == true) {
        await _confirmManualSave();
        return;
      }
      _showError('This does not appear to be a valid receipt. Please capture a proper receipt image.');
      return;
    }

    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      _showError('Please enter merchant name.');
      return;
    }

    final amountStr = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    if (_imagePath == null || _imagePath!.isEmpty) {
      _showError('Please capture or select a receipt image.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save image to app documents
      final docDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${docDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      String storedPath;
      if (widget.expenseId != null &&
          widget.initialImagePath != null &&
          _imagePath == widget.initialImagePath) {
        storedPath = _imagePath!;
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'receipt_${_selectedProjectId}_$timestamp.jpg';
        storedPath = '${receiptsDir.path}/$fileName';
        await File(_imagePath!).copy(storedPath);
      }

      // Parse date + time from field (or picker state)
      DateTime expenseDate = _receiptDateTime;
      final parsedDate =
          _validationService.parseUserDateTime(_dateController.text.trim());
      if (parsedDate != null) {
        expenseDate = parsedDate;
        _receiptDateTime = parsedDate;
      }

      final shouldContinue = await _confirmDuplicatesIfNeeded(
        merchant: merchant,
        amount: amount,
        expenseDate: expenseDate,
      );
      if (!shouldContinue) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // Generate unique ID or reuse existing for edit
      final id = widget.expenseId ?? 'exp_${DateTime.now().millisecondsSinceEpoch}';
      final status = _manualOverride ? 'pending_review' : 'logged';
      final loggedAt = DateTime.now();
      final notesBase = _notesController.text.trim().isEmpty
          ? (_manualOverride ? 'Manually verified receipt' : 'Scanned receipt')
          : _notesController.text.trim();
      final notes =
          '$notesBase · logged ${DateFormat('MMM d, yyyy h:mm a').format(loggedAt)}';

      // Save to database
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final ok = widget.expenseId != null
          ? await db.updateExpense(
              id: id,
              merchant: merchant,
              amount: amount,
              date: expenseDate,
              notes: notes,
              receiptImage: storedPath,
              status: status,
              ocrData: _ocrRawText,
              ocrConfidence: _ocrConfidence,
            )
          : await db.createExpense(
              id: id,
              projectId: _selectedProjectId!,
              merchant: merchant,
              amount: amount,
              date: expenseDate,
              category: 'Receipt',
              notes: notes,
              receiptImage: storedPath,
              status: status,
              ocrData: _ocrRawText,
              ocrConfidence: _ocrConfidence,
            );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expenseId != null
                  ? 'Expense updated successfully!'
                  : 'Expense saved successfully!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to home after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go(AppRoutes.home);
        });
      } else {
        _showError(db.error ?? 'Failed to save expense.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error saving: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _merchantController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.8),
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.appBarTheme.foregroundColor,
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  widget.expenseId != null ? 'Edit Receipt' : 'Scan Receipt',
                  style: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),

              // Image section
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Receipt Image',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_imagePath != null && !_isProcessing)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isValidReceipt
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isValidReceipt ? Icons.check_circle : Icons.warning_amber_rounded,
                                    color: _isValidReceipt ? AppColors.success : AppColors.warning,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isValidReceipt ? 'Valid Receipt' : 'Not Valid',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isValidReceipt ? AppColors.success : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptImage(isDark),
                    ],
                  ),
                ),
              ),

              // Validation Results
              if (_validationResult != null && !_isProcessing)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildValidationResults(isDark),
                  ),
                ),

              // Form section
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Extracted Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_ocrConfidence != null && !_isProcessing && _isValidReceipt)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_ocrConfidence! * 100).toInt()}% confident',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_ocrErrorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _ocrErrorMessage!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildFormFields(isDark, currency),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // Bottom button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResults(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isValidReceipt ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt Validation',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _isValidReceipt ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          ..._validationResult!.signals.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                    color: entry.value ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationService.signalLabel(entry.key),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReceiptImage(bool isDark) {
    return GestureDetector(
      onTap: _imagePath != null ? () => _showFullScreenImage() : null,
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border.all(
            color: _isValidReceipt
                ? AppColors.success
                : (_imagePath != null ? AppColors.warning : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            width: _isValidReceipt ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (_imagePath != null && File(_imagePath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePath!),
                  fit: BoxFit.cover,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap camera or gallery to add receipt',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Processing overlay
            if (_isProcessing)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black54,
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Reading receipt...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

            // Camera/Gallery buttons
            if (!_isProcessing && _imagePath == null)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      isDark: isDark,
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: _pickGallery,
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      isDark: isDark,
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: _checkCameraPermission,
                      isPrimary: true,
                    ),
                  ],
                ),
              ),

            // Retry button for invalid receipt
            if (!_isProcessing && _imagePath != null && !_isValidReceipt)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildActionButton(
                    isDark: isDark,
                    icon: Icons.refresh_rounded,
                    label: 'Try Different Image',
                    onTap: () {
                      setState(() {
                        _imagePath = null;
                        _isValidReceipt = false;
                        _validationResult = null;
                        _merchantController.clear();
                        _amountController.clear();
                      });
                    },
                    isPrimary: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black87),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.black : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                File(_imagePath!),
                fit: BoxFit.contain,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(bool isDark, CurrencyProvider currency) {
    return Column(
      children: [
        _buildTextField(
          isDark: isDark,
          label: 'Merchant Name',
          controller: _merchantController,
          hint: 'Enter merchant name',
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeField(isDark),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildProjectDropdown(isDark)),
          ],
        ),
        const SizedBox(height: 16),
        _buildAmountField(isDark, currency),
        const SizedBox(height: 16),
        _buildTextField(
          isDark: isDark,
          label: 'Notes (Optional)',
          controller: _notesController,
          hint: 'Add notes...',
          maxLines: 2,
          icon: Icons.note_alt_rounded,
        ),
      ],
    );
  }

  Widget _buildDateTimeField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Receipt date & time',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        TextField(
          controller: _dateController,
          readOnly: true,
          onTap: _pickReceiptDateTime,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'MMM DD, YYYY h:mm a',
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.event_available_rounded, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.edit_calendar_rounded, size: 20),
              onPressed: _pickReceiptDateTime,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              fontSize: 14,
            ),
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Project',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProjectId,
              isExpanded: true,
              hint: Text(
                'Select project',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
              items: _projects.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (String? id) {
                setState(() => _selectedProjectId = id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(bool isDark, CurrencyProvider currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixText: '${currency.symbol} ',
            prefixStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            hintText: '0.00',
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0),
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
          ],
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _canSave
                ? _saveExpense
                : (_validationResult?.allowManualOverride == true && !_isProcessing && !_isSaving
                    ? _confirmManualSave
                    : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
            child: _isSaving
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _canSave
                      ? Icons.save_rounded
                      : (_validationResult?.allowManualOverride == true
                          ? Icons.warning_rounded
                          : Icons.warning_rounded),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _canSave
                      ? (widget.expenseId != null ? 'Update Expense' : 'Save Expense')
                      : (_validationResult?.allowManualOverride == true
                          ? 'Review & Save'
                          : 'Invalid Receipt'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}