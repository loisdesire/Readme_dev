import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class OfflineService extends ChangeNotifier {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  bool _isOffline = false;
  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> initialize() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResult) {
    final wasOffline = _isOffline;

    // User is offline if there's no connectivity or only VPN
    _isOffline = connectivityResult.isEmpty ||
        (connectivityResult.length == 1 &&
            connectivityResult.first == ConnectivityResult.none);

    // Notify listeners only if status changed
    if (wasOffline != _isOffline) {
      notifyListeners();
      if (kDebugMode) {
        print(
            '[OFFLINE] Connection status changed: ${_isOffline ? "OFFLINE" : "ONLINE"}');
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
