package com.safefleet.navigation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record NavigationCompleteRequest(
        @NotBlank String sessionId,
        @Size(max = 40) String reason
) {
}
