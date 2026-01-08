import 'package:flutter/material.dart';
import 'package:food_order/services/admin_firestore_service.dart';
import 'package:food_order/admin_dashboard/admin_working_hours.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AdminFirestoreService _svc = AdminFirestoreService();
  String? restaurantId;
  final TextEditingController _logoCtrl = TextEditingController();
  final List<TextEditingController> _bannerCtrls = [];
  int _colorIndex = 0;
  bool _isDark = false;
  bool _isLoading = true;

  // اللون الرئيسي البرتقالي
  final Color _primaryColor = const Color(0xFFFC6011);

  @override
  void initState() {
    super.initState();
    // تهيئة الكونترولرز فارغة لتجنب الأخطاء قبل التحميل
    for (int i = 0; i < 3; i++) {
      _bannerCtrls.add(TextEditingController());
    }
    _init();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      restaurantId = data != null ? data['restaurantId'] as String? : null;
      
      if (restaurantId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .get();
        final r = snap.data() ?? {};
        
        setState(() {
          _logoCtrl.text = r['logoUrl'] as String? ?? '';
          _colorIndex = (r['themeColorIndex'] as int?) ?? 0;
          _isDark = (r['isDarkMode'] as bool?) ?? false;
          
          final banners = r['bannerImages'] != null ? List<String>.from(r['bannerImages']) : [];
          for (int i = 0; i < 3; i++) {
            if (i < banners.length) {
              _bannerCtrls[i].text = banners[i];
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    for (final c in _bannerCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (restaurantId == null) return;
    
    setState(() => _isLoading = true);
    
    final banners = _bannerCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
        
    await _svc.updateRestaurantSettings(restaurantId!, {
      'logoUrl': _logoCtrl.text.trim(),
      'themeColorIndex': _colorIndex,
      'isDarkMode': _isDark,
      'bannerImages': banners,
    });
    
    setState(() => _isLoading = false);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Settings Saved Successfully ✅'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // --- قسم الهوية ---
            _buildSectionHeader("🎨 Branding Identity"),
            const SizedBox(height: 10),
            TextField(
              controller: _logoCtrl,
              decoration: InputDecoration(
                labelText: 'Logo Image URL',
                prefixIcon: const Icon(Icons.image),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('Theme Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: List.generate(4, (i) {
                final colors = [Colors.orange, Colors.blue, Colors.green, Colors.red];
                final names = ['Orange', 'Blue', 'Green', 'Red'];
                return ChoiceChip(
                  label: Text(names[i]),
                  selected: _colorIndex == i,
                  onSelected: (v) => setState(() => _colorIndex = i),
                  selectedColor: colors[i],
                  labelStyle: TextStyle(color: _colorIndex == i ? Colors.white : Colors.black),
                );
              }),
            ),
            
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isDark,
              activeColor: _primaryColor,
              onChanged: (v) => setState(() => _isDark = v),
            ),

            const Divider(height: 40),

            // --- قسم البنرات ---
            _buildSectionHeader("🖼️ Promo Banners"),
            const SizedBox(height: 5),
            const Text("Add up to 3 image URLs for the home slider.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 15),
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _bannerCtrls[i],
                  decoration: InputDecoration(
                    labelText: 'Banner ${i + 1} URL',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
              ),

            const Divider(height: 40),

            // --- قسم العمليات (الزر الجديد هنا) ---
            _buildSectionHeader("⏰ Store Operations"),
            const SizedBox(height: 15),
            
            // 👇👇 هذا هو الزر الجديد بشكل واضح 👇👇
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time_filled, color: _primaryColor),
                ),
                title: const Text("Working Hours", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Set Open/Close times"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminWorkingHoursScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            // زر الحفظ
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('SAVE SETTINGS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _primaryColor,
      ),
    );
  }
}