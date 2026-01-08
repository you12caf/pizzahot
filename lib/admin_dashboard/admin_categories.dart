import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_order/config/app_config.dart';
import 'package:food_order/services/admin_firestore_service.dart';
import 'package:food_order/components/app_drawer.dart'; // ✅ القائمة موجودة

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AdminFirestoreService _service = AdminFirestoreService();
  String _restaurantId = '';
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRestaurantId();
  }

  Future<void> _fetchRestaurantId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? id;

    if (uid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = doc.data();
        if (data != null && data['restaurantId'] != null) {
          id = data['restaurantId'] as String?;
        }
      } catch (_) {}
    }

    // CRITICAL FALLBACK: always have a valid id
    id ??= AppConfig.targetRestaurantId;

    if (!mounted) return;
    setState(() {
      _restaurantId = id!;
      _isLoading = false;
    });
  }

  String _generateId(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  Future<void> _addCategory() async {
    if (_nameController.text.isEmpty) return;
    final name = _nameController.text.trim();
    final id = _generateId(name);
    try {
      await _service.addCategoryForRestaurant(_restaurantId, name, id);
      if (mounted) {
        Navigator.pop(context);
        _nameController.clear();
      }
    } catch (_) {}
  }

  Future<void> _deleteCategory(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteCategoryForRestaurant(_restaurantId, docId);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("New Category",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: "Category Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category))),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC6011),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12)),
                  onPressed: _addCategory,
                  child:
                      const Text("Add", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(), // ✅ القائمة موجودة
      appBar: AppBar(
        title: const Text('Manage Categories',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _restaurantId.isEmpty
                  ? null
                  : _service.streamCategoriesForRestaurant(_restaurantId),
              builder: (context, snapshot) {
                if (_restaurantId.isEmpty) {
                  return const Center(child: Text('No restaurant configured'));
                }

                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = snapshot.data ?? [];
                if (categories.isEmpty) {
                  return const Center(child: Text("No categories found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.category,
                            color: Color(0xFFFC6011)),
                        title: Text(cat['name'] ?? 'Unnamed',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteCategory(cat['docId'] ?? cat['id']),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFFC6011),
        label:
            const Text("New Category", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
