import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/connection/websocket_uri.dart';

void main() {
  group('buildRelayWebSocketUri', () {
    test('normalizes https scheme, drops :0, and removes fragment', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'https://api.sendrelay.com.ng:0#',
      );

      expect(uri.toString(),
          equals('wss://api.sendrelay.com.ng/v1/realtime/ws?token=jwt-token&type=APP'));
    });

    test('preserves explicit API path/stage', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'wss://api.sendrelay.com.ng/v1/realtime/ws',
      );

      expect(uri.toString(),
          equals('wss://api.sendrelay.com.ng/v1/realtime/ws?token=jwt-token&type=APP'));
    });

    test('accepts host-only URL and adds default scheme/path', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'api.sendrelay.com.ng',
      );

      expect(uri.toString(),
          equals('wss://api.sendrelay.com.ng/v1/realtime/ws?token=jwt-token&type=APP'));
    });

    test('encodes query params safely', () {
      final uri = buildRelayWebSocketUri(
        token: 'a+b/c==',
        baseUrl: 'wss://api.sendrelay.com.ng/v1/realtime/ws',
        deviceId: 'device id/1',
      );

      expect(
        uri.toString(),
        equals(
          'wss://api.sendrelay.com.ng/v1/realtime/ws?token=a%2Bb%2Fc%3D%3D&type=APP&deviceId=device+id%2F1',
        ),
      );
    });
  });
}
