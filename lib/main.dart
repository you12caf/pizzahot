import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;

// Services & Components
import 'package:food_order/services/auth/auth_check.dart';
import 'package:food_order/services/notification_service.dart';
import 'package:food_order/components/connection_wrapper.dart';
import 'package:food_order/firebase_options.dart';

// Models & Providers
import 'package:food_order/models/restaurant.dart';
import 'package:food_order/providers/user_provider.dart';
import 'package:food_order/themes/theme_provider.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    print("🚀 APP RUNNING ON PROJECT: ${DefaultFirebaseOptions.currentPlatform.projectId}");
  print("🌐 AUTH DOMAIN: ${DefaultFirebaseOptions.currentPlatform.authDomain}");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Future<void>.sync(() => tz.initializeTimeZones());

  if (!kIsWeb) {
    // Force-request notification permission on startup for Android 13+/iOS
    try {
      await Permission.notification.isDenied.then((value) {
        if (value) {
          Permission.notification.request();
        }
      });
    } catch (_) {}

    // --- 🔔 نظام الرادار الأمني ---

    // 1. تهيئة خدمة الإشعارات (باستخدام اسم الكلاس الموجود عندك)
    await NotificationService().init(navigatorKey);

    // 2. مراقبة المستخدم في الوضع الإنتاجي
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        try {
          await NotificationService().stopListening();
        } catch (_) {}
        return;
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        if (data == null) {
          await NotificationService().stopListening();
          return;
        }

        final role = (data['role'] ?? '').toString();
        final restaurantId = (data['restaurantId'] ?? '').toString();

        if (role == 'owner' && restaurantId.isNotEmpty) {
          await NotificationService().startListening(restaurantId);
        } else if (role == 'customer') {
          await NotificationService().stopListening();
          await NotificationService().checkPendingReviews(user.uid);
        } else {
          await NotificationService().stopListening();
        }
      } catch (_) {
        await NotificationService().stopListening();
      }
    });
    // --- 🔔 نهاية الرادار ---
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => RestaurantThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => Restaurant(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingCustomerReviews();
    }
  }

  Future<void> _checkPendingCustomerReviews() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (doc.data()?['role'] ?? '').toString().toLowerCase();
      if (role == 'customer') {
        await NotificationService().checkPendingReviews(user.uid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'Restdz',
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        // Wrap every route with ConnectionWrapper so the No-Internet screen
        // overlays the entire app immediately when connectivity drops.
        return ConnectionWrapper(child: child ?? const SizedBox.shrink());
      },
      home: const AuthCheck(),
    );
  }
}
