import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_order/config/app_config.dart';

// This provider exposes branding plus customer-facing support metadata.

class RestaurantThemeProvider with ChangeNotifier {
  static const String _fallbackRestaurantId = AppConfig.targetRestaurantId;
  static const String _defaultRestaurantName = 'My Restaurant';

  String? logoUrl;
  List<String> bannerImages = [];
  String? supportPhone;
  String? supportEmail;
  String? restaurantName = _defaultRestaurantName;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  /// Start listening for restaurant branding plus support channels.
  void startListening(String? restaurantId, BuildContext context) {
    final effectiveId = (restaurantId == null || restaurantId.isEmpty)
        ? _fallbackRestaurantId
        : restaurantId;

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(effectiveId)
        .snapshots()
        .listen((doc) {
      final data = doc.data() ?? {};
      logoUrl = data['logoUrl'] as String?;
      bannerImages = data['bannerImages'] != null
          ? List<String>.from(data['bannerImages'])
          : [];
      supportPhone = (data['supportPhone'] ?? '').toString().trim();
      supportEmail = (data['supportEmail'] ?? '').toString().trim();
      final fetchedName = (data['name'] ?? '').toString().trim();
      restaurantName =
          fetchedName.isNotEmpty ? fetchedName : _defaultRestaurantName;

      notifyListeners();
    });
  }

  // Color utilities removed — theme is now stable and hardcoded

  // Save current theme fields back to Firestore (merge)
  Future<void> saveToFirestore(String restaurantId) async {
    final data = <String, dynamic>{};
    if (logoUrl != null) data['logoUrl'] = logoUrl;
    if (bannerImages.isNotEmpty) data['bannerImages'] = bannerImages;
    if (data.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .set(data, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
