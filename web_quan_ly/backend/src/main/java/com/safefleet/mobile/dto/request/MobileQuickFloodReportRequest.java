package com.safefleet.mobile.dto.request;

import com.safefleet.flood.enums.FloodSeverity;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record MobileQuickFloodReportRequest(
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        @Size(max = 255) String address,
        @NotNull FloodSeverity severity,
        @Size(max = 500) String imageUrl,
        @Size(max = 100) String clientEventId
) {
}
