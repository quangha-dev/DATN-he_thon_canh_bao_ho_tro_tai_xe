package com.safefleet.telemetry.dto.response;

import com.safefleet.telemetry.enums.GpsStatus;

import java.time.LocalDateTime;

public record TelemetryResponse(
        Long id,
        Long vehicleId,
        String vehiclePlateNumber,
        Long driverId,
        Long tripId,
        Double lat,
        Double lng,
        Double speed,
        Double heading,
        Integer batteryLevel,
        GpsStatus gpsStatus,
        LocalDateTime createdAt,
        String clientEventId,
        LocalDateTime recordedAt,
        LocalDateTime receivedAt
) {
}
