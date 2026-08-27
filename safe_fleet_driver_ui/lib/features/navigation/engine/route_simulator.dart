import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';
import 'nav_route.dart';
import 'navigation_engine.dart';

/// Generates GPS traces along (and away from) a route.
///
/// Navigation is the one part of the app that cannot be validated by looking at
/// a screenshot: it only misbehaves once a vehicle is moving through it. Being
/// able to replay a whole drive deterministically is what makes step
/// advancement, voice tiering, off-route confirmation and hazard warnings
/// testable — and the same generator backs the on-device demo mode used to
/// rehearse a route without leaving the depot.
abstract final class RouteSimulator {
  /// Position at [offsetMeters] along the route.
  static LatLng pointAt(NavRoute route, double offsetMeters) {
    final geometry = route.geometry;
    final cumulative = route.cumulativeMeters;
    if (geometry.isEmpty) return const LatLng(0, 0);
    if (geometry.length == 1 || offsetMeters <= 0) return geometry.first;
    if (offsetMeters >= cumulative.last) return geometry.last;

    var low = 0;
    var high = cumulative.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (cumulative[middle] <= offsetMeters) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    final segment = cumulative[low + 1] - cumulative[low];
    final ratio = segment <= 0 ? 0.0 : (offsetMeters - cumulative[low]) / segment;
    final start = geometry[low];
    final end = geometry[low + 1];
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * ratio,
      start.longitude + (end.longitude - start.longitude) * ratio,
    );
  }

  static double bearingAt(NavRoute route, double offsetMeters) {
    final ahead = pointAt(route, offsetMeters + 5);
    final behind = pointAt(route, math.max(0, offsetMeters - 5));
    return SfGeo.bearing(behind, ahead);
  }

  /// A trace that follows the route from [fromOffset] to [toOffset].
  ///
  /// [lateralNoiseMeters] offsets each fix perpendicular to the road, which is
  /// what a real receiver does; guidance has to stay stable through it.
  static List<NavFix> drive(
    NavRoute route, {
    double speedMps = 11,
    double stepSeconds = 1,
    double fromOffset = 0,
    double? toOffset,
    double lateralNoiseMeters = 0,
    double accuracyMeters = 8,
    DateTime? startAt,
    int seed = 7,
  }) {
    final end = math.min(toOffset ?? route.lengthMeters, route.lengthMeters);
    final random = math.Random(seed);
    final start = startAt ?? DateTime(2026, 1, 1, 8);
    final fixes = <NavFix>[];
    var offset = fromOffset;
    var elapsed = 0.0;

    while (offset <= end) {
      final position = pointAt(route, offset);
      final course = bearingAt(route, offset);
      fixes.add(
        NavFix(
          position: lateralNoiseMeters <= 0
              ? position
              : _offsetPerpendicular(
                  position,
                  course,
                  (random.nextDouble() * 2 - 1) * lateralNoiseMeters,
                ),
          timestamp: start.add(Duration(milliseconds: (elapsed * 1000).round())),
          accuracyMeters: accuracyMeters,
          headingDeg: course,
          speedMps: speedMps,
        ),
      );
      offset += speedMps * stepSeconds;
      elapsed += stepSeconds;
      if (speedMps <= 0) break;
    }
    return fixes;
  }

  /// A trace that leaves the route at [fromOffset] and keeps going for
  /// [distanceMeters] on a bearing [bearingOffsetDeg] away from it — a driver
  /// who missed the turn.
  static List<NavFix> divert(
    NavRoute route, {
    required double fromOffset,
    required double distanceMeters,
    double speedMps = 11,
    double stepSeconds = 1,
    double bearingOffsetDeg = 90,
    double accuracyMeters = 8,
    DateTime? startAt,
  }) {
    final origin = pointAt(route, fromOffset);
    final course = (bearingAt(route, fromOffset) + bearingOffsetDeg) % 360;
    final start = startAt ?? DateTime(2026, 1, 1, 8);
    final fixes = <NavFix>[];
    var travelled = 0.0;
    var elapsed = 0.0;

    while (travelled <= distanceMeters) {
      fixes.add(
        NavFix(
          position: _translate(origin, course, travelled),
          timestamp: start.add(Duration(milliseconds: (elapsed * 1000).round())),
          accuracyMeters: accuracyMeters,
          headingDeg: course,
          speedMps: speedMps,
        ),
      );
      travelled += speedMps * stepSeconds;
      elapsed += stepSeconds;
      if (speedMps <= 0) break;
    }
    return fixes;
  }

  static LatLng _translate(LatLng from, double bearingDeg, double meters) {
    final radians = bearingDeg * math.pi / 180;
    final dLat = math.cos(radians) * meters / SfGeo.metersPerLatitudeDegree;
    final dLng =
        math.sin(radians) * meters / SfGeo.metersPerLongitudeDegree(from.latitude);
    return LatLng(from.latitude + dLat, from.longitude + dLng);
  }

  static LatLng _offsetPerpendicular(
    LatLng point,
    double courseDeg,
    double meters,
  ) => _translate(point, (courseDeg + 90) % 360, meters);
}
