// main.dart (alternative with loading handling)
import 'package:flutter/material.dart';
import 'package:projectrack1/providers/auth_provider.dart';
import 'package:projectrack1/providers/currency_provider.dart';
import 'package:projectrack1/providers/drift_database_provider.dart';
import 'package:projectrack1/providers/theme_provider.dart';
import 'package:projectrack1/routes/app_routes.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<DriftDatabaseProvider>.value(value: databaseProvider),
        ChangeNotifierProvider<CurrencyProvider>.value(value: currencyProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, DriftDatabaseProvider>(
      builder: (context, themeProvider, dbProvider, _) {
        // Show loading if database not ready
        if (!dbProvider.isInitialized) {
          return MaterialApp(
            debugShowCheckedModeBanner:false,
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
            debugShowCheckedModeBanner:false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Database Error: ${dbProvider.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Retry initialization
                        // You might want to add a retry method
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