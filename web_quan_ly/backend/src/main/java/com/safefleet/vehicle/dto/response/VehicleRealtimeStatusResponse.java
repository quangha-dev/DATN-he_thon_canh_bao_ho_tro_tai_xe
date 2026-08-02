package com.safefleet.vehicle.dto.response;

import com.safefleet.vehicle.enums.VehicleStatus;

import java.time.LocalDateTime;

public record VehicleRealtimeStatusResponse(
        Long vehicleId,
        String plateNumber,
        VehicleStatus status,
        Double lat,
        Double lng,
        Double speed,
        LocalDateTime lastUpdatedAt,
        boolean gpsOnline
) {
}
