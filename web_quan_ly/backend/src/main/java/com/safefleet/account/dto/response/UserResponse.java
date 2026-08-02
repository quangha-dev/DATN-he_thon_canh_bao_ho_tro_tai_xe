package com.safefleet.account.dto.response;

import com.safefleet.account.enums.AccountStatus;
import com.safefleet.account.enums.RoleName;

import java.time.LocalDateTime;

public record UserResponse(
        Long id,
        String username,
        String email,
        String fullName,
        String phone,
        AccountStatus status,
        RoleName role,
        LocalDateTime createdAt
) {
}
