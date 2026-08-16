-- Idempotent PostgreSQL showcase dataset for driver001 and vehicle plate 001.
CREATE TEMP TABLE demo_context AS
SELECT
    (
        SELECT d.id
        FROM drivers d
        JOIN users u ON u.id = d.user_id
        WHERE u.username = 'driver001' AND NOT d.deleted AND NOT u.deleted
        LIMIT 1
    ) AS driver_id,
    (
        SELECT v.id
        FROM vehicles v
        WHERE v.plate_number = '001' AND NOT v.deleted
        LIMIT 1
    ) AS vehicle_id,
    date_trunc('month', CURRENT_DATE)::date AS month_start;

CREATE TEMP TABLE demo_monthly_trips (
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
    source.trip_code, context.vehicle_id, context.driver_id, source.start_location, 21.0278, 105.8342,
    source.end_location, 20.9500, 105.8800,
    jsonb_build_object(
        'tripType', 'delivery',
        'cargoInfo', concat(source.cargo_name, ' · ', source.quantity_value, ' ', source.unit_name),
        'warehouseDocument', jsonb_build_object(
            'issueNumber', replace(source.trip_code, 'DEMO-001-M', 'PXK-001-'),
            'issueDate', context.month_start + source.day_offset,
            'warehouseName', source.start_location,
            'projectName', source.end_location,
            'workItem', 'Cung ứng vật tư xây dựng',
            'recipient', jsonb_build_object('name', 'Nguyễn Văn Minh', 'phone', '0912345678'),
            'preparedBy', jsonb_build_object('fullName', 'Quản trị hệ thống'),
            'deliveryDriver', jsonb_build_object('code', '001', 'fullName', 'Nguyễn Văn An'),
            'vehicle', jsonb_build_object('code', '001', 'plate', '001'),
            'items', jsonb_build_array(jsonb_build_object(
                'itemCode', source.item_code,
                'description', source.cargo_name,
                'unit', source.unit_name,
                'quantityIssued', source.quantity_value,
                'quantityReturned', 0,
                'confirmation', 'Hàng nguyên vẹn khi xuất kho'
            )),
            'confirmationStatus', CASE WHEN source.status = 'COMPLETED' THEN 'CONFIRMED' ELSE 'PENDING' END
        ),
        'route', jsonb_build_object('provider', 'OSRM', 'distanceKm', source.distance_km, 'durationMinutes', source.planned_minutes),
        'notes', 'Dữ liệu minh họa báo cáo tháng cho tài xế 001'
    )::text,
    context.month_start + source.day_offset + source.start_time,
    CASE WHEN source.status = 'COMPLETED'
        THEN context.month_start + source.day_offset + source.start_time + source.actual_delay_minutes * INTERVAL '1 minute'
        ELSE NULL END,
    context.month_start + source.day_offset + source.start_time + source.planned_minutes * INTERVAL '1 minute',
    CASE WHEN source.status = 'COMPLETED'
        THEN context.month_start + source.day_offset + source.start_time
            + (source.actual_delay_minutes + source.actual_duration_minutes) * INTERVAL '1 minute'
        ELSE NULL END,
    source.status, source.progress, 'LOW',
    CASE WHEN source.status = 'CANCELLED' THEN 'Điều chỉnh kế hoạch giao hàng' ELSE NULL END,
    context.month_start + source.day_offset + source.start_time, CURRENT_TIMESTAMP(6), FALSE
FROM demo_monthly_trips source
CROSS JOIN demo_context context
WHERE context.driver_id IS NOT NULL AND context.vehicle_id IS NOT NULL
ON CONFLICT (trip_code) DO UPDATE SET
    start_location = EXCLUDED.start_location,
    end_location = EXCLUDED.end_location,
    planned_route_json = EXCLUDED.planned_route_json,
    updated_at = CURRENT_TIMESTAMP(6);

INSERT INTO driver_work_logs (
    driver_id, trip_id, work_date, driving_minutes, rest_minutes,
    note, created_at, updated_at, deleted
)
SELECT context.driver_id, NULL, context.month_start + seed.day_offset,
       seed.driving_minutes, seed.rest_minutes,
       'Dữ liệu minh họa báo cáo tháng tài xế 001',
       CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE
FROM (VALUES (0, 360, 65), (1, 420, 80)) seed(day_offset, driving_minutes, rest_minutes)
CROSS JOIN demo_context context
WHERE context.driver_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM driver_work_logs existing
      WHERE existing.driver_id = context.driver_id
        AND existing.work_date = context.month_start + seed.day_offset
        AND existing.note = 'Dữ liệu minh họa báo cáo tháng tài xế 001'
  );

INSERT INTO safety_events (
    event_type, severity, vehicle_id, driver_id, trip_id, lat, lng, speed,
    confidence, status, note, created_at, updated_at, deleted
)
SELECT seed.event_type, seed.severity, context.vehicle_id, context.driver_id, NULL,
       21.0278, 105.8342, seed.speed_value, seed.confidence_value,
       'RESOLVED', seed.note_value,
       context.month_start + seed.day_offset + seed.event_time,
       CURRENT_TIMESTAMP(6), FALSE
FROM (
    VALUES
        ('DISTRACTION', 'MEDIUM', 0, '11:20:00'::time, 36.0, 0.72, 'Minh họa: mất tập trung ngắn, tài xế đã xác nhận'),
        ('SPEEDING', 'LOW', 0, '15:05:00'::time, 54.0, 0.68, 'Minh họa: vượt ngưỡng tốc độ trong thời gian ngắn')
) seed(event_type, severity, day_offset, event_time, speed_value, confidence_value, note_value)
CROSS JOIN demo_context context
WHERE context.driver_id IS NOT NULL AND context.vehicle_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM safety_events existing
      WHERE existing.driver_id = context.driver_id AND existing.note = seed.note_value
  );

UPDATE drivers driver
SET safety_score = 94,
    driving_time_today_minutes = CASE
        WHEN CURRENT_DATE = context.month_start + 1 THEN 420
        ELSE driver.driving_time_today_minutes
    END,
    continuous_driving_minutes = 0,
    total_trips = (SELECT COUNT(*) FROM trips WHERE driver_id = context.driver_id AND NOT deleted),
    total_alerts = (SELECT COUNT(*) FROM safety_events WHERE driver_id = context.driver_id AND NOT deleted),
    updated_at = CURRENT_TIMESTAMP(6)
FROM demo_context context
WHERE driver.id = context.driver_id;
