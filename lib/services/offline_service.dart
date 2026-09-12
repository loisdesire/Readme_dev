import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Pure decision logic, extracted so it's testable without the
/// connectivity_plus platform channel.
///
/// True if there's no real network connectivity: an empty result, or every
/// reported result is `none` or `vpn`. A VPN interface alone (no wifi/
/// mobile/ethernet/bluetooth alongside it) is treated as offline — on iOS/
/// macOS in particular, `vpn` can be reported as the sole result without a
/// real underlying network type being resolved, so it isn't trustworthy as
/// "online" on its own.
bool isOfflineFromConnectivity(List<ConnectivityResult> connectivityResult) {
  if (connectivityResult.isEmpty) return true;
  return connectivityResult.every((r) =>
      r == ConnectivityResult.none || r == ConnectivityResult.vpn);
}

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

    _isOffline = isOfflineFromConnectivity(connectivityResult);

    // Notify listeners only if status changed
    if (wasOffline != _isOffline) {
      notifyListeners();
      if (kDebugMode) {
        appLog(
          '[OFFLINE] Connection status changed: ${_isOffline ? "OFFLINE" : "ONLINE"}',
          level: 'DEBUG',
        );
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
