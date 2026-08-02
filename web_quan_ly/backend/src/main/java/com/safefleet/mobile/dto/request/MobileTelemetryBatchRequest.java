package com.safefleet.mobile.dto.request;

import com.safefleet.telemetry.dto.request.TelemetryRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public record MobileTelemetryBatchRequest(
        @NotBlank(message = "batchId là bắt buộc")
        @Size(max = 100)
        String batchId,
        @NotEmpty(message = "Batch phải có ít nhất một telemetry")
        @Size(max = 200, message = "Mỗi batch tối đa 200 telemetry")
        List<@Valid TelemetryRequest> items
) {
}
