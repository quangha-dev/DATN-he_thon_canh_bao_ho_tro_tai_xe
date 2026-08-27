import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/config/app_config.dart';
import 'engine/nav_route.dart';

typedef OfflineMapProgress = void Function(double progress);

/// Downloads the basemap tiles covering a route so guidance still has a map
/// once the vehicle leaves coverage.
///
/// The route geometry, its steps and the hazard snapshot are already cached in
/// SQLite, so a failed tile download degrades the screen to a dark background
/// with a route line on it — it never stops guidance.
abstract final class RouteOfflineMapCache {
  static Future<bool> ensure(
    NavSession session, {
    OfflineMapProgress? onProgress,
  }) async {
    if (session.isEmpty) return false;
    try {
      final existing = await getListOfRegions();
      for (final region in existing) {
        if (region.metadata['safeFleetSessionId'] == session.sessionId) {
          final status = await getOfflineRegionStatus(region.id);
          onProgress?.call(status.downloadProgress.clamp(0, 1));
          if (status.isComplete) return true;
          await resumeOfflineRegionDownload(region.id);
          return false;
        }
      }

      final geometry = session.selected.geometry;
      if (geometry.length < 2) return false;
      final distanceMeters = session.selected.lengthMeters;
      final maxZoom = distanceMeters <= 50_000
          ? 16.0
          : distanceMeters <= 200_000
          ? 14.0
          : 12.0;
      await downloadOfflineRegion(
        OfflineRegionDefinition(
          bounds: _bounds(geometry),
          mapStyleUrl: AppConfig.mapStyleUrlDark,
          minZoom: 8,
          maxZoom: maxZoom,
          includeIdeographs: false,
        ),
        metadata: {
          'safeFleetSessionId': session.sessionId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        onEvent: (event) {
          if (event is InProgress) onProgress?.call(event.progress.clamp(0, 1));
          if (event is Success) onProgress?.call(1);
        },
      );
      await _retainNewestRegions(3);
      return true;
    } catch (_) {
      return false;
    }
  }

  static LatLngBounds _bounds(List<LatLng> geometry) {
    var minLat = geometry.first.latitude;
    var maxLat = geometry.first.latitude;
    var minLng = geometry.first.longitude;
    var maxLng = geometry.first.longitude;
    for (final point in geometry.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    const padding = 0.008;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  static Future<void> _retainNewestRegions(int keep) async {
    final regions =
        (await getListOfRegions())
            .where((region) => region.metadata['safeFleetSessionId'] != null)
            .toList()
          ..sort(
            (left, right) => (right.metadata['createdAt']?.toString() ?? '')
                .compareTo(left.metadata['createdAt']?.toString() ?? ''),
          );
    for (final region in regions.skip(keep)) {
      await deleteOfflineRegion(region.id);
    }
  }
}
