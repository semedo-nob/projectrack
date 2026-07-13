// lib/ui/onboarding/onboarding3.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';

import '../../providers/theme_provider.dart';

class OnboardingScreen3 extends StatefulWidget {
  const OnboardingScreen3({super.key});

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3> {
  void _goBack() {
    Navigator.pop(context);
  }

  void _getStarted() {
    // Navigate to login or home
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);
    final theme = Theme.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: _goBack,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        size: 24,
                      ),
                    ),
                  ),

                  // Page Indicator Text
                  Text(
                    '3 of 3',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),

                  // Empty spacer
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Progress Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageDot(isDark, false),
                const SizedBox(width: 12),
                _buildPageDot(isDark, false),
                const SizedBox(width: 12),
                _buildPageIndicator(isDark, true),
              ],
            ),

            const SizedBox(height: 24),

            // Illustration Section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildIllustration(isDark, currency),
                    ),

                    const SizedBox(height: 32),

                    // Text Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            'Smarter Tracking, Deeper Insights',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Snap a photo of any receipt to instantly extract data. Get automated expense reports and project analytics delivered to your dashboard.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              height: 1.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Button Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Get Started Button
                  _buildGetStartedButton(isDark),

                  const SizedBox(height: 16),

                  // Final Step Text
                  Text(
                    'Final Step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // iOS Home Indicator Space
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDot(bool isDark, bool isActive) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightDivider,
      ),
    );
  }

  Widget _buildPageIndicator(bool isDark, bool isActive) {
    return Container(
      width: 32,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(bool isDark, CurrencyProvider currency) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
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
          // Abstract Receipt Scanning Graphic
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Receipt Shape
                Positioned(
                  child: Transform.rotate(
                    angle: -0.1, // -6 degrees in radians
                    child: Container(
                      width: 128,
                      height: 192,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Receipt lines
                            Container(
                              width: double.infinity,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 96,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            // Bottom row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 32,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  width: 48,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Scan Line
                Positioned(
                  child: Container(
                    width: double.infinity,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.8),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // OCR Extraction Chips
                Positioned(
                  top: 40,
                  right: 0,
                  child: Transform.rotate(
                    angle: 0.05, // ~3 degrees
                    child: _buildChip(
                      isDark: isDark,
                      icon: Icons.payments_rounded,
                      label: currency.format(124.5),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 80,
                  left: 0,
                  child: Transform.rotate(
                    angle: -0.2, // ~ -12 degrees
                    child: _buildChip(
                      isDark: isDark,
                      icon: Icons.calendar_today_rounded,
                      label: 'Oct 12, 2023',
                    ),
                  ),
                ),

                Positioned(
                  top: 120,
                  left: -10,
                  child: _buildChip(
                    isDark: isDark,
                    icon: Icons.storefront_rounded,
                    label: 'Starbucks',
                  ),
                ),

                // Analytics Background Bars
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAnalyticsBar(height: 0.5, isDark: isDark),
                      const SizedBox(width: 4),
                      _buildAnalyticsBar(height: 0.75, isDark: isDark),
                      const SizedBox(width: 4),
                      _buildAnalyticsBar(height: 1.0, isDark: isDark),
                      const SizedBox(width: 4),
                      _buildAnalyticsBar(height: 0.66, isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildChip({
    required bool isDark,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsBar({required double height, required bool isDark}) {
    return Container(
      width: 6,
      height: 32 * height,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildGetStartedButton(bool isDark) {
    return GestureDetector(
      onTap: _getStarted,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
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