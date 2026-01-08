import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_order/pages/settings.dart';
import 'package:food_order/pages/home_page.dart';
import 'package:food_order/pages/my_orders_page.dart';
import 'package:food_order/admin_dashboard/admin_home.dart';
import 'package:food_order/admin_dashboard/admin_categories.dart';
import 'package:food_order/admin_dashboard/admin_orders.dart';
import 'package:food_order/models/restaurant.dart';
import 'package:food_order/providers/user_provider.dart';
import 'package:food_order/services/auth/auth_service.dart';
import 'package:food_order/services/auth/login_or_register.dart';
import 'package:food_order/services/biometric_service.dart';
import 'package:food_order/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _requestedProfileLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      if (!_requestedProfileLoad && userProvider.uid == null) {
        _requestedProfileLoad = true;
        userProvider.fetchUserData();
      }
    });
  }

  Future<void> _navigateTo(Widget page, {bool clearStack = false}) async {
    Navigator.pop(context); // close drawer first for smooth transition
    if (clearStack) {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (c) => page),
        (route) => false,
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => page),
      );
    }
  }

  Future<void> _logout() async {
    Provider.of<Restaurant>(context, listen: false).clearCart();
    Navigator.pop(context);
    final notificationService = NotificationService();
    await notificationService.stopListening();
    await notificationService.cancelAllAndStop();
    await AuthService().signOut(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (c) => const LoginOrRegister()),
      (route) => false,
    );
  }

  Future<bool> _isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_enabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requireBiometricAuth() async {
    final didAuthenticate = await BiometricService().authenticateOwner();
    if (!didAuthenticate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return didAuthenticate;
  }

  Future<void> _navigateSecureAdminPage(Widget page) async {
    final bool owner = await AuthService().isOwner();
    if (!owner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: Owner role required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool requireBiometric = await _isBiometricEnabled();
    if (requireBiometric) {
      final bool authenticated = await _requireBiometricAuth();
      if (!authenticated) {
        return;
      }
    }

    if (!mounted) return;
    await _navigateTo(page);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final nameLabel = (userProvider.name ?? '').trim();
    final emailLabel = (userProvider.email ?? '').trim();
    final shownName = nameLabel.isNotEmpty
        ? nameLabel
        : (emailLabel.isNotEmpty ? emailLabel : 'Guest');
    final subtitleLabel = userProvider.isLoading
        ? null
        : (emailLabel.isNotEmpty ? emailLabel : null);
    final profileSeed = nameLabel.isNotEmpty ? nameLabel : emailLabel;
    final avatarInitial = profileSeed.isNotEmpty
        ? profileSeed.substring(0, 1).toUpperCase()
        : 'G';
    final isOwner = (userProvider.role ?? '').toLowerCase() == 'owner';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Header: minimalist, white, premium
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(
                  top: 40, left: 20, right: 20, bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Elevated avatar
                  Material(
                    elevation: 4,
                    shape: const CircleBorder(),
                    shadowColor: Colors.black.withOpacity(0.08),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        avatarInitial,
                        style: const TextStyle(
                          color: Color(0xFFFC6011),
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shownName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (userProvider.isLoading) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Loading profile...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ] else if (subtitleLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(indent: 20, endIndent: 20, height: 1),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildMenuItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => _navigateTo(
                      const HomePage(),
                      clearStack: true,
                    ),
                  ),
                  _buildMenuItem(
                    icon: Icons.shopping_bag,
                    label: 'My Orders',
                    onTap: () => _navigateTo(const MyOrdersPage()),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () async {
                      if (isOwner) {
                        final requireBiometric = await _isBiometricEnabled();
                        if (requireBiometric) {
                          final ok = await _requireBiometricAuth();
                          if (!ok) return;
                        }
                      }
                      await _navigateTo(const SettingsPage());
                    },
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 12),
                    const Divider(indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 6.0),
                      child: Text(
                        'ADMIN PANEL',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.grey[600],
                            ),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.fastfood_rounded,
                      label: 'Manage Menu',
                      onTap: () => _navigateSecureAdminPage(
                        const AdminHomeScreen(),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Manage Categories',
                      onTap: () => _navigateSecureAdminPage(
                        const AdminCategoriesScreen(),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      onTap: () => _navigateSecureAdminPage(
                        const AdminOrdersScreen(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Elegant logout pill at the bottom
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _logout,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[800], size: 22),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        horizontalTitleGap: 12,
        onTap: onTap,
      ),
    );
  }
}
