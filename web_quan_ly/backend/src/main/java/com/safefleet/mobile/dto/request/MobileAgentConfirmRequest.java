package com.safefleet.mobile.dto.request;

import com.safefleet.flood.enums.FloodSeverity;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

public record MobileAgentConfirmRequest(
        @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
        FloodSeverity floodSeverity,
        @Size(max = 255) String address,
        @Size(max = 1000) String description
) {
}
