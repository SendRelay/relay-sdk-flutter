/// Messages a Relay realtime client sends. Checked against the shared conformance fixtures
/// (packages/sdks/conformance/realtime/outgoing.json).
abstract final class RealtimeMessages {
  /// Start receiving a task's events.
  static Map<String, dynamic> subscribe(String taskId) =>
      {'action': 'subscribe', 'type': 'task', 'id': taskId};

  /// Stop receiving a task's events.
  static Map<String, dynamic> unsubscribe(String taskId) =>
      {'action': 'unsubscribe', 'type': 'task', 'id': taskId};

  /// Heartbeat; the server answers with a `pong` frame.
  static const Map<String, dynamic> ping = {'action': 'ping'};
}
