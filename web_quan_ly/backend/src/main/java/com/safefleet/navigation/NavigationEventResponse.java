package com.safefleet.navigation;

import java.time.LocalDateTime;

public record NavigationEventResponse(
        Long eventId,
        String sessionId,
        String eventType,
        Boolean offRoute,
        Integer offRouteDurationSeconds,
        Boolean rerouteRequired,
        LocalDateTime occurredAt,
        NavigationHazardAheadResponse hazardAhead
) {
}
