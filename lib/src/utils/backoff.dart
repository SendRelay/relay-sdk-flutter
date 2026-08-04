import 'dart:math' as math;

/// Calculate exponential backoff delay with jitter
///
/// Uses exponential backoff with random jitter to prevent thundering herd problem.
///
/// Formula: min(maxDelay, initialDelay * (multiplier ^ attempt) + jitter)
///
/// Parameters:
/// - [attempt]: Current attempt number (0-based)
/// - [initialDelay]: Initial delay duration
/// - [maxDelay]: Maximum delay duration (caps exponential growth)
/// - [multiplier]: Backoff multiplier (default: 1.5)
/// - [jitter]: Maximum random jitter to add (default: 20% of calculated delay)
///
/// Example:
/// ```dart
/// // First attempt (0): 1s + jitter
/// // Second attempt (1): 1.5s + jitter
/// // Third attempt (2): 2.25s + jitter
/// // Fourth attempt (3): 3.375s + jitter
/// // ...capped at maxDelay
/// final delay = calculateBackoff(
///   attempt: 2,
///   initialDelay: Duration(seconds: 1),
///   maxDelay: Duration(seconds: 30),
///   multiplier: 1.5,
/// );
/// ```
Duration calculateBackoff({
  required int attempt,
  required Duration initialDelay,
  required Duration maxDelay,
  double multiplier = 1.5,
  double? jitter,
}) {
  // Calculate exponential delay
  final baseDelayMs = initialDelay.inMilliseconds * math.pow(multiplier, attempt);

  // Cap at max delay
  final cappedDelayMs = math.min(baseDelayMs, maxDelay.inMilliseconds.toDouble());

  // Add random jitter (default: 20% of delay)
  final jitterAmount = jitter ?? cappedDelayMs * 0.2;
  final randomJitter = math.Random().nextDouble() * jitterAmount;

  final totalDelayMs = (cappedDelayMs + randomJitter).toInt();

  return Duration(milliseconds: totalDelayMs);
}

/// Calculate exponential backoff delay in milliseconds
///
/// Convenience method that returns milliseconds directly.
///
/// Example:
/// ```dart
/// final delayMs = calculateBackoffMs(
///   attempt: 2,
///   initialDelayMs: 1000,
///   maxDelayMs: 30000,
/// );
/// await Future.delayed(Duration(milliseconds: delayMs));
/// ```
int calculateBackoffMs({
  required int attempt,
  required int initialDelayMs,
  required int maxDelayMs,
  double multiplier = 1.5,
  double? jitter,
}) {
  return calculateBackoff(
    attempt: attempt,
    initialDelay: Duration(milliseconds: initialDelayMs),
    maxDelay: Duration(milliseconds: maxDelayMs),
    multiplier: multiplier,
    jitter: jitter,
  ).inMilliseconds;
}
