package com.safefleet.mobile.dto.response;

import com.safefleet.trip.dto.response.TripResponse;

public record MobileTripSummaryResponse(
        TripResponse trip,
        boolean checklistSubmitted,
        String nextAction
) {
}
