package com.safefleet.flood.dto.request;

import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateFloodReportRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        @Size(max = 255) String address,
        @NotNull FloodSeverity severity,
        @NotNull FloodSource source,
        Long reportedByDriverId,
        @Size(max = 500) String imageUrl,
        @Size(max = 100) String clientEventId
) {
}
