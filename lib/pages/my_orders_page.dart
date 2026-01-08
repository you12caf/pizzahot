import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/models/order.dart' as app_order;
import 'package:food_order/services/notification_service.dart';
import 'package:intl/intl.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  static const Duration _reviewReminderDelay = Duration(minutes: 30);
  static const int _cancelCountdownSeconds = 10;
  final Set<String> _scheduledReminders = <String>{};
  final Map<String, Timer> _cancelTimers = <String, Timer>{};
  final Map<String, ValueNotifier<int>> _cancelCountdowns =
      <String, ValueNotifier<int>>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream(String uid) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلباتي',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[50],
      body: uid == null
          ? const Center(
              child: Text('يرجى تسجيل الدخول لعرض طلباتك'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child:
                        Text('حدث خطأ أثناء تحميل الطلبات: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text('لا توجد طلبات حالياً'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final order = app_order.Order.fromDoc(doc);
                    _maybeScheduleReviewReminder(doc);
                    return _OrderCard(
                      order: order,
                      rawData: doc.data(),
                      onConfirmDelivery: () => _confirmDelivery(order),
                      onRate: () => _openRatingDialog(order),
                      onCancel: () => _startCancelCountdown(order),
                    );
                  },
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    for (final timer in _cancelTimers.values) {
      timer.cancel();
    }
    for (final notifier in _cancelCountdowns.values) {
      notifier.dispose();
    }
    _cancelTimers.clear();
    _cancelCountdowns.clear();
    super.dispose();
  }

  void _maybeScheduleReviewReminder(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return;

    final status = (data['status'] ?? '').toString().toLowerCase();
    final bool isRated = data['isRated'] == true;
    final bool alreadyScheduled = data['reviewReminderScheduled'] == true;

    if (status != 'delivered' || isRated || alreadyScheduled) {
      return;
    }

    if (_scheduledReminders.contains(doc.id)) {
      return;
    }

    _scheduledReminders.add(doc.id);

    NotificationService()
        .scheduleReviewReminder(doc.id, delay: _reviewReminderDelay)
        .then((_) {
      return FirebaseFirestore.instance
          .collection('orders')
          .doc(doc.id)
          .update({'reviewReminderScheduled': true});
    }).catchError((_) {
      _scheduledReminders.remove(doc.id);
    });
  }

  Future<void> _confirmDelivery(app_order.Order order) async {
    if (order.id == null) return;

    _scheduledReminders.add(order.id!);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id!)
          .update({
        'status': 'delivered',
        'customerConfirmed': true,
        'customerDeliveredAt': FieldValue.serverTimestamp(),
      });

      await NotificationService()
          .scheduleReviewReminder(order.id!, delay: _reviewReminderDelay);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id!)
          .update({'reviewReminderScheduled': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تأكيد استلام الطلب.')),
        );
      }
    } catch (e) {
      _scheduledReminders.remove(order.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة الطلب: $e')),
      );
    }
  }

  Future<void> _openRatingDialog(app_order.Order order) async {
    if (order.id == null) return;

    double currentRating = 5;
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تقييم الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingBar.builder(
                initialRating: currentRating,
                minRating: 1,
                allowHalfRating: false,
                itemSize: 32,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (value) => currentRating = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, currentRating),
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _saveRatingAndUpdateFoods(order, result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لتقييمك!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorText = 'تعذر حفظ التقييم: $e';
      if (e is StateError) {
        if (e.message == 'already-rated') {
          errorText = 'تم تقييم هذا الطلب مسبقاً.';
        } else if (e.message == 'order-not-found') {
          errorText = 'تعذر العثور على الطلب.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
    }
  }

  Future<void> _saveRatingAndUpdateFoods(
      app_order.Order order, double rating) async {
    if (order.id == null) return;

    final firestore = FirebaseFirestore.instance;
    final orderRef = firestore.collection('orders').doc(order.id!);

    await firestore.runTransaction((txn) async {
      final orderSnapshot = await txn.get(orderRef);
      if (!orderSnapshot.exists) {
        throw StateError('order-not-found');
      }

      final Map<String, dynamic> orderData = orderSnapshot.data() ?? {};
      if (orderData['isRated'] == true) {
        throw StateError('already-rated');
      }

      txn.update(orderRef, {
        'rating': rating,
        'isRated': true,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      final Set<String> foodIds = _extractFoodIds(orderData['items']);
      for (final foodId in foodIds) {
        final foodRef = firestore.collection('foods').doc(foodId);
        final foodSnap = await txn.get(foodRef);
        final Map<String, dynamic> foodData = foodSnap.data() ?? {};
        final double currentRating = _safeDouble(foodData['rating']);
        final int currentCount = _safeInt(foodData['ratingCount']);
        final int newCount = currentCount + 1;
        final double newAverage =
            ((currentRating * currentCount) + rating) / newCount;

        txn.set(
            foodRef,
            {
              'rating': double.parse(newAverage.toStringAsFixed(2)),
              'ratingCount': newCount,
            },
            SetOptions(merge: true));
      }
    });
  }

  Set<String> _extractFoodIds(dynamic rawItems) {
    if (rawItems is! List) return <String>{};
    final Set<String> ids = <String>{};
    for (final item in rawItems) {
      if (item is! Map<String, dynamic>) continue;
      final dynamic rawId = item['id'] ?? item['foodId'];
      if (rawId == null) continue;
      final String value = rawId.toString().trim();
      if (value.isEmpty) continue;
      ids.add(value);
    }
    return ids;
  }

  double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  int _safeInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  void _clearPendingCancellation(String orderId, {bool hideSnackBar = false}) {
    _cancelTimers.remove(orderId)?.cancel();
    final notifier = _cancelCountdowns.remove(orderId);
    if (hideSnackBar && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    if (notifier != null) {
      Future.microtask(notifier.dispose);
    }
  }

  void _startCancelCountdown(app_order.Order order) {
    final orderId = order.id;
    if (orderId == null) return;

    _clearPendingCancellation(orderId, hideSnackBar: true);

    final ValueNotifier<int> notifier =
        ValueNotifier<int>(_cancelCountdownSeconds);
    _cancelCountdowns[orderId] = notifier;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(hours: 1),
        content: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) => Text(
            'سيتم إلغاء الطلب خلال $value ثانية...',
          ),
        ),
        action: SnackBarAction(
          label: 'تراجع',
          textColor: Colors.yellowAccent[700],
          onPressed: () {
            _clearPendingCancellation(orderId, hideSnackBar: true);
            messenger.showSnackBar(
              const SnackBar(content: Text('تم إلغاء عملية الإلغاء.')),
            );
          },
        ),
      ),
    );

    _cancelTimers[orderId] =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextValue = notifier.value - 1;
      if (nextValue > 0) {
        notifier.value = nextValue;
        return;
      }

      timer.cancel();
      notifier.value = 0;
      _clearPendingCancellation(orderId, hideSnackBar: false);
      messenger.hideCurrentSnackBar();

      Future.microtask(() async {
        try {
          await FirebaseFirestore.instance.runTransaction((txn) async {
            final ref =
                FirebaseFirestore.instance.collection('orders').doc(orderId);
            final snap = await txn.get(ref);
            final currentStatus =
                (snap.data()?['status'] ?? '').toString().toLowerCase();
            if (currentStatus != 'pending') {
              throw 'لا يمكن إلغاء الطلب بعد تأكيده.';
            }
            txn.update(ref, {
              'status': 'cancelled',
              'cancelledByCustomer': true,
              'cancelledAt': FieldValue.serverTimestamp(),
            });
          });

          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('تم إلغاء الطلب بنجاح.')),
          );
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text('تعذر إلغاء الطلب: $e')),
          );
        }
      });
    });
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.rawData,
    required this.onConfirmDelivery,
    required this.onRate,
    required this.onCancel,
  });

  final app_order.Order order;
  final Map<String, dynamic>? rawData;
  final VoidCallback onConfirmDelivery;
  final VoidCallback onRate;
  final VoidCallback onCancel;

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy - HH:mm');

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final _StatusBadge badge = _StatusBadge.fromStatus(status);
    final bool isRated = rawData?['isRated'] == true;
    final double total = order.total ?? 0;
    final List<_InvoiceItem> invoiceItems = _parseInvoiceItems(order.items);
    final Widget? actions = _buildActions(status, isRated);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.id ?? '--'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(order.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badge.background,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        badge.label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: badge.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildInvoiceBody(invoiceItems),
            const SizedBox(height: 14),
            _DashedDivider(color: Colors.grey[300] ?? Colors.grey),
            const SizedBox(height: 14),
            _infoRow(
              icon: Icons.person_outline,
              value: order.customerName?.isNotEmpty == true
                  ? order.customerName!
                  : 'عميل غير معروف',
            ),
            const SizedBox(height: 8),
            _infoRow(
              icon: Icons.phone_iphone,
              value: order.phone?.isNotEmpty == true
                  ? order.phone!
                  : 'بدون رقم هاتف',
            ),
            const SizedBox(height: 8),
            _infoRow(
              icon: Icons.location_on_outlined,
              value: order.address?.isNotEmpty == true
                  ? order.address!
                  : 'لا يوجد عنوان محدد',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الإجمالي',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(total),
                    style: const TextStyle(
                      color: Color(0xFFFC6011),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (actions != null) ...[
              const SizedBox(height: 16),
              actions,
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildActions(String status, bool isRated) {
    final List<Widget> actions = [];

    final BorderRadius buttonRadius = BorderRadius.circular(28);

    if (status == 'pending') {
      actions.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade600,
            side: BorderSide(color: Colors.red.shade200),
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('إلغاء الطلب'),
        ),
      );
    }

    if (status == 'preparing') {
      actions.add(
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: onConfirmDelivery,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('استلمت الطلبية ✅'),
        ),
      );
    }

    if (status == 'delivered' && !isRated) {
      actions.add(
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFC6011),
            side: const BorderSide(color: Color(0xFFFC6011)),
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: onRate,
          icon: const Icon(Icons.star_rate_rounded),
          label: const Text('قيّم الوجبة ⭐'),
        ),
      );
    }

    if (actions.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: actions,
    );
  }

  List<_InvoiceItem> _parseInvoiceItems(List<Map<String, dynamic>>? rawItems) {
    if (rawItems == null) {
      return const [];
    }

    return rawItems.map((item) {
      final String name =
          (item['name'] ?? item['title'] ?? item['item'] ?? 'عنصر غير معروف')
              .toString();
      final int quantity = _toInt(item['quantity'] ?? item['qty'] ?? 1);
      final double price =
          _toDouble(item['total'] ?? item['price'] ?? item['amount'] ?? 0);

      return _InvoiceItem(
        name: name,
        quantity: quantity,
        price: price,
      );
    }).toList(growable: false);
  }

  List<Widget> _buildInvoiceBody(List<_InvoiceItem> items) {
    if (items.isEmpty) {
      return [
        Text(
          'تفاصيل الطلب غير متاحة',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ];
    }

    final List<Widget> children = [];
    for (int i = 0; i < items.length; i++) {
      final _InvoiceItem item = items[i];
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '${item.quantity}x ${item.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatPrice(item.price),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

      if (i != items.length - 1) {
        children.add(const SizedBox(height: 8));
      }
    }

    return children;
  }

  Widget _infoRow({required IconData icon, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 1;
    }
    return 1;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class _InvoiceItem {
  const _InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String name;
  final int quantity;
  final double price;
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double dashWidth = 6;
        const double dashSpace = 4;
        final int dashCount =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge {
  const _StatusBadge(
      {required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  factory _StatusBadge.fromStatus(String status) {
    switch (status) {
      case 'pending':
        return _StatusBadge(
          label: '⏳ في انتظار التأكيد',
          color: Colors.orange,
          background: Colors.orange.withOpacity(0.15),
        );
      case 'preparing':
        return _StatusBadge(
          label: '👨‍🍳 قيد التحضير',
          color: Colors.blue,
          background: Colors.blue.withOpacity(0.15),
        );
      case 'delivered':
        return _StatusBadge(
          label: '✅ تم التوصيل',
          color: Colors.green,
          background: Colors.green.withOpacity(0.15),
        );
      case 'cancelled':
        return _StatusBadge(
          label: '❌ ملغاة',
          color: Colors.red,
          background: Colors.red.withOpacity(0.15),
        );
      default:
        return _StatusBadge(
          label: status,
          color: Colors.grey,
          background: Colors.grey.withOpacity(0.15),
        );
    }
  }
}
