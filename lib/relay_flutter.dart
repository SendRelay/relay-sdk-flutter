/// Relay Flutter SDK - Mobile SDK
///
/// Official **client-side mobile** SDK for integrating with the Relay delivery platform.
///
/// Provides real-time task tracking with WebSocket support, automatic token
/// provisioning, and comprehensive event streaming for iOS, Android, Web, and Desktop platforms.
///
/// **ℹ️ Client-Side SDK:** This SDK uses secure WebSocket tokens (not API keys) for authentication.
/// Tokens must be provisioned by your backend using @relay-sdk/sdk-node (Server SDK).
///
/// ## Platform Support
///
/// - ✅ Android
/// - ✅ iOS
/// - ✅ Web
/// - ✅ macOS
/// - ✅ Windows
/// - ✅ Linux
///
/// ## Features
///
/// - 🔄 Real-time task tracking via WebSocket
/// - 🔐 Automatic token provisioning and refresh
/// - 📡 19 event types (task lifecycle, payments, rider location)
/// - 🔌 Automatic reconnection with exponential backoff
/// - 💓 Heartbeat monitoring for connection health
/// - 📝 Offline message queuing
/// - 🎯 Type-safe event streams
/// - 🔧 Zero configuration required
///
/// ## Installation
///
/// Add this to your package's `pubspec.yaml` file:
///
/// ```yaml
/// dependencies:
///   relay_flutter: ^1.0.0
/// ```
///
/// ## Quick Start
///
/// ```dart
/// import 'package:relay_flutter/relay_flutter.dart';
///
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
/// // Start listening to a task
/// await relay.listen('task-123');
///
/// // Subscribe to events
/// relay.onTaskAssigned.listen((event) {
///   print('Task ${event.taskId} assigned to rider ${event.riderId}');
/// });
///
/// relay.onRiderLocationUpdate.listen((event) {
///   updateMapMarker(event.location);
/// });
///
/// relay.onTaskCompleted.listen((event) {
///   showNotification('Task completed!');
/// });
/// ```
///
/// ## Backend Token Endpoint
///
/// Your backend must provide an endpoint to generate WebSocket tokens using @relay-sdk/sdk-node:
///
/// **Example (Node.js + Express):**
/// ```typescript
/// import { RelayClient } from '@relay-sdk/sdk-node';
///
/// const relay = new RelayClient({
///   apiKey: process.env.RELAY_API_KEY, // Server-side only!
/// });
///
/// app.post('/api/relay/token', authenticateUser, async (req, res) => {
///   const { taskIds } = req.body;
///
///   const { token } = await relay.auth.createWebSocketToken({
///     scope: taskIds.map((id) => `task:${id}`),
///     expiresIn: 3600, // 1 hour
///   });
///
///   res.json({ token });
/// });
/// ```
///
/// **Example (Python + FastAPI):**
/// ```python
/// from relay_sdk import RelayClient
///
/// relay = RelayClient(api_key=os.getenv("RELAY_API_KEY"))
///
/// @app.post("/api/relay/token")
/// async def create_token(task_ids: list[str], user=Depends(get_current_user)):
///     token_response = relay.auth.create_websocket_token(
///         task_ids=task_ids,
///         type="APP",
///         expires_in=3600,
///     )
///     return {"token": token_response.token}
/// ```
///
/// ## Advanced Usage
///
/// ### Multiple Tasks
///
/// ```dart
/// // Listen to multiple tasks
/// await relay.listen('task-1');
/// await relay.listen('task-2');
/// await relay.listen('task-3');
///
/// // Get all listening tasks
/// final tasks = relay.getListeningTo();
/// print('Listening to ${tasks.length} tasks');
/// ```
///
/// ### Custom Configuration
///
/// ```dart
/// final relay = RelayRealtimeClient(
///   getToken: (taskIds) async { /* ... */ },
///   url: 'wss://custom-ws-url.com',
///   deviceId: 'my-device-123',
///   autoRefresh: true,
///   tokenExpirationWarning: Duration(minutes: 5),
///   reconnect: ReconnectConfig(
///     enabled: true,
///     maxAttempts: 10,
///     initialDelay: Duration(seconds: 1),
///     maxDelay: Duration(seconds: 30),
///     backoffMultiplier: 1.5,
///   ),
///   heartbeat: HeartbeatConfig(
///     enabled: true,
///     interval: Duration(seconds: 30),
///     timeout: Duration(seconds: 10),
///   ),
///   logger: Logger('RelaySDK'),
/// );
/// ```
///
/// ### Event Filtering
///
/// ```dart
/// // Listen to all events
/// relay.events.listen((event) {
///   if (event is TaskAssignedEvent) {
///     print('Task assigned: ${event.taskId}');
///   } else if (event is TaskCompletedEvent) {
///     print('Task completed: ${event.taskId}');
///   }
/// });
///
/// // Or use specific event streams
/// relay.onTaskAssigned.listen((event) { /* ... */ });
/// relay.onTaskCompleted.listen((event) { /* ... */ });
/// ```
///
/// ### Connection Monitoring
///
/// ```dart
/// relay.onConnectionOpen.listen((_) {
///   print('Connected to Relay');
/// });
///
/// relay.onConnectionClose.listen((event) {
///   print('Disconnected: ${event.reason}');
/// });
///
/// relay.onConnectionReconnecting.listen((event) {
///   print('Reconnecting (attempt ${event.attempt})...');
/// });
///
/// relay.onTokenExpiring.listen((event) {
///   print('Token expiring at ${event.expiresAt}');
/// });
/// ```
///
/// ### Cleanup
///
/// ```dart
/// @override
/// void dispose() {
///   relay.dispose();
///   super.dispose();
/// }
/// ```
///
/// ## Event Types
///
/// ### Task Lifecycle Events
/// - `TaskCreatedEvent` - New task created
/// - `TaskOfferedEvent` - Task offered to riders
/// - `TaskAssignedEvent` - Task assigned to specific rider
/// - `TaskInProgressEvent` - Rider started task
/// - `TaskCompletedEvent` - Task completed successfully
/// - `TaskFailedEvent` - Task failed
/// - `TaskCancelledEvent` - Task cancelled
/// - `StageCompletedEvent` - Task stage (pickup/dropoff) completed
///
/// ### Payment Events
/// - `PaymentPendingEvent` - Payment held in escrow
/// - `PaymentReleasedEvent` - Payment released to rider
/// - `PaymentDisputedEvent` - Payment disputed
/// - `PaymentDisputeResolvedEvent` - Dispute resolved
///
/// ### Real-time Events
/// - `RiderLocationUpdateEvent` - Rider GPS location update
/// - `NewTaskOfferEvent` - New task offer received (rider-side)
///
/// ### Connection Events
/// - `ConnectionOpenEvent` - WebSocket connected
/// - `ConnectionCloseEvent` - WebSocket disconnected
/// - `ConnectionErrorEvent` - Connection error occurred
/// - `ConnectionReconnectingEvent` - Reconnection in progress
/// - `TokenExpiringEvent` - Token about to expire
///
/// ## Platform Support
///
/// - ✅ Android
/// - ✅ iOS
/// - ✅ Web
/// - ✅ macOS
/// - ✅ Windows
/// - ✅ Linux
///
/// ## Resources
///
/// - [Documentation](https://docs.sendrelay.com.ng)
/// - [API Reference](https://docs.sendrelay.com.ng/api-reference)
/// - [GitHub](https://github.com/SendRelay/relay-sdk-flutter)
/// - [Issues](https://github.com/SendRelay/relay-sdk-flutter/issues)
///
library relay_flutter;

// Main client
export 'src/client.dart' show RelayRealtimeClient;
// WebSocket URI builder
export 'src/connection/websocket_uri.dart'
    show
        buildRelayWebSocketUri,
        relayDefaultWebSocketPath,
        relayDefaultWebSocketUrl;
// Errors
export 'src/errors/relay_error.dart'
    show RelayError, ConnectionError, TokenError;
// Event models
export 'src/models/events.dart'
    show
        RelayEvent,
        // Enums
        TaskType,
        TaskStatus,
        Priority,
        StageType,
        StageStatus,
        PaymentStatus,
        ConnectionState,
        // Data models
        Location,
        Stage,
        // Task lifecycle events
        TaskCreatedEvent,
        TaskOfferedEvent,
        TaskAssignedEvent,
        TaskInProgressEvent,
        TaskCompletedEvent,
        TaskFailedEvent,
        TaskCancelledEvent,
        StageCompletedEvent,
        // Payment events
        PaymentPendingEvent,
        PaymentReleasedEvent,
        PaymentDisputedEvent,
        PaymentDisputeResolvedEvent,
        // Real-time events
        RiderLocationUpdateEvent,
        NewTaskOfferEvent,
        // Connection events
        ConnectionOpenEvent,
        ConnectionCloseEvent,
        ConnectionErrorEvent,
        ConnectionReconnectingEvent,
        TokenExpiringEvent;
// Configuration
export 'src/models/options.dart'
    show RelayRealtimeClientOptions, ReconnectConfig, HeartbeatConfig;
// Subscription models
export 'src/subscription/subscription_manager.dart'
    show Subscription, SubscriptionType;
// Utilities (optional - for advanced users)
export 'src/utils/jwt_decoder.dart'
    show JwtPayload, parseJwt, isTokenExpired, getTimeUntilExpiration;
