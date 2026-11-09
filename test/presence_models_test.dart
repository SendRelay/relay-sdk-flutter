import 'package:flutter_test/flutter_test.dart';
import 'package:relay_flutter/relay_flutter.dart';

void main() {
  test('parses a presence map response', () {
    final presence = PresenceMap.fromJson({
      'mode': 'test',
      'simulated': true,
      'resolution': 'BLOCK',
      'h3Resolution': 9,
      'area': {
        'center': {'latitude': 6.52, 'longitude': 3.38},
        'radiusKm': 2,
      },
      'cells': [
        {
          'cellId': '89754e64d93ffff',
          'resolution': 'NEIGHBOURHOOD',
          'h3Resolution': 8,
          'center': {'latitude': 6.52, 'longitude': 3.38},
          'boundary': [
            {'latitude': 6.52, 'longitude': 3.38},
            {'latitude': 6.53, 'longitude': 3.39},
            {'latitude': 6.52, 'longitude': 3.38},
          ],
          'density': 'MEDIUM',
          'vehicleTypes': ['MOTORCYCLE', 'CAR'],
        },
      ],
      'totals': {
        'availableRiders': 4,
        'byVehicleType': {'MOTORCYCLE': 3, 'CAR': 1},
      },
      'minRidersPerCell': 2,
      'capped': false,
      'generatedAt': '2026-10-27T10:00:00.000Z',
      'refreshAfterSeconds': 30,
    });

    expect(presence.simulated, isTrue);
    expect(presence.resolution, PresenceResolution.block);
    expect(presence.cells.single.resolution, PresenceResolution.neighbourhood);
    expect(presence.cells.single.density, PresenceDensity.medium);
    expect(presence.cells.single.boundary, hasLength(3));
    expect(presence.ridersByVehicleType['MOTORCYCLE'], 3);
    expect(presence.refreshAfter, const Duration(seconds: 30));
    expect(presence.requirements, isNull);
  });

  test('PresenceMap reads what a job needs when presence was filtered by it', () {
    final presence = PresenceMap.fromJson({
      'mode': 'live',
      'simulated': false,
      'resolution': 'NEIGHBOURHOOD',
      'area': {
        'center': {'latitude': 6.52, 'longitude': 3.38},
        'radiusKm': 4,
      },
      'cells': <dynamic>[],
      'totals': {
        'availableRiders': 0,
        'byVehicleType': <String, dynamic>{},
      },
      'generatedAt': '2026-11-09T10:00:00.000Z',
      'refreshAfterSeconds': 30,
      'requirements': {
        'vehicles': [
          {
            'vehicleType': 'MOTORCYCLE',
            'equipment': ['BOX'],
          },
        ],
      },
    });

    expect(presence.requirements, hasLength(1));
    expect(presence.requirements!.single.vehicleType, 'MOTORCYCLE');
    expect(presence.requirements!.single.equipment, ['BOX']);
  });
}
