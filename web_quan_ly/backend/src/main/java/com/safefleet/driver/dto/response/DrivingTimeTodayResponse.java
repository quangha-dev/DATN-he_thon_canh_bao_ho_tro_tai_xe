package com.safefleet.driver.dto.response;

public record DrivingTimeTodayResponse(
        Long driverId,
        Integer drivingTimeTodayMinutes,
        Integer continuousDrivingMinutes,
        Integer remainingContinuousDrivingMinutes
) {
}
