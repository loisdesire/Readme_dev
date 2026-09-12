import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/offline_service.dart';

void main() {
  group('isOfflineFromConnectivity', () {
    test('an empty result list is offline', () {
      expect(isOfflineFromConnectivity([]), isTrue);
    });

    test('[none] is offline', () {
      expect(isOfflineFromConnectivity([ConnectivityResult.none]), isTrue);
    });

    test(
        'regression: VPN alone is offline, matching the documented intent '
        '("no connectivity or only VPN") that the original boolean check '
        "never actually implemented — it only ever checked for `none`",
        () {
      expect(isOfflineFromConnectivity([ConnectivityResult.vpn]), isTrue);
    });

    test('[none, vpn] together is still offline (no real network type present)',
        () {
      expect(
        isOfflineFromConnectivity([ConnectivityResult.none, ConnectivityResult.vpn]),
        isTrue,
      );
    });

    test('wifi alone is online', () {
      expect(isOfflineFromConnectivity([ConnectivityResult.wifi]), isFalse);
    });

    test('mobile alone is online', () {
      expect(isOfflineFromConnectivity([ConnectivityResult.mobile]), isFalse);
    });

    test('VPN tunneling over wifi (both reported) is online — a real '
        'network type is present alongside the VPN', () {
      expect(
        isOfflineFromConnectivity([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        isFalse,
      );
    });

    test('bluetooth and ethernet both count as real connectivity', () {
      expect(isOfflineFromConnectivity([ConnectivityResult.bluetooth]), isFalse);
      expect(isOfflineFromConnectivity([ConnectivityResult.ethernet]), isFalse);
    });
  });

  group('OfflineService', () {
    test('defaults to online before initialize() runs', () {
      expect(OfflineService.instance.isOffline, isFalse);
      expect(OfflineService.instance.isOnline, isTrue);
    });
  });
}
