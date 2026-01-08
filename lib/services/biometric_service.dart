import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticateOwner() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) {
        if (kDebugMode) {
          debugPrint('Biometric auth unavailable on this device.');
        }
        return false;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to access Admin Panel',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Biometric auth failed: $e');
      }
      return false;
    }
  }
}
