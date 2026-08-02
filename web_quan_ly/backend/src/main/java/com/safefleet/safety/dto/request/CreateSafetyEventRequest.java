package com.safefleet.safety.dto.request;

import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventType;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record CreateSafetyEventRequest(
        @NotNull SafetyEventType eventType,
        @NotNull AlertSeverity severity,
        Long vehicleId,
        Long driverId,
        Long tripId,
        @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        Double speed,
        @DecimalMin("0.0") @DecimalMax("1.0") Double confidence,
        @Size(max = 500) String evidenceUrl,
        LocalDateTime createdAt,
        @Size(max = 500) String note,
        @Size(max = 100) String clientEventId
) {
}
