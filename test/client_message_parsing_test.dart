import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/relay_flutter.dart';

void main() {
  group('RelayRealtimeClient message parsing', () {
    test('unwraps TASK_UPDATE envelope and emits inner task event', () async {
      final client = RelayRealtimeClient(
        getToken: (_) async => 'token',
      );

      final assignedFuture = client.onTaskAssigned.first;

      client.handleIncomingMessageForTest({
        'type': 'TASK_UPDATE',
        'data': {
          'type': 'TASK_ASSIGNED',
          'taskId': 'task-123',
          'riderId': 'rider-456',
          'developerId': 'dev-789',
          'status': 'ASSIGNED',
          'assignedAt': '2026-05-14T10:00:00.000Z',
          'deliveryFee': 500000,
          'currentStageIndex': 0,
          'timestamp': '2026-05-14T10:00:01.000Z',
        },
      });

      final event = await assignedFuture;
      expect(event.taskId, equals('task-123'));
      expect(event.riderId, equals('rider-456'));
      expect(event.developerId, equals('dev-789'));
      expect(event.status, equals(TaskStatus.assigned));
      expect(event.deliveryFee, equals(500000));
      expect(event.currentStageIndex, equals(0));
    });

    // Frames exactly as the server's task room publishes them (no envelope).
    test('parses task frames as published by the server', () async {
      final client = RelayRealtimeClient(
        getToken: (_) async => 'token',
      );

      final cancelledFuture = client.onTaskCancelled.first;
      final completedFuture = client.onTaskCompleted.first;

      client.handleIncomingMessageForTest({
        'type': 'TASK_CANCELLED',
        'taskId': 'task-1',
        'developerId': 'dev-1',
        'riderId': null,
        'status': 'CANCELLED',
        'cancelledAt': '2026-10-12T10:00:00.000Z',
        'cancelledBy': 'DEVELOPER',
        'reason': 'Customer request',
      });
      client.handleIncomingMessageForTest({
        'type': 'TASK_COMPLETED',
        'taskId': 'task-2',
        'developerId': 'dev-1',
        'riderId': 'rider-1',
        'status': 'COMPLETED',
        'completedAt': '2026-10-12T11:00:00.000Z',
        'deliveryFee': 250000,
        'paymentStatus': 'PENDING',
        'completionCodeVerified': true,
      });

      final cancelled = await cancelledFuture;
      expect(cancelled.developerId, equals('dev-1'));
      expect(cancelled.riderId, isNull);
      expect(cancelled.reason, equals('Customer request'));

      final completed = await completedFuture;
      expect(completed.developerId, equals('dev-1'));
      expect(completed.deliveryFee, equals(250000));
      expect(completed.completionCodeVerified, isTrue);
    });

    test('parses NEW_TASK_OFFER with nested task payload', () async {
      final client = RelayRealtimeClient(
        getToken: (_) async => 'token',
      );

      final offerFuture = client.onNewTaskOffer.first;

      client.handleIncomingMessageForTest({
        'type': 'NEW_TASK_OFFER',
        'taskId': 'task-999',
        'tier': 2,
        'task': {
          'taskId': 'task-999',
          'taskType': 'PACKAGE_DELIVERY',
          'priority': 'URGENT',
          'deliveryFee': 250000,
          'pickupLocation': {
            'latitude': 6.5244,
            'longitude': 3.3792,
          },
          'dropoffLocation': {
            'latitude': 6.6000,
            'longitude': 3.3500,
          },
          'estimatedDistance': 12.5,
          'estimatedDuration': 35,
        },
        'offerExpiresAt': '2026-05-14T10:05:00.000Z',
        'offerTimeoutSeconds': 30,
      });

      final event = await offerFuture;
      expect(event.taskId, equals('task-999'));
      expect(event.tier, equals(2));
      expect(event.taskType, equals(TaskType.packageDelivery));
      expect(event.priority, equals(Priority.urgent));
      expect(event.deliveryFee, equals(250000));
      expect(event.pickupLocation.latitude, equals(6.5244));
      expect(event.pickupLocation.longitude, equals(3.3792));
      expect(event.dropoffLocation.latitude, equals(6.6000));
      expect(event.dropoffLocation.longitude, equals(3.3500));
      expect(event.offerTimeoutSeconds, equals(30));
      expect(event.estimatedDistance, equals(12.5));
      expect(event.estimatedDuration, equals(35));
      expect(
        event.expiresAt.toUtc(),
        equals(DateTime.parse('2026-05-14T10:05:00.000Z').toUtc()),
      );
    });
  });
}
