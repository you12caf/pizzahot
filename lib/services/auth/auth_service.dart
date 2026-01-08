import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:food_order/config/app_config.dart';
import 'package:food_order/providers/user_provider.dart';

enum AuthUserStatus { userExists, newUser }

class AuthService {
  static RecaptchaVerifier? _webVerifier;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _latestPhoneNumber;
  ConfirmationResult? _webConfirmationResult;

  User? getCurrentUser() => _firebaseAuth.currentUser;

  RecaptchaVerifier _getRecaptchaVerifier() {
    if (_webVerifier == null) {
      _webVerifier = RecaptchaVerifier(
        auth: FirebaseAuthPlatform.instance,
        container: 'recaptcha-container',
      );
    }
    return _webVerifier!;
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(Exception error) onError,
    void Function(AuthUserStatus status)? onAutoVerified,
  }) async {
    final formattedPhone = phoneNumber.trim();
    if (formattedPhone.isEmpty) {
      onError(Exception('Please enter a valid phone number.'));
      return;
    }

    _latestPhoneNumber = formattedPhone;

    try {
      if (kIsWeb) {
        try {
          final verifier = _getRecaptchaVerifier();
          // Trigger Auth
          final result = await _firebaseAuth.signInWithPhoneNumber(
              formattedPhone, verifier);
          _webConfirmationResult = result;
          onCodeSent('WEB_ID');
          // Best-effort: remove/hide recaptcha widget immediately after sending code
          try {
            _webVerifier?.clear();
          } catch (e) {
            // ignore
          }
        } catch (e) {
          // Clean up verifier to allow fresh retries
          try {
            _webVerifier?.clear();
          } catch (_) {}
          _webVerifier = null;
          onError(Exception('Failed to send code. Please try again later.'));
        }
        return;
      } else {
        await _firebaseAuth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              final status = await _signInWithCredential(credential);
              onAutoVerified?.call(status);
            } on FirebaseAuthException catch (e) {
              onError(Exception(e.message ?? e.code));
            } catch (e) {
              onError(Exception(e.toString()));
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            onError(Exception(e.message ?? e.code));
          },
          codeSent: (String verificationId, int? _) {
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      }
    } on FirebaseAuthException catch (e) {
      onError(Exception(e.message ?? e.code));
    } catch (e) {
      onError(Exception(e.toString()));
    }
  }

  Future<AuthUserStatus> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      if (kIsWeb) {
        final userCredential = await _webConfirmationResult!.confirm(smsCode);
        final user = userCredential.user;
        if (user == null) throw Exception('Unable to sign in.');

        final doc = await _firestore.collection('users').doc(user.uid).get();
        _webVerifier?.clear();
        return doc.exists ? AuthUserStatus.userExists : AuthUserStatus.newUser;
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        return await _signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }

  Future<AuthUserStatus> _signInWithCredential(
      PhoneAuthCredential credential) async {
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Unable to sign in. Please try again.');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists ? AuthUserStatus.userExists : AuthUserStatus.newUser;
  }

  Future<void> createUserProfile({
    required String fullName,
    String restaurantId = AppConfig.targetRestaurantId,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to continue.');
    }

    final phone = user.phoneNumber ?? _latestPhoneNumber;

    final payload = {
      'uid': user.uid,
      'displayName': fullName,
      'name': fullName,
      'phone': phone,
      'phoneNumber': phone,
      'role': 'customer',
      'restaurantId': restaurantId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(user.uid).set(
          payload,
          SetOptions(merge: true),
        );
  }

  Future<void> signOut(BuildContext context) async {
    Provider.of<UserProvider>(context, listen: false).clearData();
    await _firebaseAuth.signOut();
  }

  Future<String?> getCurrentUserRole() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return null;
      return (data['role'] ?? '') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isOwner() async {
    final role = await getCurrentUserRole();
    return role == 'owner';
  }
}
