package com.safefleet.trip.dto.response;

import java.time.LocalDateTime;

public record TripTimelineResponse(
        Long id,
        Long tripId,
        String action,
        Long actorId,
        String actorName,
        String note,
        LocalDateTime createdAt
) {
}
