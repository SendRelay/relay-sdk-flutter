import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/utils/device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Relay deviceId persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generates and stores a deviceId when none exists', () async {
      final deviceId = await getOrCreateRelayDeviceId();

      expect(deviceId, startsWith('relay_flutter_'));
      expect(deviceId, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(relayDeviceIdStorageKey),
        equals(deviceId),
      );
    });

    test('returns same stored deviceId across calls', () async {
      final first = await getOrCreateRelayDeviceId();
      final second = await getOrCreateRelayDeviceId();

      expect(second, equals(first));
    });

    test('reuses pre-existing stored deviceId', () async {
      SharedPreferences.setMockInitialValues({
        relayDeviceIdStorageKey: 'relay_flutter_existing_device_id',
      });

      final deviceId = await getOrCreateRelayDeviceId();
      expect(deviceId, equals('relay_flutter_existing_device_id'));
    });
  });
}
