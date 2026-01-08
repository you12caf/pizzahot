import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_order/admin_dashboard/admin_orders.dart';
import 'package:food_order/models/app_notification.dart';
import 'package:food_order/pages/my_orders_page.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Please sign in to view notifications.'),
        ),
      );
    }

    final notificationsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFFC6011),
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final now = DateTime.now();
          final sevenDaysAgo = now.subtract(const Duration(days: 7));

          final entries = <_NotificationEntry>[];

          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            final DateTime createdAt = ts?.toDate() ?? DateTime.now();
            if (createdAt.isBefore(sevenDaysAgo)) {
              unawaited(doc.reference.delete());
              continue;
            }
            final notification = AppNotification.fromDoc(doc);
            entries.add(
              _NotificationEntry(
                notification: notification,
                ref: doc.reference,
              ),
            );
          }

          if (entries.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final notification = entry.notification;
              final ref = entry.ref;
              return Card(
                color: Colors.white,
                elevation: notification.isRead ? 0 : 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.body,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _relativeTime(notification.createdAt, now),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: notification.isRead
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFC6011),
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () async {
                    await ref.update({'isRead': true});
                    final payload = notification.payload;
                    if (_isOrderPayload(payload)) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminOrdersScreen(),
                        ),
                      );
                    } else if (_isReviewPayload(payload)) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyOrdersPage(),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 72, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No notifications right now',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date, DateTime now) {
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    final days = diff.inDays;
    return days == 1 ? 'Yesterday' : '$days days ago';
  }
}

class _NotificationEntry {
  _NotificationEntry({required this.notification, required this.ref});

  final AppNotification notification;
  final DocumentReference<Map<String, dynamic>> ref;
}

bool _isOrderPayload(String payload) {
  return payload == 'order_id' ||
      payload == 'admin_orders' ||
      payload.startsWith('order_');
}

bool _isReviewPayload(String payload) {
  return payload == 'review_id' ||
      payload == 'my_orders' ||
      payload.startsWith('review_');
}
