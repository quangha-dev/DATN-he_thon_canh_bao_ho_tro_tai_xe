package com.safefleet.auth.dto.request;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenRequest(
        @NotBlank(message = "Refresh token là bắt buộc")
        String refreshToken
) {
}
