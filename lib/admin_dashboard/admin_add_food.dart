import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:food_order/config/app_config.dart';
import 'package:food_order/models/food.dart';
import 'package:food_order/services/admin_firestore_service.dart';

class AdminAddFoodScreen extends StatefulWidget {
  final Food? editingFood;
  const AdminAddFoodScreen({super.key, this.editingFood});

  @override
  State<AdminAddFoodScreen> createState() => _AdminAddFoodScreenState();
}

class _AdminAddFoodScreenState extends State<AdminAddFoodScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageController;

  bool _isLoading = false;
  String? _selectedCategoryId;
  List<Map<String, String>> _categories = [];
  String _restaurantId = AppConfig.targetRestaurantId;

  @override
  void initState() {
    super.initState();

    String initName = '';
    String initDesc = '';
    String initPrice = '';
    String initImage = '';

    if (widget.editingFood != null) {
      final food = widget.editingFood!;
      initName = food.name;
      initDesc = food.description;
      final price = food.price;
      initPrice = price % 1 == 0 ? price.toInt().toString() : price.toString();
      initImage = food.imagePath;
      _selectedCategoryId = food.category;
    }

    _nameController = TextEditingController(text: initName);
    _descController = TextEditingController(text: initDesc);
    _priceController = TextEditingController(text: initPrice);
    _imageController = TextEditingController(text: initImage);

    _fetchRestaurantAndCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurantAndCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = doc.data();
        if (data != null) {
          final restId = (data['restaurantId'] ?? '').toString();
          if (restId.isNotEmpty) {
            _restaurantId = restId;
          }
        }
      }

      final catColl = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('categories');

      final snapshot = await catColl.get();

      if (snapshot.docs.isEmpty) {
        await catColl.doc('general').set({'id': 'general', 'name': 'General'});
        if (mounted) {
          setState(() {
            _categories = [
              {'id': 'general', 'name': 'General'},
            ];
            _selectedCategoryId ??= 'general';
          });
        }
        return;
      }

      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        final idField = data['id'];
        return {
          'id': (idField is String && idField.isNotEmpty) ? idField : doc.id,
          'name': (data['name'] ?? 'Unnamed Category').toString(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _categories = loaded;
          if (_selectedCategoryId == null && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _saveFood() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select a category!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final food = Food(
        id: widget.editingFood?.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imagePath: _imageController.text.trim(),
        price: price,
        category: _selectedCategoryId!,
      );

      final service = AdminFirestoreService();
      if (widget.editingFood == null) {
        await service.addFoodForRestaurant(food, _restaurantId);
      } else if (food.id != null) {
        await service.updateFoodForRestaurant(food.id!, food);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Saved Successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        inputFormatters: formatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.editingFood == null ? 'Add New Item' : 'Edit Item',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fastfood,
                              size: 40, color: Colors.blue[300]),
                          const SizedBox(height: 8),
                          Text(
                            widget.editingFood == null
                                ? 'Create a delicious item'
                                : 'Update your tasty item',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Food Name',
                      icon: Icons.label_outline,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    _buildTextField(
                      controller: _descController,
                      label: 'Description',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Description is required'
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _priceController,
                            label: 'Price',
                            icon: Icons.attach_money,
                            type: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            validator: (value) => value == null || value.isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                icon: Icon(
                                  Icons.category_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                              value: _selectedCategoryId,
                              hint: const Text('Category'),
                              items: _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['id'],
                                  child: Text(
                                    cat['name'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategoryId = val),
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _imageController,
                      label: 'Image URL',
                      icon: Icons.image_outlined,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        onPressed: _saveFood,
                        child: const Text(
                          'Save Item',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
