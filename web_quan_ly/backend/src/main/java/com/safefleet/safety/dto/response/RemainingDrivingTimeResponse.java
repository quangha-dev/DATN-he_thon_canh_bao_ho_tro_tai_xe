package com.safefleet.safety.dto.response;

import com.safefleet.safety.enums.DrivingSessionStatus;

public record RemainingDrivingTimeResponse(
        Long driverId,
        Long sessionId,
        DrivingSessionStatus status,
        int maxContinuousMinutes,
        int continuousDrivingMinutes,
        int remainingMinutes,
        String warningLevel
) {
}
