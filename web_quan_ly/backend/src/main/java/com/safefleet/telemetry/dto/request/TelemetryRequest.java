package com.safefleet.telemetry.dto.request;

import com.safefleet.telemetry.enums.GpsStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record TelemetryRequest(
        @NotNull Long vehicleId,
        Long driverId,
        Long tripId,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        @DecimalMin("0.0") @DecimalMax("250.0") Double speed,
        @DecimalMin("0.0") @DecimalMax("360.0") Double heading,
        @DecimalMin("0") @DecimalMax("100") Integer batteryLevel,
        @DecimalMin("0.0") @DecimalMax("10000.0") Double gpsAccuracyMeters,
        GpsStatus gpsStatus,
        LocalDateTime createdAt,
        @Size(max = 100) String clientEventId
) {
}
