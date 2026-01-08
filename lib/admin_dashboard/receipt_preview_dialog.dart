import 'package:flutter/material.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/models/order.dart' as app_order;
import 'package:food_order/services/printing_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.restaurantName,
  });

  final app_order.Order order;
  final String restaurantName;

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final PrintingService _printingService = PrintingService();
  bool _isPrinting = false;
  String? _errorMessage;

  TextStyle _monoStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign? textAlign,
  }) {
    final base = GoogleFonts.courierPrime(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.3,
    );
    return base;
  }

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
      _errorMessage = null;
    });

    try {
      await _printingService.printOrder(widget.order, widget.restaurantName);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isPrinting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReceiptCard(
            order: widget.order,
            restaurantName: widget.restaurantName,
            monoStyleBuilder: _monoStyle,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              TextButton(
                onPressed:
                    _isPrinting ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.print),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _isPrinting ? 'Printing…' : 'Print Now',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC6011),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isPrinting ? null : _handlePrint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.order,
    required this.restaurantName,
    required this.monoStyleBuilder,
  });

  final app_order.Order order;
  final String restaurantName;
  final TextStyle Function(
      {double fontSize,
      FontWeight fontWeight,
      TextAlign? textAlign}) monoStyleBuilder;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    final date = order.date;
    final formattedDate = DateFormat('EEE, dd MMM yyyy • hh:mm a')
        .format(date is DateTime ? date : DateTime.now());

    children.addAll([
      Text(
        restaurantName.trim().isEmpty ? 'My Restaurant' : restaurantName.trim(),
        textAlign: TextAlign.center,
        style: monoStyleBuilder(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        formattedDate,
        textAlign: TextAlign.center,
        style: monoStyleBuilder(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      _dottedDivider(),
      const SizedBox(height: 12),
    ]);

    final items = order.items ?? [];
    if (items.isNotEmpty) {
      for (final item in items) {
        children.add(_ReceiptLineItem(
          label: _formatItemLabel(item),
          value: formatPrice(_lineTotal(item)),
          monoStyleBuilder: monoStyleBuilder,
        ));
      }
    } else if ((order.receipt ?? '').trim().isNotEmpty) {
      children.add(Text(
        order.receipt!.trim(),
        style: monoStyleBuilder(fontSize: 13),
      ));
    } else {
      children.add(Text(
        'No items provided',
        style: monoStyleBuilder(fontSize: 13),
      ));
    }

    children.addAll([
      const SizedBox(height: 12),
      _dottedDivider(),
      const SizedBox(height: 12),
      _ReceiptLineItem(
        label: 'TOTAL',
        value: formatPrice(_orderTotal()),
        monoStyleBuilder: monoStyleBuilder,
        emphasize: true,
      ),
      const SizedBox(height: 16),
      Text(
        'Customer: ${order.customerName ?? '-'}',
        style: monoStyleBuilder(fontSize: 13),
      ),
      const SizedBox(height: 4),
      Text(
        'Phone: ${order.phone ?? '-'}',
        style: monoStyleBuilder(fontSize: 13),
      ),
      const SizedBox(height: 4),
      Text(
        'Address: ${order.address ?? '-'}',
        style: monoStyleBuilder(fontSize: 13),
      ),
      const SizedBox(height: 12),
      _dottedDivider(),
      const SizedBox(height: 8),
      Text(
        'Thank you!',
        textAlign: TextAlign.center,
        style: monoStyleBuilder(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ]);

    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return Container(
      width: 340,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  double _orderTotal() {
    return order.total ?? 0;
  }

  String _formatItemLabel(Map<String, dynamic> item) {
    final qtyRaw = item['quantity'] ?? item['qty'] ?? 1;
    final qty =
        qtyRaw is num ? qtyRaw.toInt() : int.tryParse(qtyRaw.toString()) ?? 1;
    final name = (item['name'] ?? 'Item').toString();
    return '${qty}x $name';
  }

  double _lineTotal(Map<String, dynamic> item) {
    final qtyRaw = item['quantity'] ?? item['qty'] ?? 1;
    final qty =
        qtyRaw is num ? qtyRaw.toInt() : int.tryParse(qtyRaw.toString()) ?? 1;
    final priceRaw = item['price'] ?? item['total'] ?? 0;
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw.toString()) ?? 0;
    return price * qty;
  }

  Widget _dottedDivider() {
    return Text(
      ''.padLeft(32, '.'),
      textAlign: TextAlign.center,
      style: monoStyleBuilder(fontSize: 12, fontWeight: FontWeight.w300),
    );
  }
}

class _ReceiptLineItem extends StatelessWidget {
  const _ReceiptLineItem({
    required this.label,
    required this.value,
    required this.monoStyleBuilder,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final TextStyle Function(
      {double fontSize,
      FontWeight fontWeight,
      TextAlign? textAlign}) monoStyleBuilder;

  @override
  Widget build(BuildContext context) {
    final weight = emphasize ? FontWeight.w700 : FontWeight.w500;
    final size = emphasize ? 18.0 : 14.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: monoStyleBuilder(fontSize: size, fontWeight: weight),
            ),
          ),
          Text(
            value,
            style: monoStyleBuilder(fontSize: size, fontWeight: weight),
          ),
        ],
      ),
    );
  }
}
