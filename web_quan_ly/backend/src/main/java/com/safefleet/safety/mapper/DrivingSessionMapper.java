package com.safefleet.safety.mapper;

import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.safety.entity.DrivingSession;

public final class DrivingSessionMapper {

    private DrivingSessionMapper() {
    }

    public static DrivingSessionResponse toResponse(DrivingSession session) {
        return new DrivingSessionResponse(
                session.getId(),
                session.getDriver().getId(),
                session.getVehicle() == null ? null : session.getVehicle().getId(),
                session.getTrip() == null ? null : session.getTrip().getId(),
                session.getStatus(),
                session.getStartedAt(),
                session.getPausedAt(),
                session.getResumedAt(),
                session.getEndedAt(),
                session.getContinuousMinutes(),
                session.getTotalMinutes(),
                session.isOverDrivingAlertCreated()
        );
    }
}
