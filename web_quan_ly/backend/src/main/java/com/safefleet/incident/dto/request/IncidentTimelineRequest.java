package com.safefleet.incident.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record IncidentTimelineRequest(
        @NotBlank @Size(max = 80) String action,
        @Size(max = 500) String note
) {
}
