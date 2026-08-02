package com.safefleet.mobile.dto.response;

import com.safefleet.trip.dto.response.TripResponse;

public record MobileCurrentAssignmentResponse(
        TripResponse trip,
        boolean checklistSubmitted
) {
}
