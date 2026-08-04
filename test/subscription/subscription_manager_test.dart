import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/subscription/subscription_manager.dart';

void main() {
  group('SubscriptionManager', () {
    test('initializes with empty subscriptions', () {
      final manager = SubscriptionManager();

      expect(manager.isEmpty, isTrue);
      expect(manager.isNotEmpty, isFalse);
      expect(manager.count, equals(0));
    });

    group('add', () {
      test('adds subscription successfully', () {
        final manager = SubscriptionManager();

        final added = manager.add(SubscriptionType.task, 'task-1');

        expect(added, isTrue);
        expect(manager.count, equals(1));
        expect(manager.has(SubscriptionType.task, 'task-1'), isTrue);
      });

      test('returns false when adding duplicate subscription', () {
        final manager = SubscriptionManager();

        final added1 = manager.add(SubscriptionType.task, 'task-1');
        final added2 = manager.add(SubscriptionType.task, 'task-1');

        expect(added1, isTrue);
        expect(added2, isFalse);
        expect(manager.count, equals(1));
      });

      test('allows same ID with different types', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'id-1');
        manager.add(SubscriptionType.rider, 'id-1');

        expect(manager.count, equals(2));
        expect(manager.has(SubscriptionType.task, 'id-1'), isTrue);
        expect(manager.has(SubscriptionType.rider, 'id-1'), isTrue);
      });
    });

    group('remove', () {
      test('removes subscription successfully', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        final removed = manager.remove(SubscriptionType.task, 'task-1');

        expect(removed, isTrue);
        expect(manager.count, equals(0));
        expect(manager.has(SubscriptionType.task, 'task-1'), isFalse);
      });

      test('returns false when removing non-existent subscription', () {
        final manager = SubscriptionManager();

        final removed = manager.remove(SubscriptionType.task, 'task-1');

        expect(removed, isFalse);
        expect(manager.count, equals(0));
      });

      test('removes only matching type and ID', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');
        manager.add(SubscriptionType.rider, 'rider-1');

        manager.remove(SubscriptionType.task, 'task-1');

        expect(manager.count, equals(2));
        expect(manager.has(SubscriptionType.task, 'task-1'), isFalse);
        expect(manager.has(SubscriptionType.task, 'task-2'), isTrue);
        expect(manager.has(SubscriptionType.rider, 'rider-1'), isTrue);
      });
    });

    group('has', () {
      test('returns true for existing subscription', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');

        expect(manager.has(SubscriptionType.task, 'task-1'), isTrue);
      });

      test('returns false for non-existent subscription', () {
        final manager = SubscriptionManager();

        expect(manager.has(SubscriptionType.task, 'task-1'), isFalse);
      });

      test('returns false for wrong type', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'id-1');

        expect(manager.has(SubscriptionType.rider, 'id-1'), isFalse);
      });
    });

    group('get', () {
      test('returns subscription for existing entry', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        final subscription = manager.get(SubscriptionType.task, 'task-1');

        expect(subscription, isNotNull);
        expect(subscription!.type, equals(SubscriptionType.task));
        expect(subscription.id, equals('task-1'));
      });

      test('returns null for non-existent subscription', () {
        final manager = SubscriptionManager();

        final subscription = manager.get(SubscriptionType.task, 'task-1');

        expect(subscription, isNull);
      });

      test('subscription has correct timestamp', () {
        final manager = SubscriptionManager();
        final beforeAdd = DateTime.now();

        manager.add(SubscriptionType.task, 'task-1');

        final afterAdd = DateTime.now();
        final subscription = manager.get(SubscriptionType.task, 'task-1');

        expect(subscription, isNotNull);
        expect(
          subscription!.subscribedAt.isAfter(beforeAdd) ||
              subscription.subscribedAt.isAtSameMomentAs(beforeAdd),
          isTrue,
        );
        expect(
          subscription.subscribedAt.isBefore(afterAdd) ||
              subscription.subscribedAt.isAtSameMomentAs(afterAdd),
          isTrue,
        );
      });
    });

    group('getAll', () {
      test('returns all subscriptions', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');
        manager.add(SubscriptionType.rider, 'rider-1');

        final all = manager.getAll();

        expect(all.length, equals(3));
      });

      test('returns empty list when no subscriptions', () {
        final manager = SubscriptionManager();

        final all = manager.getAll();

        expect(all, isEmpty);
      });

      test('returns copy of subscriptions list', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');

        final all1 = manager.getAll();
        final all2 = manager.getAll();

        // Should be different list instances
        expect(identical(all1, all2), isFalse);
        expect(all1.length, equals(all2.length));
      });
    });

    group('getByType', () {
      test('returns subscriptions of specific type', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');
        manager.add(SubscriptionType.rider, 'rider-1');

        final tasks = manager.getByType(SubscriptionType.task);

        expect(tasks.length, equals(2));
        expect(tasks.every((s) => s.type == SubscriptionType.task), isTrue);
      });

      test('returns empty list when no subscriptions of type', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');

        final riders = manager.getByType(SubscriptionType.rider);

        expect(riders, isEmpty);
      });

      test('returns correct subscriptions after removal', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');
        manager.remove(SubscriptionType.task, 'task-1');

        final tasks = manager.getByType(SubscriptionType.task);

        expect(tasks.length, equals(1));
        expect(tasks[0].id, equals('task-2'));
      });
    });

    group('clear', () {
      test('removes all subscriptions', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');
        manager.add(SubscriptionType.rider, 'rider-1');

        manager.clear();

        expect(manager.isEmpty, isTrue);
        expect(manager.count, equals(0));
        expect(manager.getAll(), isEmpty);
      });

      test('clear on empty manager is safe', () {
        final manager = SubscriptionManager();

        manager.clear();

        expect(manager.isEmpty, isTrue);
      });
    });

    group('Subscription', () {
      test('key combines type and ID', () {
        final subscription = Subscription(
          type: SubscriptionType.task,
          id: 'task-1',
          subscribedAt: DateTime.now(),
        );

        expect(subscription.key, equals('task:task-1'));
      });

      test('equality works correctly', () {
        final now = DateTime.now();
        final sub1 = Subscription(
          type: SubscriptionType.task,
          id: 'task-1',
          subscribedAt: now,
        );
        final sub2 = Subscription(
          type: SubscriptionType.task,
          id: 'task-1',
          subscribedAt: now.add(const Duration(seconds: 1)),
        );
        final sub3 = Subscription(
          type: SubscriptionType.rider,
          id: 'task-1',
          subscribedAt: now,
        );

        expect(sub1 == sub2, isTrue); // Same type and ID
        expect(sub1 == sub3, isFalse); // Different type
        expect(sub1.hashCode == sub2.hashCode, isTrue);
      });

      test('toString returns formatted string', () {
        final subscription = Subscription(
          type: SubscriptionType.task,
          id: 'task-1',
          subscribedAt: DateTime.now(),
        );

        final str = subscription.toString();

        expect(str, contains('task'));
        expect(str, contains('task-1'));
      });
    });

    group('SubscriptionManager toString', () {
      test('returns correct format', () {
        final manager = SubscriptionManager();

        manager.add(SubscriptionType.task, 'task-1');
        manager.add(SubscriptionType.task, 'task-2');

        final str = manager.toString();

        expect(str, contains('2'));
      });
    });
  });
}
