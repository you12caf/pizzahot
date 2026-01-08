import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:food_order/models/order.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintingService {
  PrintingService._();
  static final PrintingService _instance = PrintingService._();
  factory PrintingService() => _instance;

  static const String _prefsMacKey = 'printer_mac_address';
  static const String _prefsNameKey = 'printer_name';

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> search() async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return <BluetoothDevice>[];
    }

    try {
      return await _printer.getBondedDevices();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Printer search failed: $e');
      }
      return <BluetoothDevice>[];
    }
  }

  Future<bool> isConnected() async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return false;
    }

    try {
      return await _printer.isConnected ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getSavedPrinterAddress() async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_prefsMacKey);
    return (address != null && address.isNotEmpty) ? address : null;
  }

  Future<String?> getSavedPrinterName() async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsNameKey);
    return (name != null && name.isNotEmpty) ? name : null;
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return false;
    }

    try {
      await _printer.connect(device);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMacKey, device.address ?? '');
      await prefs.setString(_prefsNameKey, device.name ?? '');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('connect error: $e');
      }
      return false;
    }
  }

  Future<bool> _attemptReconnect() async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return false;
    }

    final savedAddress = await getSavedPrinterAddress();
    if (savedAddress == null) return false;
    final devices = await search();
    BluetoothDevice? match;
    for (final device in devices) {
      if (device.address == savedAddress) {
        match = device;
        break;
      }
    }
    if (match == null) return false;
    try {
      await _printer.connect(match);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('reconnect error: $e');
      }
      return false;
    }
  }

  Future<void> printOrder(Order order, String restaurantName) async {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return;
    }

    bool connected = await isConnected();
    if (!connected) {
      connected = await _attemptReconnect();
    }
    if (!connected) {
      throw Exception('Printer not connected');
    }

    final currencyFormatter = NumberFormat('#,##0.00');
    final date = DateFormat('dd MMM yyyy - HH:mm').format(DateTime.now());
    final divider = ''.padLeft(32, '-');
    final effectiveName = restaurantName.trim().isNotEmpty
        ? restaurantName.trim()
        : 'My Restaurant';

    await _printer.printCustom(effectiveName, 3, 1);
    await _printer.printCustom(date, 1, 1);
    await _printer.printCustom(divider, 1, 1);

    if (order.items != null && order.items!.isNotEmpty) {
      for (final item in order.items!) {
        final qty = _toDouble(item['quantity'] ?? item['qty'] ?? 1).toInt();
        final name = (item['name'] ?? 'Item').toString();
        final priceValue = _toDouble(item['price'] ?? item['total'] ?? 0);
        final lineTotal = (priceValue * qty).toDouble();
        final leftText = '${qty}x $name';
        final rightText = '${currencyFormatter.format(lineTotal)} DA';
        await _printer.printLeftRight(leftText, rightText, 0);
      }
    } else if (order.receipt != null && order.receipt!.isNotEmpty) {
      await _printer.printCustom(order.receipt!, 0, 0);
    } else {
      await _printer.printCustom('No items listed', 0, 0);
    }

    await _printer.printCustom(divider, 1, 1);
    final totalValue = order.total ?? 0;
    await _printer.printCustom(
      'TOTAL: ${currencyFormatter.format(totalValue)} DA',
      2,
      1,
    );

    await _printer.printNewLine();
    await _printer.printCustom(
      'Customer: ${order.customerName ?? '-'}',
      0,
      0,
    );
    await _printer.printCustom(
      'Phone: ${order.phone ?? '-'}',
      0,
      0,
    );
    await _printer.printCustom(
      'Address: ${order.address ?? '-'}',
      0,
      0,
    );

    await _printer.printNewLine();
    await _printer.printNewLine();
    await _printer.printNewLine();
  }

  double _toDouble(dynamic value) {
    if (kIsWeb) {
      print('Web: Printing disabled');
      return 0;
    }

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
