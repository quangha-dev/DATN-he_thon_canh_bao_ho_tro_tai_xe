package com.safefleet.mobile.dto.response;

public record MobileTelemetryBatchItemResponse(
        String clientEventId,
        String status,
        Long telemetryId,
        String message
) {
}
