package com.safefleet.trip.dto.response;

import com.safefleet.trip.enums.RiskLevel;
import com.safefleet.trip.enums.TripStatus;

import java.time.LocalDateTime;

public record TripResponse(
        Long id,
        String tripCode,
        Long vehicleId,
        String vehiclePlateNumber,
        Long driverId,
        String driverName,
        String startLocation,
        Double startLat,
        Double startLng,
        String endLocation,
        Double endLat,
        Double endLng,
        String waypoints,
        String plannedRoute,
        String actualRoute,
        LocalDateTime plannedStartTime,
        LocalDateTime actualStartTime,
        LocalDateTime estimatedEndTime,
        LocalDateTime actualEndTime,
        TripStatus status,
        Integer progress,
        RiskLevel riskLevel
) {
}
