import 'package:flutter/material.dart';
import 'package:food_order/components/main_button.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/pages/delivery_page.dart';
import 'package:provider/provider.dart';
import 'package:food_order/models/restaurant.dart';
import 'package:food_order/services/database/order_services.dart';
import 'package:food_order/models/order.dart' as app_order;
import 'package:firebase_auth/firebase_auth.dart';

class PaymentPage extends StatefulWidget {
  final double total;
  const PaymentPage({super.key, required this.total});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _nameCtrl.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(BuildContext context) async {
    if (widget.total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty. Add items first.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final restaurant = Provider.of<Restaurant>(context, listen: false);
    final cart = restaurant.cart;
    if (cart.isEmpty) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty. Add items first.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _submitting = false);
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Not signed in'),
          content: Text('Please sign in to place an order.'),
        ),
      );
      return;
    }

    final items = cart
        .map((cartItem) => {
              'id': cartItem.food.id,
              'name': cartItem.food.name,
              'price': cartItem.food.price,
              'quantity': cartItem.quantity,
            })
        .toList();
    final restaurantId = cart.isNotEmpty ? cart.first.food.restaurantId : null;

    // Capture a printable receipt string before clearing the cart
    final receiptString = restaurant.displayCartReceipt();

    final order = app_order.Order(
      items: List<Map<String, dynamic>>.from(items),
      total: widget.total,
      receipt: receiptString,
      paymentMethod: 'cod',
      status: 'pending',
      restaurantId: restaurantId,
      customerId: user.uid,
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );

    try {
      final svc = FirestoreService();
      await svc.addOrder(order);
      // Clear the cart after order persisted, but we already captured receiptString
      restaurant.clearCart();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => DeliveryPage(
                    orderTotal: widget.total,
                    receiptData: receiptString,
                  )),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Order failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.total <= 0 || _submitting;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Full name',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. +213xxxxxxxx',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          hintText: 'Street, city, landmark',
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: 3,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter delivery address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.money,
                                size: 64, color: Colors.green),
                            const SizedBox(height: 12),
                            const Text('Payment Mode',
                                style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 6),
                            const Text('Cash on Delivery',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            Text('Total: ${formatPrice(widget.total)}',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFC6011))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: MainButton(
                  onTap: () {
                    if (!disabled) _placeOrder(context);
                  },
                  text: _submitting ? 'Placing...' : 'Place Order',
                  color: const Color(0xFFFC6011),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
