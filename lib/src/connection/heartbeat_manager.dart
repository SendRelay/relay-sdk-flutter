import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Heartbeat manager for WebSocket connection health monitoring
///
/// Sends periodic ping messages and monitors pong responses.
/// Calls timeout callback if pong is not received within the timeout period.
class HeartbeatManager {
  /// WebSocket channel
  final WebSocketChannel channel;

  /// Interval between ping messages
  final Duration interval;

  /// Timeout for pong response
  final Duration timeout;

  /// Callback when timeout occurs
  final void Function() onTimeout;

  /// Ping timer
  Timer? _pingTimer;

  /// Pong timeout timer
  Timer? _pongTimer;

  /// Whether heartbeat is running
  bool _isRunning = false;

  /// Whether waiting for pong
  bool _waitingForPong = false;

  /// Create heartbeat manager
  HeartbeatManager({
    required this.channel,
    required this.interval,
    required this.timeout,
    required this.onTimeout,
  });

  /// Start heartbeat monitoring
  ///
  /// Sends ping messages at regular intervals and monitors for pong responses.
  ///
  /// Example:
  /// ```dart
  /// final heartbeat = HeartbeatManager(
  ///   channel: webSocketChannel,
  ///   interval: Duration(seconds: 30),
  ///   timeout: Duration(seconds: 10),
  ///   onTimeout: () {
  ///     print('Heartbeat timeout - reconnecting');
  ///     connection.reconnect();
  ///   },
  /// );
  /// heartbeat.start();
  /// ```
  void start() {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    _schedulePing();
  }

  /// Stop heartbeat monitoring
  ///
  /// Cancels all timers and resets state.
  void stop() {
    _isRunning = false;
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _pingTimer = null;
    _pongTimer = null;
    _waitingForPong = false;
  }

  /// Notify that pong was received
  ///
  /// Call this when a pong message is received from the server.
  /// Cancels the pong timeout timer.
  ///
  /// Example:
  /// ```dart
  /// channel.stream.listen((message) {
  ///   final data = jsonDecode(message);
  ///   if (data['type'] == 'pong' || data['action'] == 'pong') {
  ///     heartbeat.receivedPong();
  ///   }
  /// });
  /// ```
  void receivedPong() {
    _pongTimer?.cancel();
    _pongTimer = null;
    _waitingForPong = false;
  }

  /// Schedule next ping
  void _schedulePing() {
    if (!_isRunning) {
      return;
    }

    _pingTimer = Timer(interval, () {
      if (!_isRunning) {
        return;
      }

      // Send ping
      try {
        channel.sink.add(jsonEncode({'action': 'ping'}));
        _waitingForPong = true;

        // Start pong timeout
        _pongTimer = Timer(timeout, () {
          if (_waitingForPong && _isRunning) {
            // Timeout occurred
            stop();
            onTimeout();
          }
        });
      } catch (error) {
        // Failed to send ping - likely disconnected
        stop();
        onTimeout();
        return;
      }

      // Schedule next ping
      _schedulePing();
    });
  }

  /// Check if heartbeat is running
  bool get isRunning => _isRunning;

  @override
  String toString() =>
      'HeartbeatManager(interval: ${interval.inSeconds}s, timeout: ${timeout.inSeconds}s, running: $_isRunning)';
}
