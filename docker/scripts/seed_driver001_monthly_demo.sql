-- Idempotent showcase dataset for the single driver 001 and vehicle 001.
-- It never creates a driver or vehicle.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET @driver_id := (
    SELECT d.id FROM drivers d
    JOIN users u ON u.id = d.user_id
    WHERE u.username = 'driver001' AND d.deleted = FALSE AND u.deleted = FALSE
    LIMIT 1
);
SET @vehicle_id := (
    SELECT id FROM vehicles
    WHERE plate_number = '001' AND deleted = FALSE
    LIMIT 1
);
SET @month_start := DATE_FORMAT(CURDATE(), '%Y-%m-01');

DROP TEMPORARY TABLE IF EXISTS demo_monthly_trips;
CREATE TEMPORARY TABLE demo_monthly_trips (
    trip_code VARCHAR(50) PRIMARY KEY,
    day_offset INT NOT NULL,
    start_time TIME NOT NULL,
    planned_minutes INT NOT NULL,
    actual_delay_minutes INT NOT NULL,
    actual_duration_minutes INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    progress INT NOT NULL,
    start_location VARCHAR(255) NOT NULL,
    end_location VARCHAR(255) NOT NULL,
    distance_km DECIMAL(8,1) NOT NULL,
    cargo_name VARCHAR(255) NOT NULL,
    item_code VARCHAR(50) NOT NULL,
    unit_name VARCHAR(30) NOT NULL,
    quantity_value DECIMAL(10,2) NOT NULL
);

INSERT INTO demo_monthly_trips VALUES
('DEMO-001-M01', 0, '06:30:00', 150, 5, 135, 'COMPLETED', 100, 'Kho trung tâm Long Biên, Hà Nội', 'Công trình Bắc Hưng Yên', 48.5, 'Cọc bê tông PHC D300', 'PHC-D300', 'mét', 280),
('DEMO-001-M02', 0, '10:00:00', 165, 0, 150, 'COMPLETED', 100, 'Kho trung tâm Long Biên, Hà Nội', 'Khu công nghiệp Thăng Long', 42.0, 'Mũi dẫn cọc D300', 'MD-D300', 'cái', 14),
('DEMO-001-M03', 0, '14:00:00', 150, 8, 172, 'COMPLETED', 100, 'Kho vật tư Đông Anh, Hà Nội', 'Dự án cầu Nhật Tân', 55.5, 'Thép dự ứng lực', 'TDUL-12', 'cuộn', 8),
('DEMO-001-M04', 0, '18:00:00', 120, 0, 105, 'COMPLETED', 100, 'Kho vật tư Đông Anh, Hà Nội', 'Nhà máy Bắc Thăng Long', 36.0, 'Xi măng PCB40', 'XM-PCB40', 'tấn', 12),
('DEMO-001-M05', 1, '06:00:00', 165, 3, 145, 'COMPLETED', 100, 'Kho trung tâm Long Biên, Hà Nội', 'Công trình Vành đai 4', 63.0, 'Cọc bê tông PHC D400', 'PHC-D400', 'mét', 240),
('DEMO-001-M06', 1, '09:30:00', 150, 0, 140, 'COMPLETED', 100, 'Kho trung tâm Long Biên, Hà Nội', 'Khu đô thị Ocean Park', 39.5, 'Bản mã thép 300x300', 'BMT-300', 'tấm', 42),
('DEMO-001-M07', 1, '13:00:00', 180, 6, 170, 'COMPLETED', 100, 'Kho vật tư Đông Anh, Hà Nội', 'Dự án đường cao tốc Nội Bài', 71.0, 'Thép cây D20', 'THEP-D20', 'tấn', 18),
('DEMO-001-M08', 1, '16:30:00', 150, 0, 138, 'COMPLETED', 100, 'Kho vật tư Đông Anh, Hà Nội', 'Nhà máy bê tông Hưng Yên', 58.0, 'Phụ gia bê tông', 'PG-BT01', 'thùng', 30),
('DEMO-001-M09', 2, '07:00:00', 180, 0, 0, 'ASSIGNED', 0, 'Kho trung tâm Long Biên, Hà Nội', 'Công trình Hà Đông', 52.0, 'Cọc bê tông PHC D300', 'PHC-D300', 'mét', 160),
('DEMO-001-M10', 1, '20:00:00', 90, 0, 0, 'CANCELLED', 0, 'Kho trung tâm Long Biên, Hà Nội', 'Công trình Thanh Trì', 31.0, 'Mũi dẫn cọc D300', 'MD-D300', 'cái', 6);

INSERT INTO trips (
    trip_code, vehicle_id, driver_id, start_location, start_lat, start_lng,
    end_location, end_lat, end_lng, planned_route_json,
    planned_start_time, actual_start_time, estimated_end_time, actual_end_time,
    status, progress, risk_level, cancel_reason, created_at, updated_at, deleted
)
SELECT
    source.trip_code, @vehicle_id, @driver_id, source.start_location, 21.0278, 105.8342,
    source.end_location, 20.9500, 105.8800,
    JSON_OBJECT(
        'tripType', 'delivery',
        'cargoInfo', CONCAT(source.cargo_name, ' · ', source.quantity_value, ' ', source.unit_name),
        'warehouseDocument', JSON_OBJECT(
            'issueNumber', REPLACE(source.trip_code, 'DEMO-001-M', 'PXK-001-'),
            'issueDate', DATE_ADD(@month_start, INTERVAL source.day_offset DAY),
            'warehouseName', source.start_location,
            'projectName', source.end_location,
            'workItem', 'Cung ứng vật tư xây dựng',
            'recipient', JSON_OBJECT('name', 'Nguyễn Văn Minh', 'phone', '0912345678'),
            'preparedBy', JSON_OBJECT('fullName', 'Quản trị hệ thống'),
            'deliveryDriver', JSON_OBJECT('code', '001', 'fullName', 'Nguyễn Văn An'),
            'vehicle', JSON_OBJECT('code', '001', 'plate', '001'),
            'items', JSON_ARRAY(JSON_OBJECT(
                'itemCode', source.item_code,
                'description', source.cargo_name,
                'unit', source.unit_name,
                'quantityIssued', source.quantity_value,
                'quantityReturned', 0,
                'confirmation', 'Hàng nguyên vẹn khi xuất kho'
            )),
            'confirmationStatus', IF(source.status = 'COMPLETED', 'CONFIRMED', 'PENDING')
        ),
        'route', JSON_OBJECT('provider', 'OSRM', 'distanceKm', source.distance_km, 'durationMinutes', source.planned_minutes),
        'notes', 'Dữ liệu minh họa báo cáo tháng cho tài xế 001'
    ),
    TIMESTAMP(DATE_ADD(@month_start, INTERVAL source.day_offset DAY), source.start_time),
    IF(source.status = 'COMPLETED', DATE_ADD(TIMESTAMP(DATE_ADD(@month_start, INTERVAL source.day_offset DAY), source.start_time), INTERVAL source.actual_delay_minutes MINUTE), NULL),
    DATE_ADD(TIMESTAMP(DATE_ADD(@month_start, INTERVAL source.day_offset DAY), source.start_time), INTERVAL source.planned_minutes MINUTE),
    IF(source.status = 'COMPLETED', DATE_ADD(DATE_ADD(TIMESTAMP(DATE_ADD(@month_start, INTERVAL source.day_offset DAY), source.start_time), INTERVAL source.actual_delay_minutes MINUTE), INTERVAL source.actual_duration_minutes MINUTE), NULL),
    source.status, source.progress, 'LOW', IF(source.status = 'CANCELLED', 'Điều chỉnh kế hoạch giao hàng', NULL),
    TIMESTAMP(DATE_ADD(@month_start, INTERVAL source.day_offset DAY), source.start_time), NOW(6), FALSE
FROM demo_monthly_trips source
WHERE @driver_id IS NOT NULL AND @vehicle_id IS NOT NULL
ON DUPLICATE KEY UPDATE
    start_location = VALUES(start_location),
    end_location = VALUES(end_location),
    planned_route_json = VALUES(planned_route_json),
    updated_at = NOW(6);

INSERT INTO driver_work_logs (driver_id, trip_id, work_date, driving_minutes, rest_minutes, note, created_at, updated_at, deleted)
SELECT @driver_id, NULL, DATE_ADD(@month_start, INTERVAL seed.day_offset DAY), seed.driving_minutes, seed.rest_minutes,
       'Dữ liệu minh họa báo cáo tháng tài xế 001', NOW(6), NOW(6), FALSE
FROM (
    SELECT 0 day_offset, 360 driving_minutes, 65 rest_minutes
    UNION ALL SELECT 1, 420, 80
) seed
WHERE @driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM driver_work_logs existing
      WHERE existing.driver_id = @driver_id
        AND existing.work_date = DATE_ADD(@month_start, INTERVAL seed.day_offset DAY)
        AND existing.note = 'Dữ liệu minh họa báo cáo tháng tài xế 001'
  );

INSERT INTO safety_events (
    event_type, severity, vehicle_id, driver_id, trip_id, lat, lng, speed,
    confidence, status, note, created_at, updated_at, deleted
)
SELECT seed.event_type, seed.severity, @vehicle_id, @driver_id, NULL, 21.0278, 105.8342,
       seed.speed_value, seed.confidence_value, 'RESOLVED', seed.note_value,
       DATE_ADD(TIMESTAMP(@month_start, seed.event_time), INTERVAL seed.day_offset DAY), NOW(6), FALSE
FROM (
    SELECT 'DISTRACTION' event_type, 'MEDIUM' severity, 0 day_offset, '11:20:00' event_time, 36.0 speed_value, 0.72 confidence_value, 'Minh họa: mất tập trung ngắn, tài xế đã xác nhận' note_value
    UNION ALL SELECT 'SPEEDING', 'LOW', 0, '15:05:00', 54.0, 0.68, 'Minh họa: vượt ngưỡng tốc độ trong thời gian ngắn'
) seed
WHERE @driver_id IS NOT NULL AND @vehicle_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM safety_events existing
      WHERE existing.driver_id = @driver_id AND existing.note = seed.note_value
  );

UPDATE drivers
SET safety_score = 94,
    driving_time_today_minutes = IF(CURDATE() = DATE_ADD(@month_start, INTERVAL 1 DAY), 420, driving_time_today_minutes),
    continuous_driving_minutes = 0,
    total_trips = (SELECT COUNT(*) FROM trips WHERE driver_id = @driver_id AND deleted = FALSE),
    total_alerts = (SELECT COUNT(*) FROM safety_events WHERE driver_id = @driver_id AND deleted = FALSE),
    updated_at = NOW(6)
WHERE id = @driver_id;

DROP TEMPORARY TABLE demo_monthly_trips;
