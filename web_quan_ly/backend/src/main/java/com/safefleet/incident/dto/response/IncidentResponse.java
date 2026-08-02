package com.safefleet.incident.dto.response;

import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.enums.IncidentType;
import com.safefleet.safety.enums.AlertSeverity;

import java.time.LocalDateTime;

public record IncidentResponse(
        Long id,
        String incidentCode,
        IncidentType type,
        AlertSeverity severity,
        Long vehicleId,
        String vehiclePlateNumber,
        Long driverId,
        String driverName,
        Long tripId,
        Double lat,
        Double lng,
        String description,
        IncidentStatus status,
        Long assignedTo,
        String assignedToName,
        LocalDateTime createdAt,
        LocalDateTime acceptedAt,
        LocalDateTime resolvedAt
) {
}
