package com.safefleet.report.dto.response;

import java.util.Map;

public record DashboardSummaryResponse(
        long totalVehicles,
        Map<String, Long> vehiclesByStatus,
        long totalDrivers,
        Map<String, Long> driversByStatus,
        long totalTrips,
        Map<String, Long> tripsByStatus,
        long openSafetyEvents,
        long openIncidents
) {
}
