package com.safefleet.mobile.dto.response;

import java.util.List;

public record MobileTelemetryBatchResponse(
        String batchId,
        int acceptedCount,
        int duplicateCount,
        int rejectedCount,
        List<MobileTelemetryBatchItemResponse> items
) {
}
