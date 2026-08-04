import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/src/connection/message_queue.dart';

void main() {
  group('MessageQueue', () {
    test('initializes with empty queue', () {
      final queue = MessageQueue();

      expect(queue.hasMessages, isFalse);
      expect(queue.size, equals(0));
    });

    test('enqueues messages correctly', () {
      final queue = MessageQueue();

      queue.enqueue({'action': 'subscribe', 'id': 'task-1'});
      queue.enqueue({'action': 'subscribe', 'id': 'task-2'});

      expect(queue.hasMessages, isTrue);
      expect(queue.size, equals(2));
    });

    test('flushes messages in FIFO order', () {
      final queue = MessageQueue();
      final receivedMessages = <Map<String, dynamic>>[];

      queue.enqueue({'action': 'subscribe', 'id': 'task-1'});
      queue.enqueue({'action': 'subscribe', 'id': 'task-2'});
      queue.enqueue({'action': 'subscribe', 'id': 'task-3'});

      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages.length, equals(3));
      expect(receivedMessages[0]['id'], equals('task-1'));
      expect(receivedMessages[1]['id'], equals('task-2'));
      expect(receivedMessages[2]['id'], equals('task-3'));
      expect(queue.hasMessages, isFalse);
      expect(queue.size, equals(0));
    });

    test('clears all messages', () {
      final queue = MessageQueue();

      queue.enqueue({'action': 'subscribe', 'id': 'task-1'});
      queue.enqueue({'action': 'subscribe', 'id': 'task-2'});

      expect(queue.size, equals(2));

      queue.clear();

      expect(queue.hasMessages, isFalse);
      expect(queue.size, equals(0));
    });

    test('respects maxSize limit', () {
      final queue = MessageQueue(maxSize: 3);

      queue.enqueue({'id': '1'});
      queue.enqueue({'id': '2'});
      queue.enqueue({'id': '3'});
      queue.enqueue({'id': '4'}); // Should drop oldest (id: 1)

      expect(queue.size, equals(3));

      final receivedMessages = <Map<String, dynamic>>[];
      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages.length, equals(3));
      expect(receivedMessages[0]['id'], equals('2'));
      expect(receivedMessages[1]['id'], equals('3'));
      expect(receivedMessages[2]['id'], equals('4'));
    });

    test('drops oldest message when queue is full', () {
      final queue = MessageQueue(maxSize: 2);

      queue.enqueue({'id': '1'});
      queue.enqueue({'id': '2'});

      expect(queue.size, equals(2));

      queue.enqueue({'id': '3'}); // Should drop id: 1

      expect(queue.size, equals(2));

      final receivedMessages = <Map<String, dynamic>>[];
      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages[0]['id'], equals('2'));
      expect(receivedMessages[1]['id'], equals('3'));
    });

    test('handles empty flush gracefully', () {
      final queue = MessageQueue();
      var callCount = 0;

      queue.flush((_) {
        callCount++;
      });

      expect(callCount, equals(0));
      expect(queue.hasMessages, isFalse);
    });

    test('handles single message correctly', () {
      final queue = MessageQueue();
      final receivedMessages = <Map<String, dynamic>>[];

      queue.enqueue({'action': 'ping'});

      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0]['action'], equals('ping'));
      expect(queue.hasMessages, isFalse);
    });

    test('allows enqueuing after flush', () {
      final queue = MessageQueue();

      queue.enqueue({'id': '1'});
      queue.flush((_) {});

      expect(queue.hasMessages, isFalse);

      queue.enqueue({'id': '2'});

      expect(queue.hasMessages, isTrue);
      expect(queue.size, equals(1));
    });

    test('toString returns correct format', () {
      final queue = MessageQueue(maxSize: 100);

      queue.enqueue({'id': '1'});
      queue.enqueue({'id': '2'});

      final str = queue.toString();

      expect(str, contains('2/100'));
    });

    test('handles complex message objects', () {
      final queue = MessageQueue();
      final complexMessage = {
        'action': 'subscribe',
        'type': 'task',
        'id': 'task-123',
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'priority': 'high',
        },
        'nested': {
          'deep': {
            'value': 42,
          },
        },
      };

      queue.enqueue(complexMessage);

      final receivedMessages = <Map<String, dynamic>>[];
      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0], equals(complexMessage));
    });

    test('maintains FIFO order with many messages', () {
      final queue = MessageQueue(maxSize: 100);

      for (var i = 0; i < 50; i++) {
        queue.enqueue({'id': i});
      }

      final receivedMessages = <Map<String, dynamic>>[];
      queue.flush((message) {
        receivedMessages.add(message);
      });

      expect(receivedMessages.length, equals(50));

      for (var i = 0; i < 50; i++) {
        expect(receivedMessages[i]['id'], equals(i));
      }
    });
  });
}
