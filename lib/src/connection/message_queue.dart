import 'dart:collection';

/// Message queue for buffering WebSocket messages when disconnected
///
/// Implements FIFO (First-In-First-Out) queue with size limit.
/// Automatically drops oldest messages when queue is full.
class MessageQueue {
  /// Maximum queue size
  final int maxSize;

  /// Internal queue storage
  final Queue<Map<String, dynamic>> _queue = Queue<Map<String, dynamic>>();

  /// Create message queue
  ///
  /// [maxSize] limits the number of queued messages (default: 100).
  /// When the queue is full, the oldest message is dropped.
  MessageQueue({this.maxSize = 100});

  /// Enqueue a message
  ///
  /// Adds message to the end of the queue.
  /// If queue is full, removes the oldest message first.
  ///
  /// Example:
  /// ```dart
  /// queue.enqueue({'action': 'subscribe', 'type': 'task', 'id': 'task-123'});
  /// ```
  void enqueue(Map<String, dynamic> message) {
    // Remove oldest message if queue is full
    if (_queue.length >= maxSize) {
      _queue.removeFirst();
    }

    _queue.add(message);
  }

  /// Flush all queued messages
  ///
  /// Calls [sendFn] for each message in FIFO order, then clears the queue.
  ///
  /// Example:
  /// ```dart
  /// queue.flush((message) {
  ///   webSocket.send(jsonEncode(message));
  /// });
  /// ```
  void flush(void Function(Map<String, dynamic> message) sendFn) {
    while (_queue.isNotEmpty) {
      final message = _queue.removeFirst();
      sendFn(message);
    }
  }

  /// Check if queue has messages
  bool get hasMessages => _queue.isNotEmpty;

  /// Get current queue size
  int get size => _queue.length;

  /// Clear all queued messages
  void clear() {
    _queue.clear();
  }

  @override
  String toString() => 'MessageQueue(size: $size/$maxSize)';
}
