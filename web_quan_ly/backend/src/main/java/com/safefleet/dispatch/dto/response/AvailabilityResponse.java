package com.safefleet.dispatch.dto.response;

import java.util.List;

public record AvailabilityResponse(
        Long vehicleId,
        boolean vehicleAvailable,
        Long driverId,
        boolean driverAvailable,
        boolean assignable,
        List<String> reasons
) {
}
