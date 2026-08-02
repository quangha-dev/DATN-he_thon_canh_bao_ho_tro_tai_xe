package com.safefleet.navigation;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record NavigationEventRequest(
        @NotBlank String sessionId,
        @NotBlank @Size(max = 40) String eventType,
        @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        Double distanceToRouteMeters,
        Double gpsAccuracyMeters,
        LocalDateTime occurredAt,
        @Size(max = 1000) String metadata
) {
}
