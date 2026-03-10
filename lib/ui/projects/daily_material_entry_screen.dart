// lib/ui/projects/daily_material_entry_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class MaterialEntry {
  String materialName;
  int quantity;
  double unitCost;
  String merchant;
  String? receiptImagePath; // Path to saved receipt image
  String receiptTag;
  String id;

  MaterialEntry({
    required this.id,
    required this.materialName,
    required this.quantity,
    required this.unitCost,
    required this.merchant,
    this.receiptImagePath,
    required this.receiptTag,
  });

  double get totalCost => quantity * unitCost;
  bool get hasReceipt => receiptImagePath != null && File(receiptImagePath!).existsSync();

  MaterialEntry copyWith({
    String? materialName,
    int? quantity,
    double? unitCost,
    String? merchant,
    String? receiptImagePath,
    String? receiptTag,
  }) {
    return MaterialEntry(
      id: id,
      materialName: materialName ?? this.materialName,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      merchant: merchant ?? this.merchant,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      receiptTag: receiptTag ?? this.receiptTag,
    );
  }
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
  double _computedTotal = 0.0;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _addNewEntry(); // Start with one empty entry
  }

  void _computeTotal() {
    setState(() {
      _computedTotal = _entries.fold(0.0, (sum, entry) => sum + entry.totalCost);
    });
  }

  void _addNewEntry() {
    setState(() {
      _entries.add(
        MaterialEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          materialName: '',
          quantity: 0,
          unitCost: 0.0,
          merchant: '',
          receiptImagePath: null,
          receiptTag: '',
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
    int? quantity,
    double? unitCost,
    String? merchant,
    String? receiptImagePath,
    String? receiptTag,
  }) {
    setState(() {
      final index = _entries.indexWhere((entry) => entry.id == id);
      if (index != -1) {
        final entry = _entries[index];
        _entries[index] = entry.copyWith(
          materialName: materialName,
          quantity: quantity,
          unitCost: unitCost,
          merchant: merchant,
          receiptImagePath: receiptImagePath,
          receiptTag: receiptTag,
        );
        _computeTotal();
      }
    });
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

  Future<void> _pickImage(ImageSource source, String entryId) async {
    if (source == ImageSource.camera) {
      await _checkCameraPermission();
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1600,
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
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt ${source == ImageSource.camera ? 'captured' : 'selected'} successfully'),
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

    setState(() => _isSubmitting = true);

    try {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final baseId = DateTime.now().millisecondsSinceEpoch;

      int successCount = 0;

      for (var i = 0; i < validEntries.length; i++) {
        final e = validEntries[i];

        // Create expense for each material entry
        final ok = await db.createExpense(
          id: 'exp_${baseId}_$i',
          projectId: widget.projectId,
          merchant: e.merchant.trim(),
          amount: e.totalCost,
          date: _selectedDate,
          category: 'Materials',
          notes: '${e.materialName.trim()} x ${e.quantity}',
          receiptImage: e.receiptImagePath,
          status: e.hasReceipt ? 'Verified' : 'Pending',
        );

        if (ok) successCount++;
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
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

                    const SizedBox(height: 200),
                  ]),
                ),
              ),
            ],
          ),

          // Fixed Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFixedFooter(isDark, currency),
          ),
        ],
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.projectName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialEntryCard(bool isDark, MaterialEntry entry, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Entry #${_entries.indexOf(entry) + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_rounded,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  size: 20,
                ),
                onPressed: () => _removeEntry(entry.id),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Material Name
          _buildTextField(
            isDark: isDark,
            label: 'Material Name',
            hint: 'e.g. Portland Cement',
            initialValue: entry.materialName,
            onChanged: (value) => _updateEntry(entry.id, materialName: value),
          ),

          const SizedBox(height: 16),

          // Quantity and Unit Cost
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  isDark: isDark,
                  label: 'Quantity',
                  hint: '0',
                  initialValue: entry.quantity.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final quantity = int.tryParse(value) ?? 0;
                    _updateEntry(entry.id, quantity: quantity);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  isDark: isDark,
                  label: 'Unit Cost (${currency.symbol})',
                  hint: '0.00',
                  initialValue: entry.unitCost > 0 ? entry.unitCost.toStringAsFixed(2) : '',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final cost = double.tryParse(value) ?? 0.0;
                    _updateEntry(entry.id, unitCost: cost);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Merchant
          _buildTextField(
            isDark: isDark,
            label: 'Merchant',
            hint: 'e.g. Home Depot',
            initialValue: entry.merchant,
            onChanged: (value) => _updateEntry(entry.id, merchant: value),
          ),

          const SizedBox(height: 16),

          // Receipt Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receipt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    if (entry.hasReceipt)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.success, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Receipt Added',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Receipt Preview (if exists)
              if (entry.hasReceipt)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(entry.receiptImagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            onPressed: () => _updateEntry(entry.id, receiptImagePath: null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Camera Button Row
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      isDark: isDark,
                      label: '',
                      hint: 'Receipt tag (optional)',
                      initialValue: entry.receiptTag,
                      onChanged: (value) => _updateEntry(entry.id, receiptTag: value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () => _showCameraBottomSheet(context, isDark, entry.id),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Material Item',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedFooter(bool isDark, CurrencyProvider currency) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL COST',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      currency.format(_computedTotal),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _computeTotal,
                  icon: const Icon(Icons.calculate_rounded, size: 18),
                  label: const Text('Compute Total'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitEntries,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  shadowColor: AppColors.primary.withOpacity(0.3),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}