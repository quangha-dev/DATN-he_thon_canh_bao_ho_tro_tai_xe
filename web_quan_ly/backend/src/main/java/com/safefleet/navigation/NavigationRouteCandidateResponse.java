package com.safefleet.navigation;

import java.util.List;

public record NavigationRouteCandidateResponse(
        Long id,
        Integer routeIndex,
        String label,
        Integer distanceMeters,
        Integer durationSeconds,
        Double totalScore,
        Double floodPenalty,
        Double vehicleRestrictionPenalty,
        Double driverTimePenalty,
        Integer floodIntersectionCount,
        Boolean safe,
        Boolean blocked,
        Boolean recommended,
        String provider,
        Boolean fallback,
        List<List<Double>> navigationWaypoints,
        List<List<Double>> geometry,
        List<NavigationStepResponse> steps,
        List<String> warnings
) {
}
