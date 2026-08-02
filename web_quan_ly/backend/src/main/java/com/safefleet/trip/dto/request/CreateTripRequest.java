package com.safefleet.trip.dto.request;

import com.safefleet.trip.enums.RiskLevel;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record CreateTripRequest(
        Long vehicleId,
        Long driverId,
        @NotBlank @Size(max = 255) String startLocation,
        Double startLat,
        Double startLng,
        @NotBlank @Size(max = 255) String endLocation,
        Double endLat,
        Double endLng,
        String waypoints,
        String plannedRoute,
        @NotNull LocalDateTime plannedStartTime,
        @NotNull LocalDateTime estimatedEndTime,
        RiskLevel riskLevel
) {
}
