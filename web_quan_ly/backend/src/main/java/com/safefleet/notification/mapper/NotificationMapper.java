package com.safefleet.notification.mapper;

import com.safefleet.notification.dto.response.NotificationResponse;
import com.safefleet.notification.entity.Notification;

public final class NotificationMapper {

    private NotificationMapper() {
    }

    public static NotificationResponse toResponse(Notification notification) {
        return toResponse(notification, notification.getReadAt() != null);
    }

    public static NotificationResponse toResponse(Notification notification, boolean read) {
        return new NotificationResponse(
                notification.getId(),
                notification.getType(),
                notification.getTitle(),
                notification.getContent(),
                notification.getReferenceType(),
                notification.getReferenceId(),
                read,
                notification.getCreatedAt()
        );
    }
}
