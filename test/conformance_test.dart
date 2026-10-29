// Runs the shared realtime conformance fixtures (packages/sdks/conformance) against this SDK.
// Every Relay UI SDK runs the same fixtures, which is how they stay at parity.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/relay_flutter.dart';
import 'package:relay_flutter/src/connection/realtime_messages.dart';

final Directory _dir = Directory(
  Platform.environment['RELAY_CONFORMANCE_DIR'] ?? '../conformance',
);

dynamic _read(String file) =>
    jsonDecode(File('${_dir.path}/$file').readAsStringSync());

/// The event's fields under the API's names, so fixture paths apply to typed events.
Map<String, dynamic> _asApiJson(RelayEvent event) => switch (event) {
      TaskOfferedEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
        },
      TaskAssignedEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
          'riderId': e.riderId,
        },
      TaskInProgressEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
          'riderId': e.riderId,
        },
      StageCompletedEvent e => {
          'taskId': e.taskId,
          'riderId': e.riderId,
          'stageIndex': e.stageIndex,
        },
      TaskCompletedEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
          'riderId': e.riderId,
        },
      TaskFailedEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
          'riderId': e.riderId,
          'reason': e.reason,
        },
      TaskCancelledEvent e => {
          'taskId': e.taskId,
          'status': e.status.value,
          'riderId': e.riderId,
          'reason': e.reason,
          'cancelledBy': e.cancelledBy,
        },
      RiderLocationUpdateEvent e => {
          'taskId': e.taskId,
          'riderId': e.riderId,
          'location': {
            'latitude': e.location.latitude,
            'longitude': e.location.longitude,
          },
          'eta': e.eta == null
              ? null
              : {
                  'stageIndex': e.eta!.stageIndex,
                  'seconds': e.eta!.remaining.inSeconds,
                  'meters': e.eta!.meters,
                },
          'timestamp': e.timestamp.toUtc().toIso8601String(),
        },
      _ => {},
    };

String? _eventName(RelayEvent event) => switch (event) {
      TaskOfferedEvent() => 'TASK_OFFERED',
      TaskAssignedEvent() => 'TASK_ASSIGNED',
      TaskInProgressEvent() => 'TASK_IN_PROGRESS',
      StageCompletedEvent() => 'STAGE_COMPLETED',
      TaskCompletedEvent() => 'TASK_COMPLETED',
      TaskFailedEvent() => 'TASK_FAILED',
      TaskCancelledEvent() => 'TASK_CANCELLED',
      RiderLocationUpdateEvent() => 'RIDER_LOCATION_UPDATE',
      _ => null,
    };

dynamic _lookup(dynamic value, String dotted) {
  dynamic node = value;
  for (final key in dotted.split('.')) {
    if (node is! Map) return null;
    node = node[key];
  }
  return node;
}

void main() {
  if (!File('${_dir.path}/manifest.json').existsSync()) {
    test('conformance fixtures', () {}, skip: 'conformance folder not found');
    return;
  }

  group('conformance frames', () {
    for (final c in (_read('realtime/frames.json')['cases'] as List)) {
      test(c['name'] as String, () async {
        final client = RelayRealtimeClient(getToken: (_) async => 'token');
        final seen = <RelayEvent>[];
        final sub = client.events.listen(seen.add);
        client.handleIncomingMessageForTest(
          Map<String, dynamic>.from(c['frame'] as Map),
        );
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        final expected = c['expect'] as Map;
        final named = seen.where((e) => _eventName(e) != null).toList();
        if (expected['event'] == null) {
          expect(named, isEmpty);
          return;
        }
        expect(named.map(_eventName).toList(), [expected['event']]);
        final json = _asApiJson(named.single);
        final fields = (expected['fields'] as Map?) ?? {};
        for (final entry in fields.entries) {
          final key = entry.key as String;
          // Timestamps are compared as instants; typed SDKs normalise the format.
          if (key == 'timestamp') {
            expect(
              DateTime.parse(_lookup(json, key) as String),
              DateTime.parse(entry.value as String),
              reason: key,
            );
          } else {
            expect(_lookup(json, key), entry.value, reason: key);
          }
        }
      });
    }
  });

  test('conformance outgoing messages', () {
    final messages = _read('realtime/outgoing.json')['messages'] as Map;
    Map<String, dynamic> want(String name) => (messages[name] as Map).map(
          (k, v) => MapEntry(k as String, v == '<taskId>' ? 'task-1' : v),
        );
    expect(RealtimeMessages.subscribe('task-1'), want('subscribe'));
    expect(RealtimeMessages.unsubscribe('task-1'), want('unsubscribe'));
    expect(RealtimeMessages.ping, want('ping'));
  });

  group('conformance url', () {
    final url = _read('realtime/url.json');
    for (final c in (url['cases'] as List)) {
      test(c['name'] as String, () {
        final built = buildRelayWebSocketUri(
          token: c['token'] as String,
          baseUrl: c['baseUrl'] as String,
          deviceId: c['deviceId'] as String?,
        );
        final want = c['expect'] as Map;
        expect(built.scheme, want['scheme']);
        expect(built.host, want['host']);
        expect(built.hasPort ? built.port : null, want['port']);
        expect(built.path, want['path']);
        expect(built.queryParameters, want['query']);
      });
    }

    test('uses the shared defaults', () {
      final d = url['defaults'] as Map;
      const reconnect = ReconnectConfig();
      const heartbeat = HeartbeatConfig();
      expect(relayDefaultWebSocketUrl, d['url']);
      expect(reconnect.enabled, d['reconnect']['enabled']);
      expect(reconnect.initialDelay.inMilliseconds, d['reconnect']['initialDelayMs']);
      expect(reconnect.maxDelay.inMilliseconds, d['reconnect']['maxDelayMs']);
      expect(reconnect.backoffMultiplier, d['reconnect']['backoffMultiplier']);
      expect(heartbeat.enabled, d['heartbeat']['enabled']);
      expect(heartbeat.interval.inMilliseconds, d['heartbeat']['intervalMs']);
      expect(heartbeat.timeout.inMilliseconds, d['heartbeat']['timeoutMs']);
      expect(
        RelayRealtimeClientOptions(getToken: (_) async => 'token')
            .tokenExpirationWarning
            .inMilliseconds,
        d['tokenRefreshBeforeExpiryMs'],
      );
    });
  });
}
