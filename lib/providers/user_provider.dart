import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  String? uid;
  String? email;
  String? name;
  String? role;
  String? restaurantId;
  bool isLoading = false;

  Future<void> fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      clearData();
      return;
    }

    _setLoading(true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = userDoc.data();

      final docName =
          (data?['displayName'] ?? data?['name'] ?? '').toString().trim();
      final resolvedName = docName.isNotEmpty
          ? docName
          : (currentUser.displayName ?? '').trim().isNotEmpty
              ? (currentUser.displayName ?? '').trim()
              : _fallbackName(currentUser.email);

      uid = currentUser.uid;
      email = (currentUser.email ?? data?['email']?.toString())?.trim();
      name = resolvedName.isNotEmpty ? resolvedName : 'User';
      final roleValue = (data?['role'] ?? '').toString().trim();
      role = roleValue.isNotEmpty ? roleValue : null;
      final restaurantValue = (data?['restaurantId'] ?? '').toString().trim();
      restaurantId = restaurantValue.isNotEmpty ? restaurantValue : null;
    } catch (_) {
      clearData();
      return;
    }

    _setLoading(false);
    notifyListeners();
  }

  void clearData() {
    uid = null;
    email = null;
    name = null;
    role = null;
    restaurantId = null;
    final wasLoading = isLoading;
    isLoading = false;
    if (wasLoading) {
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (isLoading != value) {
      isLoading = value;
      notifyListeners();
    }
  }

  String _fallbackName(String? email) {
    if (email == null || email.isEmpty) {
      return 'User';
    }
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return email;
    }
    final prefix = email.substring(0, atIndex).trim();
    return prefix.isNotEmpty ? prefix : 'User';
  }
}
