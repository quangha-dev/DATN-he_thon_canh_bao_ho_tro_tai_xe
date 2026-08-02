package com.safefleet.trip.dto.request;

import jakarta.validation.constraints.NotNull;

public record AssignTripRequest(
        @NotNull Long vehicleId,
        @NotNull Long driverId
) {
}
