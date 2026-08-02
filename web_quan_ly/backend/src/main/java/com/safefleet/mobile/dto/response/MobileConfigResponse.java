package com.safefleet.mobile.dto.response;

public record MobileConfigResponse(
        Integer maxContinuousDrivingMinutes,
        Integer warningLevel1Minutes,
        Integer warningLevel2Minutes,
        Integer criticalWarningMinutes,
        Integer phoneUsageSpeedThresholdKmh,
        Integer phoneUsageDurationThresholdSeconds,
        Integer floodReportExpirationMinutes
) {
}
