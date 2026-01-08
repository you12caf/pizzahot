import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';

class ChangePhonePage extends StatefulWidget {
  const ChangePhonePage({super.key});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  static const Color _primaryOrange = Color(0xFFFC6011);

  final TextEditingController _codeController = TextEditingController();
  String _newPhoneNumber = '';
  String? _verificationId;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeFormVisible = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSending) return;
    final phone = _newPhoneNumber.trim();
    if (phone.isEmpty) {
      _showSnack('Enter a valid phone number');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Session expired. Please login again.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _updatePhone(credential, phone);
        },
        verificationFailed: (error) {
          _showSnack(error.message ?? 'Verification failed', isError: true);
        },
        codeSent: (verificationId, _) {
          setState(() {
            _verificationId = verificationId;
            _codeFormVisible = true;
          });
          _showSnack('Code sent to $phone');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _showSnack('Unable to send code: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _verifyAndUpdate() async {
    if (_isVerifying) return;
    final verificationId = _verificationId;
    if (verificationId == null) {
      _showSnack('Send a verification code first.', isError: true);
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnack('Enter the 6-digit code.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _updatePhone(credential, _newPhoneNumber.trim());
    } catch (e) {
      _showSnack('Failed to verify: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _updatePhone(
    PhoneAuthCredential credential,
    String newPhone,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Session expired. Please login again.', isError: true);
      return;
    }

    try {
      await user.updatePhoneNumber(credential);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'phone': newPhone,
          'phoneNumber': newPhone,
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      _showSnack('Phone updated successfully', isError: false);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? e.code, isError: true);
    } catch (e) {
      _showSnack('Failed to update phone: $e', isError: true);
    }
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
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Change Phone',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: size.height * 0.25,
                child: Center(
                  child: Container(
                    width: size.width * 0.6,
                    height: size.height * 0.2,
                    decoration: BoxDecoration(
                      color: _primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: _primaryOrange,
                      size: 72,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Securely update your phone number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify your new number with SMS to keep your account safe.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 32),
              IntlPhoneField(
                initialCountryCode: 'DZ',
                disableLengthCheck: true,
                decoration: InputDecoration(
                  labelText: 'New phone number',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(color: _primaryOrange, width: 2),
                  ),
                ),
                style: const TextStyle(fontSize: 18),
                onChanged: (phone) {
                  setState(() {
                    _newPhoneNumber = phone.completeNumber;
                  });
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _isSending ? null : _sendCode,
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
              if (_codeFormVisible) ...[
                const SizedBox(height: 32),
                const Text(
                  'Enter the 6-digit code',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Pinput(
                  controller: _codeController,
                  length: 6,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.grey.shade300, width: 1.5),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 64,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primaryOrange, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryOrange.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _isVerifying ? null : _verifyAndUpdate,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify & Update',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
