package com.safefleet.location.dto.response;

import java.util.List;

public record RouteResponse(
        Double distanceKm,
        Long durationMinutes,
        List<List<Double>> coordinates,
        String provider,
        Boolean fallback,
        String message
) {
}
