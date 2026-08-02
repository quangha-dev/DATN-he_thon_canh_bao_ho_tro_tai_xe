-- Remove only Codex-owned monthly showcase rows before reloading them as UTF-8.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @driver_id := (
    SELECT d.id FROM drivers d
    JOIN users u ON u.id = d.user_id
    WHERE u.username = 'driver001' AND d.deleted = FALSE AND u.deleted = FALSE
    LIMIT 1
);
SET @month_start := DATE_FORMAT(CURDATE(), '%Y-%m-01');

DELETE FROM safety_events
WHERE driver_id = @driver_id
  AND created_at >= @month_start
  AND created_at < DATE_ADD(@month_start, INTERVAL 1 MONTH)
  AND ((event_type = 'DISTRACTION' AND ABS(confidence - 0.72) < 0.0001)
    OR (event_type = 'SPEEDING' AND ABS(confidence - 0.68) < 0.0001));

DELETE FROM driver_work_logs
WHERE driver_id = @driver_id
  AND work_date >= @month_start
  AND work_date < DATE_ADD(@month_start, INTERVAL 1 MONTH)
  AND driving_minutes IN (360, 420)
  AND rest_minutes IN (65, 80);

-- Trip rows are deliberately preserved because real GPS telemetry can already
-- reference them. The seed uses ON DUPLICATE KEY UPDATE to repair their text.
