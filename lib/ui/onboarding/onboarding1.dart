// lib/ui/onboarding/onboarding1.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:projectrack1/themes/app_colors.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Onboarding: Welcome → Track Expense → Get Started
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Welcome',
      description: 'Manage every detail from construction sites to agricultural yields. Track your projects and expenses in one organized place.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCe1__ZxZ4-iex8KNkTvsRUKoE_mIOSWSu4vhvOm71dgNGd26qdUXf3GEmqdPTgK-WoBGoHJ-KIjsAlY2Bk9v51KbtIGsJR6hDI2CD5mthpt5KeT4PXHY5WE7Yw8bwBOy9uuIGKrN3YXsw7eXHrUQTM6dXzVmTS4P3CVaZ6qQOmUt82bNOkN75MSjWLCz88Je-LA7QaQYHKcvE_mR_Q15RMiizmMBCaaHI7OnU-giIPBuwU4wX60gm7dg7uNMxVZTZfhLXJuvdKj7vG',
    ),
    OnboardingPageData(
      title: 'Track Expense',
      description: 'Easily log and categorize expenses. Scan receipts and let our OCR technology do the work for you.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCe1__ZxZ4-iex8KNkTvsRUKoE_mIOSWSu4vhvOm71dgNGd26qdUXf3GEmqdPTgK-WoBGoHJ-KIjsAlY2Bk9v51KbtIGsJR6hDI2CD5mthpt5KeT4PXHY5WE7Yw8bwBOy9uuIGKrN3YXsw7eXHrUQTM6dXzVmTS4P3CVaZ6qQOmUt82bNOkN75MSjWLCz88Je-LA7QaQYHKcvE_mR_Q15RMiizmMBCaaHI7OnU-giIPBuwU4wX60gm7dg7uNMxVZTZfhLXJuvdKj7vG',
    ),
    OnboardingPageData(
      title: 'Get Started',
      description: 'Ready to organize your projects and expenses? Create an account and start tracking today.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCe1__ZxZ4-iex8KNkTvsRUKoE_mIOSWSu4vhvOm71dgNGd26qdUXf3GEmqdPTgK-WoBGoHJ-KIjsAlY2Bk9v51KbtIGsJR6hDI2CD5mthpt5KeT4PXHY5WE7Yw8bwBOy9uuIGKrN3YXsw7eXHrUQTM6dXzVmTS4P3CVaZ6qQOmUt82bNOkN75MSjWLCz88Je-LA7QaQYHKcvE_mR_Q15RMiizmMBCaaHI7OnU-giIPBuwU4wX60gm7dg7uNMxVZTZfhLXJuvdKj7vG',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // In lib/ui/onboarding/onboarding1.dart, update the _nextPage method
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page: Get Started → go to login
      context.go('/login');
    }
  }

  void _skipOnboarding() {
    context.go('/login');
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
            // Top Navigation with Skip button
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
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(context, isDark, _pages[index]);
                },
              ),
            ),

            // Footer Navigation
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      return _buildPageIndicator(isDark, index == _currentPage);
                    }),
                  ),

                  const SizedBox(height: 32),

                  // Next Step Button
                  _buildNextButton(isDark),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(BuildContext context, bool isDark, OnboardingPageData page) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration Image - flexible height with max constraint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AspectRatio(
                aspectRatio: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    image: DecorationImage(
                      image: NetworkImage(page.imageUrl),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Show placeholder on error
                      },
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? AppColors.salamonoShadowDark : AppColors.salamonoShadow,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Text Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark
                          ? AppColors.darkText.withOpacity(0.8)
                          : AppColors.lightText.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(bool isDark, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : (isDark ? Colors.white.withOpacity(0.2) : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  Widget _buildNextButton(bool isDark) {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next Step',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.black,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}




// Data model for onboarding pages
class OnboardingPageData {
  final String title;
  final String description;
  final String imageUrl;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}

