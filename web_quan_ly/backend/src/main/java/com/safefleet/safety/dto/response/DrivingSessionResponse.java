package com.safefleet.safety.dto.response;

import com.safefleet.safety.enums.DrivingSessionStatus;

import java.time.LocalDateTime;

public record DrivingSessionResponse(
        Long id,
        Long driverId,
        Long vehicleId,
        Long tripId,
        DrivingSessionStatus status,
        LocalDateTime startedAt,
        LocalDateTime pausedAt,
        LocalDateTime resumedAt,
        LocalDateTime endedAt,
        Integer continuousMinutes,
        Integer totalMinutes,
        boolean overDrivingAlertCreated
) {
}
