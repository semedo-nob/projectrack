// lib/ui/projects/daily_material_entry_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../service/inventory_service.dart';
import '../../service/smart_unit_suggestion_service.dart';
import '../../service/receipt_validation_service.dart';
import '../../service/unit_service.dart';

class MaterialEntry {
  String materialName;
  double quantity;
  /// [UnitOption.id] from [UnitService.all].
  String unitId;
  double unitCost;
  String merchant;
  String? receiptImagePath;
  String receiptTag;
  String id;
  bool isReceiptValid;

  MaterialEntry({
    required this.id,
    required this.materialName,
    required this.quantity,
    required this.unitId,
    required this.unitCost,
    required this.merchant,
    this.receiptImagePath,
    required this.receiptTag,
    this.isReceiptValid = false,
  });

  double get totalCost => quantity * unitCost;
  bool get hasReceipt => receiptImagePath != null && File(receiptImagePath!).existsSync();

  MaterialEntry copyWith({
    String? materialName,
    double? quantity,
    String? unitId,
    double? unitCost,
    String? merchant,
    String? receiptImagePath,
    String? receiptTag,
    bool? isReceiptValid,
  }) {
    return MaterialEntry(
      id: id,
      materialName: materialName ?? this.materialName,
      quantity: quantity ?? this.quantity,
      unitId: unitId ?? this.unitId,
      unitCost: unitCost ?? this.unitCost,
      merchant: merchant ?? this.merchant,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      receiptTag: receiptTag ?? this.receiptTag,
      isReceiptValid: isReceiptValid ?? this.isReceiptValid,
    );
  }
}

class _MaterialTemplate {
  final String materialName;
  final String unitId;

  const _MaterialTemplate({
    required this.materialName,
    required this.unitId,
  });

  Map<String, dynamic> toJson() => {
        'materialName': materialName,
        'unitId': unitId,
      };

  static _MaterialTemplate fromJson(Map<String, dynamic> json) => _MaterialTemplate(
        materialName: json['materialName'] as String? ?? '',
        unitId: json['unitId'] as String? ?? 'u_kg',
      );
}

class DailyMaterialEntryScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const DailyMaterialEntryScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<DailyMaterialEntryScreen> createState() => _DailyMaterialEntryScreenState();
}

class _DailyMaterialEntryScreenState extends State<DailyMaterialEntryScreen> {
  List<MaterialEntry> _entries = [];
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String? _processingEntryId;
  String? _duplicateHint;
  String _defaultMaterialUnitId = 'u_piece';
  List<String> _materialSuggestions = [];
  final Map<String, List<UnitOption>> _unitSuggestionsByEntry = {};
  /// Units the user explicitly picked (do not auto-overwrite on material rename).
  final Set<String> _userPickedUnitEntryIds = {};

  double get _totalCost => _entries.fold(0.0, (sum, entry) => sum + entry.totalCost);

  static const _templatePrefsKey = 'daily_material_template_list_v2';
  static const _starterTemplates = <_MaterialTemplate>[
    _MaterialTemplate(materialName: 'Portland cement', unitId: 'u_bag'),
    _MaterialTemplate(materialName: 'Sand (fine)', unitId: 'u_tonne'),
    _MaterialTemplate(materialName: 'Rebar 12mm', unitId: 'u_piece'),
    _MaterialTemplate(materialName: 'Paint', unitId: 'u_litre'),
    _MaterialTemplate(materialName: 'Timber', unitId: 'u_m'),
    _MaterialTemplate(materialName: 'Maize seed', unitId: 'u_kg'),
    _MaterialTemplate(materialName: 'Fertilizer (NPK)', unitId: 'u_bag'),
    _MaterialTemplate(materialName: 'Field labour', unitId: 'u_hour'),
    _MaterialTemplate(materialName: 'Irrigation water', unitId: 'u_litre'),
  ];
  List<_MaterialTemplate> _userTemplates = [];

  List<_MaterialTemplate> get _allQuickTemplates => [
        ..._userTemplates,
        ..._starterTemplates.where(
          (s) => !_userTemplates.any(
            (u) =>
                u.materialName.toLowerCase() == s.materialName.toLowerCase(),
          ),
        ),
      ];

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static const _validationService = ReceiptValidationService();

  @override
  void initState() {
    super.initState();
    _loadDefaultMaterialUnit();
    _loadTemplates();
    _loadMaterialSuggestions();
    _addNewEntry();
  }

  Future<void> _loadDefaultMaterialUnit() async {
    await SmartUnitSuggestionService.ensureLoaded();
    // Prefer last learned/common piece over forcing kg for every new line.
    if (!mounted) return;
    setState(() {
      _defaultMaterialUnitId = UnitService.byId('u_piece')?.id ?? 'u_kg';
    });
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_templatePrefsKey) ??
        prefs.getStringList('daily_material_template_list') ??
        [];
    final decoded = list
        .map((item) {
          try {
            return _MaterialTemplate.fromJson(
              json.decode(item) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<_MaterialTemplate>()
        .where((t) => t.materialName.trim().isNotEmpty)
        .toList();
    if (!mounted) return;
    setState(() {
      _userTemplates = decoded;
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final userTemplates = _userTemplates
        .map((template) => json.encode(template.toJson()))
        .toList();
    await prefs.setStringList(_templatePrefsKey, userTemplates);
  }

  Future<void> _loadMaterialSuggestions() async {
    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final names = <String>{};

      final inventory = InventoryService(db.database);
      final items = await inventory.getProjectInventory(widget.projectId);
      for (final item in items) {
        if (item.name.trim().isNotEmpty) names.add(item.name.trim());
      }

      final expenses = await db.getExpensesByProject(widget.projectId);
      for (final e in expenses) {
        final notes = e.notes?.trim() ?? '';
        if (notes.isNotEmpty) {
          // Saved as "MaterialName x 2 bags" or similar
          final cut = notes.split(' · ').first;
          final name = cut.split(' x ').first.trim();
          if (name.isNotEmpty && name.length < 80) names.add(name);
        }
        if (e.category == ExpenseCategory.materials &&
            e.merchant.trim().isNotEmpty &&
            e.merchant.length < 40) {
          // Merchant alone is not material; skip.
        }
      }

      for (final t in _userTemplates) {
        names.add(t.materialName.trim());
      }

      final sorted = names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _materialSuggestions = sorted;
      });
    } catch (_) {
      // Suggestions are optional; entry still works fully offline.
    }
  }

  Future<void> _refreshUnitSuggestions(String entryId, String materialName) async {
    final suggestions = await SmartUnitSuggestionService.suggestUnitsForMaterial(
      materialName,
      limit: 5,
    );
    if (!mounted) return;
    setState(() {
      _unitSuggestionsByEntry[entryId] = suggestions;
    });

    final entry = _entries.cast<MaterialEntry?>().firstWhere(
          (e) => e?.id == entryId,
          orElse: () => null,
        );
    if (entry == null) return;
    if (_userPickedUnitEntryIds.contains(entryId)) return;
    if (suggestions.isEmpty) return;
    // Only auto-apply when the line still looks untouched.
    if (entry.quantity == 0 &&
        entry.unitCost == 0 &&
        (entry.unitId == _defaultMaterialUnitId ||
            entry.unitId == 'u_kg' ||
            entry.unitId.isEmpty)) {
      _updateEntry(entryId, unitId: suggestions.first.id);
    }
  }

  Future<void> _addTemplateFromEntry(String entryId) async {
    final entry = _entries.firstWhere((e) => e.id == entryId, orElse: () => _entries.first);
    if (entry.materialName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a material name before saving a template.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final template = _MaterialTemplate(
      materialName: entry.materialName.trim(),
      unitId: entry.unitId,
    );

    setState(() {
      _userTemplates = [
        template,
        ..._userTemplates.where(
          (t) =>
              t.materialName.toLowerCase() !=
              template.materialName.toLowerCase(),
        ),
      ];
      _duplicateHint = 'Saved “${template.materialName}” for quick reuse';
      if (!_materialSuggestions.any(
        (n) => n.toLowerCase() == template.materialName.toLowerCase(),
      )) {
        _materialSuggestions = [..._materialSuggestions, template.materialName]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
    });
    await _saveTemplates();
  }

  Future<void> _removeUserTemplate(_MaterialTemplate template) async {
    setState(() {
      _userTemplates = _userTemplates
          .where(
            (t) =>
                t.materialName.toLowerCase() !=
                template.materialName.toLowerCase(),
          )
          .toList();
    });
    await _saveTemplates();
  }

  void _applyTemplate(_MaterialTemplate template) {
    final blankEntry = _entries.firstWhere(
      (entry) => entry.materialName.trim().isEmpty,
      orElse: () {
        _addNewEntry();
        return _entries.last;
      },
    );

    setState(() {
      final index = _entries.indexOf(blankEntry);
      _entries[index] = blankEntry.copyWith(
        materialName: template.materialName,
        unitId: template.unitId,
      );
      _userPickedUnitEntryIds.add(blankEntry.id);
      _duplicateHint = null;
      _computeTotal();
    });
    _refreshUnitSuggestions(blankEntry.id, template.materialName);
  }

  void _duplicateEntry(String entryId) {
    final original = _entries.firstWhere((entry) => entry.id == entryId);
    final duplicate = MaterialEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      materialName: original.materialName,
      quantity: original.quantity,
      unitId: original.unitId,
      unitCost: original.unitCost,
      merchant: original.merchant,
      receiptImagePath: null,
      receiptTag: original.receiptTag,
      isReceiptValid: false,
    );

    setState(() {
      _entries.add(duplicate);
      _duplicateHint =
          'Entry ${_entries.length} was duplicated from Entry ${_entries.indexOf(original) + 1} — update quantity or receipt as needed';
      _computeTotal();
    });
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void _computeTotal() {
    setState(() {
      // Rebuild and recalculate totals from the current entry list.
    });
  }

  void _addNewEntry() {
    setState(() {
      _entries.add(
        MaterialEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          materialName: '',
          quantity: 0,
          unitId: _defaultMaterialUnitId,
          unitCost: 0.0,
          merchant: '',
          receiptImagePath: null,
          receiptTag: '',
          isReceiptValid: false,
        ),
      );
    });
  }

  void _removeEntry(String id) {
    setState(() {
      _entries.removeWhere((entry) => entry.id == id);
      _computeTotal();
    });
  }

  void _updateEntry(String id, {
    String? materialName,
    double? quantity,
    String? unitId,
    double? unitCost,
    String? merchant,
    String? receiptImagePath,
    String? receiptTag,
    bool? isReceiptValid,
  }) {
    setState(() {
      final index = _entries.indexWhere((entry) => entry.id == id);
      if (index != -1) {
        final entry = _entries[index];
        _entries[index] = entry.copyWith(
          materialName: materialName,
          quantity: quantity,
          unitId: unitId,
          unitCost: unitCost,
          merchant: merchant,
          receiptImagePath: receiptImagePath,
          receiptTag: receiptTag,
          isReceiptValid: isReceiptValid,
        );
        _computeTotal();
      }
    });
    if (materialName != null) {
      _refreshUnitSuggestions(id, materialName);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: AppColors.lightText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
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

  Future<String?> _saveReceiptImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${appDir.path}/receipts/${widget.projectId}');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'material_${_entries.length}_$timestamp.jpg';
      final savedPath = '${receiptsDir.path}/$fileName';
      await imageFile.copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('Error saving receipt: $e');
      return null;
    }
  }

  bool _isReceiptAcceptable(ReceiptValidationResult result) =>
      result.isValid || result.allowManualOverride;

  Future<void> _processReceiptImage(File imageFile, String entryId) async {
    setState(() {
      _processingEntryId = entryId;
    });

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      final result = _validationService.validate(text);
      final isValid = _isReceiptAcceptable(result);

      if (!mounted) return;

      if (isValid) {
        final parsed = result.parsed;
        if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
          _updateEntry(entryId, merchant: parsed.merchant!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_validationService.tierMessage(result.tier)),
            backgroundColor: result.isValid ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.rejectionReason ??
                  'This does not appear to be a valid receipt. Please try again.',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _updateEntry(entryId, isReceiptValid: isValid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing receipt: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _updateEntry(entryId, isReceiptValid: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingEntryId = null;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String entryId) async {
    if (source == ImageSource.camera) {
      await _checkCameraPermission();
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final picker = ImagePicker();
      final XFile? image = await auth.runWithoutBiometricLock(
        () => picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1200,
          maxHeight: 1600,
        ),
      );

      if (image == null) return;

      // Show loading indicator
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Validate image (basic checks)
      final file = File(image.path);
      final fileSize = await file.length();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Validate file size (max 10MB)
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Maximum size is 10MB.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Save image to app storage
      final savedPath = await _saveReceiptImage(file);

      if (savedPath != null && mounted) {
        _updateEntry(
          entryId,
          receiptImagePath: savedPath,
          receiptTag: 'Receipt ${DateFormat('MMM d').format(DateTime.now())}',
          isReceiptValid: false, // Will be updated after OCR
        );

        // Process the receipt for validation
        await _processReceiptImage(file, entryId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt ${source == ImageSource.camera ? 'captured' : 'selected'} and processed'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showCameraBottomSheet(BuildContext context, bool isDark, String entryId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkTextTertiary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture or select receipt image',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: const Text(
                'Take Photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Use camera to capture receipt'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, entryId);
              },
            ),

            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Select existing receipt image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, entryId);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submitEntries() async {
    // Validate entries
    final validEntries = _entries.where((e) =>
    e.materialName.trim().isNotEmpty &&
        e.merchant.trim().isNotEmpty &&
        e.quantity > 0 &&
        e.unitCost >= 0).toList();

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add at least one entry with material, merchant, quantity > 0 and unit cost.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if any entry has an invalid receipt
    final entriesWithInvalidReceipt = validEntries.where((e) => e.hasReceipt && !e.isReceiptValid).toList();
    if (entriesWithInvalidReceipt.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entriesWithInvalidReceipt.length} receipt(s) could not be verified. '
            'Remove them or attach clearer receipt photos.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final baseId = DateTime.now().millisecondsSinceEpoch;

      int successCount = 0;

      for (var i = 0; i < validEntries.length; i++) {
        final e = validEntries[i];

        // Create expense for each material entry
        final unit = UnitService.byId(e.unitId) ?? UnitService.byId('u_kg')!;
        final base = UnitService.toBase(
          quantityOriginal: e.quantity,
          unit: unit,
        );

        final expenseId = 'exp_${baseId}_$i';
        final ok = await db.createExpense(
          id: expenseId,
          projectId: widget.projectId,
          merchant: e.merchant.trim(),
          amount: e.totalCost,
          date: _selectedDate,
          category: 'Materials',
          notes:
              '${e.materialName.trim()} x ${UnitService.formatQuantity(e.quantity, unit)}',
          receiptImage: e.receiptImagePath,
          status: e.hasReceipt ? 'Verified' : 'Pending',
          quantityOriginal: e.quantity,
          unitOriginal: unit.id,
          quantityBase: base.quantityBase,
          unitBase: base.unitBase,
        );

        if (ok) {
          successCount++;
          try {
            await InventoryService(db.database).recordPurchase(
              projectId: widget.projectId,
              materialName: e.materialName.trim(),
              quantityOriginal: e.quantity,
              unit: unit,
              expenseId: expenseId,
              notes: 'From material entry',
              occurredAt: _selectedDate,
            );
          } catch (invErr) {
            debugPrint('Inventory update skipped: $invErr');
          }
        }
      }

      if (!mounted) return;

      if (successCount == validEntries.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount entries saved successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to logs history
        context.push('/project/${widget.projectId}/logs-history', extra: widget.projectName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $successCount of ${validEntries.length} entries'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving entries: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Top App Bar
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.8),
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.appBarTheme.foregroundColor,
                  size: 20,
                ),
                onPressed: () => context.go(AppRoutes.home),
              ),
            ),
            title: Text(
              'Daily Material Entry',
              style: theme.appBarTheme.titleTextStyle,
            ),
            centerTitle: false,
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Project Context Header
                _buildProjectHeader(isDark),

                const SizedBox(height: 16),

                // Selected Date
                _buildDateHeader(isDark),

                const SizedBox(height: 20),
                _buildTemplatesStrip(isDark),

                const SizedBox(height: 24),
                _buildSummaryCard(isDark, currency),

                const SizedBox(height: 24),

                // Material Entries List
                ...List.generate(_entries.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildMaterialEntryCard(isDark, _entries[index], currency),
                  );
                }),

                // Add Row Button
                _buildAddEntryButton(isDark),

                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom, left: 16, right: 16, top: 8),
          child: _buildSubmitBar(isDark),
        ),
      ),
    );
  }

  Widget _buildProjectHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CURRENT PROJECT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.projectName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(width: 10),
          Text(
            DateFormat('EEE, MMM d yyyy').format(_selectedDate),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesStrip(bool isDark) {
    final templates = _allQuickTemplates;
    final recent = _materialSuggestions.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your materials & starters — tap to prefill · long-press saved ones to remove',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == templates.length) {
                return GestureDetector(
                  onTap: () {
                    if (_entries.isNotEmpty) {
                      _addTemplateFromEntry(_entries.last.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save custom',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final template = templates[index];
              final isUserSaved = _userTemplates.any(
                (t) =>
                    t.materialName.toLowerCase() ==
                    template.materialName.toLowerCase(),
              );
              return GestureDetector(
                onTap: () => _applyTemplate(template),
                onLongPress: isUserSaved
                    ? () async {
                        await _removeUserTemplate(template);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Removed “${template.materialName}”'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUserSaved
                        ? AppColors.primary.withOpacity(0.12)
                        : (isDark ? AppColors.darkCard : AppColors.lightBackground),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUserSaved ? Icons.bookmark_rounded : Icons.bolt_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        template.materialName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Recent / inventory — type any custom name below',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final name = recent[index];
                return ActionChip(
                  label: Text(name),
                  onPressed: () {
                    final blank = _entries.firstWhere(
                      (e) => e.materialName.trim().isEmpty,
                      orElse: () {
                        _addNewEntry();
                        return _entries.last;
                      },
                    );
                    _updateEntry(blank.id, materialName: name);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialEntryCard(bool isDark, MaterialEntry entry, CurrencyProvider currency) {
    final isProcessing = _processingEntryId == entry.id;
    final entryIndex = _entries.indexOf(entry) + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.hasReceipt
              ? (entry.isReceiptValid ? AppColors.success : AppColors.warning)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: entry.hasReceipt ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entry $entryIndex',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.materialName.isNotEmpty ? entry.materialName : 'Material name',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      size: 20,
                    ),
                    onPressed: () => _duplicateEntry(entry.id),
                    tooltip: 'Duplicate entry',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.bolt_rounded,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      size: 20,
                    ),
                    onPressed: () => _addTemplateFromEntry(entry.id),
                    tooltip: 'Save as template',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_rounded,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      size: 20,
                    ),
                    onPressed: () => _removeEntry(entry.id),
                    tooltip: 'Delete entry',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildMaterialNameField(isDark, entry),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  isDark: isDark,
                  label: 'Quantity',
                  hint: '0',
                  initialValue: entry.quantity == 0
                      ? ''
                      : (entry.quantity == entry.quantity.roundToDouble()
                          ? entry.quantity.round().toString()
                          : entry.quantity.toString()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    final quantity = double.tryParse(value.trim()) ?? 0.0;
                    _updateEntry(entry.id, quantity: quantity);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildUnitDropdown(isDark, entry),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Builder(
                  builder: (context) {
                    final u = UnitService.byId(entry.unitId);
                    final unitLabel = u?.displayName ?? 'unit';
                    return _buildTextField(
                      isDark: isDark,
                      label: 'Cost per $unitLabel',
                      hint: '0.00',
                      initialValue: entry.unitCost > 0 ? entry.unitCost.toStringAsFixed(2) : '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        final cost = double.tryParse(value) ?? 0.0;
                        _updateEntry(entry.id, unitCost: cost);
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          if ((_unitSuggestionsByEntry[entry.id] ?? const []).isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  'Suggested units:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                ...(_unitSuggestionsByEntry[entry.id] ?? []).map((u) {
                  final selected = entry.unitId == u.id;
                  return ChoiceChip(
                    label: Text(u.displayName),
                    selected: selected,
                    onSelected: (_) {
                      _userPickedUnitEntryIds.add(entry.id);
                      _updateEntry(entry.id, unitId: u.id);
                      SmartUnitSuggestionService.recordUnitPreference(
                        entry.materialName,
                        u.name,
                      );
                    },
                  );
                }),
              ],
            ),
          ],

          const SizedBox(height: 16),

          _buildTextField(
            isDark: isDark,
            label: 'Merchant',
            hint: 'e.g. Home Depot',
            initialValue: entry.merchant,
            onChanged: (value) => _updateEntry(entry.id, merchant: value),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(entry.totalCost),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: isProcessing ? null : () => _showCameraBottomSheet(context, isDark, entry.id),
                icon: Icon(
                  entry.hasReceipt && entry.isReceiptValid ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 18,
                ),
                label: Text(
                  entry.hasReceipt
                      ? (entry.isReceiptValid ? 'Receipt verified' : 'Add receipt')
                      : 'Add receipt',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: entry.hasReceipt && entry.isReceiptValid
                      ? AppColors.success.withOpacity(0.9)
                      : AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialNameField(bool isDark, MaterialEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Material name (any custom name)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        Autocomplete<String>(
          key: ValueKey('material_${entry.id}'),
          initialValue: TextEditingValue(text: entry.materialName),
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim().toLowerCase();
            if (q.isEmpty) {
              return _materialSuggestions.take(12);
            }
            return _materialSuggestions
                .where((n) => n.toLowerCase().contains(q))
                .take(12);
          },
          onSelected: (value) {
            _userPickedUnitEntryIds.remove(entry.id);
            _updateEntry(entry.id, materialName: value);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) {
                _userPickedUnitEntryIds.remove(entry.id);
                _updateEntry(entry.id, materialName: value);
              },
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: InputDecoration(
                hintText: 'Type anything — tiles, diesel, labour…',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                filled: true,
                fillColor:
                    isDark ? AppColors.darkBackground : AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: const Icon(Icons.edit_rounded, size: 18),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUnitDropdown(bool isDark, MaterialEntry entry) {
    final units = UnitService.sortedForDropdown();
    final validIds = units.map((u) => u.id).toSet();
    final currentId =
        validIds.contains(entry.unitId) ? entry.unitId : _defaultMaterialUnitId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: currentId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor:
                isDark ? AppColors.darkBackground : AppColors.lightBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          items: [
            for (final u in units)
              DropdownMenuItem(
                value: u.id,
                child: Text(
                  '${u.displayName} (${u.category})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            _userPickedUnitEntryIds.add(entry.id);
            _updateEntry(entry.id, unitId: v);
            final u = UnitService.byId(v);
            if (u != null && entry.materialName.trim().isNotEmpty) {
              SmartUnitSuggestionService.recordUnitPreference(
                entry.materialName,
                u.name,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required String label,
    required String hint,
    required String initialValue,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildAddEntryButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addNewEntry,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Add item',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_entries.length} items',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total cost',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.format(_totalCost),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                '${_entries.where((e) => e.hasReceipt && e.isReceiptValid).length} receipts verified',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'The total is updated instantly while you fill each material row. Keep typing without losing focus.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(bool isDark) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitEntries,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text(
                'Submit Entries',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}