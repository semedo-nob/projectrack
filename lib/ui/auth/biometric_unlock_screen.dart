import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/drift_database_provider.dart';
import '../../routes/app_routes.dart';
import '../../themes/app_colors.dart';

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _isUnlocking = false;

  Future<void> _unlock() async {
    setState(() => _isUnlocking = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final db = Provider.of<DriftDatabaseProvider>(context, listen: false);
    final ok = await auth.loginWithBiometrics();
    if (!mounted) return;
    setState(() => _isUnlocking = false);

    if (ok) {
      final uid = auth.currentUser?.id;
      if (uid != null) db.setActiveUserId(uid);
      context.go(AppRoutes.home);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.errorMessage ?? 'Biometric unlock failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock ProjectRack',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Biometric security is enabled for this account. Authenticate to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUnlocking ? null : _unlock,
                      icon: _isUnlocking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(
                        _isUnlocking
                            ? 'Unlocking...'
                            : 'Unlock with Biometrics',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).dismissBiometricLock();
                      if (!context.mounted) return;
                      context.go(AppRoutes.login);
                    },
                    child: const Text('Use email and password instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
