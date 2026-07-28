// lib/routes/app_route.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/widgets/bottom_bar.dart';

import '../splash_screen.dart';
import '../ui/auth/biometric_unlock_screen.dart';
import '../ui/auth/login_screen.dart';
import '../ui/auth/register_screen.dart';
import '../ui/onboarding/onboarding1.dart';
import '../ui/onboarding/onboarding2.dart';
import '../ui/onboarding/onboarding3.dart';
import '../ui/projects/create_project_screen.dart';
import '../ui/projects/project_logs.dart';
import '../ui/projects/project_overview_screen.dart';
import '../ui/projects/daily_material_entry_screen.dart';
import '../ui/projects/project_activities_screen.dart';
import '../ui/projects/project_schedule_screen.dart';
import '../ui/projects/projects_screen.dart';
import '../ui/receipts/receipt_detail_view.dart';
import '../ui/receipts/receipt_gallery.dart';
import '../ui/receipts/receipt_upload.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/expense.dart';
import '../ui/screens/notifications.dart';
import '../ui/screens/profile.dart';
import '../ui/screens/reports.dart';
import '../ui/screens/settings.dart';
import '../ui/screens/settings_unit_screen.dart';
import '../ui/tasks/task_detail_screen.dart';
import '../ui/tasks/task_form_screen.dart';
import '../ui/tasks/tasks_screen.dart';
import '../ui/inventory/inventory_screen.dart';
import '../constants/models/task_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String unlock = '/unlock';
  static const String createProject = '/create-project';
  static const String projectOverview = '/project/:id';
  static const String dailyMaterialEntry = '/project/:id/material-entry';
  static const String dailyLogsHistory = '/project/:id/logs-history';
  static const String projects = '/projects';
  static const String onboarding = '/onboarding';
  static const String categorizedExpenses = '/project/:id/expenses';
  static const String dashboard = '/dashboard';
  static const String home = '/home';
  static const String onboarding2 = '/onboarding2'; // Add this route
  static const String onboarding3 = '/onboarding3';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String unitSettings = '/settings/units';

  // Nested routes
  static const String projectDetails = '/projects/:id';
  static const String editProject = '/projects/:id/edit';
  static const String receiptOcr = '/receipt-ocr'; // Add this route
  static const String projectReceiptOcr = '/project/:id/receipt-ocr';
  static const String receiptGallery = '/receipt-gallery'; // Add this route
  static const String projectReceiptGallery = '/project/:id/receipt-gallery';
  static const String receiptDetail = '/receipt/:id'; // Add this route
  static const String projectReceiptDetail =
      '/project/:projectId/receipt/:receiptId';
  static const String reportsAnalytics = '/reports'; // Add this route
  static const String projectReports = '/project/:id/reports';
  static const String projectTasks = '/project/:id/tasks';
  static const String projectTaskCreate = '/project/:id/tasks/new';
  static const String projectTaskDetail = '/project/:id/tasks/:taskId';
  static const String projectTaskEdit = '/project/:id/tasks/:taskId/edit';
  static const String projectInventory = '/project/:id/inventory';
  static const String projectActivities = '/project/:id/activities';
  static const String projectSchedule = '/project/:id/schedule';
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  redirect: (BuildContext context, GoRouterState state) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuth = auth.isAuthenticated;
    final needsUnlock = auth.needsBiometricUnlock;
    final isInitial = auth.status == AuthStatus.initial;
    final isLoading = auth.status == AuthStatus.loading;
    final path = state.uri.path;
    final isPublic =
        path == AppRoutes.splash ||
        path == AppRoutes.login ||
        path == AppRoutes.register ||
        path.startsWith(AppRoutes.onboarding) ||
        path == AppRoutes.onboarding2 ||
        path == AppRoutes.onboarding3;
    if (isInitial || isLoading) return null;
    if (!isAuth && !isPublic) return AppRoutes.login;
    if (isAuth && needsUnlock && path != AppRoutes.unlock)
      return AppRoutes.unlock;
    if (isAuth && !needsUnlock && path == AppRoutes.unlock)
      return AppRoutes.home;
    if (isAuth && (path == AppRoutes.login || path == AppRoutes.register))
      return AppRoutes.home;
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.onboarding2,
      name: 'onboarding2',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const OnboardingScreen2(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.onboarding3,
      name: 'onboarding3',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const OnboardingScreen3(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    // Splash Screen
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // Login Screen
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: AppRoutes.unlock,
      name: 'unlock',
      builder: (context, state) => const BiometricUnlockScreen(),
    ),

    // Register Screen
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Create Project Screen
    GoRoute(
      path: AppRoutes.createProject,
      name: 'create-project',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const CreateProjectScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    // Projects Screen (List all projects)
    GoRoute(
      path: AppRoutes.projects,
      name: 'projects',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const ProjectsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // Project Overview Screen with parameter
    GoRoute(
      path: AppRoutes.projectOverview,
      name: 'project-overview',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project Details';
        return ProjectOverviewScreen(projectId: id, projectName: projectName);
      },
    ),

    // Daily Material Entry Screen
    GoRoute(
      path: AppRoutes.dailyMaterialEntry,
      name: 'daily-material-entry',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project Details';

        return CustomTransitionPage(
          child: DailyMaterialEntryScreen(
            projectId: id,
            projectName: projectName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    // Daily Logs History Screen
    GoRoute(
      path: AppRoutes.dailyLogsHistory,
      name: 'daily-logs-history',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project Details';

        return CustomTransitionPage(
          child: DailyLogsHistoryScreen(
            projectId: id,
            projectName: projectName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // Project tasks
    GoRoute(
      path: AppRoutes.projectTasks,
      name: 'project-tasks',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return TasksScreen(projectId: id, projectName: projectName);
      },
    ),
    GoRoute(
      path: AppRoutes.projectInventory,
      name: 'project-inventory',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return InventoryScreen(projectId: id, projectName: projectName);
      },
    ),
    GoRoute(
      path: AppRoutes.projectActivities,
      name: 'project-activities',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return ProjectActivitiesScreen(
          projectId: id,
          projectName: projectName,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.projectSchedule,
      name: 'project-schedule',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return ProjectScheduleScreen(
          projectId: id,
          projectName: projectName,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.projectTaskCreate,
      name: 'project-task-create',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return TaskFormScreen(projectId: id, projectName: projectName);
      },
    ),
    GoRoute(
      path: AppRoutes.projectTaskEdit,
      name: 'project-task-edit',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final taskId = state.pathParameters['taskId'] ?? '';
        final extra = state.extra;
        String projectName = 'Project';
        ProjectTask? task;
        if (extra is Map) {
          projectName = extra['projectName'] as String? ?? projectName;
          task = extra['task'] as ProjectTask?;
        } else if (extra is String) {
          projectName = extra;
        }
        return TaskFormScreen(
          projectId: id,
          projectName: projectName,
          task: task,
          taskId: taskId,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.projectTaskDetail,
      name: 'project-task-detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final taskId = state.pathParameters['taskId'] ?? '';
        final extra = state.extra;
        String projectName = 'Project';
        ProjectTask? task;
        if (extra is Map) {
          projectName = extra['projectName'] as String? ?? projectName;
          task = extra['task'] as ProjectTask?;
        } else if (extra is String) {
          projectName = extra;
        }
        return TaskDetailScreen(
          projectId: id,
          projectName: projectName,
          taskId: taskId,
          initialTask: task,
        );
      },
    ),

    // Dashboard Screen
    GoRoute(
      path: AppRoutes.dashboard,
      name: 'dashboard',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
        );
      },
    ),

    // Home with Bottom Navigation Bar
    // Home with Bottom Navigation Bar
    // In your app_route.dart, replace the home route with:

    // Home with Bottom Navigation Bar
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: MainScaffold(
            items: [
              BottomBarItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                screen: const DashboardScreen(),
              ),
              BottomBarItem(
                icon: Icons.folder_outlined,
                selectedIcon: Icons.folder_rounded,
                label: 'Projects',
                screen: const ProjectsScreen(),
              ),
              BottomBarItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Expense',
                screen: const CategorizedExpensesScreen(
                  projectId: 'default',
                  projectName: 'Default',
                ),
              ),
              BottomBarItem(
                icon: Icons.person_outlined,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                screen: const ProfileScreen(),
              ),
            ],
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.categorizedExpenses,
      name: 'categorized-expenses',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        var projectName = 'Project Details';
        final extra = state.extra;
        if (extra is String) {
          projectName = extra;
        } else if (extra is Map && extra['projectName'] is String) {
          projectName = extra['projectName'] as String;
        }

        return CustomTransitionPage(
          child: CategorizedExpensesScreen(
            projectId: id,
            projectName: projectName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.receiptOcr,
      name: 'receipt-ocr',
      pageBuilder: (context, state) {
        final extra = state.extra;
        String? imagePath;
        String? projectId;
        String? projectName;
        if (extra is Map<String, dynamic>) {
          imagePath = extra['imagePath'] as String?;
          projectId = extra['projectId'] as String?;
          projectName = extra['projectName'] as String?;
        }
        final expenseId = extra is Map<String, dynamic> ? extra['expenseId'] as String? : null;
        final merchant = extra is Map<String, dynamic> ? extra['merchant'] as String? : null;
        final amount = extra is Map<String, dynamic> ? extra['amount'] as double? : null;
        final date = extra is Map<String, dynamic> ? extra['date'] as String? : null;
        final notes = extra is Map<String, dynamic> ? extra['notes'] as String? : null;
        return CustomTransitionPage(
          child: ReceiptOcrScreen(
            initialImagePath: imagePath,
            initialProjectId: projectId,
            projectId: projectId,
            projectName: projectName,
            expenseId: expenseId,
            initialMerchant: merchant,
            initialAmount: amount,
            initialDate: date,
            initialNotes: notes,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    // Project-scoped receipt OCR: /project/:id/receipt-ocr
    GoRoute(
      path: AppRoutes.projectReceiptOcr,
      name: 'project-receipt-ocr',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final extra = state.extra;
        String? imagePath;
        String? projectName;
        if (extra is Map<String, dynamic>) {
          imagePath = extra['imagePath'] as String?;
          projectName = extra['projectName'] as String?;
        }
        return CustomTransitionPage(
          child: ReceiptOcrScreen(
            initialImagePath: imagePath,
            initialProjectId: id.isNotEmpty ? id : null,
            projectId: id.isNotEmpty ? id : null,
            projectName: projectName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.receiptGallery,
      name: 'receipt-gallery',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const ReceiptGalleryScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.receiptDetail,
      name: 'receipt-detail',
      pageBuilder: (context, state) {
        final receiptId = state.pathParameters['id'] ?? '';

        return CustomTransitionPage(
          child: ReceiptDetailScreen(receiptId: receiptId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.reportsAnalytics,
      name: 'reports-analytics',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const ReportsAnalyticsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.projectReports,
      name: 'project-reports',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final projectName = state.extra as String? ?? 'Project';
        return CustomTransitionPage(
          child: ReportsAnalyticsScreen(
            projectId: id,
            projectName: projectName,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.notifications,
      name: 'notifications',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const NotificationsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),

    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.unitSettings,
      name: 'unitSettings',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const SettingsUnitScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ),
  ],
);
