import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectionWrapper extends StatefulWidget {
  const ConnectionWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectionWrapper> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends State<ConnectionWrapper> {
  StreamSubscription<ConnectivityResult>? _subscription;
  ConnectivityResult? _latestResult;
  bool _hasInitialCheck = false;

  @override
  void initState() {
    super.initState();
    _performInitialCheck();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((result) => _handleResult(result));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _performInitialCheck() async {
    final result = await Connectivity().checkConnectivity();
    _handleResult(result, fromInitialCheck: true);
  }

  void _handleResult(ConnectivityResult result,
      {bool fromInitialCheck = false}) {
    final offline = result == ConnectivityResult.none;
    if (!mounted) return;
    setState(() {
      _latestResult = result;
      _hasInitialCheck = true;
    });

    if (offline && _hasInitialCheck && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection detected.')),
      );
    }
  }

  Future<void> _manualCheck() async {
    final result = await Connectivity().checkConnectivity();
    final connected = result != ConnectivityResult.none;
    if (!mounted) return;
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still offline')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected =
        _latestResult != ConnectivityResult.none && _hasInitialCheck;

    if (!isConnected) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 96,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasInitialCheck
                      ? 'Please check your network settings to continue ordering.'
                      : 'Checking connection…',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _manualCheck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(_hasInitialCheck ? 'Try Again' : 'Retry'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
