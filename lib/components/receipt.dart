import 'package:flutter/material.dart';
import 'package:food_order/components/main_button.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/models/restaurant.dart';
import 'package:provider/provider.dart';

class Receipt extends StatelessWidget {
  final String? receiptText;
  final double? orderTotal;

  const Receipt({super.key, this.receiptText, this.orderTotal});

  Widget _dashedDivider(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final dashWidth = 6.0;
      final dashCount = (constraints.maxWidth / (dashWidth * 2)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(dashCount, (i) {
          return Container(
            width: dashWidth,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.grey[300],
          );
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double deviceHeight = MediaQuery.of(context).size.height;
    final double containerHeight = deviceHeight / 2;

    // If orderTotal provided, show the professional COD Digital Ticket
    if (orderTotal != null) {
      final lines = (receiptText ?? '')
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: const [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 48),
                          SizedBox(height: 8),
                          Text('✅ Order Placed Successfully',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('Total to Pay:',
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(formatPrice(orderTotal!),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(
                            'Please prepare the exact cash amount for the driver.',
                            style: TextStyle(color: Colors.grey[700]))),
                    const SizedBox(height: 12),
                    _dashedDivider(context),
                    const SizedBox(height: 12),
                    Text('Items',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (lines.isEmpty)
                      const Text('No items to show',
                          style: TextStyle(color: Colors.black54))
                    else
                      ...lines.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(l,
                                style:
                                    const TextStyle(fontFamily: 'RobotoMono')),
                          )),
                    const SizedBox(height: 12),
                    MainButton(
                        onTap: () => Navigator.pop(context),
                        text: 'Done',
                        color: const Color(0xFFFC6011))
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Fallback: show provider-based receipt (legacy behaviour)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              height: containerHeight,
              child: SingleChildScrollView(
                child: Consumer<Restaurant>(
                  builder: (context, restaurant, child) =>
                      Text(restaurant.displayCartReceipt()),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: MainButton(onTap: () => Navigator.pop(context), text: 'Back'),
        ),
      ],
    );
  }
}
