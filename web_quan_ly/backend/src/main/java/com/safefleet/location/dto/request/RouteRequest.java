package com.safefleet.location.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

public record RouteRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double startLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double startLng,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double endLat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double endLng
) {
}
