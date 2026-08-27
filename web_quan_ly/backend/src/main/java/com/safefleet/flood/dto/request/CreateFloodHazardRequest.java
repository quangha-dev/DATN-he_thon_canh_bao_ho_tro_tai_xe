package com.safefleet.flood.dto.request;

import com.safefleet.flood.enums.FloodGeometryType;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.RoadHazardType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateFloodHazardRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        @Size(max = 255) String address,
        RoadHazardType hazardType,
        @NotNull FloodSeverity severity,
        @NotNull FloodSource source,
        Long reportedByDriverId,
        @Size(max = 500) String imageUrl,
        @Size(max = 100) String clientEventId,
        @NotNull FloodGeometryType geometryType,
        @Size(max = 100) List<@Valid FloodGeometryPoint> geometry,
        @DecimalMin("20") @DecimalMax("2000") Double radiusMeters
) {
}
