# Relay Flutter SDK

[![pub package](https://img.shields.io/pub/v/relay_flutter.svg)](https://pub.dev/packages/relay_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
**📱 Mobile SDK** | WebSocket Client

Official Flutter SDK for the [Relay](https://sendrelay.com.ng) delivery platform. This is a **client-side mobile SDK** designed for Flutter applications.

> **ℹ️ Client-Side SDK:** This SDK uses WebSocket tokens (not API keys) for secure client authentication. Tokens must be provisioned by your backend using [@relay-sdk/sdk-node](https://github.com/SendRelay/relay-sdk-node) (Server SDK).

**Platform Support:** iOS • Android • Web • macOS • Windows • Linux

## Features

- 🔄 **Real-time Task Tracking** - WebSocket-based live updates
- 🔐 **Automatic Token Management** - Token provisioning and auto-refresh
- 📡 **19 Event Types** - Task lifecycle, payments, rider location
- 🔌 **Auto-Reconnection** - Exponential backoff with subscription preservation
- 💓 **Heartbeat Monitoring** - Connection health checks
- 📝 **Offline Message Queuing** - Buffer messages when disconnected
- 🎯 **Type-Safe Event Streams** - Strongly typed Dart streams
- 🔧 **Zero Configuration** - Sensible defaults, minimal setup
- 🌍 **Platform Support** - Android, iOS, Web, Desktop

## Usage Context

### Mobile SDK (Flutter Applications)

This SDK is designed for **client-side Flutter applications** and provides:

- ✅ **Real-time WebSocket connection** for live task updates
- ✅ **Automatic token provisioning** via backend callback
- ✅ **19+ event types** for complete task lifecycle tracking
- ✅ **Auto-reconnection** with exponential backoff
- ✅ **Token auto-refresh** before expiration
- ✅ **Offline message queuing**
- ✅ **Type-safe Dart Streams** for all events
- ✅ **Cross-platform support** (iOS, Android, Web, Desktop)

**Typical Use Cases:**
- Mobile delivery tracking apps (customer-facing)
- Rider applications (task offers and navigation)
- Real-time order status updates
- Live rider location on maps
- Push notification triggers
- Cross-platform delivery management

**Security Model:**
This SDK uses **temporary WebSocket tokens** instead of API keys. Your backend (using @relay-sdk/sdk-node) generates these tokens with limited scope and expiration:

```dart
// Frontend (Flutter) - Request token from backend
final relay = RelayRealtimeClient(
  getToken: (taskIds) async {
    final response = await http.post(
      Uri.parse('https://your-backend.com/api/relay/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'taskIds': taskIds}),
    );
    return jsonDecode(response.body)['token'];
  },
);
```

```typescript
// Backend (Node.js) - Generate token with @relay-sdk/sdk-node
const { token } = await relay.auth.createWebSocketToken({
  scope: ['task:task-123'],
  expiresIn: 3600, // 1 hour
});
```

### Server-Side Alternative

For server-side task creation and management:
- **Node.js backend:** Use [@relay-sdk/sdk-node](https://github.com/SendRelay/relay-sdk-node) - REST API client with full access

### Web Alternative

For browser-based web applications (non-Flutter):
- **Web apps:** Use [@relay-sdk/sdk-browser](https://github.com/SendRelay/relay-sdk-browser) - WebSocket client optimized for browsers

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  relay_flutter: ^1.2.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:relay_flutter/relay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 1. Create Relay client
final relay = RelayRealtimeClient(
  getToken: (taskIds) async {
    // Fetch token from your backend
    final response = await http.post(
      Uri.parse('https://your-backend.com/api/relay/token'),
      headers: {
        'Authorization': 'Bearer $userToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'taskIds': taskIds}),
    );

    final data = jsonDecode(response.body);
    return data['token'] as String;
  },
);

// 2. Start listening to a task
await relay.listen('task-123');

// 3. Subscribe to events
relay.onTaskAssigned.listen((event) {
  print('Task ${event.taskId} assigned to rider ${event.riderId}');
});

relay.onRiderLocationUpdate.listen((event) {
  print('Rider at ${event.location.latitude}, ${event.location.longitude}');
  updateMapMarker(event.location);
});

relay.onTaskCompleted.listen((event) {
  print('Task completed!');
  showCompletionDialog();
});

// 4. Cleanup when done
@override
void dispose() {
  relay.dispose();
  super.dispose();
}
```

## Backend Token Endpoint

The SDK requires a backend endpoint to fetch WebSocket tokens. This ensures your API keys never leave your backend.

### Example Backend (Node.js/Express)

```javascript
import express from 'express';
import { RelayClient } from '@relay-sdk/sdk-node';

const app = express();
app.use(express.json());

const relay = new RelayClient({
  apiKey: process.env.RELAY_API_KEY, // Server-side API key
});

app.post('/api/relay/token', authenticateUser, async (req, res) => {
  const { taskIds } = req.body;

  // Fetch token from Relay API
  const { token } = await relay.auth.createWebSocketToken({
    scope: taskIds.map((id) => `task:${id}`),
    expiresIn: 3600, // 1 hour
  });

  res.json({ token });
});
```

### Example Backend (Python/FastAPI)

```python
from relay_sdk import RelayClient
from fastapi import FastAPI, Depends

relay = RelayClient(api_key=os.getenv("RELAY_API_KEY"))

@app.post("/api/relay/token")
async def create_token(task_ids: list[str], user=Depends(get_current_user)):
    token_response = relay.auth.create_websocket_token(
        scope=[f"task:{task_id}" for task_id in task_ids],
        expires_in=3600,
    )
    return {"token": token_response.token}
```

## Usage

### Basic Task Tracking

```dart
import 'package:flutter/material.dart';
import 'package:relay_flutter/relay_flutter.dart';

class TaskTrackerScreen extends StatefulWidget {
  final String taskId;
  const TaskTrackerScreen({required this.taskId});

  @override
  State<TaskTrackerScreen> createState() => _TaskTrackerScreenState();
}

class _TaskTrackerScreenState extends State<TaskTrackerScreen> {
  late RelayRealtimeClient _relay;
  String _status = 'PENDING';
  Location? _riderLocation;

  @override
  void initState() {
    super.initState();

    _relay = RelayRealtimeClient(
      getToken: _fetchToken,
    );

    // Start listening to task
    _relay.listen(widget.taskId);

    // Subscribe to events
    _relay.onTaskAssigned.listen((event) {
      if (event.taskId == widget.taskId) {
        setState(() => _status = 'ASSIGNED');
      }
    });

    _relay.onTaskInProgress.listen((event) {
      if (event.taskId == widget.taskId) {
        setState(() => _status = 'IN_PROGRESS');
      }
    });

    _relay.onTaskCompleted.listen((event) {
      if (event.taskId == widget.taskId) {
        setState(() => _status = 'COMPLETED');
        _showCompletionDialog();
      }
    });

    _relay.onRiderLocationUpdate.listen((event) {
      if (event.taskId == widget.taskId) {
        setState(() => _riderLocation = event.location);
      }
    });
  }

  Future<String> _fetchToken(List<String> taskIds) async {
    final response = await http.post(
      Uri.parse('https://your-backend.com/api/relay/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'taskIds': taskIds}),
    );
    return jsonDecode(response.body)['token'];
  }

  @override
  void dispose() {
    _relay.stopListening(widget.taskId);
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task ${widget.taskId}')),
      body: Column(
        children: [
          StatusBadge(status: _status),
          if (_riderLocation != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _riderLocation!.latitude,
                  _riderLocation!.longitude,
                ),
                zoom: 15,
              ),
            ),
        ],
      ),
    );
  }
}
```

### Tracking Multiple Tasks

```dart
class OrderListScreen extends StatefulWidget {
  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late RelayRealtimeClient _relay;
  final Map<String, String> _taskStatuses = {};
  final List<String> _taskIds = ['task-1', 'task-2', 'task-3'];

  @override
  void initState() {
    super.initState();

    _relay = RelayRealtimeClient(
      getToken: _fetchToken,
      logger: Logger('RelaySDK'),
    );

    // Listen to all tasks
    for (final taskId in _taskIds) {
      _relay.listen(taskId);
    }

    // Update statuses on events
    _relay.onTaskAssigned.listen((event) {
      setState(() => _taskStatuses[event.taskId] = 'ASSIGNED');
    });

    _relay.onTaskInProgress.listen((event) {
      setState(() => _taskStatuses[event.taskId] = 'IN_PROGRESS');
    });

    _relay.onTaskCompleted.listen((event) {
      setState(() => _taskStatuses[event.taskId] = 'COMPLETED');
    });

    _relay.onTaskFailed.listen((event) {
      setState(() => _taskStatuses[event.taskId] = 'FAILED');
      _showErrorDialog(event.reason);
    });
  }

  Future<String> _fetchToken(List<String> taskIds) async {
    throw UnimplementedError('Implement your backend token fetch here');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ListView.builder(
        itemCount: _taskIds.length,
        itemBuilder: (context, index) {
          final taskId = _taskIds[index];
          final status = _taskStatuses[taskId] ?? 'PENDING';

          return ListTile(
            title: Text('Order ${index + 1}'),
            subtitle: Text('Status: $status'),
            trailing: _buildStatusIcon(status),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }
}
```

### Custom Configuration

```dart
final relay = RelayRealtimeClient(
  getToken: _fetchToken,
  url: 'wss://custom-relay-ws.com/v1',
  deviceId: 'my-device-123',
  autoRefresh: true,
  tokenExpirationWarning: Duration(minutes: 5),
  reconnect: ReconnectConfig(
    enabled: true,
    maxAttempts: 10,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    backoffMultiplier: 1.5,
  ),
  heartbeat: HeartbeatConfig(
    enabled: true,
    interval: Duration(seconds: 30),
    timeout: Duration(seconds: 10),
  ),
  logger: Logger('RelaySDK')..level = Level.ALL,
);
```

### Listening to All Events

```dart
// Listen to all events with type checking
relay.events.listen((event) {
  if (event is TaskAssignedEvent) {
    print('Task assigned: ${event.taskId}');
  } else if (event is TaskCompletedEvent) {
    print('Task completed: ${event.taskId}');
  } else if (event is RiderLocationUpdateEvent) {
    updateMap(event.location);
  } else if (event is ConnectionErrorEvent) {
    showErrorSnackbar(event.error);
  }
});
```

### Connection Monitoring

```dart
relay.onConnectionOpen.listen((_) {
  print('Connected to Relay WebSocket');
  setState(() => _connectionStatus = 'Connected');
});

relay.onConnectionClose.listen((event) {
  print('Disconnected: ${event.reason}');
  setState(() => _connectionStatus = 'Disconnected');
});

relay.onConnectionReconnecting.listen((event) {
  print('Reconnecting (attempt ${event.attempt} in ${event.delay}ms)...');
  setState(() => _connectionStatus = 'Reconnecting...');
});

relay.onTokenExpiring.listen((event) {
  print('Token expiring at ${event.expiresAt}');
  // Token will auto-refresh if autoRefresh is enabled
});
```

### Manual Connection Control

```dart
// Manually connect (usually not needed - listen() auto-connects)
await relay.connect();

// Check connection state
if (relay.isConnected()) {
  print('WebSocket is connected');
}

final state = relay.getState();
// ConnectionState.connecting | connected | disconnecting | disconnected | reconnecting

// Manually disconnect
relay.disconnect();
```

## Event Types

### Task Lifecycle Events

| Event | Description |
|-------|-------------|
| `TaskCreatedEvent` | New task created (webhook only) |
| `TaskOfferedEvent` | Task offered to riders |
| `TaskAssignedEvent` | Task assigned to specific rider |
| `TaskInProgressEvent` | Rider started task |
| `TaskCompletedEvent` | Task completed successfully |
| `TaskFailedEvent` | Task failed (timeout, rider issue) |
| `TaskCancelledEvent` | Task cancelled by developer |
| `StageCompletedEvent` | Task stage (pickup/dropoff) completed |

### Payment Events

| Event | Description |
|-------|-------------|
| `PaymentPendingEvent` | Payment held in escrow (24h) |
| `PaymentReleasedEvent` | Payment released to rider |
| `PaymentDisputedEvent` | Payment disputed by developer |
| `PaymentDisputeResolvedEvent` | Dispute resolved by admin |

### Real-time Events

| Event | Description |
|-------|-------------|
| `RiderLocationUpdateEvent` | Rider GPS location update |
| `NewTaskOfferEvent` | New task offer (rider-side only) |

### Connection Events

| Event | Description |
|-------|-------------|
| `ConnectionOpenEvent` | WebSocket connected |
| `ConnectionCloseEvent` | WebSocket disconnected |
| `ConnectionErrorEvent` | Connection error occurred |
| `ConnectionReconnectingEvent` | Reconnection in progress |
| `TokenExpiringEvent` | Token about to expire |

## API Reference

### RelayRealtimeClient

#### Constructor

```dart
RelayRealtimeClient({
  required Future<String> Function(List<String> taskIds) getToken,
  String? url,
  String? deviceId,
  bool autoRefresh = true,
  Duration tokenExpirationWarning = const Duration(minutes: 5),
  ReconnectConfig? reconnect,
  HeartbeatConfig? heartbeat,
  Logger? logger,
})
```

Notes:
- `url` defaults to `wss://api.sendrelay.com.ng/v1/realtime/ws`
- `deviceId` is optional. If omitted, the SDK generates and persists one locally.

#### Methods

| Method | Description |
|--------|-------------|
| `listen(String taskId)` | Start listening to task events |
| `stopListening(String taskId)` | Stop listening to task events |
| `getListeningTo()` | Get list of task IDs being tracked |
| `connect()` | Manually connect to WebSocket |
| `disconnect({bool graceful})` | Disconnect from WebSocket |
| `getState()` | Get current connection state |
| `isConnected()` | Check if connected |
| `getSubscriptions()` | Get all active subscriptions |
| `clearSubscriptions()` | Clear all subscriptions |
| `dispose()` | Cleanup resources (call in dispose()) |

#### Event Streams

| Stream | Event Type |
|--------|------------|
| `events` | All events |
| `onTaskCreated` | `TaskCreatedEvent` |
| `onTaskOffered` | `TaskOfferedEvent` |
| `onTaskAssigned` | `TaskAssignedEvent` |
| `onTaskInProgress` | `TaskInProgressEvent` |
| `onTaskCompleted` | `TaskCompletedEvent` |
| `onTaskFailed` | `TaskFailedEvent` |
| `onTaskCancelled` | `TaskCancelledEvent` |
| `onStageCompleted` | `StageCompletedEvent` |
| `onPaymentPending` | `PaymentPendingEvent` |
| `onPaymentReleased` | `PaymentReleasedEvent` |
| `onPaymentDisputed` | `PaymentDisputedEvent` |
| `onPaymentDisputeResolved` | `PaymentDisputeResolvedEvent` |
| `onRiderLocationUpdate` | `RiderLocationUpdateEvent` |
| `onNewTaskOffer` | `NewTaskOfferEvent` |
| `onConnectionOpen` | `ConnectionOpenEvent` |
| `onConnectionClose` | `ConnectionCloseEvent` |
| `onConnectionError` | `ConnectionErrorEvent` |
| `onConnectionReconnecting` | `ConnectionReconnectingEvent` |
| `onTokenExpiring` | `TokenExpiringEvent` |

## Configuration

### ReconnectConfig

```dart
ReconnectConfig({
  bool enabled = true,
  int maxAttempts = -1,        // -1 = infinite
  Duration initialDelay = Duration(seconds: 1),
  Duration maxDelay = Duration(seconds: 30),
  double backoffMultiplier = 1.5,
})
```

### HeartbeatConfig

```dart
HeartbeatConfig({
  bool enabled = true,
  Duration interval = Duration(seconds: 30),
  Duration timeout = Duration(seconds: 10),
})
```

## Error Handling

```dart
try {
  await relay.listen('task-123');
} on ConnectionError catch (e) {
  print('Connection failed: ${e.message}');
  showErrorDialog('Unable to connect to Relay');
} on TokenError catch (e) {
  print('Token error: ${e.message}');
  refreshAuthToken();
} on RelayError catch (e) {
  print('Relay error: ${e.message}');
}

// Or listen to error events
relay.onConnectionError.listen((event) {
  print('Connection error: ${event.error}');
  showErrorSnackbar(event.error);
});
```

## Testing

For unit tests, you can mock the `getToken` callback:

```dart
final relay = RelayRealtimeClient(
  getToken: (taskIds) async {
    return 'mock-jwt-token';
  },
  url: 'wss://localhost:8080', // Mock WebSocket server
);
```

## Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Supported |
| iOS | ✅ Supported |
| Web | ✅ Supported |
| macOS | ✅ Supported |
| Windows | ✅ Supported |
| Linux | ✅ Supported |

## Migration from Browser SDK

If you're familiar with the Browser SDK (`@relay-sdk/sdk-browser`), the Flutter SDK maintains API parity:

| Browser SDK | Flutter SDK |
|-------------|-------------|
| `new RelayRealtimeClient()` | `RelayRealtimeClient()` |
| `client.listen('task-123')` | `await relay.listen('task-123')` |
| `client.on('TASK_ASSIGNED', handler)` | `relay.onTaskAssigned.listen(handler)` |
| `client.stopListening('task-123')` | `await relay.stopListening('task-123')` |
| `client.disconnect()` | `relay.disconnect()` |

The main difference is using Dart `Stream<T>` instead of event emitters.

## Resources

- [Documentation](https://docs.sendrelay.com.ng)
- [API Reference](https://docs.sendrelay.com.ng/api-reference)
- [GitHub Repository](https://github.com/SendRelay/relay-sdk-flutter)
- [Issue Tracker](https://github.com/SendRelay/relay-sdk-flutter/issues)
- [Relay Dashboard](https://dashboard.sendrelay.com.ng)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For questions and support:
- GitHub Issues: https://github.com/SendRelay/relay-sdk-flutter/issues
- Email: ops@sendrelay.com.ng
- Discord: https://discord.gg/relay
