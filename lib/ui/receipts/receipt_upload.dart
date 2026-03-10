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

import '../../providers/currency_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class ReceiptOcrScreen extends StatefulWidget {
  final String? initialImagePath;
  final String? initialProjectId;
  final String? projectId;
  final String? projectName;

  const ReceiptOcrScreen({
    super.key,
    this.initialImagePath,
    this.initialProjectId,
    this.projectId,
    this.projectName,
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
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Common merchant names for better recognition
  final List<String> _commonMerchants = [
    'Walmart', 'Target', 'Costco', 'Home Depot', 'Lowe\'s',
    'Starbucks', 'McDonald\'s', 'Amazon', 'Uber', 'Lyft',
    'Shell', 'Exxon', 'CVS', 'Walgreens', 'Kroger', 'Safeway'
  ];

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
      // Set default date to today
      if (_dateController.text.isEmpty) {
        _dateController.text = DateFormat('MMM d, yyyy').format(DateTime.now());
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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
          _ocrConfidence = null;
          _ocrErrorMessage = null;
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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
          _ocrConfidence = null;
          _ocrErrorMessage = null;
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

  Future<void> _runOcr(String path) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _ocrErrorMessage = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      if (!mounted) return;

      // Calculate confidence based on text length and structure
      double confidence = 0.7; // Base confidence
      if (text.length > 50) confidence += 0.1;
      if (text.contains(RegExp(r'\d+\.\d{2}'))) confidence += 0.1; // Has price
      if (text.contains(RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}'))) confidence += 0.1; // Has date

      setState(() {
        _isProcessing = false;
        _ocrConfidence = confidence.clamp(0.0, 1.0);
      });

      _parseAndFill(text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _ocrErrorMessage = 'OCR failed: ${e.toString().substring(0, min(50, e.toString().length))}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR failed. You can enter details manually.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _parseAndFill(String text) {
    if (text.trim().isEmpty) return;

    final lines = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // Parse amount
    _parseAmount(lines);

    // Parse date
    _parseDate(lines);

    // Parse merchant
    _parseMerchant(lines);
  }

  void _parseAmount(List<String> lines) {
    // Look for common amount patterns
    final amountRegex = RegExp(
      r'(?:total|amount|sum|balance|due|price|cost|grand total|amount due)[\s:]*[\$€£]?\s*([\d,]+\.?\d{0,2})',
      caseSensitive: false,
    );

    // Also look for standalone amounts at end of lines
    final standaloneRegex = RegExp(
      r'[\$€£]\s*([\d,]+\.?\d{0,2})|([\d,]+\.\d{2})\s*$',
      caseSensitive: false,
    );

    double? bestAmount;
    int bestScore = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for total-related lines (higher priority)
      final totalMatch = amountRegex.firstMatch(line);
      if (totalMatch != null) {
        final numStr = (totalMatch.group(1) ?? '').replaceAll(',', '');
        final v = double.tryParse(numStr);
        if (v != null && v > 0 && v < 1000000) {
          // Prioritize lines with "total" keyword
          if (line.toLowerCase().contains('total')) {
            bestAmount = v;
            bestScore = 10;
            break;
          }
          if (bestScore < 5) {
            bestAmount = v;
            bestScore = 5;
          }
        }
      }

      // Check for standalone amounts (lower priority)
      final standaloneMatch = standaloneRegex.firstMatch(line);
      if (standaloneMatch != null && bestScore < 3) {
        final numStr = (standaloneMatch.group(1) ?? standaloneMatch.group(2) ?? '').replaceAll(',', '');
        final v = double.tryParse(numStr);
        if (v != null && v > 0 && v < 1000000) {
          bestAmount = v;
          bestScore = 3;
        }
      }
    }

    if (bestAmount != null) {
      _amountController.text = bestAmount.toStringAsFixed(2);
    }
  }

  void _parseDate(List<String> lines) {
    // Try multiple date formats
    final dateFormats = [
      RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})'), // MM/DD/YYYY or DD/MM/YYYY
      RegExp(r'(\w{3,9})\s+(\d{1,2}),?\s*(\d{4})'), // Month DD, YYYY
      RegExp(r'(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})'), // YYYY-MM-DD
      RegExp(r'(\d{1,2})\s+(\w{3,9})\s+(\d{4})'), // DD Month YYYY
    ];

    DateTime? bestDate;

    for (final line in lines) {
      for (final format in dateFormats) {
        final match = format.firstMatch(line);
        if (match != null) {
          try {
            DateTime? parsed;

            if (format.pattern.contains('w{3,9}')) {
              // Handle month name formats
              final monthStr = match.group(1)!.toLowerCase();
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);

              final months = [
                'january', 'february', 'march', 'april', 'may', 'june',
                'july', 'august', 'september', 'october', 'november', 'december'
              ];

              int month = -1;
              for (int i = 0; i < months.length; i++) {
                if (months[i].startsWith(monthStr.substring(0, 3))) {
                  month = i + 1;
                  break;
                }
              }

              if (month >= 1 && month <= 12) {
                parsed = DateTime(year, month, day);
              }
            } else {
              // Handle numeric formats
              final a = int.parse(match.group(1)!);
              final b = int.parse(match.group(2)!);
              final c = int.parse(match.group(3)!);

              final year = c > 99 ? c : 2000 + c;

              // Try to determine if it's MM/DD or DD/MM
              if (a > 12) {
                // Must be DD/MM
                parsed = DateTime(year, b, a);
              } else if (b > 12) {
                // Must be MM/DD
                parsed = DateTime(year, a, b);
              } else {
                // Ambiguous, try both and pick the one that makes sense
                final date1 = DateTime(year, a, b);
                final date2 = DateTime(year, b, a);

                if (date1.isBefore(DateTime.now()) && date1.year == year) {
                  parsed = date1;
                } else if (date2.isBefore(DateTime.now()) && date2.year == year) {
                  parsed = date2;
                }
              }
            }

            if (parsed != null && parsed.year > 2000 && parsed.year < 2100) {
              bestDate = parsed;
              break;
            }
          } catch (_) {}
        }
      }
      if (bestDate != null) break;
    }

    if (bestDate != null) {
      _dateController.text = DateFormat('MMM d, yyyy').format(bestDate);
    }
  }

  void _parseMerchant(List<String> lines) {
    if (lines.isEmpty) return;

    // Look for known merchant names first
    String? foundMerchant;
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      for (final merchant in _commonMerchants) {
        if (lowerLine.contains(merchant.toLowerCase())) {
          foundMerchant = merchant;
          break;
        }
      }
      if (foundMerchant != null) break;
    }

    // If no known merchant found, use first non-empty line
    if (foundMerchant == null && lines.isNotEmpty) {
      String merchant = lines.first;
      // Clean up common OCR artifacts
      merchant = merchant.replaceAll(RegExp(r"[^a-zA-Z0-9\s\.&'-]"), '');
      if (merchant.length > 50) merchant = merchant.substring(0, 50);
      foundMerchant = merchant;
    }

    if (foundMerchant != null && _merchantController.text.isEmpty) {
      _merchantController.text = foundMerchant;
    }
  }

  Future<void> _saveExpense() async {
    // Validate inputs
    if (_selectedProjectId == null || _projects.isEmpty) {
      _showError('Please select a project.');
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_${_selectedProjectId}_$timestamp.jpg';
      final storedPath = '${receiptsDir.path}/$fileName';
      await File(_imagePath!).copy(storedPath);

      // Parse date
      DateTime expenseDate = DateTime.now();
      try {
        expenseDate = DateFormat('MMM d, yyyy').parse(_dateController.text.trim());
      } catch (_) {
        // Keep current date if parsing fails
      }

      // Generate unique ID
      final id = 'exp_${DateTime.now().millisecondsSinceEpoch}';

      // Save to database
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      final ok = await db.createExpense(
        id: id,
        projectId: _selectedProjectId!,
        merchant: merchant,
        amount: amount,
        date: expenseDate,
        category: 'Receipt',
        notes: _notesController.text.trim().isEmpty
            ? 'Scanned receipt'
            : _notesController.text.trim(),
        receiptImage: storedPath,
        status: 'Logged',
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense saved successfully!'),
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
                  'Scan Receipt',
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
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ready',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
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
                          if (_ocrConfidence != null && !_isProcessing)
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
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
            if (!_isProcessing)
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
              child: _buildTextField(
                isDark: isDark,
                label: 'Date',
                controller: _dateController,
                hint: 'MMM DD, YYYY',
                icon: Icons.calendar_today_rounded,
              ),
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
            onPressed: (_isProcessing || _isSaving) ? null : _saveExpense,
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
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded),
                SizedBox(width: 8),
                Text(
                  'Save Expense',
                  style: TextStyle(
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