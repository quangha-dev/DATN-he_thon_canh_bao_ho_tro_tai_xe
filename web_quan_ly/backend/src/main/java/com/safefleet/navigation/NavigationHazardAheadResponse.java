package com.safefleet.navigation;

/**
 * The nearest hazard sitting on the part of the route the driver has not
 * travelled yet.
 *
 * <p>{@code distanceAlongRouteMeters} is measured forward along the selected
 * geometry rather than as a straight line, so the app can speak a distance the
 * driver will actually cover before reaching it.</p>
 */
public record NavigationHazardAheadResponse(
        Long hazardId,
        String hazardType,
        String severity,
        Double distanceAlongRouteMeters,
        Boolean blocking,
        String address
) {
}
