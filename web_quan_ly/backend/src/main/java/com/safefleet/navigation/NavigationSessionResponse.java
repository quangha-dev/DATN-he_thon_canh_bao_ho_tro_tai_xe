package com.safefleet.navigation;

import java.time.LocalDateTime;
import java.util.List;

public record NavigationSessionResponse(
        String sessionId,
        Long tripId,
        Long vehicleId,
        String status,
        Double originLat,
        Double originLng,
        Double destinationLat,
        Double destinationLng,
        String destinationName,
        Boolean safe,
        Integer selectedRouteIndex,
        List<NavigationRouteCandidateResponse> routes,
        LocalDateTime startedAt,
        LocalDateTime updatedAt
) {
}
