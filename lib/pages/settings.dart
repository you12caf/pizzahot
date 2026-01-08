import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_order/config/app_config.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';
import 'package:food_order/models/restaurant.dart';
import 'package:food_order/services/notification_service.dart';
import 'package:food_order/pages/change_phone_page.dart';
import 'package:food_order/admin_dashboard/admin_home.dart';
import 'package:food_order/admin_dashboard/admin_orders.dart';
import 'package:food_order/admin_dashboard/admin_working_hours.dart';
import 'package:food_order/pages/printer_settings_page.dart';
import 'package:food_order/pages/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _primaryOrange = Color(0xFFFC6011);
  static const String _fallbackRestaurantId = AppConfig.targetRestaurantId;
  static const String _defaultSupportPhone = '+213 555 555 555';
  static const String _defaultSupportEmail = 'support@restodz.com';

  String? _userEmail;
  String? _userRole;
  String _restaurantId = _fallbackRestaurantId;
  String _displayName = '';
  String _phoneNumber = '';

  bool _isLoadingUser = true;
  bool _isSaving = false;
  bool _isSavingSupport = false;
  bool _notificationsEnabled = false;
  bool _isReadingPrefs = true;
  bool _biometricEnabled = false;

  final TextEditingController _logoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final List<TextEditingController> _bannerControllers = List.generate(
    3,
    (_) => TextEditingController(),
  );
  final TextEditingController _supportPhoneController = TextEditingController();
  final TextEditingController _supportEmailController = TextEditingController();

  bool get _isOwner {
    final role = (_userRole ?? '').toLowerCase();
    return role == 'owner' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _nameController.dispose();
    for (final c in _bannerControllers) {
      c.dispose();
    }
    _supportPhoneController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isReadingPrefs = true;
    });

    bool notificationsEnabled = false;
    try {
      await NotificationService().init();
      notificationsEnabled = NotificationService().getAlertEnabled();
    } catch (_) {}

    bool biometricEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _biometricEnabled = biometricEnabled;
      _isReadingPrefs = false;
    });
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.notification.request();
    final granted = status.isGranted;
    await NotificationService().init();
    await NotificationService().setAlertEnabled(granted);
    return granted;
  }

  Widget _buildProfileCard() {
    final rawEmail = (_userEmail ?? '').trim();
    final email = rawEmail.isNotEmpty ? rawEmail : '';
    final name = _displayName.isNotEmpty ? _displayName : 'Guest User';
    final phone =
        _phoneNumber.isNotEmpty ? _phoneNumber : 'Add your phone number';
    final roleKey = (_userRole ?? '').toLowerCase();
    String? roleLabel;
    TextStyle roleStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black45,
    );

    if (roleKey == 'owner') {
      roleLabel = 'RESTAURANT MANAGER';
      roleStyle = const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: _primaryOrange,
      );
    } else if (roleKey == 'customer') {
      roleLabel = 'Customer';
      roleStyle = const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      );
    } else if ((_userRole ?? '').isEmpty) {
      roleLabel = 'Guest';
    }

    final trimmedName = name.trim();
    final fallbackInitialSource = trimmedName.isNotEmpty
        ? trimmedName
        : (email.trim().isNotEmpty ? email.trim() : 'U');
    final initial = fallbackInitialSource.substring(0, 1).toUpperCase();

    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _primaryOrange.withOpacity(0.1),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryOrange,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (roleLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(roleLabel, style: roleStyle),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: _primaryOrange),
              onPressed: _showEditProfileDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message,
      {Color backgroundColor = const Color(0xFF222222)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('Unable to open ${uri.scheme} link',
            backgroundColor: Colors.red);
      }
    } catch (e) {
      _showSnackBar('Failed to open link: $e', backgroundColor: Colors.red);
    }
  }

  /// 1. Robust Data Loading
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _userEmail = 'Guest';
        _userRole = null;
        _restaurantId = _fallbackRestaurantId;
        _displayName = 'Guest';
        _phoneNumber = '';
        _isLoadingUser = false;
      });
      return;
    }

    String? email = user.email ?? ' ';
    String? role;
    String? restId;
    String displayName = '';
    String phoneNumber = '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        role = (data['role'] ?? '') as String?;
        restId = (data['restaurantId'] ?? '') as String?;
        displayName =
            (data['displayName'] ?? data['name'] ?? '').toString().trim();
        phoneNumber = (data['phoneNumber'] ?? '').toString().trim();
      }
    } catch (_) {}

    // CRITICAL FALLBACK: never leave restaurantId null/empty
    restId =
        (restId == null || restId.isEmpty) ? _fallbackRestaurantId : restId;

    if (!mounted) return;
    setState(() {
      _userEmail = email;
      _userRole = role;
      _restaurantId = restId!;
      _displayName = displayName;
      _phoneNumber = phoneNumber;
      _isLoadingUser = false;
    });

    if (!mounted) return;
    Provider.of<RestaurantThemeProvider>(context, listen: false)
        .startListening(_restaurantId, context);

    // Pre-fill branding inputs from current theme provider if owner
    if (_userRole == 'owner') {
      _loadRestaurantImages();
      _loadOwnerSupportConfig(_restaurantId);
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to edit profile', backgroundColor: Colors.red);
      return;
    }

    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _phoneNumber);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  suffixIcon: Icon(Icons.edit),
                  helperText: 'Tap to change your phone securely.',
                ),
                onTap: () {
                  Navigator.of(context).pop(false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePhonePage(),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      final updatedName = nameController.text.trim();
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'displayName': updatedName,
          },
          SetOptions(merge: true),
        );
        if (mounted) {
          setState(() {
            _displayName = updatedName;
          });
        }
        _showSnackBar('Profile updated',
            backgroundColor: const Color(0xFF2e7d32));
      } catch (e) {
        _showSnackBar('Update failed: $e', backgroundColor: Colors.red);
      }
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _loadRestaurantImages() async {
    final themeProvider =
        Provider.of<RestaurantThemeProvider>(context, listen: false);
    _logoController.text = themeProvider.logoUrl ?? '';
    final fetchedName =
        (themeProvider.restaurantName ?? 'My Restaurant').trim();
    _nameController.text =
        fetchedName.isNotEmpty ? fetchedName : 'My Restaurant';
    for (int i = 0; i < 3; i++) {
      if (i < themeProvider.bannerImages.length) {
        _bannerControllers[i].text = themeProvider.bannerImages[i];
      }
    }
  }

  Future<void> _loadOwnerSupportConfig(String restaurantId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        _supportPhoneController.text =
            (data['supportPhone'] ?? '').toString().trim();
        _supportEmailController.text =
            (data['supportEmail'] ?? '').toString().trim();
        final fetchedName = (data['name'] ?? '').toString().trim();
        if (fetchedName.isNotEmpty) {
          _nameController.text = fetchedName;
        }
      }
    } catch (_) {}
  }

  Future<void> _handleAlertToggle(bool enable) async {
    setState(() {
      _notificationsEnabled = enable;
    });

    try {
      if (enable) {
        final granted = await _requestPermission();
        if (!granted && mounted) {
          setState(() {
            _notificationsEnabled = false;
          });
        }
      } else {
        await NotificationService().setAlertEnabled(false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = !enable;
      });
    }
  }

  Future<void> _handleBiometricToggle(bool enable) async {
    final previous = _biometricEnabled;
    setState(() {
      _biometricEnabled = enable;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', enable);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricEnabled = previous;
      });
      _showSnackBar('Unable to update biometric setting',
          backgroundColor: Colors.red);
    }
  }

  /// 2. Save Branding Logic
  Future<void> _saveBranding() async {
    if (_isSaving) return;

    final String effectiveRestaurantId =
        (_restaurantId.isEmpty) ? _fallbackRestaurantId : _restaurantId;

    final String logo = _logoController.text.trim();
    final String restaurantName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'My Restaurant';
    final List<String> newBanners = _bannerControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(effectiveRestaurantId)
          .set(
        {
          'logoUrl': logo,
          'bannerImages': newBanners,
          'name': restaurantName,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // Refresh branding instantly in the app
      Provider.of<RestaurantThemeProvider>(context, listen: false)
          .startListening(effectiveRestaurantId, context);

      _showSnackBar('Saved successfully',
          backgroundColor: const Color(0xFF2e7d32));
    } catch (e) {
      _showSnackBar('Error: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveSupportInfo() async {
    if (_isSavingSupport) return;

    final String effectiveRestaurantId =
        (_restaurantId.isEmpty) ? _fallbackRestaurantId : _restaurantId;

    final String phone = _supportPhoneController.text.trim();
    final String email = _supportEmailController.text.trim();

    setState(() {
      _isSavingSupport = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(effectiveRestaurantId)
          .set(
        {
          'supportPhone': phone,
          'supportEmail': email,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Provider.of<RestaurantThemeProvider>(context, listen: false)
          .startListening(effectiveRestaurantId, context);
      _showSnackBar('Support info saved',
          backgroundColor: const Color(0xFF2e7d32));
    } catch (e) {
      _showSnackBar('Failed to save support info: $e',
          backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSupport = false;
        });
      }
    }
  }

  Future<void> _handleCallSupport(String? phone) async {
    final value = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : _defaultSupportPhone;
    final normalized = value.replaceAll(' ', '');
    await _launchExternal(Uri(scheme: 'tel', path: normalized));
  }

  Future<void> _handleEmailSupport(String? email) async {
    final value = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : _defaultSupportEmail;
    await _launchExternal(Uri(scheme: 'mailto', path: value));
  }

  void _showPhoneLockedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Phone number locked'),
          content: const Text(
            'To update your phone number, please logout and sign back in with the new number. This keeps your account secure.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    Provider.of<Restaurant>(context, listen: false).clearCart();
    final notificationService = NotificationService();
    await notificationService.stopListening();
    await notificationService.cancelAllAndStop();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginOrRegisterPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  if (_isOwner) ...[
                    _buildSupportConfigCard(),
                    const SizedBox(height: 16),
                    _buildBrandingSection(),
                    const SizedBox(height: 16),
                    _buildNotificationsSection(),
                    // --- Working Hours Button ---
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 5)
                        ],
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled,
                            color: Color(0xFFFC6011)),
                        title: const Text("Working Hours",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Set Open/Close times"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminWorkingHoursScreen()));
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildManagementSection(),
                  ] else ...[
                    _buildSupportSection(),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _buildSupportSection() {
    return Consumer<RestaurantThemeProvider>(
      builder: (context, theme, _) {
        final phone = (theme.supportPhone != null &&
                theme.supportPhone!.trim().isNotEmpty)
            ? theme.supportPhone!.trim()
            : _defaultSupportPhone;
        final email = (theme.supportEmail != null &&
                theme.supportEmail!.trim().isNotEmpty)
            ? theme.supportEmail!.trim()
            : _defaultSupportEmail;

        return _buildSectionCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.phone, color: _primaryOrange),
                title: const Text('Call Support'),
                subtitle: Text(phone),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _handleCallSupport(phone),
              ),
              const Divider(height: 0),
              ListTile(
                leading:
                    const Icon(Icons.email_outlined, color: _primaryOrange),
                title: const Text('Email Support'),
                subtitle: Text(email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _handleEmailSupport(email),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportConfigCard() {
    if (!_isOwner) return const SizedBox.shrink();

    return _buildSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Support Info Configuration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supportPhoneController,
              decoration: const InputDecoration(
                labelText: 'Support phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supportEmailController,
              decoration: const InputDecoration(
                labelText: 'Support email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSavingSupport ? null : _saveSupportInfo,
                child: _isSavingSupport
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Support Info',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection() {
    return _buildSectionCard(
      child: ExpansionTile(
        title: const Text(
          'Branding (Logo & Banners)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: const Icon(Icons.image_rounded, color: _primaryOrange),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _logoController,
            decoration: const InputDecoration(
              labelText: 'Logo URL',
              helperText: 'Recommended: 500x500 px (PNG)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bannerControllers[0],
            decoration: const InputDecoration(
              labelText: 'Banner 1 URL',
              helperText: 'Recommended: 1200x600 px (JPG)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bannerControllers[1],
            decoration: const InputDecoration(
              labelText: 'Banner 2 URL',
              helperText: 'Recommended: 1200x600 px (JPG)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bannerControllers[2],
            decoration: const InputDecoration(
              labelText: 'Banner 3 URL',
              helperText: 'Recommended: 1200x600 px (JPG)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF44336),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : _saveBranding,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Images',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return _buildSectionCard(
      child: Column(
        children: [
          _isReadingPrefs
              ? ListTile(
                  title: const Text(
                    'Order Alerts 🔔',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : SwitchListTile(
                  title: const Text(
                    'Order Alerts 🔔',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: _notificationsEnabled,
                  activeColor: _primaryOrange,
                  onChanged: (val) => _handleAlertToggle(val),
                ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.touch_app, color: Colors.blue),
            title: const Text('Test Alert Sound'),
            onTap: () async {
              await NotificationService().playSound();
              await NotificationService().showNotification(
                'Test',
                'System works!',
                payload: 'test',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection() {
    return _buildSectionCard(
      child: Column(
        children: [
          _isReadingPrefs
              ? ListTile(
                  leading: const Icon(Icons.fingerprint, color: _primaryOrange),
                  title: const Text(
                    'Biometric Security 🔒',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  secondary:
                      const Icon(Icons.fingerprint, color: _primaryOrange),
                  title: const Text(
                    'Biometric Security 🔒',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Require biometrics before opening admin screens',
                  ),
                  value: _biometricEnabled,
                  activeColor: _primaryOrange,
                  onChanged: _handleBiometricToggle,
                ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_rounded,
                color: _primaryOrange),
            title: const Text('Manage Menu'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded,
                color: Colors.blueAccent),
            title: const Text('Manage Orders'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.print_rounded, color: Colors.teal),
            title: const Text('Printer Settings'),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFF44336)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
