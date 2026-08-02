package com.safefleet.mobile.dto.response;

import com.safefleet.driver.dto.response.DriverResponse;

public record MobileProfileResponse(
        Long userId,
        String username,
        String email,
        String fullName,
        String phone,
        String role,
        DriverResponse driver
) {
}
