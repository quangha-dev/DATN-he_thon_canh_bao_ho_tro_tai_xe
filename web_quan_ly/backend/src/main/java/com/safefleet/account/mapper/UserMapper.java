package com.safefleet.account.mapper;

import com.safefleet.account.dto.response.UserResponse;
import com.safefleet.account.entity.UserAccount;

public final class UserMapper {

    private UserMapper() {
    }

    public static UserResponse toResponse(UserAccount user) {
        return new UserResponse(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getFullName(),
                user.getPhone(),
                user.getStatus(),
                user.getRole().getName(),
                user.getCreatedAt()
        );
    }
}
