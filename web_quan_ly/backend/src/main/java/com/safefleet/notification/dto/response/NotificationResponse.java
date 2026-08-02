package com.safefleet.notification.dto.response;

import com.safefleet.notification.enums.NotificationType;

import java.time.LocalDateTime;

public record NotificationResponse(
        Long id,
        NotificationType type,
        String title,
        String content,
        String referenceType,
        Long referenceId,
        boolean read,
        LocalDateTime createdAt
) {
}
