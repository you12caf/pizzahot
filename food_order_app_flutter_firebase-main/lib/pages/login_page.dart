import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_order/components/auth_main_top_container.dart';
import 'package:food_order/components/main_button.dart';
import 'package:food_order/components/main_text_filed.dart';
import 'package:food_order/constants/style.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;
  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_isSendingCode) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('Please enter your phone number.');
      return;
    }

    setState(() => _isSendingCode = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!mounted) return;
          _onAuthComplete();
        } catch (e) {
          if (!mounted) return;
          _showSnack('Auto verification failed: $e', isError: true);
        }
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _isSendingCode = false);
        _showSnack(e.message ?? 'Failed to send code.', isError: true);
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSendingCode = false;
        });
        _showSnack('Verification code sent.');
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_isVerifyingCode) return;
    final code = _otpController.text.trim();
    final verificationId = _verificationId;

    if (verificationId == null) {
      _showSnack('Please request a code first.', isError: true);
      return;
    }

    if (code.length != 6) {
      _showSnack('Enter the 6-digit code.', isError: true);
      return;
    }

    setState(() => _isVerifyingCode = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _auth.signInWithCredential(credential);
      if (!mounted) return;
      _onAuthComplete();
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Unable to verify code.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isVerifyingCode = false);
      }
    }
  }

  void _onAuthComplete() {
    setState(() {
      _isSendingCode = false;
      _isVerifyingCode = false;
      _otpController.clear();
    });
    _showSnack('Phone verified successfully.');
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

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthMainTopContainer(screenHeight: screenHeight),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  MainTextField(
                      icon: Icons.phone,
                      controller: _phoneController,
                      hintText: "+213 555 000 000",
                      obscureText: false,
                      keyboardType: TextInputType.phone),
                  const SizedBox(
                    height: 10,
                  ),
                  if (_verificationId != null) ...[
                    MainTextField(
                        icon: Icons.lock_outline_rounded,
                        controller: _otpController,
                        hintText: "Enter 6-digit code",
                        obscureText: false,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    MainButton(
                      text: _isVerifyingCode ? "Verifying..." : "Verify Code",
                      onTap: _verifyOtp,
                    ),
                    const SizedBox(height: 10),
                  ],
                  MainButton(
                    text: _isSendingCode ? "Sending..." : "Send Code",
                    onTap: _sendOtp,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Not a Member?",
                        style: smBoldTextStyle,
                      ),
                      TextButton(
                          onPressed: () {
                            widget.onTap!();
                          },
                          child: Text(
                            "Register",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .inversePrimary),
                          ))
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'We use SMS verification to keep your account secure.',
                    textAlign: TextAlign.center,
                    style: smBoldTextStyle.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
