import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String? id;
  final String? receipt; // legacy string receipt
  final List<Map<String, dynamic>>? items; // structured items (optional)
  final double? total;
  final DateTime date;
  final String status;
  final String paymentMethod;
  final String? restaurantId;
  final String? customerId;
  final String? customerName;
  final String? phone;
  final String? address;

  Order({
    this.id,
    this.receipt,
    this.items,
    this.total,
    DateTime? date,
    this.status = 'pending',
    this.paymentMethod = 'cod',
    this.restaurantId,
    this.customerId,
    this.customerName,
    this.phone,
    this.address,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (receipt != null) 'order': receipt,
      if (items != null) 'items': items,
      if (total != null) 'total': total,
      'date': date,
      'status': status,
      'paymentMethod': paymentMethod,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    };
  }

  factory Order.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Order(
      id: doc.id,
      receipt: data['order'] as String?,
      items: data['items'] != null
          ? List<Map<String, dynamic>>.from(data['items'])
          : null,
      total: data['total'] != null
          ? (data['total'] is int)
              ? (data['total'] as int).toDouble()
              : (data['total'] as double?)
          : null,
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? 'cod',
      restaurantId: data['restaurantId'],
      customerId: data['customerId'],
      customerName: data['customerName'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
    );
  }
}
