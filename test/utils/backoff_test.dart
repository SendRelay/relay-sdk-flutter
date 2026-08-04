import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/utils/backoff.dart';

void main() {
  group('Backoff', () {
    group('calculateBackoff', () {
      test('returns initial delay for first attempt', () {
        final delay = calculateBackoff(
          attempt: 0,
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          multiplier: 1.5,
          jitter: 0, // Disable jitter for predictable testing
        );

        expect(delay.inMilliseconds, equals(1000));
      });

      test('applies exponential backoff correctly', () {
        final delays = [
          calculateBackoff(
            attempt: 0,
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            multiplier: 2.0,
            jitter: 0,
          ),
          calculateBackoff(
            attempt: 1,
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            multiplier: 2.0,
            jitter: 0,
          ),
          calculateBackoff(
            attempt: 2,
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            multiplier: 2.0,
            jitter: 0,
          ),
        ];

        expect(delays[0].inSeconds, equals(1)); // 1s
        expect(delays[1].inSeconds, equals(2)); // 2s
        expect(delays[2].inSeconds, equals(4)); // 4s
      });

      test('applies multiplier of 1.5 correctly', () {
        final delay1 = calculateBackoff(
          attempt: 1,
          initialDelay: const Duration(seconds: 2),
          maxDelay: const Duration(seconds: 60),
          multiplier: 1.5,
          jitter: 0,
        );

        expect(delay1.inSeconds, equals(3)); // 2 * 1.5 = 3s
      });

      test('caps delay at maxDelay', () {
        final delay = calculateBackoff(
          attempt: 10, // Large attempt number
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          multiplier: 2.0,
          jitter: 0,
        );

        expect(delay.inSeconds, lessThanOrEqualTo(30));
      });

      test('includes jitter when specified', () {
        final delays = List.generate(
          10,
          (_) => calculateBackoff(
            attempt: 0,
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            multiplier: 1.5,
            // jitter defaults to 20% of delay
          ),
        );

        // All delays should be different due to random jitter
        final uniqueDelays = delays.toSet();
        expect(uniqueDelays.length, greaterThan(1));

        // All delays should be >= 1000ms (base delay)
        for (final delay in delays) {
          expect(delay.inMilliseconds, greaterThanOrEqualTo(1000));
          // And <= 1000 + 20% jitter = 1200ms
          expect(delay.inMilliseconds, lessThanOrEqualTo(1200));
        }
      });

      test('respects custom jitter amount', () {
        final delays = List.generate(
          10,
          (_) => calculateBackoff(
            attempt: 0,
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            multiplier: 1.5,
            jitter: 500.0, // Fixed 500ms jitter
          ),
        );

        for (final delay in delays) {
          expect(delay.inMilliseconds, greaterThanOrEqualTo(1000));
          expect(delay.inMilliseconds, lessThanOrEqualTo(1500));
        }
      });

      test('handles zero jitter', () {
        final delay1 = calculateBackoff(
          attempt: 0,
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          multiplier: 1.5,
          jitter: 0,
        );

        final delay2 = calculateBackoff(
          attempt: 0,
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          multiplier: 1.5,
          jitter: 0,
        );

        // With zero jitter, delays should be identical
        expect(delay1.inMilliseconds, equals(delay2.inMilliseconds));
      });

      test('handles large attempt numbers', () {
        final delay = calculateBackoff(
          attempt: 100,
          initialDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          multiplier: 1.5,
          jitter: 0,
        );

        // Should be capped at maxDelay
        expect(delay.inSeconds, equals(30));
      });
    });

    group('calculateBackoffMs', () {
      test('returns milliseconds for first attempt', () {
        final delayMs = calculateBackoffMs(
          attempt: 0,
          initialDelayMs: 1000,
          maxDelayMs: 30000,
          multiplier: 1.5,
          jitter: 0,
        );

        expect(delayMs, equals(1000));
      });

      test('applies exponential backoff correctly', () {
        final delayMs = calculateBackoffMs(
          attempt: 1,
          initialDelayMs: 1000,
          maxDelayMs: 30000,
          multiplier: 2.0,
          jitter: 0,
        );

        expect(delayMs, equals(2000));
      });

      test('caps delay at maxDelayMs', () {
        final delayMs = calculateBackoffMs(
          attempt: 10,
          initialDelayMs: 1000,
          maxDelayMs: 30000,
          multiplier: 2.0,
          jitter: 0,
        );

        expect(delayMs, lessThanOrEqualTo(30000));
      });

      test('includes jitter when specified', () {
        final delays = List.generate(
          10,
          (_) => calculateBackoffMs(
            attempt: 0,
            initialDelayMs: 1000,
            maxDelayMs: 30000,
            multiplier: 1.5,
          ),
        );

        // All delays should be different due to random jitter
        final uniqueDelays = delays.toSet();
        expect(uniqueDelays.length, greaterThan(1));

        for (final delayMs in delays) {
          expect(delayMs, greaterThanOrEqualTo(1000));
          expect(delayMs, lessThanOrEqualTo(1200)); // 1000 + 20%
        }
      });
    });
  });
}
