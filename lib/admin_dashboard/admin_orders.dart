// lib/admin_dashboard/admin_orders.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_order/admin_dashboard/receipt_preview_dialog.dart';
import 'package:food_order/config/app_config.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/services/admin_firestore_service.dart';
import 'package:food_order/models/order.dart' as app_order;
import 'package:intl/intl.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';
import 'package:provider/provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final AdminFirestoreService _service = AdminFirestoreService();

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;
  String _selectedStatus = 'All';
  String? _restaurantId;
  bool _isLoading = true;
  static const String _defaultRestaurantName = 'My Restaurant';

  final Color primaryOrange = const Color(0xFFFC6011);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
    // Fetch restaurant id once to avoid re-running future on rebuilds
    _initRestaurantId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Keep the robust restaurant id fetching
  Future<String?> _getRestaurantId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['restaurantId'] != null) {
      return data['restaurantId'] as String;
    }

    // fallback
    return AppConfig.targetRestaurantId;
  }

  Future<void> _initRestaurantId() async {
    try {
      final id = await _getRestaurantId();
      if (!mounted) return;
      setState(() {
        _restaurantId = id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restaurantId = null;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d, y').format(date);
  }

  // Central processing: sort newest first, apply search/date/status filters
  List<app_order.Order> _processOrders(List<app_order.Order> orders) {
    // Defensive copy
    final list = List<app_order.Order>.from(orders);

    // SORT: newest first
    list.sort((a, b) => b.date.compareTo(a.date));

    return list.where((o) {
      final status = o.status.toLowerCase();

      // Status filter
      if (_selectedStatus.toLowerCase() != 'all' &&
          status != _selectedStatus.toLowerCase()) return false;

      // Date filter
      if (_selectedDate != null && !_isSameDay(o.date, _selectedDate!)) {
        return false;
      }

      // Search filter: customerName, phone, address
      if (_searchQuery.isNotEmpty) {
        final name = (o.customerName ?? '').toLowerCase();
        final phone = (o.phone ?? '').toLowerCase();
        final addr = (o.address ?? '').toLowerCase();
        if (!name.contains(_searchQuery) &&
            !phone.contains(_searchQuery) &&
            !addr.contains(_searchQuery) &&
            !(o.receipt ?? '').toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  // Delete order
  Future<void> _deleteOrder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('orders').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order deleted')));
      }
    }
  }

  Future<void> _updateStatus(String id, String status,
      {bool isCodPaid = false}) async {
    final updates = {'status': status};
    if (isCodPaid) updates['paymentMethod'] = 'cod_paid';
    await _service.updateOrder(id, updates);
  }

  Future<void> _showReceiptPreview(app_order.Order order) async {
    final restaurantName =
        Provider.of<RestaurantThemeProvider>(context, listen: false)
                .restaurantName ??
            _defaultRestaurantName;

    final bool? printed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptPreviewDialog(
        order: order,
        restaurantName: restaurantName,
      ),
    );

    if (printed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent to printer')),
      );
    }
  }

  Color _statusBackgroundColor(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered') return Colors.green.withOpacity(0.12);
    if (s == 'cancelled') return Colors.red.withOpacity(0.12);
    if (s == 'pending') return primaryOrange.withOpacity(0.12);
    return Colors.grey.withOpacity(0.12);
  }

  Color _statusTextColor(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered') return Colors.green;
    if (s == 'cancelled') return Colors.red;
    if (s == 'pending') return primaryOrange;
    return Colors.grey[700] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Manage Orders',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_restaurantId == null)
              ? const Center(child: Text('Error: No Restaurant ID'))
              : Column(
                  children: [
                    // Header: Search + Date
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search name / phone / address',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _selectedDate != null
                                        ? primaryOrange.withOpacity(0.08)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selectedDate != null
                                        ? Border.all(color: primaryOrange)
                                        : null,
                                  ),
                                  child: Icon(Icons.calendar_month,
                                      color: _selectedDate != null
                                          ? primaryOrange
                                          : Colors.grey[600]),
                                ),
                              ),
                              if (_selectedDate != null)
                                IconButton(
                                    onPressed: () =>
                                        setState(() => _selectedDate = null),
                                    icon: const Icon(Icons.close)),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Status chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                'All',
                                'Pending',
                                'Preparing',
                                'Delivered',
                                'Cancelled'
                              ].map((s) {
                                final selected = _selectedStatus == s;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(s),
                                    selected: selected,
                                    selectedColor: primaryOrange,
                                    onSelected: (_) =>
                                        setState(() => _selectedStatus = s),
                                    labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Orders list
                    Expanded(
                      child: StreamBuilder<List<app_order.Order>>(
                        stream:
                            _service.streamOrdersForRestaurant(_restaurantId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: Text('No orders'));
                          }

                          final processed = _processOrders(snapshot.data!);
                          if (processed.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text('No orders found',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80, top: 8),
                            itemCount: processed.length,
                            itemBuilder: (context, index) {
                              final order = processed[index];
                              final showHeader = index == 0 ||
                                  !_isSameDay(
                                      order.date, processed[index - 1].date);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 8),
                                      child: Text(_formatGroupDate(order.date),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700])),
                                    ),
                                  _orderCard(order),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _orderCard(app_order.Order order) {
    final status = order.status.toLowerCase();
    final isPending = status == 'pending';
    final isPreparing = status == 'preparing';
    final isDelivered = status == 'delivered';
    final isCancelled = status == 'cancelled';
    final canPrint = (order.items != null && order.items!.isNotEmpty) ||
        ((order.receipt ?? '').isNotEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customerName ?? 'Guest',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(DateFormat('hh:mm a').format(order.date),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Print receipt',
                        icon: Icon(
                          Icons.print_outlined,
                          color: canPrint ? primaryOrange : Colors.grey[400],
                        ),
                        onPressed:
                            canPrint ? () => _showReceiptPreview(order) : null,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _statusBackgroundColor(order.status),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(order.status.toUpperCase(),
                                style: TextStyle(
                                    color: _statusTextColor(order.status),
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              order.total != null
                                  ? formatPrice(order.total!.toDouble())
                                  : formatPrice(0),
                              style: TextStyle(
                                  color: primaryOrange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              title: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(order.address ?? 'No address',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              children: [
                if (order.items != null && order.items!.isNotEmpty) ...[
                  for (final item in order.items!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: primaryOrange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('${item['quantity']}x',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFC6011))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item['name'] ?? 'Item')),
                          const SizedBox(width: 8),
                          Text(
                            formatPrice(
                              ((item['price'] is num)
                                      ? item['price'] as num
                                      : num.tryParse(
                                              item['price']?.toString() ??
                                                  '') ??
                                          0)
                                  .toDouble(),
                            ),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(order.phone ?? 'No phone')
                ]),
                const SizedBox(height: 12),

                // Actions
                if (!isDelivered && !isCancelled)
                  Row(children: [
                    if (isPending) ...[
                      Expanded(
                          child: ElevatedButton(
                              onPressed: () =>
                                  _updateStatus(order.id!, 'preparing'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryOrange,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Accept',
                                  style: TextStyle(color: Colors.white)))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () =>
                                  _updateStatus(order.id!, 'cancelled'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Reject'))),
                    ] else if (isPreparing) ...[
                      Expanded(
                          child: ElevatedButton(
                              onPressed: () =>
                                  _updateStatus(order.id!, 'delivered'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Complete',
                                  style: TextStyle(color: Colors.white)))),
                    ]
                  ]),

                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: () => _deleteOrder(order.id!),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.grey),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.grey)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
