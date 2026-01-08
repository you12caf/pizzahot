import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_order/config/app_config.dart';

class SetupWizardPage extends StatefulWidget {
  const SetupWizardPage({super.key});

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  final _formKey = GlobalKey<FormState>();

  // المعرف الثابت لضمان عمل الـ Fallback
  final String restaurantId = AppConfig.targetRestaurantId;
  // اسم المطعم الافتراضي لتهيئة النموذج بسرعة
  final String restaurantName = 'El Hana Food';

  late final TextEditingController _nameController;

  bool _isLoading = false;
  List<String> logs = [];

  void _log(String message) {
    setState(() {
      logs.add("• $message");
    });
    print("SETUP: $message");
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: restaurantName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      logs.clear();
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _log("❌ Error: No user logged in. Please sign in first.");
        setState(() => _isLoading = false);
        return;
      }

      _log("🚀 Starting Initialization for ${user.phoneNumber}...");

      // 1. إعداد وثيقة المطعم (Restaurant Doc)
      // بناءً على التقرير: logoUrl, bannerImages, themeColorIndex, isDarkMode
      _log("🏗️ Creating Restaurant Profile ($restaurantId)...");
      await firestore.collection('restaurants').doc(restaurantId).set({
        'name': _nameController.text.trim(),
        'logoUrl': '', // يملأها المالك لاحقاً
        'bannerImages': [], // قائمة فارغة
        'themeColorIndex': 0, // برتقالي افتراضي
        'isDarkMode': false,
        'supportPhone': user.phoneNumber ?? '',
        'supportEmail': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. إعداد الأقسام (Categories)
      // بناءً على التقرير: name, id, createdAt
      _log("📂 Creating Default Categories...");
      final categoriesRef = firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection('categories');

      await categoriesRef.doc('general').set({
        'name': 'General',
        'id': 'general',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await categoriesRef.doc('drinks').set({
        'name': 'Drinks',
        'id': 'drinks',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. إضافة طبق تجريبي (Sample Food)
      // بناءً على التقرير: rating, ratingCount, imagePath, price (double)
      _log("🍔 Adding Sample Food Item...");
      await firestore.collection('foods').add({
        'name': 'Welcome Burger',
        'description': 'A delicious sample burger to start your menu.',
        'imagePath': 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
        'price': 500.0, // Double required
        'category': 'general', // Links to category ID
        'restaurantId': restaurantId,
        'rating': 5.0, // Default rating
        'ratingCount': 1,
      });

      // 4. ترقية المستخدم (User Promotion)
      // بناءً على التقرير: role, restaurantId
      _log("👑 Promoting You to Owner...");
      await firestore.collection('users').doc(user.uid).set({
        'role': 'owner',
        'restaurantId': restaurantId,
        'phone': user.phoneNumber,
        // نحافظ على البيانات الموجودة
      }, SetOptions(merge: true));

      _log("✅ DONE! Database is ready.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Setup Complete! Please Restart App."),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _log("❌ FATAL ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("SaaS Setup Wizard 🧙‍♂️"),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Initialize New Client Database",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "This will create the restaurant structure, categories, sample food, and promote your account to Owner.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Restaurant Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _initializeDatabase,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.rocket_launch),
                label: const Text("LAUNCH SETUP",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC6011),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text("Logs:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) => Text(logs[i],
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
