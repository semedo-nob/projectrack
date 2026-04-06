// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();

    // Navigate to onboarding after loading
    _navigateToOnboarding();
  }

  Future<void> _navigateToOnboarding() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final started = DateTime.now();
    const minSplash = Duration(milliseconds: 1200);
    const maxWait = Duration(seconds: 12);

    // Wait until auth session is resolved (avoid racing splash vs secure storage)
    while (mounted &&
        (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) &&
        DateTime.now().difference(started) < maxWait) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
    if (!mounted) return;

    if (auth.isAuthenticated) {
      final uid = auth.currentUser?.id;
      if (uid != null) {
        Provider.of<DriftDatabaseProvider>(context, listen: false).setActiveUserId(uid);
      }
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Center the entire content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo with glow effect
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeInAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: _buildLogoWithGlow(isDark),
                  ),

                  const SizedBox(height: 32),

                  // App name and tagline
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Column(
                      children: [
                        Text(
                          'ProjectRack',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your projects, on track.',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Loading indicator section
                  Column(
                    children: [
                      // Loading text with pulse animation
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1500),
                        tween: Tween<double>(begin: 0.6, end: 1.0),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Text(
                          'Loading workspace...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary.withOpacity(0.8)
                                : AppColors.lightTextTertiary.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Progress bar
                      Container(
                        width: 240,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Version text
                  Text(
                    'v1.0.2',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary.withOpacity(0.5)
                          : AppColors.lightTextTertiary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Background blur circles
          ..._buildBackgroundBlurs(isDark),
        ],
      ),
    );
  }

  Widget _buildLogoWithGlow(bool isDark) {
    return Container(
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),

          // Logo container
          Container(
            width: 144,
            height: 144,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.darkCard : Colors.white,
                width: 4,
              ),
            ),
            child: const Icon(
              Icons.layers_rounded,
              size: 72,
              color: Color(0xCC000000), // Black with 80% opacity
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundBlurs(bool isDark) {
    return [
      // Top left blur
      Positioned(
        top: -MediaQuery.of(context).size.height * 0.05,
        left: -MediaQuery.of(context).size.width * 0.05,
        child: Container(
          width: MediaQuery.of(context).size.height * 0.4,
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(isDark ? 0.03 : 0.05),
          ),
        ),
      ),

      // Bottom right blur
      Positioned(
        bottom: -MediaQuery.of(context).size.height * 0.05,
        right: -MediaQuery.of(context).size.width * 0.05,
        child: Container(
          width: MediaQuery.of(context).size.height * 0.35,
          height: MediaQuery.of(context).size.height * 0.35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(isDark ? 0.02 : 0.03),
          ),
        ),
      ),
    ];
  }
}