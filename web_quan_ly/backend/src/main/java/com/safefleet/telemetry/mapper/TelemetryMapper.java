package com.safefleet.telemetry.mapper;

import com.safefleet.telemetry.dto.response.TelemetryResponse;
import com.safefleet.telemetry.entity.TelemetryLog;

public final class TelemetryMapper {

    private TelemetryMapper() {
    }

    public static TelemetryResponse toResponse(TelemetryLog log) {
        return new TelemetryResponse(
                log.getId(),
                log.getVehicle().getId(),
                log.getVehicle().getPlateNumber(),
                log.getDriver() == null ? null : log.getDriver().getId(),
                log.getTrip() == null ? null : log.getTrip().getId(),
                log.getLat(),
                log.getLng(),
                log.getSpeed(),
                log.getHeading(),
                log.getBatteryLevel(),
                log.getGpsStatus(),
                log.getCreatedAt(),
                log.getClientEventId(),
                log.getRecordedAt(),
                log.getReceivedAt()
        );
    }
}
