// main.dart (alternative with loading handling)
import 'package:flutter/material.dart';
import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/providers/currency_provider.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
import 'package:projectrack1/service/notification_scheduler_service.dart';
import 'package:provider/provider.dart';
import 'package:projectrack1/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize providers
  final themeProvider = ThemeProvider();
  final databaseProvider = DriftDatabaseProvider();

  // Initialize database
  await databaseProvider.initializeDriftDatabase();

  final currencyProvider = CurrencyProvider();
  currencyProvider.setDatabase(databaseProvider.database);

  final authProvider = AuthProvider(database: databaseProvider.database);

  // OS reminders for budget / schedule / missing logs / receipts.
  await NotificationSchedulerService.instance.initialize();
  // Defer first schedule until after first frame when auth/user projects load.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationSchedulerService.instance
          .refreshFromProvider(databaseProvider);
    } catch (_) {}
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<DriftDatabaseProvider>.value(
          value: databaseProvider,
        ),
        ChangeNotifierProvider<CurrencyProvider>.value(value: currencyProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _shouldLockOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Camera/gallery/biometric sheets background the app — do not lock then.
      if (auth.shouldSuppressBiometricLock) {
        _shouldLockOnResume = false;
        return;
      }
      _shouldLockOnResume = auth.isAuthenticated && auth.biometricEnabled;
      return;
    }
    if (state == AppLifecycleState.resumed && _shouldLockOnResume) {
      _shouldLockOnResume = false;
      if (auth.shouldSuppressBiometricLock) return;
      auth.requireBiometricUnlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, DriftDatabaseProvider>(
      builder: (context, themeProvider, dbProvider, _) {
        // Show loading if database not ready
        if (!dbProvider.isInitialized) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      dbProvider.error ?? 'Initializing database...',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Show error if database failed
        if (dbProvider.error != null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Database Error: ${dbProvider.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await dbProvider.initializeDriftDatabase();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Normal app with router
        return MaterialApp.router(
          title: 'ProjectRack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
