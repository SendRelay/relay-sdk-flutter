import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/models/options.dart';

void main() {
  group('RelayRealtimeClientOptions defaults', () {
    test('uses the api.sendrelay.com.ng realtime endpoint by default', () {
      final options = RelayRealtimeClientOptions(
        getToken: (_) async => 'token',
      );

      expect(options.url, equals('https://api.sendrelay.com.ng/v1/realtime/ws'));
    });

    test('keeps deviceId null when not provided', () {
      final options = RelayRealtimeClientOptions(
        getToken: (_) async => 'token',
      );

      expect(options.deviceId, isNull);
    });

    test('uses provided deviceId after trimming', () {
      final options = RelayRealtimeClientOptions(
        getToken: (_) async => 'token',
        deviceId: '  my-device-123  ',
      );

      expect(options.deviceId, equals('my-device-123'));
    });
  });
}
