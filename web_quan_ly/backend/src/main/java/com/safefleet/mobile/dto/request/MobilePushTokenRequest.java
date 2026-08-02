package com.safefleet.mobile.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record MobilePushTokenRequest(
        @NotBlank @Size(max = 100) String deviceUuid,
        @NotBlank @Pattern(regexp = "ANDROID|IOS") String platform,
        @NotBlank @Pattern(regexp = "FCM|APNS|MOCK") String provider,
        @NotBlank @Size(max = 512) String token,
        @Size(max = 40) String appVersion,
        @Size(max = 80) String osVersion,
        @Size(max = 120) String deviceModel
) {
}
