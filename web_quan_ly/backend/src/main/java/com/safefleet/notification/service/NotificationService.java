package com.safefleet.notification.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.notification.dto.response.NotificationResponse;
import com.safefleet.notification.entity.Notification;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.mapper.NotificationMapper;
import com.safefleet.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserAccountRepository userAccountRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final JdbcTemplate jdbcTemplate;
    private final PushNotificationService pushNotificationService;

    @Transactional
    public NotificationResponse createGlobal(NotificationType type,
                                             String title,
                                             String content,
                                             String referenceType,
                                             Long referenceId) {
        Notification notification = new Notification();
        notification.setType(type);
        notification.setTitle(title);
        notification.setContent(content);
        notification.setReferenceType(referenceType);
        notification.setReferenceId(referenceId);
        Notification saved = notificationRepository.saveAndFlush(notification);
        NotificationResponse response = NotificationMapper.toResponse(saved);
        pushNotificationService.enqueue(
                saved.getId(), null, saved.getTitle(), saved.getContent(),
                saved.getReferenceType(), saved.getReferenceId()
        );
        messagingTemplate.convertAndSend("/topic/notifications", response);
        return response;
    }

    @Transactional
    public NotificationResponse createForUser(Long recipientId,
                                              NotificationType type,
                                              String title,
                                              String content,
                                              String referenceType,
                                              Long referenceId) {
        UserAccount recipient = userAccountRepository.findById(recipientId)
                .orElseThrow(() -> new NotFoundException("User", recipientId));
        Notification notification = new Notification();
        notification.setRecipient(recipient);
        notification.setType(type);
        notification.setTitle(title);
        notification.setContent(content);
        notification.setReferenceType(referenceType);
        notification.setReferenceId(referenceId);
        Notification saved = notificationRepository.saveAndFlush(notification);
        NotificationResponse response = NotificationMapper.toResponse(saved);
        pushNotificationService.enqueue(
                saved.getId(), recipientId, saved.getTitle(), saved.getContent(),
                saved.getReferenceType(), saved.getReferenceId()
        );
        messagingTemplate.convertAndSend("/topic/notifications", response);
        return response;
    }

    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> currentUserNotifications(Pageable pageable) {
        Long userId = SecurityUtils.currentUserId();
        return PageResponse.from(notificationRepository.findVisibleToUser(userId, pageable)
                .map(notification -> NotificationMapper.toResponse(notification, isRead(notification.getId(), userId))));
    }

    @Transactional
    public NotificationResponse markRead(Long id) {
        Long userId = SecurityUtils.currentUserId();
        Notification notification = notificationRepository.findVisibleById(id, userId)
                .orElseThrow(() -> new NotFoundException("Notification", id));
        jdbcTemplate.update("""
                INSERT IGNORE INTO notification_reads (notification_id, user_id, read_at)
                VALUES (?, ?, CURRENT_TIMESTAMP(6))
                """, notification.getId(), userId);
        return NotificationMapper.toResponse(notification, true);
    }

    @Transactional
    public void markAllRead() {
        Long userId = SecurityUtils.currentUserId();
        jdbcTemplate.update("""
                INSERT IGNORE INTO notification_reads (notification_id, user_id, read_at)
                SELECT id, ?, CURRENT_TIMESTAMP(6)
                FROM notifications
                WHERE recipient_id IS NULL OR recipient_id = ?
                """, userId, userId);
    }

    private boolean isRead(Long notificationId, Long userId) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM notification_reads
                WHERE notification_id = ? AND user_id = ?
                """, Integer.class, notificationId, userId);
        return count != null && count > 0;
    }
}
