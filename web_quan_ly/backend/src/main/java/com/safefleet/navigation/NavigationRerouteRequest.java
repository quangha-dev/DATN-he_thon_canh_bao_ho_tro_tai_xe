package com.safefleet.navigation;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record NavigationRerouteRequest(
        @NotBlank String sessionId,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double currentLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double currentLng,
        Double gpsAccuracyMeters,
        String reason
) {
}
