package com.safefleet.safety.dto.request;

import jakarta.validation.constraints.NotNull;

public record StartDrivingSessionRequest(
        @NotNull Long driverId,
        Long vehicleId,
        Long tripId
) {
}
