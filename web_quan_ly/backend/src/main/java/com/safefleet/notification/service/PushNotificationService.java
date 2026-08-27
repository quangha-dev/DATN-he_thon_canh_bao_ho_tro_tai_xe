package com.safefleet.notification.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.mobile.dto.request.MobilePushTokenRequest;
import com.safefleet.mobile.dto.response.MobilePushTokenResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class PushNotificationService {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final ObjectProvider<FirebaseMessaging> firebaseMessagingProvider;

    @Value("${app.push.fcm-enabled:false}")
    private boolean fcmEnabled;

    @Value("${app.push.max-attempts:6}")
    private int maxAttempts;

    @Transactional
    public MobilePushTokenResponse register(MobilePushTokenRequest request) {
        Long userId = SecurityUtils.currentUserId();
        String deviceUuid = request.deviceUuid().trim();
        List<Map<String, Object>> devices = jdbcTemplate.queryForList(
                "SELECT id, user_id FROM mobile_devices WHERE device_uuid = ?",
                deviceUuid
        );
        Long deviceId;
        if (devices.isEmpty()) {
            jdbcTemplate.update("""
                    INSERT INTO mobile_devices
                        (device_uuid, user_id, platform, app_version, os_version, device_model,
                         last_seen_at, created_at, updated_at, deleted)
                    VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6),
                            CURRENT_TIMESTAMP(6), FALSE)
                    """,
                    deviceUuid,
                    userId,
                    request.platform(),
                    request.appVersion(),
                    request.osVersion(),
                    request.deviceModel()
            );
            deviceId = jdbcTemplate.queryForObject(
                    "SELECT id FROM mobile_devices WHERE device_uuid = ?",
                    Long.class,
                    deviceUuid
            );
        } else {
            Map<String, Object> device = devices.getFirst();
            long ownerId = ((Number) device.get("user_id")).longValue();
            if (ownerId != userId) {
                throw new ForbiddenActionException("Thiết bị đã thuộc một tài khoản khác");
            }
            deviceId = ((Number) device.get("id")).longValue();
            jdbcTemplate.update("""
                    UPDATE mobile_devices
                    SET platform = ?, app_version = ?, os_version = ?, device_model = ?,
                        last_seen_at = CURRENT_TIMESTAMP(6), updated_at = CURRENT_TIMESTAMP(6),
                        deleted = FALSE
                    WHERE id = ?
                    """,
                    request.platform(),
                    request.appVersion(),
                    request.osVersion(),
                    request.deviceModel(),
                    deviceId
            );
        }

        List<Map<String, Object>> tokenOwners = jdbcTemplate.queryForList(
                "SELECT user_id FROM push_tokens WHERE provider = ? AND token = ?",
                request.provider(),
                request.token().trim()
        );
        if (!tokenOwners.isEmpty()
                && ((Number) tokenOwners.getFirst().get("user_id")).longValue() != userId) {
            throw new ForbiddenActionException("Push token đã thuộc một tài khoản khác");
        }

        jdbcTemplate.update("""
                INSERT INTO push_tokens
                    (user_id, device_id, provider, token, enabled, last_used_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, TRUE, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))
                ON CONFLICT (provider, token) DO UPDATE SET
                    device_id = EXCLUDED.device_id,
                    enabled = TRUE,
                    last_used_at = CURRENT_TIMESTAMP(6),
                    updated_at = CURRENT_TIMESTAMP(6)
                """,
                userId,
                deviceId,
                request.provider(),
                request.token().trim()
        );
        return findResponse(userId, deviceUuid, request.provider(), request.token().trim());
    }

    @Transactional
    public void unregister(String deviceUuid) {
        Long userId = SecurityUtils.currentUserId();
        jdbcTemplate.update("""
                UPDATE push_tokens pt
                SET enabled = FALSE, updated_at = CURRENT_TIMESTAMP(6)
                FROM mobile_devices md
                WHERE md.device_uuid = ? AND md.user_id = ?
                  AND md.id = pt.device_id
                """, deviceUuid, userId);
        jdbcTemplate.update("""
                UPDATE mobile_devices
                SET last_seen_at = CURRENT_TIMESTAMP(6), updated_at = CURRENT_TIMESTAMP(6)
                WHERE device_uuid = ? AND user_id = ?
                """, deviceUuid, userId);
    }

    @Transactional
    public void enqueue(Long notificationId,
                        Long recipientId,
                        String title,
                        String body,
                        String referenceType,
                        Long referenceId) {
        if (recipientId == null) {
            jdbcTemplate.update("""
                    INSERT INTO pending_push_notifications
                        (notification_id, user_id, push_token_id, title, body, data_json,
                         status, attempt_count, next_attempt_at, created_at)
                    SELECT ?, pt.user_id, pt.id, ?, ?,
                           jsonb_build_object('referenceType', ?, 'referenceId', ?)::text,
                           'PENDING', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
                    FROM push_tokens pt
                    WHERE pt.enabled = TRUE
                    """, notificationId, title, body, referenceType, referenceId);
        } else {
            jdbcTemplate.update("""
                    INSERT INTO pending_push_notifications
                        (notification_id, user_id, push_token_id, title, body, data_json,
                         status, attempt_count, next_attempt_at, created_at)
                    SELECT ?, pt.user_id, pt.id, ?, ?,
                           jsonb_build_object('referenceType', ?, 'referenceId', ?)::text,
                           'PENDING', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
                    FROM push_tokens pt
                    WHERE pt.enabled = TRUE AND pt.user_id = ?
                    """, notificationId, title, body, referenceType, referenceId, recipientId);
        }
    }

    @Scheduled(fixedDelayString = "${app.push.dispatch-interval-ms:30000}")
    public void dispatchPending() {
        if (!fcmEnabled) {
            int fallbackCount = jdbcTemplate.update("""
                    UPDATE pending_push_notifications
                    SET status = 'POLLING_FALLBACK',
                        last_error = 'FCM disabled; mobile REST polling remains active'
                    WHERE status = 'PENDING' AND next_attempt_at <= CURRENT_TIMESTAMP(6)
                    """);
            if (fallbackCount > 0) {
                log.info("Moved {} push item(s) to REST polling fallback", fallbackCount);
            }
            return;
        }
        FirebaseMessaging messaging = firebaseMessagingProvider.getIfAvailable();
        if (messaging == null) {
            log.error("FCM is enabled but FirebaseMessaging is not configured");
            return;
        }

        for (PushWork item : claimPending(100)) {
            try {
                String messageId = messaging.send(buildMessage(item));
                jdbcTemplate.update("""
                        UPDATE pending_push_notifications
                        SET status = 'SENT', sent_at = CURRENT_TIMESTAMP(6),
                            last_error = NULL
                        WHERE id = ? AND status = 'SENDING'
                        """, item.id());
                jdbcTemplate.update("""
                        UPDATE push_tokens
                        SET last_used_at = CURRENT_TIMESTAMP(6), updated_at = CURRENT_TIMESTAMP(6)
                        WHERE id = ?
                        """, item.pushTokenId());
                log.debug("Sent FCM push {} as {}", item.id(), messageId);
            } catch (FirebaseMessagingException exception) {
                handleFailure(item, exception, exception.getMessagingErrorCode());
            } catch (Exception exception) {
                handleFailure(item, exception, null);
            }
        }
    }

    private List<PushWork> claimPending(int limit) {
        return jdbcTemplate.query("""
                WITH claimed AS (
                    SELECT ppn.id
                    FROM pending_push_notifications ppn
                    JOIN push_tokens pt ON pt.id = ppn.push_token_id
                    WHERE ppn.status = 'PENDING'
                      AND ppn.next_attempt_at <= CURRENT_TIMESTAMP(6)
                      AND pt.enabled = TRUE
                      AND pt.provider = 'FCM'
                    ORDER BY ppn.created_at
                    FOR UPDATE OF ppn SKIP LOCKED
                    LIMIT ?
                )
                UPDATE pending_push_notifications ppn
                SET status = 'SENDING', attempt_count = attempt_count + 1,
                    last_error = NULL
                FROM claimed, push_tokens pt
                WHERE ppn.id = claimed.id AND pt.id = ppn.push_token_id
                RETURNING ppn.id, ppn.push_token_id, ppn.title, ppn.body,
                          ppn.data_json, ppn.attempt_count, pt.token
                """, (resultSet, rowNumber) -> new PushWork(
                resultSet.getLong("id"),
                resultSet.getLong("push_token_id"),
                resultSet.getString("title"),
                resultSet.getString("body"),
                resultSet.getString("data_json"),
                resultSet.getInt("attempt_count"),
                resultSet.getString("token")
        ), limit);
    }

    private Message buildMessage(PushWork item) throws Exception {
        Map<String, Object> rawData = item.dataJson() == null || item.dataJson().isBlank()
                ? Map.of()
                : objectMapper.readValue(item.dataJson(), new TypeReference<>() {
                });
        Map<String, String> data = new LinkedHashMap<>();
        rawData.forEach((key, value) -> {
            if (value != null) {
                data.put(key, value.toString());
            }
        });
        data.put("pushId", Long.toString(item.id()));

        return Message.builder()
                .setToken(item.token())
                .setNotification(Notification.builder()
                        .setTitle(item.title())
                        .setBody(item.body())
                        .build())
                .putAllData(data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .build())
                .build();
    }

    private void handleFailure(PushWork item,
                               Exception exception,
                               MessagingErrorCode errorCode) {
        boolean invalidToken = errorCode == MessagingErrorCode.UNREGISTERED
                || errorCode == MessagingErrorCode.SENDER_ID_MISMATCH;
        boolean retryable = errorCode == null
                || errorCode == MessagingErrorCode.INTERNAL
                || errorCode == MessagingErrorCode.UNAVAILABLE
                || errorCode == MessagingErrorCode.QUOTA_EXCEEDED
                || errorCode == MessagingErrorCode.THIRD_PARTY_AUTH_ERROR;
        boolean exhausted = item.attemptCount() >= Math.max(1, maxAttempts);
        String status = retryable && !exhausted ? "PENDING" : "FAILED";
        int retryMinutes = Math.min(30, 1 << Math.min(item.attemptCount(), 5));
        String error = abbreviate(exception.getMessage(), 1000);

        jdbcTemplate.update("""
                UPDATE pending_push_notifications
                SET status = ?, last_error = ?,
                    next_attempt_at = CURRENT_TIMESTAMP(6) + (? * INTERVAL '1 minute')
                WHERE id = ? AND status = 'SENDING'
                """, status, error, retryMinutes, item.id());
        if (invalidToken) {
            jdbcTemplate.update("""
                    UPDATE push_tokens
                    SET enabled = FALSE, updated_at = CURRENT_TIMESTAMP(6)
                    WHERE id = ?
                    """, item.pushTokenId());
        }
        log.warn("FCM push {} failed with {} (status={}, attempt={}): {}",
                item.id(), errorCode, status, item.attemptCount(), error);
    }

    private static String abbreviate(String value, int maxLength) {
        if (value == null || value.isBlank()) {
            return "Unknown FCM dispatch error";
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }

    private record PushWork(
            long id,
            long pushTokenId,
            String title,
            String body,
            String dataJson,
            int attemptCount,
            String token
    ) {
    }

    private MobilePushTokenResponse findResponse(Long userId,
                                                 String deviceUuid,
                                                 String provider,
                                                 String token) {
        return jdbcTemplate.queryForObject("""
                SELECT pt.id, md.device_uuid, md.platform, pt.provider, pt.enabled, md.last_seen_at
                FROM push_tokens pt
                JOIN mobile_devices md ON md.id = pt.device_id
                WHERE pt.user_id = ? AND md.device_uuid = ? AND pt.provider = ? AND pt.token = ?
                """, (resultSet, rowNumber) -> {
            Timestamp lastSeen = resultSet.getTimestamp("last_seen_at");
            return new MobilePushTokenResponse(
                    resultSet.getLong("id"),
                    resultSet.getString("device_uuid"),
                    resultSet.getString("platform"),
                    resultSet.getString("provider"),
                    resultSet.getBoolean("enabled"),
                    lastSeen == null ? null : lastSeen.toLocalDateTime()
            );
        }, userId, deviceUuid, provider, token);
    }
}
