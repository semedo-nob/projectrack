// lib/ui/onboarding/onboarding2.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key});

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2> {
  void _skipOnboarding() {
    context.go('/login');
  }

  void _continueToNext() {
    // Navigate to next onboarding or login
    context.go('/onboarding3'); // or '/login' if this is the last
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.primaryLight.withOpacity(0.7)
                            : AppColors.primaryMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Illustration Area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildIllustration(isDark),
                    ),

                    const SizedBox(height: 40),

                    // Headline Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Smart Material Tracking',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Body Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Log your materials in seconds. ProjectRack automatically computes costs and updates your daily project budget so you don\'t have to.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightText.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPageIndicator(isDark, false),
                      const SizedBox(width: 12),
                      _buildPageIndicator(isDark, true),
                      const SizedBox(width: 12),
                      _buildPageIndicator(isDark, false),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Continue Button
                  _buildContinueButton(isDark),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(bool isDark) {
    return Center(
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Phone Mockup
            Positioned(
              child: Container(
                width: 192,
                height: 256,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppColors.salamonoShadowDark
                          : AppColors.salamonoShadow,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Material rows
                      _buildMaterialRow(isDark, Icons.construction_rounded, 45),
                      const SizedBox(height: 12),
                      _buildMaterialRow(isDark, Icons.square_foot_rounded, 32),
                    ],
                  ),
                ),
              ),
            ),

            // Calculation Bubble
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBackground : Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: 0.1, // Slight rotation
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total Cost',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark
                              ? AppColors.darkBackground.withOpacity(0.6)
                              : Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$4,290',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkBackground : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(bool isDark, IconData icon, double width) {
    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),

        // Progress bar placeholder
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Value indicator
        Container(
          width: 32,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isDark, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 10,
      width: isActive ? 24 : 10,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
        borderRadius: BorderRadius.circular(30),
        boxShadow: isActive
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          )
        ]
            : null,
      ),
    );
  }

  Widget _buildContinueButton(bool isDark) {
    return GestureDetector(
      onTap: _continueToNext,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkBackground : Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: isDark ? AppColors.darkBackground : Colors.black,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}