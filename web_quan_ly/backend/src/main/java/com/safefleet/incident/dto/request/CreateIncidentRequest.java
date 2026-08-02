package com.safefleet.incident.dto.request;

import com.safefleet.incident.enums.IncidentType;
import com.safefleet.safety.enums.AlertSeverity;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateIncidentRequest(
        @NotNull IncidentType type,
        @NotNull AlertSeverity severity,
        Long vehicleId,
        Long driverId,
        Long tripId,
        Double lat,
        Double lng,
        @Size(max = 1000) String description
) {
}
