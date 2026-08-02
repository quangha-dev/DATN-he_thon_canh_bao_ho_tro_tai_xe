package com.safefleet.trip.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CancelTripRequest(@NotBlank @Size(max = 255) String reason) {
}
