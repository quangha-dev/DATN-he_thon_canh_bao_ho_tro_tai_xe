package com.safefleet.navigation.provider;

import java.util.List;

public interface RoutingProvider {

    List<ProviderRoute> routes(List<GeoPoint> points, boolean alternatives);

    record GeoPoint(double lat, double lng) {
    }

    record TurnStep(
            String instruction,
            String roadName,
            double distanceMeters,
            double durationSeconds,
            String maneuverType,
            String modifier,
            GeoPoint location
    ) {
    }

    record ProviderRoute(
            double distanceMeters,
            double durationSeconds,
            List<GeoPoint> geometry,
            List<TurnStep> steps,
            String provider,
            boolean fallback
    ) {
    }
}
