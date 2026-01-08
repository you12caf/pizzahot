import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:food_order/models/order.dart' as app_order;
import 'package:food_order/services/printing_service.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrintingService _printingService = PrintingService();

  List<BluetoothDevice> _devices = <BluetoothDevice>[];
  String? _selectedAddress;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final devices = await _printingService.search();
    final savedAddress = await _printingService.getSavedPrinterAddress();
    final connected = await _printingService.isConnected();
    setState(() {
      _devices = devices;
      _selectedAddress = savedAddress;
      _isConnected = connected;
      _initializing = false;
    });
  }

  Future<bool> _ensurePermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = statuses.values.every((status) => status.isGranted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permissions are required.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return granted;
  }

  Future<void> _scanDevices() async {
    if (!await _ensurePermissions()) return;
    setState(() => _isScanning = true);
    final devices = await _printingService.search();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _selectedAddress = device.address);
    final success = await _printingService.connect(device);
    if (!mounted) return;
    setState(() => _isConnected = success);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Connected to ${device.name ?? device.address}.'
            : 'Failed to connect to ${device.name ?? device.address}.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _handleTestPrint() async {
    try {
      final restaurantName =
          Provider.of<RestaurantThemeProvider>(context, listen: false)
                  .restaurantName ??
              'My Restaurant';
      await _printingService.printOrder(
        app_order.Order(
          id: 'test',
          customerName: 'Printer Test',
          address: 'RestoDZ HQ',
          phone: '+213 555 000 000',
          items: <Map<String, dynamic>>[
            {'name': 'Sample Item', 'quantity': 1, 'price': 100},
            {'name': 'Drink', 'quantity': 2, 'price': 50},
          ],
          total: 200,
        ),
        restaurantName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test receipt sent to printer.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusChip = Chip(
      avatar: Icon(
        _isConnected ? Icons.check_circle : Icons.cancel,
        color: _isConnected ? Colors.green : Colors.red,
      ),
      label: Text(_isConnected ? 'Connected' : 'Disconnected'),
      backgroundColor: _isConnected ? Colors.green[50] : Colors.red[50],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      statusChip,
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: _isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                        onPressed: _isScanning ? null : _scanDevices,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Paired Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _devices.isEmpty
                        ? const Center(
                            child: Text(
                              'No paired printers found. Pair a printer in system settings and tap Scan.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              final address = device.address ?? 'Unknown';
                              final isSelected =
                                  _selectedAddress == device.address;
                              return RadioListTile<String>(
                                value: address,
                                groupValue: _selectedAddress,
                                onChanged: (_) => _connectToDevice(device),
                                title: Text(device.name ?? 'Unknown printer'),
                                subtitle: Text(address),
                                secondary: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : const Icon(Icons.print),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Test Print'),
                      onPressed: _handleTestPrint,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
