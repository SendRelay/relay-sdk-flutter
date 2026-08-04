import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/connection/websocket_uri.dart';

void main() {
  group('buildRelayWebSocketUri', () {
    test('normalizes https scheme, drops :0, and removes fragment', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'https://ws.sendrelay.com.ng:0#',
      );

      expect(uri.toString(),
          equals('wss://ws.sendrelay.com.ng/v1?token=jwt-token&type=APP'));
    });

    test('preserves explicit API path/stage', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'wss://ws.sendrelay.com.ng/v1',
      );

      expect(uri.toString(),
          equals('wss://ws.sendrelay.com.ng/v1?token=jwt-token&type=APP'));
    });

    test('accepts host-only URL and adds default scheme/path', () {
      final uri = buildRelayWebSocketUri(
        token: 'jwt-token',
        baseUrl: 'ws.sendrelay.com.ng',
      );

      expect(uri.toString(),
          equals('wss://ws.sendrelay.com.ng/v1?token=jwt-token&type=APP'));
    });

    test('encodes query params safely', () {
      final uri = buildRelayWebSocketUri(
        token: 'a+b/c==',
        baseUrl: 'wss://ws.sendrelay.com.ng/v1',
        deviceId: 'device id/1',
      );

      expect(
        uri.toString(),
        equals(
          'wss://ws.sendrelay.com.ng/v1?token=a%2Bb%2Fc%3D%3D&type=APP&deviceId=device+id%2F1',
        ),
      );
    });
  });
}
