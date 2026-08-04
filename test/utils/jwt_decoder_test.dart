import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/utils/jwt_decoder.dart';
import 'package:relay_flutter/src/errors/relay_error.dart';

void main() {
  group('JwtDecoder', () {
    group('parseJwt', () {
      test('parses valid JWT token', () {
        // Create a test JWT token
        final payload = {
          'sub': 'user123',
          'scope': ['task:task-1', 'task:task-2'],
          'exp': 1234567890,
          'iat': 1234560000,
          'jti': 'token-id-123',
          'iss': 'sendrelay.com.ng',
          'aud': 'relay-app',
        };

        final token = _createTestJwt(payload);
        final decoded = parseJwt(token);

        expect(decoded.sub, equals('user123'));
        expect(decoded.scope, equals(['task:task-1', 'task:task-2']));
        expect(decoded.exp, equals(1234567890));
        expect(decoded.iat, equals(1234560000));
        expect(decoded.jti, equals('token-id-123'));
        expect(decoded.iss, equals('sendrelay.com.ng'));
        expect(decoded.aud, equals('relay-app'));
      });

      test('parses JWT with custom fields', () {
        final payload = {
          'sub': 'user123',
          'exp': 1234567890,
          'customField': 'customValue',
          'nestedField': {'nested': 'value'},
        };

        final token = _createTestJwt(payload);
        final decoded = parseJwt(token);

        expect(decoded.sub, equals('user123'));
        expect(decoded.claims['customField'], equals('customValue'));
        expect(decoded.claims['nestedField'], isA<Map>());
      });

      test('parses JWT without optional fields', () {
        final payload = {
          'sub': 'user123',
        };

        final token = _createTestJwt(payload);
        final decoded = parseJwt(token);

        expect(decoded.sub, equals('user123'));
        expect(decoded.exp, isNull);
        expect(decoded.iat, isNull);
        expect(decoded.scope, isNull);
      });

      test('throws TokenError on invalid format (missing parts)', () {
        expect(
          () => parseJwt('invalid-token'),
          throwsA(isA<TokenError>()),
        );
      });

      test('throws TokenError on invalid format (empty parts)', () {
        expect(
          () => parseJwt('..'),
          throwsA(isA<TokenError>()),
        );
      });

      test('throws TokenError on invalid base64', () {
        expect(
          () => parseJwt('header.!!!invalid-base64!!!.signature'),
          throwsA(isA<TokenError>()),
        );
      });

      test('throws TokenError on invalid JSON', () {
        final invalidJson = base64UrlEncode(utf8.encode('not-json'));
        expect(
          () => parseJwt('header.$invalidJson.signature'),
          throwsA(isA<TokenError>()),
        );
      });

      test('handles base64url padding correctly', () {
        // Base64url encoding removes padding, test it's handled correctly
        final payloads = [
          {'sub': 'a'}, // Payload length that needs no padding
          {'sub': 'ab'}, // Payload length that needs padding
          {'sub': 'abc'}, // Different padding scenario
        ];

        for (final payload in payloads) {
          final token = _createTestJwt(payload);
          final decoded = parseJwt(token);
          expect(decoded.sub, equals(payload['sub']));
        }
      });

      test('handles base64url special characters', () {
        // Base64url uses '-' and '_' instead of '+' and '/'
        final payload = {
          'sub': 'user-with-special_chars+/=',
        };

        final token = _createTestJwt(payload);
        final decoded = parseJwt(token);

        expect(decoded.sub, equals('user-with-special_chars+/='));
      });
    });

    group('isTokenExpired', () {
      test('returns false for token without expiration', () {
        final payload = {'sub': 'user123'};
        final token = _createTestJwt(payload);

        expect(isTokenExpired(token), isFalse);
      });

      test('returns false for valid token (not expired)', () {
        final futureExp =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000;
        final payload = {'sub': 'user123', 'exp': futureExp};
        final token = _createTestJwt(payload);

        expect(isTokenExpired(token), isFalse);
      });

      test('returns true for expired token', () {
        final pastExp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = {'sub': 'user123', 'exp': pastExp};
        final token = _createTestJwt(payload);

        expect(isTokenExpired(token), isTrue);
      });

      test('returns true for token expiring right now', () {
        final nowExp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final payload = {'sub': 'user123', 'exp': nowExp};
        final token = _createTestJwt(payload);

        // Token should be expired (or about to expire)
        expect(isTokenExpired(token), isTrue);
      });

      test('returns true for invalid token', () {
        expect(isTokenExpired('invalid-token'), isTrue);
      });

      test('returns true for malformed token', () {
        expect(isTokenExpired('header.payload'), isTrue);
      });
    });

    group('getTimeUntilExpiration', () {
      test('returns null for token without expiration', () {
        final payload = {'sub': 'user123'};
        final token = _createTestJwt(payload);

        expect(getTimeUntilExpiration(token), isNull);
      });

      test('returns correct duration for valid token', () {
        final futureExp =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000;
        final payload = {'sub': 'user123', 'exp': futureExp};
        final token = _createTestJwt(payload);

        final duration = getTimeUntilExpiration(token);

        expect(duration, isNotNull);
        expect(duration!.inMinutes, closeTo(60, 1)); // ~60 minutes ± 1
      });

      test('returns Duration.zero for expired token', () {
        final pastExp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = {'sub': 'user123', 'exp': pastExp};
        final token = _createTestJwt(payload);

        final duration = getTimeUntilExpiration(token);

        expect(duration, equals(Duration.zero));
      });

      test('returns null for invalid token', () {
        expect(getTimeUntilExpiration('invalid-token'), isNull);
      });

      test('returns correct duration for token expiring soon', () {
        final futureExp = DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = {'sub': 'user123', 'exp': futureExp};
        final token = _createTestJwt(payload);

        final duration = getTimeUntilExpiration(token);

        expect(duration, isNotNull);
        expect(duration!.inMinutes, closeTo(5, 1)); // ~5 minutes ± 1
      });

      test('returns correct duration for long-lived token', () {
        final futureExp =
            DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/
                1000;
        final payload = {'sub': 'user123', 'exp': futureExp};
        final token = _createTestJwt(payload);

        final duration = getTimeUntilExpiration(token);

        expect(duration, isNotNull);
        expect(duration!.inDays, closeTo(7, 1)); // ~7 days ± 1
      });
    });

    group('JwtPayload', () {
      test('fromJson creates payload correctly', () {
        final json = {
          'sub': 'user123',
          'scope': ['task:1', 'task:2'],
          'exp': 1234567890,
          'iat': 1234560000,
          'jti': 'token-id',
          'iss': 'issuer',
          'aud': 'audience',
          'customField': 'value',
        };

        final payload = JwtPayload.fromJson(json);

        expect(payload.sub, equals('user123'));
        expect(payload.scope, equals(['task:1', 'task:2']));
        expect(payload.exp, equals(1234567890));
        expect(payload.iat, equals(1234560000));
        expect(payload.jti, equals('token-id'));
        expect(payload.iss, equals('issuer'));
        expect(payload.aud, equals('audience'));
        expect(payload.claims['customField'], equals('value'));
      });

      test('toString returns formatted string', () {
        final payload = JwtPayload(
          sub: 'user123',
          exp: 1234567890,
          scope: ['task:1'],
          claims: {},
        );

        final str = payload.toString();

        expect(str, contains('user123'));
        expect(str, contains('1234567890'));
        expect(str, contains('task:1'));
      });
    });
  });
}

// Helper function to create test JWT tokens
String _createTestJwt(Map<String, dynamic> payload) {
  final header = {'alg': 'HS256', 'typ': 'JWT'};

  final headerEncoded = base64UrlEncode(utf8.encode(jsonEncode(header)));
  final payloadEncoded = base64UrlEncode(utf8.encode(jsonEncode(payload)));
  final signature = 'test-signature';

  return '$headerEncoded.$payloadEncoded.$signature';
}
