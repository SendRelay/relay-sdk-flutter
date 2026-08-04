import 'package:meta/meta.dart';

/// Subscription type
enum SubscriptionType {
  /// Task subscription
  task,

  /// Rider subscription
  rider,

  /// Developer subscription
  developer,
}

/// Subscription to a resource
@immutable
class Subscription {
  /// Subscription type
  final SubscriptionType type;

  /// Resource ID
  final String id;

  /// Subscribed timestamp
  final DateTime subscribedAt;

  /// Create subscription
  const Subscription({
    required this.type,
    required this.id,
    required this.subscribedAt,
  });

  /// Create subscription key for storage
  String get key => '${type.name}:$id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Subscription(type: $type, id: $id)';
}

/// Manages subscriptions to resources
///
/// Tracks active subscriptions and provides methods for adding, removing,
/// and querying subscriptions.
class SubscriptionManager {
  /// Active subscriptions (key: "type:id", value: Subscription)
  final Map<String, Subscription> _subscriptions = {};

  /// Add a subscription
  ///
  /// Returns true if subscription was added, false if already exists.
  ///
  /// Example:
  /// ```dart
  /// final added = manager.add(SubscriptionType.task, 'task-123');
  /// if (added) {
  ///   print('Subscribed to task-123');
  /// } else {
  ///   print('Already subscribed to task-123');
  /// }
  /// ```
  bool add(SubscriptionType type, String id) {
    final subscription = Subscription(
      type: type,
      id: id,
      subscribedAt: DateTime.now(),
    );

    if (_subscriptions.containsKey(subscription.key)) {
      return false; // Already subscribed
    }

    _subscriptions[subscription.key] = subscription;
    return true;
  }

  /// Remove a subscription
  ///
  /// Returns true if subscription was removed, false if not found.
  ///
  /// Example:
  /// ```dart
  /// final removed = manager.remove(SubscriptionType.task, 'task-123');
  /// if (removed) {
  ///   print('Unsubscribed from task-123');
  /// }
  /// ```
  bool remove(SubscriptionType type, String id) {
    final key = '${type.name}:$id';
    return _subscriptions.remove(key) != null;
  }

  /// Check if subscribed to a resource
  ///
  /// Example:
  /// ```dart
  /// if (manager.has(SubscriptionType.task, 'task-123')) {
  ///   print('Already listening to task-123');
  /// }
  /// ```
  bool has(SubscriptionType type, String id) {
    final key = '${type.name}:$id';
    return _subscriptions.containsKey(key);
  }

  /// Get all subscriptions
  ///
  /// Returns a list of all active subscriptions.
  ///
  /// Example:
  /// ```dart
  /// final subscriptions = manager.getAll();
  /// print('Active subscriptions: ${subscriptions.length}');
  /// ```
  List<Subscription> getAll() {
    return _subscriptions.values.toList();
  }

  /// Get subscriptions by type
  ///
  /// Example:
  /// ```dart
  /// final taskSubscriptions = manager.getByType(SubscriptionType.task);
  /// print('Subscribed to ${taskSubscriptions.length} tasks');
  /// ```
  List<Subscription> getByType(SubscriptionType type) {
    return _subscriptions.values.where((s) => s.type == type).toList();
  }

  /// Get subscription by key
  ///
  /// Example:
  /// ```dart
  /// final subscription = manager.get(SubscriptionType.task, 'task-123');
  /// if (subscription != null) {
  ///   print('Subscribed at: ${subscription.subscribedAt}');
  /// }
  /// ```
  Subscription? get(SubscriptionType type, String id) {
    final key = '${type.name}:$id';
    return _subscriptions[key];
  }

  /// Clear all subscriptions
  ///
  /// Example:
  /// ```dart
  /// manager.clear();
  /// print('All subscriptions cleared');
  /// ```
  void clear() {
    _subscriptions.clear();
  }

  /// Get subscription count
  int get count => _subscriptions.length;

  /// Check if there are any subscriptions
  bool get isEmpty => _subscriptions.isEmpty;

  /// Check if there are subscriptions
  bool get isNotEmpty => _subscriptions.isNotEmpty;

  @override
  String toString() => 'SubscriptionManager(count: $count)';
}
