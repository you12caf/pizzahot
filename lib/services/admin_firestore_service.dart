import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_order/models/food.dart';
import 'package:food_order/models/order.dart' as app_order;

class AdminFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _foods => _firestore.collection('foods');
  CollectionReference get _orders => _firestore.collection('orders');
  CollectionReference restaurants(String id) =>
      _firestore.collection('restaurants');

  Stream<List<Food>> streamFoodsForRestaurant(String restaurantId) {
    final query = _foods.where('restaurantId', isEqualTo: restaurantId);
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Food.fromDoc(doc)).toList(growable: false));
  }

  Future<DocumentReference> addFoodForRestaurant(
      Food food, String restaurantId) {
    final data = food.toMap();
    data['restaurantId'] = restaurantId;
    return _foods.add(data);
  }

  Future<void> updateFoodForRestaurant(String id, Food food) async {
    final data = food.toMap();
    await _foods.doc(id).update(data);
  }

  Future<void> deleteFood(String id) async {
    await _foods.doc(id).delete();
  }

  // Categories under restaurants/{id}/categories
  Stream<List<Map<String, dynamic>>> streamCategoriesForRestaurant(
      String restaurantId) {
    final coll = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories');
    return coll.snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'docId': d.id,
          'id': data['id'] as String? ?? d.id,
          'name': data['name'] as String? ?? '',
          'createdAt': data['createdAt'], // may be null or a Timestamp
        };
      }).toList(growable: false);

      // Client-side sort: place documents without createdAt first, then by createdAt (oldest -> newest)
      list.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return -1;
        if (bTs == null) return 1;
        try {
          final aDate = (aTs is Timestamp)
              ? aTs.toDate()
              : (aTs is DateTime ? aTs : DateTime.parse(aTs.toString()));
          final bDate = (bTs is Timestamp)
              ? bTs.toDate()
              : (bTs is DateTime ? bTs : DateTime.parse(bTs.toString()));
          return aDate.compareTo(bDate);
        } catch (_) {
          return 0;
        }
      });

      return list;
    });
  }

  Future<DocumentReference> addCategoryForRestaurant(
      String restaurantId, String name, String id) async {
    final coll = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories');
    return await coll.add({
      'name': name,
      'id': id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategoryForRestaurant(
      String restaurantId, String docId, String name, String id) async {
    final doc = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories')
        .doc(docId);
    await doc.update({'name': name, 'id': id});
  }

  Future<void> deleteCategoryForRestaurant(
      String restaurantId, String docId) async {
    final doc = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories')
        .doc(docId);
    await doc.delete();
  }

  // Restaurant settings
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRestaurant(String id) {
    return _firestore.collection('restaurants').doc(id).snapshots();
  }

  Future<void> updateRestaurantSettings(
      String id, Map<String, dynamic> data) async {
    await _firestore
        .collection('restaurants')
        .doc(id)
        .set(data, SetOptions(merge: true));
  }

  Stream<List<app_order.Order>> streamOrdersForRestaurant(String restaurantId) {
    final query = _orders.where('restaurantId', isEqualTo: restaurantId);
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => app_order.Order.fromDoc(doc))
        .toList(growable: false));
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    await _orders.doc(orderId).update(updates);
  }

  Future<void> deleteOrder(String id) async {
    await _orders.doc(id).delete();
  }
}
