package com.safefleet.auth.dto.response;

import com.safefleet.account.enums.RoleName;

public record AuthResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresInSeconds,
        Long userId,
        Long driverId,
        String username,
        String email,
        String fullName,
        RoleName role
) {
}
