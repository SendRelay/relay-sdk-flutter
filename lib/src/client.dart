import 'dart:async';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'models/events.dart';
import 'models/options.dart';
import 'connection/websocket_connection.dart';
import 'subscription/subscription_manager.dart';
import 'errors/relay_error.dart';
import 'utils/device_id.dart';
import 'utils/jwt_decoder.dart';

/// Relay real-time client for Flutter
///
/// Provides real-time task tracking with WebSocket communication,
/// automatic token provisioning, and subscription management.
///
/// Example:
/// ```dart
/// final relay = RelayRealtimeClient(
///   getToken: (taskIds) async {
///     final response = await http.post(
///       Uri.parse('https://your-backend.com/api/relay/token'),
///       headers: {'Content-Type': 'application/json'},
///       body: jsonEncode({'taskIds': taskIds}),
///     );
///     return jsonDecode(response.body)['token'];
///   },
/// );
///
/// await relay.listen('task-123');
///
/// relay.onTaskAssigned.listen((event) {
///   print('Task assigned to rider ${event.riderId}');
/// });
/// ```
class RelayRealtimeClient {
  /// Client options
  final RelayRealtimeClientOptions _options;

  /// WebSocket connection
  late final WebSocketConnection _connection;

  /// Subscription manager
  final SubscriptionManager _subscriptions = SubscriptionManager();

  /// Set of task IDs being listened to
  final Set<String> _listeningTo = {};

  /// Current token
  String? _currentToken;

  /// Token refresh timer
  Timer? _tokenRefreshTimer;

  /// Stream controller for all events
  final StreamController<RelayEvent> _eventsController =
      StreamController<RelayEvent>.broadcast();

  /// Stream of all Relay events
  Stream<RelayEvent> get events => _eventsController.stream;

  // ============================================================================
  // Task Lifecycle Event Streams
  // ============================================================================

  /// Stream of task created events
  Stream<TaskCreatedEvent> get onTaskCreated => events
      .where((event) => event is TaskCreatedEvent)
      .cast<TaskCreatedEvent>();

  /// Stream of task offered events
  Stream<TaskOfferedEvent> get onTaskOffered => events
      .where((event) => event is TaskOfferedEvent)
      .cast<TaskOfferedEvent>();

  /// Stream of task assigned events
  Stream<TaskAssignedEvent> get onTaskAssigned => events
      .where((event) => event is TaskAssignedEvent)
      .cast<TaskAssignedEvent>();

  /// Stream of task in progress events
  Stream<TaskInProgressEvent> get onTaskInProgress => events
      .where((event) => event is TaskInProgressEvent)
      .cast<TaskInProgressEvent>();

  /// Stream of task completed events
  Stream<TaskCompletedEvent> get onTaskCompleted => events
      .where((event) => event is TaskCompletedEvent)
      .cast<TaskCompletedEvent>();

  /// Stream of task failed events
  Stream<TaskFailedEvent> get onTaskFailed =>
      events.where((event) => event is TaskFailedEvent).cast<TaskFailedEvent>();

  /// Stream of task cancelled events
  Stream<TaskCancelledEvent> get onTaskCancelled => events
      .where((event) => event is TaskCancelledEvent)
      .cast<TaskCancelledEvent>();

  /// Stream of stage completed events
  Stream<StageCompletedEvent> get onStageCompleted => events
      .where((event) => event is StageCompletedEvent)
      .cast<StageCompletedEvent>();

  // ============================================================================
  // Payment Event Streams
  // ============================================================================

  /// Stream of payment pending events
  Stream<PaymentPendingEvent> get onPaymentPending => events
      .where((event) => event is PaymentPendingEvent)
      .cast<PaymentPendingEvent>();

  /// Stream of payment released events
  Stream<PaymentReleasedEvent> get onPaymentReleased => events
      .where((event) => event is PaymentReleasedEvent)
      .cast<PaymentReleasedEvent>();

  /// Stream of payment disputed events
  Stream<PaymentDisputedEvent> get onPaymentDisputed => events
      .where((event) => event is PaymentDisputedEvent)
      .cast<PaymentDisputedEvent>();

  /// Stream of payment dispute resolved events
  Stream<PaymentDisputeResolvedEvent> get onPaymentDisputeResolved => events
      .where((event) => event is PaymentDisputeResolvedEvent)
      .cast<PaymentDisputeResolvedEvent>();

  // ============================================================================
  // Real-time Event Streams
  // ============================================================================

  /// Stream of rider location update events
  Stream<RiderLocationUpdateEvent> get onRiderLocationUpdate => events
      .where((event) => event is RiderLocationUpdateEvent)
      .cast<RiderLocationUpdateEvent>();

  /// Stream of new task offer events
  Stream<NewTaskOfferEvent> get onNewTaskOffer => events
      .where((event) => event is NewTaskOfferEvent)
      .cast<NewTaskOfferEvent>();

  // ============================================================================
  // Connection Event Streams
  // ============================================================================

  /// Stream of connection open events
  Stream<ConnectionOpenEvent> get onConnectionOpen => events
      .where((event) => event is ConnectionOpenEvent)
      .cast<ConnectionOpenEvent>();

  /// Stream of connection close events
  Stream<ConnectionCloseEvent> get onConnectionClose => events
      .where((event) => event is ConnectionCloseEvent)
      .cast<ConnectionCloseEvent>();

  /// Stream of connection error events
  Stream<ConnectionErrorEvent> get onConnectionError => events
      .where((event) => event is ConnectionErrorEvent)
      .cast<ConnectionErrorEvent>();

  /// Stream of connection reconnecting events
  Stream<ConnectionReconnectingEvent> get onConnectionReconnecting => events
      .where((event) => event is ConnectionReconnectingEvent)
      .cast<ConnectionReconnectingEvent>();

  /// Stream of token expiring events
  Stream<TokenExpiringEvent> get onTokenExpiring => events
      .where((event) => event is TokenExpiringEvent)
      .cast<TokenExpiringEvent>();

  /// Create a Relay real-time client
  ///
  /// Required parameters:
  /// - [getToken]: Callback to fetch WebSocket token from your backend
  ///
  /// Optional parameters:
  /// - [url]: WebSocket URL (default: wss://ws.sendrelay.com.ng/v1)
  /// - [deviceId]: Optional device identifier (auto-generated if omitted)
  /// - [autoRefresh]: Auto-refresh tokens before expiration (default: true)
  /// - [tokenExpirationWarning]: Token refresh warning threshold (default: 5 minutes)
  /// - [reconnect]: Reconnection configuration
  /// - [heartbeat]: Heartbeat configuration
  /// - [logger]: Optional logger for debugging
  RelayRealtimeClient({
    required Future<String> Function(List<String> taskIds) getToken,
    String? url,
    String? deviceId,
    bool autoRefresh = true,
    Duration tokenExpirationWarning = const Duration(minutes: 5),
    ReconnectConfig? reconnect,
    HeartbeatConfig? heartbeat,
    Logger? logger,
  }) : _options = RelayRealtimeClientOptions(
          getToken: getToken,
          url: url,
          deviceId: deviceId,
          autoRefresh: autoRefresh,
          tokenExpirationWarning: tokenExpirationWarning,
          reconnect: reconnect,
          heartbeat: heartbeat,
          logger: logger,
        ) {
    _connection = WebSocketConnection(
      url: _options.url,
      deviceId: _options.deviceId,
      reconnectConfig: _options.reconnect,
      heartbeatConfig: _options.heartbeat,
      logger: _options.logger,
    );

    _setupConnectionHandlers();
  }

  /// Start listening to task events
  ///
  /// Subscribes to real-time events for the specified task.
  /// Automatically connects to WebSocket if not already connected.
  ///
  /// Example:
  /// ```dart
  /// await relay.listen('task-123');
  /// ```
  Future<void> listen(String taskId) async {
    _listeningTo.add(taskId);

    if (_subscriptions.has(SubscriptionType.task, taskId)) {
      _log('debug', 'Already listening to $taskId');
      return;
    }

    if (!isConnected() &&
        _connection.getState() != ConnectionState.connecting) {
      await connect();
    }

    await _subscribeToTask(taskId);
    _log('info', 'Listening to task $taskId');
  }

  /// Stop listening to task events
  ///
  /// Unsubscribes from real-time events for the specified task.
  ///
  /// Example:
  /// ```dart
  /// await relay.stopListening('task-123');
  /// ```
  Future<void> stopListening(String taskId) async {
    _listeningTo.remove(taskId);

    if (!_subscriptions.has(SubscriptionType.task, taskId)) {
      return;
    }

    await _unsubscribeFromTask(taskId);
    _log('info', 'Stopped listening to task $taskId');
  }

  /// Get all tasks being listened to
  ///
  /// Returns a list of task IDs currently being tracked.
  ///
  /// Example:
  /// ```dart
  /// final tasks = relay.getListeningTo();
  /// print('Listening to ${tasks.length} tasks');
  /// ```
  List<String> getListeningTo() => _listeningTo.toList();

  /// Manually connect to WebSocket
  ///
  /// Usually not needed as `listen()` automatically connects.
  /// Use this if you want to establish connection before subscribing.
  ///
  /// Example:
  /// ```dart
  /// await relay.connect();
  /// ```
  Future<void> connect() async {
    final taskIds = _listeningTo.toList();
    _log('info', 'Fetching token for ${taskIds.length} task(s)...');

    try {
      await _ensureDeviceId();
      final token = await _fetchValidToken(taskIds);
      _connection.setToken(token);
      _currentToken = token;

      _scheduleTokenRefresh();
      await _connection.connect();

      _log('info', 'Connected successfully');
    } catch (error) {
      _log('error', 'Failed to connect: $error');
      throw ConnectionError('Connection failed', error);
    }
  }

  /// Disconnect from WebSocket
  ///
  /// Closes the WebSocket connection gracefully.
  ///
  /// [graceful] - Whether to wait for pending messages (default: true)
  ///
  /// Example:
  /// ```dart
  /// relay.disconnect();
  /// ```
  void disconnect({bool graceful = true}) {
    _connection.disconnect(graceful: graceful);
  }

  /// Get current connection state
  ///
  /// Returns the current WebSocket connection state.
  ///
  /// Example:
  /// ```dart
  /// final state = relay.getState();
  /// // ConnectionState.connecting | connected | disconnecting | disconnected | reconnecting
  /// ```
  ConnectionState getState() => _connection.getState();

  /// Check if connected
  ///
  /// Returns true if WebSocket is currently connected.
  ///
  /// Example:
  /// ```dart
  /// if (relay.isConnected()) {
  ///   print('WebSocket is connected');
  /// }
  /// ```
  bool isConnected() => _connection.isConnected();

  /// Get all active subscriptions
  ///
  /// Returns a list of all active subscriptions.
  ///
  /// Example:
  /// ```dart
  /// final subscriptions = relay.getSubscriptions();
  /// print('Active subscriptions: ${subscriptions.length}');
  /// ```
  List<Subscription> getSubscriptions() => _subscriptions.getAll();

  /// Clear all subscriptions
  ///
  /// Removes all subscriptions from memory.
  /// Does not send unsubscribe messages to server.
  ///
  /// Example:
  /// ```dart
  /// relay.clearSubscriptions();
  /// ```
  void clearSubscriptions() {
    _subscriptions.clear();
    _listeningTo.clear();
  }

  /// Dispose resources
  ///
  /// Call this when you're done using the client (e.g., in dispose()).
  /// Cancels timers, closes streams, and disconnects WebSocket.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   relay.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _connection.dispose();
    _eventsController.close();
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  /// Setup connection event handlers
  void _setupConnectionHandlers() {
    // Connection opened
    _connection.onOpen.listen((_) {
      _eventsController.add(ConnectionOpenEvent());
      _resubscribeAll();
    });

    // Connection closed
    _connection.onClose.listen((data) {
      _eventsController.add(ConnectionCloseEvent(
        code: data['code'] as int?,
        reason: data['reason'] as String?,
      ));
    });

    // Connection error
    _connection.onError.listen((error) {
      _eventsController.add(ConnectionErrorEvent(
        error: error.toString(),
      ));
    });

    // Reconnecting
    _connection.onReconnecting.listen((data) {
      _eventsController.add(ConnectionReconnectingEvent(
        attempt: data['attempt'] as int,
        delay: data['delay'] as int,
      ));
    });

    // Incoming messages
    _connection.onMessage.listen((data) {
      _handleIncomingMessage(data as Map<String, dynamic>);
    });
  }

  @visibleForTesting
  void handleIncomingMessageForTest(Map<String, dynamic> message) {
    _handleIncomingMessage(message);
  }

  /// Handle incoming WebSocket message
  void _handleIncomingMessage(Map<String, dynamic> message) {
    Map<String, dynamic> payload = message;
    String? type = message['type'] as String?;

    // Most business events are wrapped as:
    // { type: 'TASK_UPDATE', data: { type: 'TASK_ASSIGNED', ...payload } }
    if (type == 'TASK_UPDATE' && message['data'] is Map<String, dynamic>) {
      payload =
          Map<String, dynamic>.from(message['data'] as Map<String, dynamic>);
      type = payload['type'] as String?;
    } else if (message['data'] is Map<String, dynamic> &&
        type == 'RIDER_LOCATION_UPDATE') {
      // Defensive support for direct RIDER_LOCATION_UPDATE wrappers
      payload =
          Map<String, dynamic>.from(message['data'] as Map<String, dynamic>);
      payload['type'] = 'RIDER_LOCATION_UPDATE';
      type = 'RIDER_LOCATION_UPDATE';
    }

    if (type == null) {
      _log('warn', 'Received message without type', message);
      return;
    }

    try {
      switch (type) {
        case 'TASK_CREATED':
          _emitTaskCreatedEvent(payload);
          break;
        case 'TASK_OFFERED':
          _emitTaskOfferedEvent(payload);
          break;
        case 'TASK_ASSIGNED':
          _emitTaskAssignedEvent(payload);
          break;
        case 'TASK_IN_PROGRESS':
          _emitTaskInProgressEvent(payload);
          break;
        case 'TASK_COMPLETED':
          _emitTaskCompletedEvent(payload);
          break;
        case 'TASK_FAILED':
          _emitTaskFailedEvent(payload);
          break;
        case 'TASK_CANCELLED':
          _emitTaskCancelledEvent(payload);
          break;
        case 'STAGE_COMPLETED':
          _emitStageCompletedEvent(payload);
          break;
        case 'PAYMENT_PENDING':
          _emitPaymentPendingEvent(payload);
          break;
        case 'PAYMENT_RELEASED':
          _emitPaymentReleasedEvent(payload);
          break;
        case 'PAYMENT_DISPUTED':
          _emitPaymentDisputedEvent(payload);
          break;
        case 'PAYMENT_DISPUTE_RESOLVED':
          _emitPaymentDisputeResolvedEvent(payload);
          break;
        case 'RIDER_LOCATION_UPDATE':
          _emitRiderLocationUpdateEvent(payload);
          break;
        case 'NEW_TASK_OFFER':
          _emitNewTaskOfferEvent(payload);
          break;
        default:
          _log('warn', 'Unknown message type: $type', message);
      }
    } catch (error) {
      _log('error', 'Failed to emit event for type $type', error);
    }
  }

  /// Emit task created event
  void _emitTaskCreatedEvent(Map<String, dynamic> data) {
    final stages = (data['stages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Stage.fromJson)
        .toList();

    final event = TaskCreatedEvent(
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      taskType: _parseTaskType(data['taskType'] as String),
      priority: _parsePriority(data['priority'] as String),
      deliveryFee: _asInt(data['deliveryFee']),
      totalFee: _asInt(data['totalFee']),
      stages: stages,
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
    _eventsController.add(event);
  }

  /// Emit task offered event
  void _emitTaskOfferedEvent(Map<String, dynamic> data) {
    final event = TaskOfferedEvent(
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      tier: _asInt(data['tier']),
      ridersOffered: _asInt(data['ridersOffered']),
      offeredAt: _parseDateTime(data['offeredAt']),
    );
    _eventsController.add(event);
  }

  /// Emit task assigned event
  void _emitTaskAssignedEvent(Map<String, dynamic> data) {
    final event = TaskAssignedEvent(
      taskId: data['taskId'] as String,
      riderId: data['riderId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      assignedAt: DateTime.parse(data['assignedAt'] as String),
      deliveryFee: _asInt(data['deliveryFee']),
      currentStageIndex: _asInt(data['currentStageIndex']),
    );
    _eventsController.add(event);
  }

  /// Emit task in progress event
  void _emitTaskInProgressEvent(Map<String, dynamic> data) {
    final event = TaskInProgressEvent(
      taskId: data['taskId'] as String,
      riderId: data['riderId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      currentStageIndex: _asInt(data['currentStageIndex']),
      startedAt: _parseDateTime(data['startedAt']),
    );
    _eventsController.add(event);
  }

  /// Emit task completed event
  void _emitTaskCompletedEvent(Map<String, dynamic> data) {
    final event = TaskCompletedEvent(
      taskId: data['taskId'] as String,
      riderId: data['riderId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      completedAt: DateTime.parse(data['completedAt'] as String),
      deliveryFee: _asInt(data['deliveryFee']),
      paymentStatus:
          _parseOptionalPaymentStatus(data['paymentStatus'] as String?),
      completionCodeVerified: data['completionCodeVerified'] as bool?,
    );
    _eventsController.add(event);
  }

  /// Emit task failed event
  void _emitTaskFailedEvent(Map<String, dynamic> data) {
    final event = TaskFailedEvent(
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      reason: data['reason'] as String,
      failedAt: DateTime.parse(data['failedAt'] as String),
      riderId: data['riderId'] as String?,
      refunded: data['refunded'] as bool? ?? false,
      refundAmount: _asInt(data['refundAmount'] ?? 0),
    );
    _eventsController.add(event);
  }

  /// Emit task cancelled event
  void _emitTaskCancelledEvent(Map<String, dynamic> data) {
    final event = TaskCancelledEvent(
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      status: _parseTaskStatus(data['status'] as String),
      reason: data['reason'] as String?,
      cancelledAt: DateTime.parse(data['cancelledAt'] as String),
      riderId: data['riderId'] as String?,
    );
    _eventsController.add(event);
  }

  /// Emit stage completed event
  void _emitStageCompletedEvent(Map<String, dynamic> data) {
    final stage = _asMap(data['stage']);

    final stageType = stage != null
        ? _parseStageType(stage['type'] as String)
        : _parseStageType(data['stageType'] as String);

    final completedAt = stage != null
        ? _parseDateTime(stage['completedAt'])
        : _parseDateTime(data['completedAt']);

    final event = StageCompletedEvent(
      taskId: data['taskId'] as String,
      riderId: data['riderId'] as String,
      developerId: data['developerId'] as String,
      stageIndex: _asInt(data['stageIndex']),
      stageType: stageType,
      completedAt: completedAt,
      completionPhoto:
          (stage?['completionPhoto'] ?? data['completionPhoto']) as String?,
      notes: (stage?['completionNotes'] ?? data['notes']) as String?,
      nextStageIndex: data['nextStageIndex'] != null
          ? _asInt(data['nextStageIndex'])
          : null,
      totalStages: _asInt(data['totalStages']),
    );
    _eventsController.add(event);
  }

  /// Emit payment pending event
  void _emitPaymentPendingEvent(Map<String, dynamic> data) {
    final event = PaymentPendingEvent(
      transactionId: data['transactionId'] as String,
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      riderId: data['riderId'] as String,
      amount: _asInt(data['amount']),
      status: _parsePaymentStatus(data['status'] as String),
      releaseAt: DateTime.parse(data['releaseAt'] as String),
      disputeWindowHours: _asInt(data['disputeWindowHours']),
    );
    _eventsController.add(event);
  }

  /// Emit payment released event
  void _emitPaymentReleasedEvent(Map<String, dynamic> data) {
    final event = PaymentReleasedEvent(
      transactionId: data['transactionId'] as String,
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      riderId: data['riderId'] as String,
      amount: _asInt(data['amount']),
      status: _parsePaymentStatus(data['status'] as String),
      releasedAt: DateTime.parse(data['releasedAt'] as String),
    );
    _eventsController.add(event);
  }

  /// Emit payment disputed event
  void _emitPaymentDisputedEvent(Map<String, dynamic> data) {
    final event = PaymentDisputedEvent(
      disputeId: data['disputeId'] as String,
      transactionId: data['transactionId'] as String,
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      riderId: data['riderId'] as String,
      amount: _asInt(data['amount']),
      status: _parsePaymentStatus(data['status'] as String),
      reason: data['reason'] as String,
      description: data['description'] as String,
      disputedAt: DateTime.parse(data['disputedAt'] as String),
    );
    _eventsController.add(event);
  }

  /// Emit payment dispute resolved event
  void _emitPaymentDisputeResolvedEvent(Map<String, dynamic> data) {
    final event = PaymentDisputeResolvedEvent(
      disputeId: data['disputeId'] as String,
      transactionId: data['transactionId'] as String,
      taskId: data['taskId'] as String,
      developerId: data['developerId'] as String,
      riderId: data['riderId'] as String?,
      resolution: data['resolution'] as String,
      refundAmount: _asInt(data['refundAmount']),
      riderPayment: _asInt(data['riderPayment']),
      resolvedAt: DateTime.parse(data['resolvedAt'] as String),
      resolvedBy: data['resolvedBy'] as String,
      notes: data['notes'] as String?,
    );
    _eventsController.add(event);
  }

  /// Emit rider location update event
  void _emitRiderLocationUpdateEvent(Map<String, dynamic> data) {
    final event = RiderLocationUpdateEvent(
      riderId: data['riderId'] as String,
      taskId: data['taskId'] as String,
      location: Location.fromJson(data['location'] as Map<String, dynamic>),
    );
    _eventsController.add(event);
  }

  /// Emit new task offer event
  void _emitNewTaskOfferEvent(Map<String, dynamic> data) {
    final task = _asMap(data['task']) ?? <String, dynamic>{};

    final event = NewTaskOfferEvent(
      taskId: data['taskId'] as String,
      tier: _asInt(data['tier']),
      taskType: _parseTaskType(task['taskType'] as String),
      priority: _parsePriority(task['priority'] as String),
      deliveryFee: _asInt(task['deliveryFee']),
      pickupLocation: Location.fromJson(
        _asMap(task['pickupLocation']) ??
            _asMap(task['pickup']) ??
            <String, dynamic>{},
      ),
      dropoffLocation: Location.fromJson(
        _asMap(task['dropOffLocation']) ??
            _asMap(task['dropoffLocation']) ??
            _asMap(task['dropoff']) ??
            <String, dynamic>{},
      ),
      expiresAt: _parseDateTime(data['offerExpiresAt']),
      offerTimeoutSeconds: _asInt(data['offerTimeoutSeconds']),
      estimatedDistance: (task['estimatedDistance'] as num?)?.toDouble(),
      estimatedDuration: (task['estimatedDuration'] as num?)?.toInt(),
    );
    _eventsController.add(event);
  }

  /// Subscribe to task
  Future<void> _subscribeToTask(String taskId) async {
    await _connection.send({
      'action': 'subscribe',
      'type': 'task',
      'id': taskId,
    });

    _subscriptions.add(SubscriptionType.task, taskId);
  }

  /// Unsubscribe from task
  Future<void> _unsubscribeFromTask(String taskId) async {
    await _connection.send({
      'action': 'unsubscribe',
      'type': 'task',
      'id': taskId,
    });

    _subscriptions.remove(SubscriptionType.task, taskId);
  }

  /// Resubscribe to all tasks (after reconnection)
  Future<void> _resubscribeAll() async {
    final taskIds = _listeningTo.toList();

    if (taskIds.isEmpty) return;

    _log('info', 'Resubscribing to ${taskIds.length} task(s)...');

    for (final taskId in taskIds) {
      try {
        await _subscribeToTask(taskId);
        _log('debug', 'Resubscribed to $taskId');
      } catch (error) {
        _log('error', 'Failed to resubscribe to $taskId: $error');
      }
    }

    _log('info', 'Resubscription complete');
  }

  /// Schedule token refresh
  void _scheduleTokenRefresh() {
    _tokenRefreshTimer?.cancel();

    if (_currentToken == null || !_options.autoRefresh) return;

    final timeUntilExpiration = getTimeUntilExpiration(_currentToken!);
    if (timeUntilExpiration == null) {
      _log('warn', 'Token has no expiration');
      return;
    }

    final refreshTime = timeUntilExpiration - _options.tokenExpirationWarning;

    if (refreshTime.isNegative || refreshTime.inSeconds <= 0) {
      _refreshToken(); // Refresh immediately
    } else {
      _tokenRefreshTimer = Timer(refreshTime, _refreshToken);
      _log('info', 'Token refresh scheduled in ${refreshTime.inSeconds}s');
    }
  }

  /// Refresh token
  Future<void> _refreshToken() async {
    try {
      _log('info', 'Refreshing token...');

      // Emit warning event
      final expiresAt = DateTime.now().add(_options.tokenExpirationWarning);
      _eventsController.add(TokenExpiringEvent(
        expiresAt: expiresAt,
        warningDuration: _options.tokenExpirationWarning,
      ));

      // Fetch new token
      final taskIds = _listeningTo.toList();
      final newToken = await _fetchValidToken(taskIds);

      // Update connection token
      _connection.updateToken(newToken);
      _currentToken = newToken;

      // Schedule next refresh
      _scheduleTokenRefresh();

      _log('info', 'Token refreshed successfully');
    } catch (error) {
      _log('error', 'Token refresh failed: $error');
      _eventsController.add(ConnectionErrorEvent(
        error: 'Token refresh failed: $error',
      ));
    }
  }

  Future<String> _fetchValidToken(List<String> taskIds) async {
    var token = await _options.getToken(taskIds);

    if (isTokenExpired(token)) {
      _log('warn', 'Received expired WebSocket token, retrying once...');
      token = await _options.getToken(taskIds);
      if (isTokenExpired(token)) {
        throw const TokenError(
          'Token provider returned an expired WebSocket token. Ensure your backend issues a fresh JWT before connect.',
        );
      }
    }

    return token;
  }

  Future<void> _ensureDeviceId() async {
    if ((_connection.getDeviceId()?.isNotEmpty ?? false)) {
      return;
    }

    if (_options.deviceId != null && _options.deviceId!.isNotEmpty) {
      _connection.setDeviceId(_options.deviceId!);
      return;
    }

    final persistentDeviceId = await getOrCreateRelayDeviceId();
    _connection.setDeviceId(persistentDeviceId);
  }

  /// Parse task type from string
  TaskType _parseTaskType(String value) {
    return TaskType.values.firstWhere((e) => e.value == value);
  }

  /// Parse task status from string
  TaskStatus _parseTaskStatus(String value) {
    return TaskStatus.values.firstWhere((e) => e.value == value);
  }

  /// Parse priority from string
  Priority _parsePriority(String value) {
    return Priority.values.firstWhere((e) => e.value == value);
  }

  /// Parse stage type from string
  StageType _parseStageType(String value) {
    return StageType.values.firstWhere((e) => e.value == value);
  }

  /// Parse payment status from string
  PaymentStatus _parsePaymentStatus(String value) {
    return PaymentStatus.values.firstWhere((e) => e.value == value);
  }

  PaymentStatus? _parseOptionalPaymentStatus(String? value) {
    if (value == null) return null;
    return PaymentStatus.values.firstWhere((e) => e.value == value);
  }

  int _asInt(dynamic value) {
    return (value as num).toInt();
  }

  DateTime _parseDateTime(dynamic value) {
    return DateTime.parse(value as String);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  /// Log message
  void _log(String level, String message, [dynamic meta]) {
    final logger = _options.logger;
    if (logger == null) return;

    switch (level) {
      case 'debug':
        logger.fine(message, meta);
        break;
      case 'info':
        logger.info(message, meta);
        break;
      case 'warn':
        logger.warning(message, meta);
        break;
      case 'error':
        logger.severe(message, meta);
        break;
    }
  }

  @override
  String toString() =>
      'RelayRealtimeClient(state: ${getState()}, listening: ${_listeningTo.length})';
}
