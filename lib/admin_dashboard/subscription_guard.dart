import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_order/config/app_config.dart';
import 'package:food_order/pages/subscription_expired_page.dart';

class SubscriptionGuard extends StatelessWidget {
  const SubscriptionGuard({super.key, required this.child, this.restaurantId});

  final Widget child;
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    final targetId = (restaurantId ?? '').isNotEmpty
        ? restaurantId!
        : AppConfig.targetRestaurantId;

    final stream = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(targetId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const SubscriptionExpiredPage(
            errorMessage: 'Unable to verify subscription status.',
          );
        }

        final data = snapshot.data?.data();
        final rawExpiry = data?['subscriptionExpiry'];
        DateTime? expiry;
        if (rawExpiry is Timestamp) {
          expiry = rawExpiry.toDate();
        } else if (rawExpiry is DateTime) {
          expiry = rawExpiry;
        }

        // Safety default: missing expiry => allow access
        final expired = expiry != null && DateTime.now().isAfter(expiry);
        if (expired) {
          return SubscriptionExpiredPage(expiry: expiry);
        }

        return child;
      },
    );
  }
}
