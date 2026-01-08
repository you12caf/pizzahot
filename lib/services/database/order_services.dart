import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_order/models/order.dart' as app_order;

class FirestoreService {
  final CollectionReference orders =
      FirebaseFirestore.instance.collection('orders');

  Future<void> saveOrderToDatabase(String receipt) async {
    await orders.add({
      'date': DateTime.now(),
      'order': receipt,
    });
  }

  Future<DocumentReference> addOrder(app_order.Order order) async {
    // 1. Force-authenticate: userId must come from FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to place an order.');
    }

    // 2. Sanitize textual inputs
    final String? rawName = order.customerName?.trim();
    final String? rawPhone = order.phone?.trim();
    final String? rawAddress = order.address?.trim();

    if (rawName == null || rawName.isEmpty) {
      throw Exception('Customer name is required.');
    }
    if (rawPhone == null || rawPhone.isEmpty) {
      throw Exception('Phone number is required.');
    }
    if (rawAddress == null || rawAddress.isEmpty) {
      throw Exception('Address is required.');
    }

    // 3. Calculate / validate total price
    double? total = order.total;
    if (total != null) {
      if (total <= 0) {
        throw Exception('Total price must be positive.');
      }
    }

    // 4. Build secure payload for Firestore (do not trust client fields)
    final Map<String, dynamic> data = {};

    // Items / receipt come from the Order model as-is
    if (order.receipt != null) data['order'] = order.receipt;
    if (order.items != null) data['items'] = order.items;
    if (total != null) data['total'] = total;

    // Force server timestamp and initial status
    data['date'] = FieldValue.serverTimestamp();
    data['status'] = 'pending';
    data['paymentMethod'] = order.paymentMethod;

    // Hard bind to authenticated user
    data['customerId'] = user.uid;
    data['customerName'] = rawName;
    data['phone'] = rawPhone;
    data['address'] = rawAddress;

    // Ensure restaurantId is explicitly saved with the order
    if (order.restaurantId != null && order.restaurantId!.isNotEmpty) {
      data['restaurantId'] = order.restaurantId;
    }

    return await orders.add(data);
  }
}
