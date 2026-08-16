package com.safefleet.flood.dto.response;

public record FloodWarningResponse(
        Long floodReportId,
        int recipientCount,
        double radiusKm
) {
}
