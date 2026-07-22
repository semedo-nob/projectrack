// lib/widgets/bottom_bar.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/drift_database_provider.dart';
import '../routes/app_routes.dart';

class BottomBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  BottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });
}

class MainScaffold extends StatefulWidget {
  final List<BottomBarItem> items;
  final int initialIndex;

  const MainScaffold({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  String? _currentProjectId; // Track current project context

  // Glimmer animation for FAB
  late AnimationController _glimmerController;
  late Animation<double> _glimmerAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Subtle glimmer animation (pulse + glow)
    _glimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glimmerAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _glimmerController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Listen for project context changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProjectContext();
    });
  }

  void _updateProjectContext() {
    // Try to get current project from database provider
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    if (db.currentProject != null) {
      setState(() {
        _currentProjectId = db.currentProject!.id;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glimmerController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _scanReceiptWithCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ImagePicker picker = ImagePicker();
      final XFile? image = await auth.runWithoutBiometricLock(
        () => picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        ),
      );

      if (image != null && mounted) {
        if (_currentProjectId != null && _currentProjectId!.isNotEmpty) {
          final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
          await db.loadProject(_currentProjectId!);
          final projectName = db.currentProject?.name;
          context.push(
            AppRoutes.projectReceiptOcr.replaceFirst(':id', _currentProjectId!),
            extra: {'imagePath': image.path, 'projectName': projectName},
          );
        } else {
          context.push(
            AppRoutes.receiptOcr,
            extra: {'imagePath': image.path},
          );
        }
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    }
  }

  Future<void> _scanReceiptFromGallery() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ImagePicker picker = ImagePicker();
    final XFile? image = await auth.runWithoutBiometricLock(
      () => picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      ),
    );

    if (image != null && mounted) {
      if (_currentProjectId != null && _currentProjectId!.isNotEmpty) {
        final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
        await db.loadProject(_currentProjectId!);
        final projectName = db.currentProject?.name;
        context.push(
          AppRoutes.projectReceiptOcr.replaceFirst(':id', _currentProjectId!),
          extra: {'imagePath': image.path, 'projectName': projectName},
        );
      } else {
        context.push(
          AppRoutes.receiptOcr,
          extra: {'imagePath': image.path},
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('Please enable camera access in settings to scan receipts.'),
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

  Future<void> _showActionBottomSheet() async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode(context);

    // Refresh project context
    _updateProjectContext();

    // Get project name if available
    String? projectName;
    if (_currentProjectId != null) {
      final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
      await db.loadProject(_currentProjectId!);
      projectName = db.currentProject?.name;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkTextTertiary.withOpacity(0.3) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),

            // Create Project Option
            _buildBottomSheetOption(
              isDark: isDark,
              icon: Icons.create_new_folder_rounded,
              iconColor: AppColors.primary,
              title: 'Create Project',
              subtitle: 'Start a new project',
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.createProject);
              },
            ),

            // Divider
            const Divider(height: 1, indent: 20, endIndent: 20),

            // Camera Option
            _buildBottomSheetOption(
              isDark: isDark,
              icon: Icons.camera_alt_rounded,
              iconColor: AppColors.primary,
              title: 'Scan Receipt with Camera',
              subtitle: _currentProjectId != null
                  ? 'Attach to ${projectName ?? 'current project'}'
                  : 'Take a photo of your receipt',
              onTap: () {
                Navigator.pop(context);
                _scanReceiptWithCamera();
              },
            ),

            // Gallery Option
            _buildBottomSheetOption(
              isDark: isDark,
              icon: Icons.photo_library_rounded,
              iconColor: AppColors.secondary,
              title: 'Choose from Gallery',
              subtitle: _currentProjectId != null
                  ? 'Select receipt for ${projectName ?? 'current project'}'
                  : 'Select an existing receipt image',
              onTap: () {
                Navigator.pop(context);
                _scanReceiptFromGallery();
              },
            ),

            // Quick Material Entry (if in project context)
            if (_currentProjectId != null)
              _buildBottomSheetOption(
                isDark: isDark,
                icon: Icons.inventory_2_rounded,
                iconColor: AppColors.info,
                title: 'Quick Material Entry',
                subtitle: 'Add materials to ${projectName ?? 'project'}',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/project/$_currentProjectId/material-entry',
                    extra: projectName,
                  );
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBody: true,
      body: Stack(
        children: [
          // PageView for swipe navigation
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: widget.items.map((item) => item.screen).toList(),
          ),

          // Bottom Bar with Integrated FAB
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  AppColors.darkCard.withOpacity(0.9),
                  AppColors.darkSurface.withOpacity(0.95),
                ]
                    : [
                  Colors.white.withOpacity(0.95),
                  AppColors.lightSurface.withOpacity(0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dashboard Tab
                _buildNavItem(index: 0, isDark: isDark, item: widget.items[0]),

                // Projects Tab
                _buildNavItem(index: 1, isDark: isDark, item: widget.items[1]),

                // FAB in the middle
                _buildFabItem(isDark),

                // Expense Tab
                _buildNavItem(index: 2, isDark: isDark, item: widget.items[2]),

                // Profile Tab
                _buildNavItem(index: 3, isDark: isDark, item: widget.items[3]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required bool isDark,
    required BottomBarItem item,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                size: 24,
              ),
              if (isSelected) ...[
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 2),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabItem(bool isDark) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _glimmerAnimation,
        builder: (context, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: GestureDetector(
              onTap: _showActionBottomSheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(_glimmerAnimation.value * 0.7),
                          blurRadius: 12 * _glimmerAnimation.value,
                          spreadRadius: 2 * _glimmerAnimation.value,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}