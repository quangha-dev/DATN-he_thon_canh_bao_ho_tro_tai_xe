package com.safefleet.safety.dto.response;

import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.enums.SafetyEventType;

import java.time.LocalDateTime;

public record SafetyEventResponse(
        Long id,
        String clientEventId,
        SafetyEventType eventType,
        AlertSeverity severity,
        Long vehicleId,
        String vehiclePlateNumber,
        Long driverId,
        String driverName,
        Long tripId,
        Double lat,
        Double lng,
        Double speed,
        Double confidence,
        String evidenceUrl,
        SafetyEventStatus status,
        Long handledBy,
        String handledByName,
        LocalDateTime handledAt,
        String note,
        LocalDateTime createdAt,
        LocalDateTime receivedAt
) {
}
