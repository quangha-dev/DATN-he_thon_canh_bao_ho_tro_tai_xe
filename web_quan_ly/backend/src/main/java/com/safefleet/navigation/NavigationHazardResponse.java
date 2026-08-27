package com.safefleet.navigation;

import java.time.LocalDateTime;
import java.util.List;

/**
 * A hazard exactly as it was known when the route was scored.
 *
 * <p>Frozen onto the session so the device keeps warning about the same set of
 * closures after it loses connectivity, and so a reroute decision can be
 * replayed later against the inputs that actually produced it.</p>
 *
 * @param geometry ring or polyline in {@code [lng, lat]} order, matching the
 *                 order used by the route geometry the app already draws
 */
public record NavigationHazardResponse(
        Long id,
        String hazardType,
        String severity,
        String status,
        String geometryType,
        Double lat,
        Double lng,
        Double radiusMeters,
        List<List<Double>> geometry,
        Boolean hardClosure,
        String address,
        LocalDateTime expiredAt
) {
}
