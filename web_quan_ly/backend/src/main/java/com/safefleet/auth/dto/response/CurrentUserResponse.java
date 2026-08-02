package com.safefleet.auth.dto.response;

import com.safefleet.account.enums.AccountStatus;
import com.safefleet.account.enums.RoleName;

public record CurrentUserResponse(
        Long userId,
        Long driverId,
        String username,
        String email,
        String fullName,
        AccountStatus status,
        RoleName role
) {
}
