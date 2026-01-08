import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_order/models/food.dart';

class FoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch food menu. If [restaurantId] is provided, only foods for that
  /// restaurant are returned. If null, returns all foods.
  Future<List<Food>> fetchFoodMenu({String? restaurantId}) async {
    Query query = _firestore.collection('foods');
    if (restaurantId != null) {
      query = query.where('restaurantId', isEqualTo: restaurantId);
    }
    final QuerySnapshot snapshot = await query.get();
    return snapshot.docs.map((doc) {
      // preserve document id by using fromDoc
      return Food.fromDoc(doc);
    }).toList();
  }
}
