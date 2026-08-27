import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';
import 'maneuver.dart';

/// One guidance instruction, resolved against the route polyline.
///
/// [startOffsetMeters] and [endOffsetMeters] are measured along the geometry —
/// the same space the map matcher works in — so "distance to the next turn" is
/// exact instead of drifting against a sum of provider step lengths.
class NavStep {
  const NavStep({
    required this.index,
    required this.maneuver,
    required this.instruction,
    required this.roadName,
    required this.location,
    required this.startOffsetMeters,
    required this.endOffsetMeters,
    required this.durationSeconds,
    this.roundaboutExitCount,
    this.exitNumber,
    this.toward,
  });

  final int index;
  final SfManeuver maneuver;
  final String instruction;
  final String roadName;
  final LatLng location;
  final double startOffsetMeters;
  final double endOffsetMeters;
  final double durationSeconds;
  final int? roundaboutExitCount;
  final String? exitNumber;
  final String? toward;

  double get lengthMeters => math.max(0, endOffsetMeters - startOffsetMeters);

  bool get isArrival => maneuver.isArrival;

  NavStep copyWith({double? endOffsetMeters}) => NavStep(
    index: index,
    maneuver: maneuver,
    instruction: instruction,
    roadName: roadName,
    location: location,
    startOffsetMeters: startOffsetMeters,
    endOffsetMeters: endOffsetMeters ?? this.endOffsetMeters,
    durationSeconds: durationSeconds,
    roundaboutExitCount: roundaboutExitCount,
    exitNumber: exitNumber,
    toward: toward,
  );
}

/// A hazard as it was known when the route was scored.
///
/// The set is frozen onto the session by the backend so the device keeps
/// warning about the same closures after it goes offline.
class NavHazard {
  NavHazard({
    required this.id,
    required this.hazardType,
    required this.severity,
    required this.hardClosure,
    required this.geometry,
    required this.radiusMeters,
    this.address,
  });

  final int? id;
  final String hazardType;
  final String severity;
  final bool hardClosure;
  final List<LatLng> geometry;
  final double radiusMeters;
  final String? address;

  bool get isTrafficJam => hazardType == 'TRAFFIC_JAM';

  String get label => isTrafficJam ? 'kẹt xe' : 'ngập nước';

  LatLng get center {
    if (geometry.isEmpty) return const LatLng(0, 0);
    var lat = 0.0;
    var lng = 0.0;
    for (final point in geometry) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / geometry.length, lng / geometry.length);
  }

  static NavHazard? fromJson(Map<String, dynamic> json) {
    final geometry = _points(json['geometry']);
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final resolved = geometry.isNotEmpty
        ? geometry
        : (lat == null || lng == null)
        ? const <LatLng>[]
        : [LatLng(lat, lng)];
    if (resolved.isEmpty) return null;
    return NavHazard(
      id: (json['id'] as num?)?.toInt(),
      hazardType: json['hazardType']?.toString() ?? 'FLOOD',
      severity: json['severity']?.toString() ?? 'MEDIUM',
      hardClosure: json['hardClosure'] == true,
      geometry: resolved,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 120,
      address: json['address']?.toString(),
    );
  }

  static List<LatLng> _points(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .where((point) => point.length >= 2)
        .map(
          (point) => LatLng(
            (point[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

/// A hazard resolved against one specific route.
class NavHazardOnRoute {
  const NavHazardOnRoute({
    required this.hazard,
    required this.offsetMeters,
    required this.clearanceMeters,
  });

  final NavHazard hazard;

  /// Distance from the route start to the point nearest the hazard.
  final double offsetMeters;

  /// How far the hazard sits from the route, after subtracting its radius.
  /// Zero means the route runs through it.
  final double clearanceMeters;

  bool get onRoute => clearanceMeters <= 0;
}

/// One routing alternative, with everything the guidance engine needs
/// precomputed at construction time.
class NavRoute {
  NavRoute._({
    required this.routeIndex,
    required this.label,
    required this.provider,
    required this.providerFallback,
    required this.safe,
    required this.blocked,
    required this.hazardIntersectionCount,
    required this.reportedDistanceMeters,
    required this.reportedDurationSeconds,
    required this.geometry,
    required this.cumulativeMeters,
    required this.steps,
    required this.warnings,
    required this.hazardsOnRoute,
  });

  final int routeIndex;
  final String label;
  final String provider;

  /// True when the road graph that produced this route could not honour the
  /// dynamic closure list — the route is usable but must be shown as degraded.
  final bool providerFallback;
  final bool safe;
  final bool blocked;
  final int hazardIntersectionCount;
  final double reportedDistanceMeters;
  final double reportedDurationSeconds;
  final List<LatLng> geometry;

  /// `cumulativeMeters[i]` is the distance from the start to `geometry[i]`.
  final List<double> cumulativeMeters;
  final List<NavStep> steps;
  final List<String> warnings;
  final List<NavHazardOnRoute> hazardsOnRoute;

  double get lengthMeters =>
      cumulativeMeters.isEmpty ? 0 : cumulativeMeters.last;

  bool get isUsable => geometry.length >= 2;

  /// Number of hazards actually intersecting this route, counted on the device
  /// from the frozen snapshot. The planner used to show every hazard within
  /// 20 km of the midpoint, which wildly overstated the risk.
  int get hazardsOnRouteCount =>
      hazardsOnRoute.where((hazard) => hazard.onRoute).length;

  static NavRoute? fromJson(
    Map<String, dynamic> json, {
    List<NavHazard> hazards = const [],
  }) {
    final geometry = _geometry(json['geometry']);
    if (geometry.length < 2) return null;

    final cumulative = List<double>.filled(geometry.length, 0);
    for (var index = 1; index < geometry.length; index++) {
      cumulative[index] =
          cumulative[index - 1] +
          SfGeo.distance(geometry[index - 1], geometry[index]);
    }
    final totalMeters = cumulative.last;

    final steps = _steps(json['steps'], geometry, cumulative);
    return NavRoute._(
      routeIndex: (json['routeIndex'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? 'Tuyến đường',
      provider: json['provider']?.toString() ?? 'ROAD_GRAPH',
      providerFallback: json['fallback'] == true || json['providerFallback'] == true,
      safe: json['safe'] != false,
      blocked: json['blocked'] == true,
      hazardIntersectionCount:
          (json['floodIntersectionCount'] as num?)?.toInt() ?? 0,
      reportedDistanceMeters:
          (json['distanceMeters'] as num?)?.toDouble() ?? totalMeters,
      reportedDurationSeconds:
          (json['durationSeconds'] as num?)?.toDouble() ?? 0,
      geometry: geometry,
      cumulativeMeters: cumulative,
      steps: steps,
      warnings: (json['warnings'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      hazardsOnRoute: _resolveHazards(hazards, geometry, cumulative),
    );
  }

  static List<LatLng> _geometry(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .where((point) => point.length >= 2)
        .map(
          (point) => LatLng(
            (point[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  static List<NavStep> _steps(
    Object? raw,
    List<LatLng> geometry,
    List<double> cumulative,
  ) {
    if (raw is! List || raw.isEmpty) return const [];
    final entries = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final totalMeters = cumulative.last;

    // Provider step lengths and geometry length differ by a percent or two.
    // When the backend supplied a shape index the offsets come straight from
    // the polyline; otherwise the step lengths are rescaled onto it so the two
    // measurements cannot drift apart during guidance.
    final hasShapeIndex = entries.every(
      (step) => step['beginShapeIndex'] is num,
    );
    final offsets = <double>[];
    if (hasShapeIndex) {
      for (final step in entries) {
        final index = (step['beginShapeIndex'] as num).toInt().clamp(
          0,
          geometry.length - 1,
        );
        offsets.add(cumulative[index]);
      }
    } else {
      var declared = 0.0;
      for (final step in entries) {
        declared += (step['distanceMeters'] as num?)?.toDouble() ?? 0;
      }
      final scale = declared <= 0 ? 1.0 : totalMeters / declared;
      var running = 0.0;
      for (final step in entries) {
        offsets.add(running);
        running += ((step['distanceMeters'] as num?)?.toDouble() ?? 0) * scale;
      }
    }

    // Offsets must be non-decreasing; a provider occasionally reports a shape
    // index that steps backwards across a leg boundary.
    for (var index = 1; index < offsets.length; index++) {
      if (offsets[index] < offsets[index - 1]) {
        offsets[index] = offsets[index - 1];
      }
    }

    final steps = <NavStep>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final lat = (entry['lat'] as num?)?.toDouble();
      final lng = (entry['lng'] as num?)?.toDouble();
      final endOffset = index + 1 < offsets.length
          ? offsets[index + 1]
          : totalMeters;
      steps.add(
        NavStep(
          index: index,
          maneuver: SfManeuver.parse(
            entry['maneuver']?.toString() ?? entry['maneuverType']?.toString(),
            modifier: entry['modifier']?.toString(),
          ),
          instruction: entry['instruction']?.toString() ?? 'Tiếp tục đi thẳng',
          roadName: entry['roadName']?.toString() ?? '',
          location: lat != null && lng != null
              ? LatLng(lat, lng)
              : geometry[_nearestIndex(cumulative, offsets[index])],
          startOffsetMeters: offsets[index],
          endOffsetMeters: math.max(offsets[index], endOffset),
          durationSeconds: (entry['durationSeconds'] as num?)?.toDouble() ?? 0,
          roundaboutExitCount: (entry['roundaboutExitCount'] as num?)?.toInt(),
          exitNumber: _blankToNull(entry['exitNumber']),
          toward: _blankToNull(entry['toward']),
        ),
      );
    }
    return List.unmodifiable(steps);
  }

  static String? _blankToNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _nearestIndex(List<double> cumulative, double offset) {
    for (var index = 0; index < cumulative.length; index++) {
      if (cumulative[index] >= offset) return index;
    }
    return cumulative.length - 1;
  }

  static List<NavHazardOnRoute> _resolveHazards(
    List<NavHazard> hazards,
    List<LatLng> geometry,
    List<double> cumulative,
  ) {
    if (hazards.isEmpty || geometry.length < 2) return const [];
    final resolved = <NavHazardOnRoute>[];
    for (final hazard in hazards) {
      var bestLateral = double.infinity;
      var bestOffset = 0.0;
      for (final point in hazard.geometry) {
        for (var index = 1; index < geometry.length; index++) {
          final projection = SfGeo.projectOnSegment(
            point,
            geometry[index - 1],
            geometry[index],
          );
          if (projection.lateralMeters < bestLateral) {
            bestLateral = projection.lateralMeters;
            bestOffset =
                cumulative[index - 1] +
                (cumulative[index] - cumulative[index - 1]) * projection.ratio;
          }
        }
      }
      if (bestLateral.isInfinite) continue;
      resolved.add(
        NavHazardOnRoute(
          hazard: hazard,
          offsetMeters: bestOffset,
          clearanceMeters: math.max(0, bestLateral - hazard.radiusMeters),
        ),
      );
    }
    resolved.sort((a, b) => a.offsetMeters.compareTo(b.offsetMeters));
    return List.unmodifiable(resolved);
  }
}

/// A navigation session: every alternative the backend produced, the one it
/// recommends, and the hazard set they were all scored against.
class NavSession {
  const NavSession({
    required this.sessionId,
    required this.routes,
    required this.selectedIndex,
    required this.safe,
    required this.hazards,
    this.tripId,
    this.status,
    this.destination,
    this.destinationName,
    this.origin,
  });

  final String sessionId;
  final List<NavRoute> routes;
  final int selectedIndex;
  final bool safe;
  final List<NavHazard> hazards;
  final int? tripId;
  final String? status;
  final LatLng? destination;
  final String? destinationName;
  final LatLng? origin;

  bool get isEmpty => routes.isEmpty;

  NavRoute get selected => routes[selectedIndex.clamp(0, routes.length - 1)];

  bool get providerFallback => routes.isNotEmpty && selected.providerFallback;

  NavSession selectRoute(int index) => NavSession(
    sessionId: sessionId,
    routes: routes,
    selectedIndex: index.clamp(0, routes.length - 1),
    safe: safe,
    hazards: hazards,
    tripId: tripId,
    status: status,
    destination: destination,
    destinationName: destinationName,
    origin: origin,
  );

  factory NavSession.fromJson(Map<String, dynamic> json) {
    final hazards = (json['hazards'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NavHazard.fromJson(Map<String, dynamic>.from(item)))
        .whereType<NavHazard>()
        .toList(growable: false);
    final routes = (json['routes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              NavRoute.fromJson(Map<String, dynamic>.from(item), hazards: hazards),
        )
        .whereType<NavRoute>()
        .where((route) => route.isUsable)
        .toList(growable: false);

    final destinationLat = (json['destinationLat'] as num?)?.toDouble();
    final destinationLng = (json['destinationLng'] as num?)?.toDouble();
    final originLat = (json['originLat'] as num?)?.toDouble();
    final originLng = (json['originLng'] as num?)?.toDouble();

    var selected = (json['selectedRouteIndex'] as num?)?.toInt() ?? 0;
    final recommended = routes.indexWhere((route) => route.routeIndex == selected);
    selected = recommended >= 0 ? recommended : 0;

    return NavSession(
      sessionId: json['sessionId']?.toString() ?? '',
      routes: routes,
      selectedIndex: routes.isEmpty ? 0 : selected.clamp(0, routes.length - 1),
      safe: json['safe'] != false,
      hazards: hazards,
      tripId: (json['tripId'] as num?)?.toInt(),
      status: json['status']?.toString(),
      destination: destinationLat != null && destinationLng != null
          ? LatLng(destinationLat, destinationLng)
          : null,
      destinationName: json['destinationName']?.toString(),
      origin: originLat != null && originLng != null
          ? LatLng(originLat, originLng)
          : null,
    );
  }
}
