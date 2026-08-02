package com.safefleet.mobile.dto.response;

import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.notification.dto.response.NotificationResponse;
import com.safefleet.trip.dto.response.TripResponse;

import java.time.LocalDateTime;
import java.util.List;

public record MobileBootstrapResponse(
        MobileProfileResponse profile,
        MobileSafetySummaryResponse safety,
        MobileConfigResponse config,
        MobileCurrentAssignmentResponse currentAssignment,
        List<TripResponse> todayTrips,
        List<FloodReportResponse> activeFloodPoints,
        List<NotificationResponse> notifications,
        LocalDateTime serverTime
) {
}
