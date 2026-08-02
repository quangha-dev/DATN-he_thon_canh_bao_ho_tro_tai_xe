package com.safefleet.dispatch.dto.response;

import java.util.List;

public record DispatchSuggestionResponse(
        Long vehicleId,
        String plateNumber,
        Long driverId,
        String driverName,
        double score,
        Double distanceKm,
        List<String> reasons
) {
}
