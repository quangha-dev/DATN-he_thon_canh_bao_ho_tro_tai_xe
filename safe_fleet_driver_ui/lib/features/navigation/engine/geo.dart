import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Planar geodesy on a local tangent plane.
///
/// Navigation only ever measures distances between points a few hundred metres
/// apart, where an equirectangular projection anchored at the local latitude is
/// accurate to well under a metre and roughly an order of magnitude cheaper
/// than haversine. That matters here: the matcher evaluates many segments per
/// GPS fix, several times a second, on a phone that is also running the
/// drowsiness model.
abstract final class SfGeo {
  static const metersPerLatitudeDegree = 111320.0;

  /// Metres per degree of longitude at [latitude]. Clamped away from zero so a
  /// nonsensical latitude cannot produce an infinite scale.
  static double metersPerLongitudeDegree(double latitude) =>
      metersPerLatitudeDegree *
      math.cos(latitude * math.pi / 180).abs().clamp(0.2, 1.0);

  static double distance(LatLng a, LatLng b) {
    final scale = metersPerLongitudeDegree((a.latitude + b.latitude) / 2);
    final dx = (b.longitude - a.longitude) * scale;
    final dy = (b.latitude - a.latitude) * metersPerLatitudeDegree;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Compass bearing from [a] to [b] in degrees, 0 = north, clockwise.
  static double bearing(LatLng a, LatLng b) {
    final scale = metersPerLongitudeDegree((a.latitude + b.latitude) / 2);
    final dx = (b.longitude - a.longitude) * scale;
    final dy = (b.latitude - a.latitude) * metersPerLatitudeDegree;
    if (dx == 0 && dy == 0) return 0;
    final degrees = math.atan2(dx, dy) * 180 / math.pi;
    return (degrees + 360) % 360;
  }

  /// Smallest absolute angle between two bearings, in degrees (0..180).
  static double bearingDelta(double first, double second) {
    final delta = ((first - second) % 360 + 540) % 360 - 180;
    return delta.abs();
  }

  /// Projects [point] onto the segment [start]-[end].
  static SegmentProjection projectOnSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    final scale = metersPerLongitudeDegree(point.latitude);
    final segmentX = (end.longitude - start.longitude) * scale;
    final segmentY = (end.latitude - start.latitude) * metersPerLatitudeDegree;
    final pointX = (point.longitude - start.longitude) * scale;
    final pointY = (point.latitude - start.latitude) * metersPerLatitudeDegree;
    final squaredLength = segmentX * segmentX + segmentY * segmentY;
    if (squaredLength == 0) {
      return SegmentProjection(
        ratio: 0,
        lateralMeters: math.sqrt(pointX * pointX + pointY * pointY),
        snapped: start,
      );
    }
    final ratio = ((pointX * segmentX + pointY * segmentY) / squaredLength)
        .clamp(0.0, 1.0);
    final deltaX = pointX - segmentX * ratio;
    final deltaY = pointY - segmentY * ratio;
    return SegmentProjection(
      ratio: ratio,
      lateralMeters: math.sqrt(deltaX * deltaX + deltaY * deltaY),
      snapped: LatLng(
        start.latitude + (end.latitude - start.latitude) * ratio,
        start.longitude + (end.longitude - start.longitude) * ratio,
      ),
    );
  }

  /// Shortest distance from [point] to a polyline. Returns
  /// [double.infinity] for a polyline that has no segment.
  static double distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.length < 2) {
      return polyline.isEmpty ? double.infinity : distance(point, polyline.first);
    }
    var best = double.infinity;
    for (var index = 1; index < polyline.length; index++) {
      final projection = projectOnSegment(
        point,
        polyline[index - 1],
        polyline[index],
      );
      if (projection.lateralMeters < best) best = projection.lateralMeters;
    }
    return best;
  }

  /// Ray-casting point-in-polygon test on the raw degree coordinates. The
  /// latitude scale cancels out for a containment test, so no projection is
  /// needed.
  static bool pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (
      var current = 0, previous = polygon.length - 1;
      current < polygon.length;
      previous = current++
    ) {
      final first = polygon[current];
      final second = polygon[previous];
      final crosses =
          (first.latitude > point.latitude) !=
              (second.latitude > point.latitude) &&
          point.longitude <
              (second.longitude - first.longitude) *
                      (point.latitude - first.latitude) /
                      (second.latitude - first.latitude + 1e-12) +
                  first.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

class SegmentProjection {
  const SegmentProjection({
    required this.ratio,
    required this.lateralMeters,
    required this.snapped,
  });

  /// Where the projection landed on the segment, 0 at the start, 1 at the end.
  final double ratio;
  final double lateralMeters;
  final LatLng snapped;
}
