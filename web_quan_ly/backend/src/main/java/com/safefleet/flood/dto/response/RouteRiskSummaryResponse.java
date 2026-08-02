package com.safefleet.flood.dto.response;

import com.safefleet.flood.enums.FloodSeverity;

import java.util.List;

public record RouteRiskSummaryResponse(
        boolean risky,
        FloodSeverity highestSeverity,
        int matchedFloodPoints,
        List<FloodReportResponse> matchedReports
) {
}
