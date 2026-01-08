import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_order/admin_dashboard/admin_orders.dart';
import 'package:food_order/pages/my_orders_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  bool _initialized = false;
  bool _isAlertEnabled = true;
  GlobalKey<NavigatorState>? _navigatorKey;
  final Set<String> _seenOrderIds = <String>{};

  static const String _prefsKeyEnabled = 'alert_enabled';
  static const String _prefsKeyLastAlert = 'last_alert_time';

  static const String _channelId = 'resto_shopify_v2';
  static const String _channelName = 'RestoDZ Shopify Alerts';

  Future<void> init([GlobalKey<NavigatorState>? navigatorKey]) async {
    if (kIsWeb) return;

    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }

    if (_initialized) return;

    await Permission.notification.request();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shopify-style high priority alerts for new orders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    try {
      final prefs = await SharedPreferences.getInstance();
      _isAlertEnabled = prefs.getBool(_prefsKeyEnabled) ?? true;
    } catch (e) {
      if (kDebugMode) {
        print('SharedPreferences error, defaulting alerts ON: $e');
      }
      _isAlertEnabled = true;
    }

    _initialized = true;
  }

  bool get isAlertEnabled => _isAlertEnabled;

  bool getAlertEnabled() => _isAlertEnabled;

  Future<void> setAlertEnabled(bool value) async {
    _isAlertEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnabled, value);
    } catch (e) {
      if (kDebugMode) {
        print('SharedPreferences save error: $e');
      }
    }
  }

  Future<void> playSound() async {
    if (kIsWeb) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      if (kDebugMode) {
        print('Audio Error: $e');
      }
    }
  }

  // Public helper for manual tests (e.g. from Settings page)
  Future<void> showNotification(
    String title,
    String body, {
    String payload = 'admin_orders',
  }) async {
    if (kIsWeb) return;

    await _showNotification(title, body, payload);
  }

  Future<void> _showNotification(
      String title, String body, String payload) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Notification Error: $e');
      }
    }
  }

  Future<void> _saveToHistory(
    String uid,
    String title,
    String body,
    String payload,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to save notification history for $uid: $e');
      }
    }
  }

  Future<void> startListening(String restaurantId) async {
    if (kIsWeb) return;

    final id = restaurantId.trim();
    if (id.isEmpty) return;

    if (!_initialized) {
      await init();
    }

    await stopListening();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('🚫 startListening aborted: no authenticated user.');
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (userDoc.data()?['role'] ?? '').toString().toLowerCase();
      if (role != 'owner') {
        if (kDebugMode) {
          print('🚫 startListening aborted: role "$role" is not owner.');
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚫 startListening aborted: role check failed -> $e');
      }
      return;
    }

    _seenOrderIds.clear();

    final ownerUid = user.uid;
    final prefs = await SharedPreferences.getInstance();

    final coll = FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: id)
        .where('status', isEqualTo: 'pending');

    _subscription = coll.snapshots().listen(
      (snapshot) async {
        if (!_isAlertEnabled) {
          return;
        }

        final storedTimestamp = prefs.getInt(_prefsKeyLastAlert) ?? 0;
        final List<_BufferedOrder> newOrders = <_BufferedOrder>[];

        for (final doc in snapshot.docs) {
          final data = doc.data();

          if (doc.metadata.hasPendingWrites) {
            continue;
          }

          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status != 'pending') {
            continue;
          }

          final Timestamp? ts = data['date'] as Timestamp?;
          final int orderMs = ts != null
              ? ts.toDate().millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch;

          final bool isNewerThanCursor =
              ts == null || orderMs > storedTimestamp;
          if (!isNewerThanCursor) {
            continue;
          }

          if (_seenOrderIds.contains(doc.id)) {
            continue;
          }
          _seenOrderIds.add(doc.id);

          final customer = (data['customerName'] ?? 'New Customer').toString();
          final rawTotal = (data['total'] ?? 0).toString();
          final formattedTotal = rawTotal.replaceAll('.0', '');
          const String title = 'New Order! 💸';
          final String body =
              'New Order from: $customer\nTotal: $formattedTotal DA';
          final String payload = 'order_${doc.id}';

          newOrders.add(
            _BufferedOrder(
              timestampMs: orderMs,
              title: title,
              body: body,
              payload: payload,
            ),
          );
        }

        if (newOrders.isEmpty) {
          return;
        }

        unawaited(playSound());

        if (newOrders.length == 1) {
          final order = newOrders.first;
          await showNotification(
            order.title,
            order.body,
            payload: order.payload,
          );
        } else {
          final int count = newOrders.length;
          await showNotification(
            '🚀 New Orders',
            'You have $count new orders waiting!',
            payload: 'admin_orders',
          );
        }

        for (final order in newOrders) {
          unawaited(
            _saveToHistory(
              ownerUid,
              order.title,
              order.body,
              order.payload,
            ),
          );
        }

        final int newestTimestamp = newOrders
            .map((order) => order.timestampMs)
            .fold(storedTimestamp, (prev, ts) => ts > prev ? ts : prev);

        if (newestTimestamp != storedTimestamp) {
          await prefs.setInt(_prefsKeyLastAlert, newestTimestamp);
        }
      },
      onError: (e) {
        if (kDebugMode) {
          print('Listener error: $e');
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _seenOrderIds.clear();
  }

  Future<void> cancelAllAndStop() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Unable to cancel notifications: $e');
      }
    }
    await stopListening();
  }

  Future<void> scheduleReviewReminder(
    String orderId, {
    Duration delay = const Duration(minutes: 5),
  }) async {
    await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('Review reminder aborted: no authenticated user.');
      }
      return;
    }

    final tz.TZDateTime scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

    const title = 'بصحتكم! 🍔';
    const body = 'نتمنى أن تكون الوجبة قد أعجبتك، اضغط هنا لتقييمها.';
    const payload = 'my_orders';

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        orderId.hashCode,
        title,
        body,
        scheduledTime,
        notificationDetails,
        androidAllowWhileIdle: true,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
      unawaited(_saveToHistory(user.uid, title, body, payload));
    } catch (e) {
      if (kDebugMode) {
        print('Review reminder scheduling failed: $e');
      }
    }
  }

  Future<void> checkPendingReviews(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final alertedKey = 'review_alerted_$userId';
      final alertedOrders = prefs.getStringList(alertedKey) ?? <String>[];

      final query = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'delivered')
          .where('isRated', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) {
        return;
      }

      final List<String> updatedCache = List<String>.from(alertedOrders);
      for (final doc in query.docs) {
        final data = doc.data();
        final Timestamp? ts = data['date'] as Timestamp?;
        if (ts == null) {
          continue;
        }

        final DateTime orderTime = ts.toDate();
        final bool isOlderThanWindow =
            DateTime.now().difference(orderTime) >= const Duration(minutes: 30);
        if (!isOlderThanWindow) {
          continue;
        }

        if (updatedCache.contains(doc.id)) {
          continue;
        }

        await showNotification(
          'بصحتكم! 🍔',
          'نتمنى أن تكون الوجبة قد أعجبتك، اضغط هنا لتقييمها.',
          payload: 'my_orders',
        );
        unawaited(
          _saveToHistory(
            userId,
            'بصحتكم! 🍔',
            'نتمنى أن تكون الوجبة قد أعجبتك، اضغط هنا لتقييمها.',
            'my_orders',
          ),
        );
        updatedCache.add(doc.id);
      }

      await prefs.setStringList(alertedKey, updatedCache);
    } catch (e) {
      if (kDebugMode) {
        print('checkPendingReviews failed: $e');
      }
    }
  }

  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    navigateFromPayload(payload);
  }

  void navigateFromPayload(String payload) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      if (kDebugMode) {
        print('⚠️ Navigator not attached; cannot handle payload $payload');
      }
      return;
    }

    if (payload == 'admin_orders' || payload.startsWith('order_')) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
      );
    } else if (payload == 'my_orders' || payload.startsWith('review_')) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
      );
    } else if (kDebugMode) {
      print('⚠️ Unhandled notification payload: $payload');
    }
  }
}

class _BufferedOrder {
  _BufferedOrder({
    required this.timestampMs,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int timestampMs;
  final String title;
  final String body;
  final String payload;
}
