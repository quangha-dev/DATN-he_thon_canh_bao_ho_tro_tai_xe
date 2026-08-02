package com.safefleet.incident.dto.request;

import com.safefleet.safety.enums.AlertSeverity;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SosRequest(
        Long vehicleId,
        Long driverId,
        Long tripId,
        @NotNull Double lat,
        @NotNull Double lng,
        AlertSeverity severity,
        @Size(max = 1000) String description,
        @Size(max = 100) String clientEventId
) {
}
