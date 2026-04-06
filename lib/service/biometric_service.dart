// lib/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String? _lastError;

  String? get lastError => _lastError;

  Future<bool> isAvailable() async {
    try {
      _lastError = null;
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();
      if (!isSupported) {
        _lastError = 'This device does not support secure authentication.';
        return false;
      }
      if (!canCheckBiometrics || biometrics.isEmpty) {
        _lastError =
            'No biometric methods are enrolled. Add a fingerprint or face unlock in device settings.';
        return false;
      }
      return true;
    } catch (e) {
      _lastError = _friendlyMessage(e);
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      _lastError = null;
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      _lastError = _friendlyMessage(e);
      return [];
    }
  }

  Future<bool> authenticate() async {
    try {
      _lastError = null;
      final available = await getAvailableBiometrics();
      if (available.isEmpty) {
        _lastError ??=
            'No biometric methods are available on this device yet.';
        return false;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      _lastError = _friendlyMessage(e);
      return false;
    }
  }

  String _friendlyMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('notenrolled') || lower.contains('not enrolled')) {
      return 'No fingerprint or face unlock is enrolled on this device.';
    }
    if (lower.contains('notavailable') || lower.contains('not available')) {
      return 'Biometric authentication is not available on this device.';
    }
    if (lower.contains('temporarylockout') || lower.contains('lockedout')) {
      return 'Biometric authentication is temporarily locked. Try again in a moment.';
    }
    if (lower.contains('permanentlylockedout')) {
      return 'Biometric authentication is locked. Unlock it in device security settings first.';
    }
    if (lower.contains('passcode not set') ||
        lower.contains('security update required') ||
        lower.contains('device credentials')) {
      return 'Set a secure screen lock on this device before enabling biometrics.';
    }
    if (lower.contains('no_fragment_activity')) {
      return 'Biometric authentication needs a compatible Android activity. Rebuild the app after updating platform files.';
    }

    return text;
  }
}
