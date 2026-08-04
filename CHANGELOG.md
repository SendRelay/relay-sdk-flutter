# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-XX

### Added
- Initial stable release of Relay Flutter SDK
- Real-time task tracking via WebSocket
- Automatic token provisioning and refresh
- 19 event types across task lifecycle, payments, and real-time updates
- Automatic reconnection with exponential backoff
- Heartbeat monitoring for connection health
- Offline message queuing
- Type-safe event streams using Dart `Stream<T>`
- Subscription preservation across reconnections
- Support for multiple simultaneous task tracking
- Comprehensive error handling with custom exceptions
- JWT token parsing utilities
- Full platform support (Android, iOS, Web, Desktop)
- Extensive documentation and examples

### Event Types
- **Task Lifecycle**: TaskCreated, TaskOffered, TaskAssigned, TaskInProgress, TaskCompleted, TaskFailed, TaskCancelled, StageCompleted
- **Payments**: PaymentPending, PaymentReleased, PaymentDisputed, PaymentDisputeResolved
- **Real-time**: RiderLocationUpdate, NewTaskOffer
- **Connection**: ConnectionOpen, ConnectionClose, ConnectionError, ConnectionReconnecting, TokenExpiring

### Configuration Options
- `ReconnectConfig` - Customizable reconnection behavior
- `HeartbeatConfig` - Configurable heartbeat monitoring
- `RelayRealtimeClientOptions` - Comprehensive client configuration

### Core Features
- `RelayRealtimeClient` - Main SDK client
- `listen(taskId)` - Subscribe to task events
- `stopListening(taskId)` - Unsubscribe from task events
- `getListeningTo()` - Get tracked task IDs
- `connect()` / `disconnect()` - Manual connection control
- Event streams for all 19 event types
- Automatic token refresh before expiration
- Graceful disconnection with message flushing

### Developer Experience
- Zero configuration required (sensible defaults)
- Type-safe API with full Dart type annotations
- Comprehensive dartdoc comments on all public APIs
- Example Flutter app demonstrating all features
- Migration guide for Browser SDK users

## [1.2.2] - 2026-06-26

### Changed
- Maintenance and packaging release in the 1.2.x line; no public API changes.

## [1.2.0] - 2026-05-25

### Added
- New `buildRelayWebSocketUri()` utility for safe, normalized WebSocket URI construction
- Persisted SDK device ID generation via `shared_preferences` when `deviceId` is omitted
- Regression tests for URI normalization and persistent device ID behavior

### Changed
- Default WebSocket endpoint now includes API version path: `wss://ws.sendrelay.com.ng/v1`
- WebSocket URI normalization now:
  - forces WebSocket schemes (`https -> wss`, `http -> ws`)
  - removes invalid `:0` ports
  - strips URL fragments (`#`)
  - safely encodes query parameters via `Uri`
- Connection flow now validates token freshness before opening/reopening sockets

## [Unreleased]

### Planned Features
- Unit tests for all core components
- Integration tests with mock WebSocket server
- CI/CD pipeline for automated testing
- Performance benchmarks
- Additional example apps (maps integration, multi-task dashboard)
- Localization support for error messages

---

## Version History

- **1.2.2** (2026-06-26) - Maintenance and packaging release
- **1.2.0** (2026-05-25) - WebSocket URI normalization, `/v1` default endpoint, persisted `deviceId`
- **1.0.0** (2025-01-XX) - Initial stable release

## Migration Guide

### From Browser SDK (@relay-sdk/sdk-browser)

The Flutter SDK maintains API parity with the Browser SDK v2.0:

```dart
// Before (Browser SDK - TypeScript)
const relay = new RelayRealtimeClient({ getToken });
relay.listen('task-123');
relay.on('TASK_ASSIGNED', (event) => { /* ... */ });

// After (Flutter SDK - Dart)
final relay = RelayRealtimeClient(getToken: getToken);
await relay.listen('task-123');
relay.onTaskAssigned.listen((event) { /* ... */ });
```

Key differences:
- Use `Stream<T>` instead of EventEmitter (`on()` → `onEventName.listen()`)
- Use `Future<T>` instead of `Promise<T>`
- Call `dispose()` when done (Flutter lifecycle pattern)
- Import from `package:relay_flutter/relay_flutter.dart`

## Links

- [GitHub Repository](https://github.com/SendRelay/relay-sdk-flutter)
- [pub.dev Package](https://pub.dev/packages/relay_flutter)
- [Documentation](https://docs.sendrelay.com.ng)
- [API Reference](https://docs.sendrelay.com.ng/api-reference)
