package com.safefleet.mobile.dto.response;

import com.safefleet.driver.enums.DriverStatus;

public record MobileSafetySummaryResponse(
        Long driverId,
        DriverStatus status,
        Integer safetyScore,
        Integer drivingTimeTodayMinutes,
        Integer continuousDrivingMinutes,
        Integer remainingContinuousDrivingMinutes,
        Integer totalTrips,
        Integer totalAlerts
) {
}
