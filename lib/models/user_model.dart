import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String? email;
  final String? displayName;
  final String? role; // 'owner' or 'customer'
  final String? restaurantId; // assigned if role == 'owner'

  UserModel({
    this.id,
    this.email,
    this.displayName,
    this.role,
    this.restaurantId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (role != null) 'role': role,
      if (restaurantId != null) 'restaurantId': restaurantId,
    };
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      role: data['role'] as String?,
      restaurantId: data['restaurantId'] as String?,
    );
  }
}
