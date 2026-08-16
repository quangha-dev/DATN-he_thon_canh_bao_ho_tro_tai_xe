-- Remove only SafeFleet-owned monthly showcase rows before reloading the PostgreSQL seed.
WITH context AS (
    SELECT d.id AS driver_id, date_trunc('month', CURRENT_DATE)::date AS month_start
    FROM drivers d
    JOIN users u ON u.id = d.user_id
    WHERE u.username = 'driver001' AND NOT d.deleted AND NOT u.deleted
    LIMIT 1
)
DELETE FROM safety_events event
USING context
WHERE event.driver_id = context.driver_id
  AND event.created_at >= context.month_start
  AND event.created_at < context.month_start + INTERVAL '1 month'
  AND ((event.event_type = 'DISTRACTION' AND ABS(event.confidence - 0.72) < 0.0001)
    OR (event.event_type = 'SPEEDING' AND ABS(event.confidence - 0.68) < 0.0001));

WITH context AS (
    SELECT d.id AS driver_id, date_trunc('month', CURRENT_DATE)::date AS month_start
    FROM drivers d
    JOIN users u ON u.id = d.user_id
    WHERE u.username = 'driver001' AND NOT d.deleted AND NOT u.deleted
    LIMIT 1
)
DELETE FROM driver_work_logs work_log
USING context
WHERE work_log.driver_id = context.driver_id
  AND work_log.work_date >= context.month_start
  AND work_log.work_date < context.month_start + INTERVAL '1 month'
  AND work_log.driving_minutes IN (360, 420)
  AND work_log.rest_minutes IN (65, 80);

-- Trip rows are deliberately preserved because real GPS telemetry can reference them.
-- The PostgreSQL seed uses ON CONFLICT DO UPDATE to repair their text.
