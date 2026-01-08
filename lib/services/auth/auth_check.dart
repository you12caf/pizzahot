import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_order/admin_dashboard/subscription_guard.dart';
import 'package:food_order/admin_dashboard/admin_home.dart';
import 'package:food_order/pages/complete_profile_page.dart';
import 'package:food_order/pages/home_page.dart';
import 'package:food_order/services/auth/login_or_register.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';
import 'package:provider/provider.dart';

// Routes users based on their Firestore profile.
// Missing profile => force CompleteProfilePage until onboarding completes.
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginOrRegister();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }

            if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
              return const CompleteProfilePage();
            }

            final data = profileSnapshot.data!.data() ?? <String, dynamic>{};
            final role = (data['role'] ?? '').toString();
            final restaurantId = (data['restaurantId'] ?? '').toString();

            if (restaurantId.isNotEmpty) {
              try {
                Provider.of<RestaurantThemeProvider>(context, listen: false)
                    .startListening(restaurantId, context);
              } catch (_) {}
            }

            return role == 'owner'
                ? SubscriptionGuard(
                    restaurantId: restaurantId.isNotEmpty ? restaurantId : null,
                    child: const AdminHomeScreen(),
                  )
                : const HomePage();
          },
        );
      },
    );
  }
}

Widget _buildLoading() {
  return const Scaffold(
    backgroundColor: Colors.white,
    body: Center(child: CircularProgressIndicator()),
  );
}
