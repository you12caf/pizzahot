import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:food_order/pages/complete_profile_page.dart';
import 'package:food_order/services/auth/auth_check.dart';
import 'package:food_order/services/auth/auth_service.dart';
import 'package:pinput/pinput.dart';

class LoginOrRegisterPage extends StatefulWidget {
  const LoginOrRegisterPage({super.key});

  @override
  State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
}

enum AuthView { phoneInput, otpInput, profile }

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
  static const Color _primaryOrange = Color(0xFFFC6011);

  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isLoading = false;
  AuthView _currentView = AuthView.phoneInput;
  String? _currentVerificationId;
  String? _otpError;
  BuildContext? _activeSheetContext;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_isSending) return;

    String rawPhone = _phoneController.text.trim();
    // Remove leading zero if exists
    if (rawPhone.startsWith('0')) rawPhone = rawPhone.substring(1);

    // Hardcode DZ code for safety
    String finalPhone = '+213' + rawPhone;

    if (rawPhone.isEmpty) {
      _showSnack('Phone number is empty!');
      return;
    }

    print("🚀 SENDING TO FIREBASE: '$finalPhone'");

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    try {
      await _authService.verifyPhone(
        phoneNumber: finalPhone,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _isSending = false;
            if (verificationId.isNotEmpty) {
              _currentVerificationId = verificationId;
              _currentView = AuthView.otpInput;
            }
          });
          if (verificationId.isEmpty) return;
          _showOtpSheet(verificationId);
          _showSnack('Code sent to $finalPhone');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isSending = false);
          _showSnack(error.toString(), isError: true);
        },
        onAutoVerified: (status) {
          if (!mounted) return;
          setState(() => _isSending = false);
          _closeOtpSheetIfOpen();
          _routeAfterVerification();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showSnack('Unable to send code: $e', isError: true);
    }
  }

  Future<void> _verifyOtp(
      {required String verificationId, required String code}) async {
    // Capture navigator and scaffold up-front to avoid async-gap issues
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      await _authService.verifyOtp(
        verificationId: verificationId,
        smsCode: code,
      );
    } catch (e) {
      // If Firebase already signed the user in, let auth flow proceed
      if (FirebaseAuth.instance.currentUser != null) {
        if (mounted) setState(() => _isVerifying = false);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthCheck()),
          (route) => false,
        );
        return;
      }
      if (mounted) setState(() => _isVerifying = false);
      scaffold.showSnackBar(SnackBar(
        content: Text('Verification failed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Success: hide keyboard (best-effort)
    try {
      FocusScope.of(context).unfocus();
    } catch (_) {}

    // Close any open bottom sheet/dialog before navigation
    try {
      if (navigator.canPop()) navigator.pop();
    } catch (_) {}

    // Decide destination based on user document and force navigation using captured navigator
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        scaffold.showSnackBar(const SnackBar(
          content: Text('Session expired. Please try again.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthCheck()),
          (route) => false,
        );
      } else {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CompleteProfilePage()),
          (route) => false,
        );
      }
    } catch (e) {
      // If navigation fails, at least stop spinner and notify
      if (mounted) setState(() => _isVerifying = false);
      scaffold.showSnackBar(SnackBar(
        content: Text('Navigation failed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _closeOtpSheetIfOpen() {
    if (_activeSheetContext != null) {
      Navigator.of(_activeSheetContext!).pop();
      _activeSheetContext = null;
    }
  }

  Future<void> _showOtpSheet(String verificationId) async {
    setState(() => _otpError = null);
    _otpController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        _activeSheetContext = sheetContext;
        bool isVerifying = false;

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit({String? codeOverride}) async {
                if (isVerifying || _isVerifying) return;
                final code = (codeOverride ?? _otpController.text).trim();
                if (code.length != 6) {
                  _showSnack('Enter the 6-digit code.');
                  return;
                }
                // 1. Close keyboard IMMEDIATELY
                FocusScope.of(sheetContext).unfocus();
                // 2. Show spinner
                setSheetState(() {
                  isVerifying = true;
                  _otpError = null;
                });
                setState(() => _isVerifying = true);
                // 3. Verify OTP
                try {
                  await _authService.verifyOtp(
                    verificationId: verificationId,
                    smsCode: code,
                  );
                  // 4. SUCCESS: Force navigation
                  if (!mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/auth_check',
                    (route) => false,
                  );
                } catch (e) {
                  // 5. FAILURE: If user ended up signed in, proceed. Else show error.
                  final signedInUser = FirebaseAuth.instance.currentUser;
                  if (signedInUser != null && mounted) {
                    setSheetState(() {
                      _otpError = null;
                      isVerifying = false;
                    });
                    setState(() => _isVerifying = false);
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/auth_check',
                      (route) => false,
                    );
                    return;
                  }
                  setSheetState(() {
                    _otpError = 'Wrong Code';
                    isVerifying = false;
                  });
                  if (mounted) {
                    setState(() => _isVerifying = false);
                    _otpController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incorrect Code'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }

              final baseTheme = PinTheme(
                width: 56,
                height: 64,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
              );

              final focusedTheme = baseTheme.copyWith(
                decoration: baseTheme.decoration?.copyWith(
                  border: Border.all(color: _primaryOrange, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryOrange.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              );

              final errorTheme = baseTheme.copyWith(
                decoration: baseTheme.decoration?.copyWith(
                  border: Border.all(color: Colors.red, width: 2),
                  color: Colors.red.withOpacity(0.08),
                ),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Enter verification code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to your phone number.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  Pinput(
                    controller: _otpController,
                    length: 6,
                    defaultPinTheme: baseTheme,
                    focusedPinTheme: focusedTheme,
                    errorPinTheme: errorTheme,
                    keyboardType: TextInputType.number,
                    forceErrorState: _otpError != null,
                    errorText: _otpError,
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    onChanged: (_) {
                      if (_otpError != null) {
                        setSheetState(() => _otpError = null);
                      }
                    },
                    onCompleted: (pin) async {
                      if (_isVerifying) return;
                      // 1. Close keyboard IMMEDIATELY
                      FocusScope.of(context).unfocus();
                      // 2. Show spinner
                      setSheetState(() => isVerifying = true);
                      setState(() => _isVerifying = true);
                      // 3. Verify OTP
                      try {
                        await _authService.verifyOtp(
                          verificationId: verificationId,
                          smsCode: pin,
                        );
                        // 4. SUCCESS: Force navigation
                        if (!mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/auth_check',
                          (route) => false,
                        );
                      } catch (e) {
                        // 5. FAILURE: If user ended up signed in, proceed. Else show error.
                        final signedInUser = FirebaseAuth.instance.currentUser;
                        if (signedInUser != null && mounted) {
                          setSheetState(() => isVerifying = false);
                          setState(() => _isVerifying = false);
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/auth_check',
                            (route) => false,
                          );
                          return;
                        }
                        if (mounted) {
                          setSheetState(() => isVerifying = false);
                          setState(() => _isVerifying = false);
                          _otpController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Incorrect Code'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isVerifying || _isVerifying)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: (isVerifying || _isVerifying)
                            ? null
                            : () => submit(),
                        child: const Text(
                          'Verify & Continue',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() => _activeSheetContext = null);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
      ),
    );
  }

  Future<void> _routeAfterVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('Session expired. Please try again.', isError: true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthCheck()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CompleteProfilePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to verify account: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: size.height * 0.4,
              width: double.infinity,
              child: Center(
                child: Image.asset(
                  'images/login_hero.png',
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.restaurant,
                    size: 80,
                    color: Color(0xFFFC6011),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order your favorite food',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover top restaurants near you and track deliveries in real time.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    IntlPhoneField(
                      controller: _phoneController,
                      initialCountryCode: 'DZ',
                      disableLengthCheck: true,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide:
                              BorderSide(color: _primaryOrange, width: 2),
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _isSending ? null : _requestCode,
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send Code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
