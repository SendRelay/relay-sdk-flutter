import 'package:logging/logging.dart';
import '../connection/websocket_uri.dart';

/// Reconnection configuration
class ReconnectConfig {
  /// Enable automatic reconnection
  final bool enabled;

  /// Maximum reconnection attempts (-1 for infinite)
  final int maxAttempts;

  /// Initial delay before first reconnection
  final Duration initialDelay;

  /// Maximum delay between reconnection attempts
  final Duration maxDelay;

  /// Backoff multiplier for exponential backoff
  final double backoffMultiplier;

  /// Create reconnection configuration
  const ReconnectConfig({
    this.enabled = true,
    this.maxAttempts = -1,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 1.5,
  });

  @override
  String toString() =>
      'ReconnectConfig(enabled: $enabled, maxAttempts: $maxAttempts, '
      'initialDelay: ${initialDelay.inSeconds}s, maxDelay: ${maxDelay.inSeconds}s)';
}

/// Heartbeat configuration
class HeartbeatConfig {
  /// Enable heartbeat monitoring
  final bool enabled;

  /// Interval between heartbeat pings
  final Duration interval;

  /// Timeout for heartbeat response
  final Duration timeout;

  /// Create heartbeat configuration
  const HeartbeatConfig({
    this.enabled = true,
    this.interval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 10),
  });

  @override
  String toString() =>
      'HeartbeatConfig(enabled: $enabled, interval: ${interval.inSeconds}s, '
      'timeout: ${timeout.inSeconds}s)';
}

/// Relay real-time client configuration
class RelayRealtimeClientOptions {
  /// Callback to fetch WebSocket token from backend
  ///
  /// This function should make an authenticated request to your backend
  /// to fetch a WebSocket token for the specified task IDs.
  ///
  /// Example:
  /// ```dart
  /// getToken: (taskIds) async {
  ///   final response = await http.post(
  ///     Uri.parse('https://your-backend.com/api/relay/token'),
  ///     headers: {'Authorization': 'Bearer $userToken'},
  ///     body: jsonEncode({'taskIds': taskIds}),
  ///   );
  ///   return jsonDecode(response.body)['token'];
  /// }
  /// ```
  final Future<String> Function(List<String> taskIds) getToken;

  /// WebSocket URL (default: wss://ws.sendrelay.com.ng/v1)
  final String url;

  /// Device identifier.
  ///
  /// If not provided, the SDK generates and persists one automatically on first connect.
  final String? deviceId;

  /// Auto-refresh tokens before expiration
  final bool autoRefresh;

  /// Token refresh warning threshold
  ///
  /// When the token is about to expire within this duration,
  /// a token refresh will be triggered.
  final Duration tokenExpirationWarning;

  /// Reconnection configuration
  final ReconnectConfig reconnect;

  /// Heartbeat configuration
  final HeartbeatConfig heartbeat;

  /// Optional logger for debugging
  final Logger? logger;

  /// Create Relay real-time client options
  RelayRealtimeClientOptions({
    required this.getToken,
    String? url,
    String? deviceId,
    this.autoRefresh = true,
    this.tokenExpirationWarning = const Duration(minutes: 5),
    ReconnectConfig? reconnect,
    HeartbeatConfig? heartbeat,
    this.logger,
  })  : url = url ?? relayDefaultWebSocketUrl,
        deviceId = _normalizeDeviceId(deviceId),
        reconnect = reconnect ?? const ReconnectConfig(),
        heartbeat = heartbeat ?? const HeartbeatConfig();

  @override
  String toString() =>
      'RelayRealtimeClientOptions(url: $url, autoRefresh: $autoRefresh, '
      'reconnect: $reconnect, heartbeat: $heartbeat)';
}

String? _normalizeDeviceId(String? deviceId) {
  final normalized = deviceId?.trim();
  if (normalized != null && normalized.isNotEmpty) {
    return normalized;
  }
  return null;
}
