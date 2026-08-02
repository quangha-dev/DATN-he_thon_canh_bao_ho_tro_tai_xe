package com.safefleet.navigation;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record NavigationRouteRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double originLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double originLng,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double destinationLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double destinationLng,
        @Size(max = 255) String destinationName,
        Long tripId
) {
}
