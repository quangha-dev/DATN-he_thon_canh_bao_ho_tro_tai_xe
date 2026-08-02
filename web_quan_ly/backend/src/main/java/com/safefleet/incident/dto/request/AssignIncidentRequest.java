package com.safefleet.incident.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record AssignIncidentRequest(
        @NotNull Long rescueUserId,
        @Size(max = 500) String note
) {
}
