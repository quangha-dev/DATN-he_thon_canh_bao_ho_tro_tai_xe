package com.safefleet.incident.dto.response;

import java.time.LocalDateTime;

public record IncidentTimelineResponse(
        Long id,
        Long incidentId,
        String action,
        Long actorId,
        String actorName,
        String note,
        LocalDateTime createdAt
) {
}
