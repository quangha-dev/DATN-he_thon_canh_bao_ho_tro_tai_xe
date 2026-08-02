package com.safefleet.mobile.dto.response;

import java.time.LocalDateTime;

public record MobilePushTokenResponse(
        Long id,
        String deviceUuid,
        String platform,
        String provider,
        boolean enabled,
        LocalDateTime lastSeenAt
) {
}
