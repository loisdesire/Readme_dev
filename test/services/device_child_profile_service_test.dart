import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/device_child_profile_service.dart';

// The real FlutterSecureStorage backend talks to a platform channel that
// isn't available under plain `flutter_test` — this in-memory fake stands
// in for it, same pattern as this codebase's Firebase `.withInstances`
// test doubles.
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};
  int readCount = 0;

  @override
  Future<String?> read(String key) async {
    readCount++;
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class ThrowingSecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async {
    throw Exception('secure storage unavailable');
  }

  @override
  Future<void> write(String key, String value) async {}
}

const junior = RememberedChildProfile(
  uid: 'kid-1',
  username: 'Junior',
  email: 'junior@example.com',
  password: 'password123',
  avatar: '👦',
);

const rosie = RememberedChildProfile(
  uid: 'kid-2',
  username: 'Rosie',
  email: 'rosie@example.com',
  password: 'password456',
  avatar: '👧',
);

void main() {
  late InMemorySecureKeyValueStore store;
  late DeviceChildProfileService service;

  setUp(() {
    store = InMemorySecureKeyValueStore();
    service = DeviceChildProfileService(store: store);
  });

  test('a fresh device has no remembered children', () async {
    expect(await service.getRememberedChildren(), isEmpty);
  });

  test('rememberChild makes it show up in getRememberedChildren', () async {
    await service.rememberChild(junior);

    final profiles = await service.getRememberedChildren();
    expect(profiles, [junior]);
  });

  test('rememberChild for a second child keeps both', () async {
    await service.rememberChild(junior);
    await service.rememberChild(rosie);

    final profiles = await service.getRememberedChildren();
    expect(profiles, containsAll([junior, rosie]));
    expect(profiles, hasLength(2));
  });

  test(
      'rememberChild called again for the same uid replaces the old entry, '
      'not a duplicate — e.g. a password reset', () async {
    await service.rememberChild(junior);
    const updated = RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'new-password',
      avatar: '👦',
    );
    await service.rememberChild(updated);

    final profiles = await service.getRememberedChildren();
    expect(profiles, hasLength(1));
    expect(profiles.single.password, 'new-password');
  });

  test('forgetChild removes just that one child', () async {
    await service.rememberChild(junior);
    await service.rememberChild(rosie);

    await service.forgetChild('kid-1');

    final profiles = await service.getRememberedChildren();
    expect(profiles, [rosie]);
  });

  test('forgetChild for a uid that was never remembered is a harmless no-op',
      () async {
    await service.rememberChild(junior);

    await service.forgetChild('does-not-exist');

    expect(await service.getRememberedChildren(), [junior]);
  });

  test('corrupted stored data degrades to an empty list, not a crash',
      () async {
    await store.write('readme_remembered_children', 'not valid json {{{');

    expect(await service.getRememberedChildren(), isEmpty);
  });

  test(
      'secure storage being unavailable (e.g. right after a fresh install) '
      'degrades to an empty list, not a crash', () async {
    final throwingService =
        DeviceChildProfileService(store: ThrowingSecureKeyValueStore());

    expect(await throwingService.getRememberedChildren(), isEmpty);
  });
}
