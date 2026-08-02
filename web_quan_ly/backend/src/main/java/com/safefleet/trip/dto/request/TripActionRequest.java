package com.safefleet.trip.dto.request;

import jakarta.validation.constraints.Size;

public record TripActionRequest(
        @Size(max = 500) String note,
        @Size(max = 100) String clientEventId
) {
}
