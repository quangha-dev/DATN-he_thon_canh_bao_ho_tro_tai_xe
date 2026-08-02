package com.safefleet.navigation;

public record NavigationStepResponse(
        String instruction,
        String roadName,
        Double distanceMeters,
        Double durationSeconds,
        String maneuverType,
        String modifier,
        Double lat,
        Double lng
) {
}
