import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionExpiredPage extends StatelessWidget {
  const SubscriptionExpiredPage({super.key, this.expiry, this.errorMessage});

  final DateTime? expiry;
  final String? errorMessage;

  static const String _supportPhone = '0658043043';
  static const Color _primaryOrange = Color(0xFFFC6011);
  static const Color _whatsAppGreen = Color(0xFF25D366);
  static const Color _surface = Color(0xFFF4F6FA);

  Future<void> _launch(BuildContext context, Uri uri) async {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link. Please try again.')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiryText =
        expiry != null ? 'Expired on ${expiry!.toLocal()}' : null;
    final whatsappMessage = Uri.encodeComponent(
      'Hi, my subscription appears expired. Please help me renew.',
    );

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE3E8F0), Color(0xFFD6DEEA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Service Suspended',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Renewal required to manage orders. Customers can still place orders and generate revenue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
                    if (expiryText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        expiryText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launch(
                              context,
                              Uri.parse(
                                  'https://wa.me/$_supportPhone?text=$whatsappMessage'),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Renew via WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _whatsAppGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launch(
                              context,
                              Uri.parse('tel:$_supportPhone'),
                            ),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call Support'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
