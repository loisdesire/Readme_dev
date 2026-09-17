// File: lib/services/device_child_profile_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A child's login remembered on this one device so they can tap their own
/// avatar to sign in instead of a parent typing their email/password every
/// time (docs/child-account-model-design.md, "Option B"). Storing a real
/// password on-device — even encrypted via secure storage — is a genuine
/// security tradeoff, named plainly in that doc rather than glossed over;
/// it's scoped to this one device, and never touches Firestore or any
/// backend.
@immutable
class RememberedChildProfile {
  final String uid;
  final String username;
  final String email;
  final String password;
  final String avatar;

  const RememberedChildProfile({
    required this.uid,
    required this.username,
    required this.email,
    required this.password,
    required this.avatar,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'username': username,
        'email': email,
        'password': password,
        'avatar': avatar,
      };

  factory RememberedChildProfile.fromJson(Map<String, dynamic> json) {
    return RememberedChildProfile(
      uid: json['uid'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      avatar: (json['avatar'] as String?) ?? '🧒',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RememberedChildProfile &&
      other.uid == uid &&
      other.username == username &&
      other.email == email &&
      other.password == password &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(uid, username, email, password, avatar);
}

/// Thin abstraction over secure on-device key/value storage. The real
/// `FlutterSecureStorage` talks to a platform channel that isn't available
/// under plain `flutter_test` (no real platform) — same class of gap as
/// this codebase's Firebase services, which is why they take an injectable
/// backend via `.withInstances(...)`. Tests inject an in-memory fake here
/// the same way.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _FlutterSecureStorageStore implements SecureKeyValueStore {
  const _FlutterSecureStorageStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Stores/retrieves the list of children remembered on this device.
class DeviceChildProfileService {
  static const _storageKey = 'readme_remembered_children';

  final SecureKeyValueStore _store;

  DeviceChildProfileService({@visibleForTesting SecureKeyValueStore? store})
      : _store = store ?? const _FlutterSecureStorageStore();

  Future<List<RememberedChildProfile>> getRememberedChildren() async {
    try {
      final raw = await _store.read(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) =>
              RememberedChildProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Secure storage being unavailable (a known flutter_secure_storage
      // gotcha right after a fresh install on some Android versions) or
      // corrupted/unexpected stored data shouldn't crash the app on
      // launch — just show no remembered profiles instead, same as a
      // device that never had any.
      return [];
    }
  }

  Future<void> rememberChild(RememberedChildProfile profile) async {
    final existing = await getRememberedChildren();
    final updated = [
      ...existing.where((p) => p.uid != profile.uid),
      profile,
    ];
    await _writeAll(updated);
  }

  Future<void> forgetChild(String uid) async {
    final existing = await getRememberedChildren();
    final updated = existing.where((p) => p.uid != uid).toList();
    await _writeAll(updated);
  }

  Future<void> _writeAll(List<RememberedChildProfile> profiles) {
    return _store.write(
      _storageKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }
}
