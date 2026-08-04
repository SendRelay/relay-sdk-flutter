import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/events.dart';
import '../models/options.dart';
import '../errors/relay_error.dart';
import '../utils/jwt_decoder.dart';
import '../utils/backoff.dart';
import 'heartbeat_manager.dart';
import 'message_queue.dart';
import 'websocket_uri.dart';

/// WebSocket connection manager with automatic reconnection
///
/// Handles connection lifecycle, reconnection, heartbeat, and message queuing.
class WebSocketConnection {
  /// WebSocket URL
  final String url;

  /// Optional device ID
  String? _deviceId;

  /// Reconnection configuration
  final ReconnectConfig reconnectConfig;

  /// Heartbeat configuration
  final HeartbeatConfig heartbeatConfig;

  /// Optional logger
  final Logger? logger;

  /// Current WebSocket channel
  WebSocketChannel? _channel;

  /// Current connection state
  ConnectionState _state = ConnectionState.disconnected;

  /// Current JWT token
  String? _token;

  /// Reconnection attempt count
  int _reconnectAttempt = 0;

  /// Reconnection timer
  Timer? _reconnectTimer;

  /// Heartbeat manager
  HeartbeatManager? _heartbeat;

  /// Message queue for offline messages
  final MessageQueue _messageQueue;

  /// Stream subscription for incoming messages
  StreamSubscription<dynamic>? _messageSubscription;

  /// Stream controllers for events
  final StreamController<void> _openController =
      StreamController<void>.broadcast();
  final StreamController<Map<String, dynamic>> _closeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<dynamic> _errorController =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();
  final StreamController<Map<String, dynamic>> _reconnectingController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Event streams
  Stream<void> get onOpen => _openController.stream;
  Stream<Map<String, dynamic>> get onClose => _closeController.stream;
  Stream<dynamic> get onError => _errorController.stream;
  Stream<dynamic> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onReconnecting =>
      _reconnectingController.stream;

  /// Create WebSocket connection
  WebSocketConnection({
    required this.url,
    String? deviceId,
    required this.reconnectConfig,
    required this.heartbeatConfig,
    this.logger,
    int messageQueueSize = 100,
  })  : _deviceId = deviceId,
        _messageQueue = MessageQueue(maxSize: messageQueueSize);

  /// Connect to WebSocket server
  ///
  /// Example:
  /// ```dart
  /// await connection.connect();
  /// ```
  Future<void> connect() async {
    if (_state == ConnectionState.connected ||
        _state == ConnectionState.connecting) {
      return;
    }

    if (_token == null) {
      throw const ConnectionError(
          'Token must be set before connecting. Call setToken() first.');
    }
    if (isTokenExpired(_token!)) {
      throw const TokenError(
          'WebSocket token is expired. Fetch a fresh token before connecting.');
    }

    _setState(ConnectionState.connecting);
    _log('info', 'Connecting to WebSocket...');

    try {
      final uri = _buildUri();
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be ready
      await _channel!.ready;

      _log('info', 'WebSocket connected');
      _setState(ConnectionState.connected);
      _reconnectAttempt = 0;
      _openController.add(null);

      // Start heartbeat
      if (heartbeatConfig.enabled && _channel != null) {
        _heartbeat = HeartbeatManager(
          channel: _channel!,
          interval: heartbeatConfig.interval,
          timeout: heartbeatConfig.timeout,
          onTimeout: () {
            _log('warn', 'Heartbeat timeout - reconnecting');
            _reconnect();
          },
        );
        _heartbeat!.start();
      }

      // Listen to incoming messages
      _messageSubscription = _channel!.stream.listen(
        (dynamic message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;

            // Handle pong for heartbeat
            if (data['type'] == 'pong' || data['action'] == 'pong') {
              _heartbeat?.receivedPong();
              return;
            }

            _messageController.add(data);
          } catch (error) {
            _log('error', 'Failed to parse message', error);
          }
        },
        onError: (dynamic error) {
          _log('error', 'WebSocket error', error);
          _errorController.add(error);
        },
        onDone: () {
          _log('info', 'WebSocket closed');
          _cleanup();
          _closeController.add({'code': null, 'reason': null});

          // Auto-reconnect
          if (reconnectConfig.enabled) {
            _reconnect();
          }
        },
      );

      // Flush queued messages
      _messageQueue.flush((message) {
        _channel!.sink.add(jsonEncode(message));
      });
    } catch (error) {
      _log('error', 'Connection failed', error);
      _setState(ConnectionState.disconnected);
      throw ConnectionError('WebSocket connection failed', error);
    }
  }

  /// Disconnect from WebSocket server
  ///
  /// [graceful] - Whether to wait for pending messages (default: true)
  ///
  /// Example:
  /// ```dart
  /// connection.disconnect();
  /// ```
  void disconnect({bool graceful = true}) {
    if (_state == ConnectionState.disconnected ||
        _state == ConnectionState.disconnecting) {
      return;
    }

    _setState(ConnectionState.disconnecting);
    _log('info', 'Disconnecting...');

    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }

    if (graceful && _messageQueue.hasMessages) {
      // Wait briefly for queued messages to flush
      Future.delayed(const Duration(seconds: 1), () {
        _channel?.sink.close(1000, 'Client disconnect');
      });
    } else {
      _channel?.sink.close(1000, 'Client disconnect');
    }

    _cleanup();
  }

  /// Send a message
  ///
  /// [message] - Message to send
  ///
  /// Example:
  /// ```dart
  /// await connection.send({'action': 'subscribe', 'type': 'task', 'id': 'task-123'});
  /// ```
  Future<void> send(Map<String, dynamic> message) async {
    if (_state != ConnectionState.connected) {
      // Queue message for when connection is restored
      _messageQueue.enqueue(message);
      _log('debug', 'Message queued (not connected)', message);
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
      _log('debug', 'Message sent', message);
    } catch (error) {
      _log('error', 'Failed to send message', error);
      _messageQueue.enqueue(message);
      throw ConnectionError('Failed to send message', error);
    }
  }

  /// Get current connection state
  ConnectionState getState() => _state;

  /// Check if connected
  bool isConnected() => _state == ConnectionState.connected;

  /// Update token (for refresh)
  ///
  /// Disconnects and reconnects with new token.
  ///
  /// [token] - New JWT token
  ///
  /// Example:
  /// ```dart
  /// connection.updateToken(newToken);
  /// ```
  void updateToken(String token) {
    _token = token;
    // Reconnect with new token
    if (isConnected()) {
      disconnect(graceful: false);
      Future.delayed(const Duration(milliseconds: 100), () => connect());
    }
  }

  /// Set token
  ///
  /// [token] - JWT token
  ///
  /// Example:
  /// ```dart
  /// connection.setToken('eyJhbGc...');
  /// ```
  void setToken(String token) {
    _token = token;
  }

  /// Get current token
  String? getToken() => _token;

  /// Check if token is set
  bool hasToken() => _token != null;

  /// Set device ID used in WebSocket query params
  void setDeviceId(String deviceId) {
    final normalized = deviceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _deviceId = normalized;
  }

  /// Get current device ID
  String? getDeviceId() => _deviceId;

  /// Dispose resources
  void dispose() {
    disconnect(graceful: false);
    _openController.close();
    _closeController.close();
    _errorController.close();
    _messageController.close();
    _reconnectingController.close();
  }

  /// Reconnect to WebSocket
  void _reconnect() {
    if (!reconnectConfig.enabled) {
      return;
    }

    if (reconnectConfig.maxAttempts != -1 &&
        _reconnectAttempt >= reconnectConfig.maxAttempts) {
      _log('error', 'Max reconnection attempts reached');
      _setState(ConnectionState.disconnected);
      _errorController
          .add(const ConnectionError('Max reconnection attempts reached'));
      return;
    }

    _setState(ConnectionState.reconnecting);
    _reconnectAttempt++;

    final delay = calculateBackoff(
      attempt: _reconnectAttempt - 1,
      initialDelay: reconnectConfig.initialDelay,
      maxDelay: reconnectConfig.maxDelay,
      multiplier: reconnectConfig.backoffMultiplier,
    );

    _log('info',
        'Reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectAttempt)...');
    _reconnectingController.add({
      'attempt': _reconnectAttempt,
      'delay': delay.inMilliseconds,
    });

    _reconnectTimer = Timer(delay, () {
      connect().catchError((Object error) {
        _log('error', 'Reconnection failed', error);
        _reconnect(); // Try again
      });
    });
  }

  /// Cleanup resources
  void _cleanup() {
    _heartbeat?.stop();
    _heartbeat = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  /// Set connection state
  void _setState(ConnectionState state) {
    _state = state;
  }

  /// Build WebSocket URL with query parameters
  Uri _buildUri() {
    if (_token == null) {
      throw const ConnectionError('Token must be set before connecting');
    }

    return buildRelayWebSocketUri(
      token: _token!,
      baseUrl: url,
      connectionType: 'APP',
      deviceId: _deviceId,
    );
  }

  /// Log message using configured logger
  void _log(String level, String message, [dynamic meta]) {
    if (logger == null) return;

    switch (level) {
      case 'debug':
        logger!.fine(message, meta);
        break;
      case 'info':
        logger!.info(message, meta);
        break;
      case 'warn':
        logger!.warning(message, meta);
        break;
      case 'error':
        logger!.severe(message, meta);
        break;
    }
  }

  @override
  String toString() =>
      'WebSocketConnection(state: $_state, url: $url, hasToken: ${hasToken()})';
}
