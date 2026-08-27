import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';
import 'nav_route.dart';

class RouteMatch {
  const RouteMatch({
    required this.segmentIndex,
    required this.offsetMeters,
    required this.lateralMeters,
    required this.snapped,
    required this.courseDeg,
    required this.confident,
  });

  /// Index of the first vertex of the matched segment.
  final int segmentIndex;

  /// Distance travelled along the route to the matched point.
  final double offsetMeters;

  /// Perpendicular distance from the raw fix to the route.
  final double lateralMeters;
  final LatLng snapped;

  /// Bearing of the matched segment — what the vehicle is following, which is
  /// steadier than a raw GPS heading at low speed.
  final double courseDeg;

  /// True when the vehicle is close enough to the route for the snapped
  /// position to be meaningful, or when a relocation has just re-established
  /// where it is. False means the fix is genuinely far from the route.
  final bool confident;
}

/// Snaps GPS fixes onto a route.
///
/// A naive "nearest point on the whole polyline" search breaks on any route
/// that comes back near itself — a loop, an out-and-back leg, two parallel
/// carriageways — by teleporting progress to the wrong pass. Matching inside a
/// window around the last known position keeps progress monotonic, and makes
/// each fix cost a few dozen segment tests instead of the whole polyline.
class RouteMatcher {
  RouteMatcher(this.route);

  final NavRoute route;

  double? _lastOffset;
  DateTime? _lastFixAt;

  double? get lastOffsetMeters => _lastOffset;

  void reset({double? offsetMeters}) {
    _lastOffset = offsetMeters;
    _lastFixAt = null;
  }

  RouteMatch match(
    LatLng point, {
    double? headingDeg,
    double speedMps = 0,
    double accuracyMeters = 0,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final elapsed = _lastFixAt == null
        ? 0.0
        : now.difference(_lastFixAt!).inMilliseconds / 1000.0;
    _lastFixAt = now;

    final anchor = _lastOffset;
    _MatchCandidate? windowed;

    if (anchor != null) {
      // Allow for the ground actually covered since the previous fix, plus
      // slack for a fix that arrived late or a stretch spent in a tunnel.
      final forward = (math.max(speedMps, 8) * math.max(elapsed, 8) * 1.5 + 250)
          .clamp(250.0, 5000.0);
      windowed = _search(
        point,
        headingDeg: headingDeg,
        speedMps: speedMps,
        fromMeters: anchor - 120,
        toMeters: anchor + forward,
      );
    }

    final acceptable = math.max(70.0, accuracyMeters * 2 + 30);
    var best = windowed;
    var relocated = false;
    var lateral = windowed?.lateralMeters ?? double.infinity;

    if (windowed == null || windowed.lateralMeters > acceptable) {
      final global = _search(
        point,
        headingDeg: headingDeg,
        speedMps: speedMps,
        fromMeters: 0,
        toMeters: double.infinity,
      );
      if (global != null) {
        // The true distance to the route is the global minimum - that is what
        // decides "off route". Progress, on the other hand, must stay in the
        // window, or a route that passes near itself would teleport the driver
        // forwards. Only a decisively better match earns a relocation, which is
        // what recovers after a background kill or a restart mid-route.
        lateral = math.min(lateral, global.lateralMeters);
        if (windowed == null || global.lateralMeters < windowed.lateralMeters - 50) {
          best = global;
          relocated = true;
        }
      }
    }

    best ??= _MatchCandidate(
      segmentIndex: 0,
      offsetMeters: 0,
      lateralMeters: route.geometry.isEmpty
          ? double.infinity
          : SfGeo.distance(point, route.geometry.first),
      snapped: route.geometry.isEmpty ? point : route.geometry.first,
      courseDeg: 0,
      cost: double.infinity,
    );
    if (lateral.isInfinite) lateral = best.lateralMeters;

    _lastOffset = best.offsetMeters;
    return RouteMatch(
      segmentIndex: best.segmentIndex,
      offsetMeters: best.offsetMeters,
      lateralMeters: lateral,
      snapped: best.snapped,
      courseDeg: best.courseDeg,
      confident: relocated || lateral <= acceptable,
    );
  }

  _MatchCandidate? _search(
    LatLng point, {
    required double? headingDeg,
    required double speedMps,
    required double fromMeters,
    required double toMeters,
  }) {
    final geometry = route.geometry;
    final cumulative = route.cumulativeMeters;
    if (geometry.length < 2) return null;

    final first = math.max(0, _segmentAt(cumulative, fromMeters));
    _MatchCandidate? best;

    for (var index = first + 1; index < geometry.length; index++) {
      if (cumulative[index - 1] > toMeters) break;
      final projection = SfGeo.projectOnSegment(
        point,
        geometry[index - 1],
        geometry[index],
      );
      final course = SfGeo.bearing(geometry[index - 1], geometry[index]);
      // GPS heading is noise below walking pace, so it only gets a vote once
      // the vehicle is clearly moving. Where it is usable it separates the two
      // directions of the same street, which lateral distance alone cannot.
      final headingPenalty =
          headingDeg != null && headingDeg >= 0 && speedMps >= 2.5
          ? SfGeo.bearingDelta(headingDeg, course) / 180.0 * 30.0
          : 0.0;
      final cost = projection.lateralMeters + headingPenalty;
      if (best == null || cost < best.cost) {
        best = _MatchCandidate(
          segmentIndex: index - 1,
          offsetMeters:
              cumulative[index - 1] +
              (cumulative[index] - cumulative[index - 1]) * projection.ratio,
          lateralMeters: projection.lateralMeters,
          snapped: projection.snapped,
          courseDeg: course,
          cost: cost,
        );
      }
    }
    return best;
  }

  /// Index of the last vertex at or before [meters], by binary search.
  static int _segmentAt(List<double> cumulative, double meters) {
    if (meters <= 0) return 0;
    var low = 0;
    var high = cumulative.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (cumulative[middle] <= meters) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }
}

class _MatchCandidate {
  const _MatchCandidate({
    required this.segmentIndex,
    required this.offsetMeters,
    required this.lateralMeters,
    required this.snapped,
    required this.courseDeg,
    required this.cost,
  });

  final int segmentIndex;
  final double offsetMeters;
  final double lateralMeters;
  final LatLng snapped;
  final double courseDeg;
  final double cost;
}
