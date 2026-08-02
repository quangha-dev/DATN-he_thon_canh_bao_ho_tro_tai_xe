package com.safefleet.mobile.dto.response;

import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.trip.dto.response.TripResponse;

public record MobileWorkflowResponse(
        String action,
        TripResponse trip,
        DrivingSessionResponse drivingSession,
        String navigationSessionId
) {
}
