package com.safefleet.notification.service;

import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.mobile.dto.request.MobilePushTokenRequest;
import com.safefleet.mobile.dto.response.MobilePushTokenResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class PushNotificationService {

    private final JdbcTemplate jdbcTemplate;

    @Value("${app.push.fcm-enabled:false}")
    private boolean fcmEnabled;

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
                ON DUPLICATE KEY UPDATE
                    device_id = VALUES(device_id),
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
                JOIN mobile_devices md ON md.id = pt.device_id
                SET pt.enabled = FALSE, pt.updated_at = CURRENT_TIMESTAMP(6)
                WHERE md.device_uuid = ? AND md.user_id = ?
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
                           JSON_OBJECT('referenceType', ?, 'referenceId', ?),
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
                           JSON_OBJECT('referenceType', ?, 'referenceId', ?),
                           'PENDING', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
                    FROM push_tokens pt
                    WHERE pt.enabled = TRUE AND pt.user_id = ?
                    """, notificationId, title, body, referenceType, referenceId, recipientId);
        }
    }

    @Scheduled(fixedDelayString = "${app.push.dispatch-interval-ms:30000}")
    @Transactional
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
        // Production FCM credentials are intentionally not embedded. Keep queued rows retryable.
        jdbcTemplate.update("""
                UPDATE pending_push_notifications
                SET attempt_count = attempt_count + 1,
                    next_attempt_at = DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL 5 MINUTE),
                    last_error = 'FCM adapter requires deployment credentials'
                WHERE status = 'PENDING' AND next_attempt_at <= CURRENT_TIMESTAMP(6)
                """);
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
