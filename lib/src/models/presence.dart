import 'package:meta/meta.dart';

/// How finely rider presence is grouped. Nothing finer than a city block is
/// ever returned.
enum PresenceResolution {
  /// H3 resolution 9, cells ≈ 0.1 km² — a city block (the default).
  block('BLOCK'),

  /// H3 resolution 8, cells ≈ 0.74 km².
  neighbourhood('NEIGHBOURHOOD'),

  /// H3 resolution 7, cells ≈ 5.2 km².
  district('DISTRICT');

  const PresenceResolution(this.value);

  /// Wire value.
  final String value;

  /// Parses a wire value, defaulting to [district] (the coarsest) when unknown.
  static PresenceResolution parse(String? value) => PresenceResolution.values
      .firstWhere((r) => r.value == value, orElse: () => district);
}

/// Banded riders per cell: [low] 1–2, [medium] 3–5, [high] 6 or more.
enum PresenceDensity {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const PresenceDensity(this.value);

  /// Wire value.
  final String value;

  /// Parses a wire value, defaulting to [low] when unknown.
  static PresenceDensity parse(String? value) => PresenceDensity.values
      .firstWhere((d) => d.value == value, orElse: () => low);
}

/// A latitude/longitude pair.
@immutable
class PresencePoint {
  /// Latitude
  final double latitude;

  /// Longitude
  final double longitude;

  /// Create a point
  const PresencePoint({required this.latitude, required this.longitude});

  /// Parse from JSON
  factory PresencePoint.fromJson(Map<String, dynamic> json) => PresencePoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

/// One map cell with available riders. Riders are never identified.
@immutable
class PresenceCell {
  /// H3 cell index
  final String cellId;

  /// Coarser than requested where too few riders were present to show finer
  /// cells without singling a rider out.
  final PresenceResolution resolution;

  /// H3 resolution of [cellId]
  final int h3Resolution;

  /// Cell centre
  final PresencePoint center;

  /// Closed polygon outline (first point repeated last)
  final List<PresencePoint> boundary;

  /// Banded rider count
  final PresenceDensity density;

  /// Vehicle types with at least one available rider, e.g. `MOTORCYCLE`
  final List<String> vehicleTypes;

  /// Create a presence cell
  const PresenceCell({
    required this.cellId,
    required this.resolution,
    required this.h3Resolution,
    required this.center,
    required this.boundary,
    required this.density,
    required this.vehicleTypes,
  });

  /// Parse from JSON
  factory PresenceCell.fromJson(Map<String, dynamic> json) => PresenceCell(
    cellId: json['cellId'] as String,
    resolution: PresenceResolution.parse(json['resolution'] as String?),
    h3Resolution: (json['h3Resolution'] as num).toInt(),
    center: PresencePoint.fromJson(
      Map<String, dynamic>.from(json['center'] as Map),
    ),
    boundary: (json['boundary'] as List)
        .map((p) => PresencePoint.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(growable: false),
    density: PresenceDensity.parse(json['density'] as String?),
    vehicleTypes: (json['vehicleTypes'] as List? ?? const [])
        .map((type) => type.toString())
        .toList(growable: false),
  );
}

/// Anonymous presence of available riders around a point — the body of
/// `GET /v1/sdk/presence`.
///
/// Presence is read with an API key, so your app gets it from your backend
/// (for example with `relay.presence.get()` in @relay-sdk/sdk-node) and parses
/// it here:
///
/// ```dart
/// final response = await http.get(
///   Uri.parse('https://your-backend.com/api/relay/presence?lat=6.52&lng=3.38'),
/// );
/// final presence = PresenceMap.fromJson(jsonDecode(response.body));
/// for (final cell in presence.cells) {
///   polygons.add(Polygon(points: cell.boundary /* … */));
/// }
/// ```
@immutable
class PresenceMap {
  /// `live` or `test`
  final String mode;

  /// Test keys receive simulated riders
  final bool simulated;

  /// Requested resolution
  final PresenceResolution resolution;

  /// Covered area centre (snapped to a fixed grid near the requested point)
  final PresencePoint areaCenter;

  /// Covered area radius in km
  final double areaRadiusKm;

  /// Cells with available riders
  final List<PresenceCell> cells;

  /// Available riders in the area
  final int availableRiders;

  /// Available riders per vehicle type, e.g. `{'MOTORCYCLE': 12}`
  final Map<String, int> ridersByVehicleType;

  /// When the snapshot was taken
  final DateTime generatedAt;

  /// Snapshots are cached; polling faster than this returns the same data
  final Duration refreshAfter;

  /// Create a presence map
  const PresenceMap({
    required this.mode,
    required this.simulated,
    required this.resolution,
    required this.areaCenter,
    required this.areaRadiusKm,
    required this.cells,
    required this.availableRiders,
    required this.ridersByVehicleType,
    required this.generatedAt,
    required this.refreshAfter,
  });

  /// Parse from JSON
  factory PresenceMap.fromJson(Map<String, dynamic> json) {
    final area = Map<String, dynamic>.from(json['area'] as Map);
    final totals = Map<String, dynamic>.from(json['totals'] as Map);
    return PresenceMap(
      mode: json['mode'] as String,
      simulated: json['simulated'] == true,
      resolution: PresenceResolution.parse(json['resolution'] as String?),
      areaCenter: PresencePoint.fromJson(
        Map<String, dynamic>.from(area['center'] as Map),
      ),
      areaRadiusKm: (area['radiusKm'] as num).toDouble(),
      cells: (json['cells'] as List)
          .map((c) => PresenceCell.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(growable: false),
      availableRiders: (totals['availableRiders'] as num).toInt(),
      ridersByVehicleType: Map<String, dynamic>.from(
        totals['byVehicleType'] as Map? ?? const {},
      ).map((type, count) => MapEntry(type, (count as num).toInt())),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      refreshAfter: Duration(
        seconds: (json['refreshAfterSeconds'] as num?)?.toInt() ?? 30,
      ),
    );
  }
}
