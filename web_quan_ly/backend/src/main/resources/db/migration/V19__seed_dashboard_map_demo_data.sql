-- Dữ liệu minh hoạ tối thiểu cho dashboard và bản đồ điều hành.
-- Tất cả bản ghi dùng mã DEMO riêng để migration an toàn và không trùng dữ liệu thật.

INSERT INTO drivers (
    full_name, phone, email, address, license_number, license_class,
    license_expired_at, status, safety_score, driving_time_today_minutes,
    continuous_driving_minutes, total_trips, total_alerts,
    created_at, updated_at, deleted
) VALUES
    ('Phạm Đức Long', '0901001001', 'long.pham.demo@safefleet.vn', 'Long Biên, Hà Nội', 'DEMO-B2-1001', 'B2', CURRENT_DATE + 730, 'DRIVING', 92, 135, 72, 18, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE),
    ('Nguyễn Hải Yến', '0901001002', 'yen.nguyen.demo@safefleet.vn', 'Hà Đông, Hà Nội', 'DEMO-C-1002', 'C', CURRENT_DATE + 900, 'DRIVING', 84, 188, 96, 26, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE),
    ('Trần Quốc Minh', '0901001003', 'minh.tran.demo@safefleet.vn', 'Cầu Giấy, Hà Nội', 'DEMO-C-1003', 'C', CURRENT_DATE + 640, 'RESTING', 76, 220, 0, 31, 6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE)
ON CONFLICT (license_number) DO NOTHING;

INSERT INTO vehicles (
    plate_number, vehicle_type, brand, model, manufacture_year,
    load_capacity, seat_count, fuel_type, status, current_driver_id,
    inspection_expired_at, insurance_expired_at,
    last_lat, last_lng, last_speed, last_updated_at,
    created_at, updated_at, deleted
)
SELECT
    sample.plate_number, sample.vehicle_type, sample.brand, sample.model,
    sample.manufacture_year, sample.load_capacity, sample.seat_count,
    sample.fuel_type, sample.status, driver.id,
    CURRENT_DATE + 240, CURRENT_DATE + 180,
    sample.lat, sample.lng, sample.speed, CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE
FROM (
    VALUES
        ('29C-123.45', 'TRUCK', 'THACO', 'Ollin 720', 2023, 7.20::numeric, 3, 'DIESEL', 'RUNNING', 'DEMO-B2-1001', 21.02890::double precision, 105.86220::double precision, 42.0::double precision),
        ('30H-456.78', 'VAN', 'Ford', 'Transit', 2024, 1.40::numeric, 16, 'DIESEL', 'RUNNING', 'DEMO-C-1002', 21.01580::double precision, 105.80480::double precision, 35.0::double precision),
        ('29D-789.01', 'TRUCK', 'Isuzu', 'NPR 400', 2022, 3.50::numeric, 3, 'DIESEL', 'RESTING', 'DEMO-C-1003', 21.04150::double precision, 105.79020::double precision, 0.0::double precision)
) AS sample(
    plate_number, vehicle_type, brand, model, manufacture_year,
    load_capacity, seat_count, fuel_type, status, license_number, lat, lng, speed
)
JOIN drivers driver ON driver.license_number = sample.license_number
ON CONFLICT (plate_number) DO NOTHING;

UPDATE drivers driver
SET current_vehicle_id = vehicle.id,
    updated_at = CURRENT_TIMESTAMP
FROM vehicles vehicle
WHERE (driver.license_number, vehicle.plate_number) IN (
    ('DEMO-B2-1001', '29C-123.45'),
    ('DEMO-C-1002', '30H-456.78'),
    ('DEMO-C-1003', '29D-789.01')
)
AND (
    (driver.license_number = 'DEMO-B2-1001' AND vehicle.plate_number = '29C-123.45') OR
    (driver.license_number = 'DEMO-C-1002' AND vehicle.plate_number = '30H-456.78') OR
    (driver.license_number = 'DEMO-C-1003' AND vehicle.plate_number = '29D-789.01')
);

INSERT INTO trips (
    trip_code, vehicle_id, driver_id, start_location, start_lat, start_lng,
    end_location, end_lat, end_lng, planned_start_time, actual_start_time,
    estimated_end_time, status, progress, risk_level,
    created_at, updated_at, deleted
)
SELECT
    sample.trip_code, vehicle.id, driver.id,
    sample.start_location, sample.start_lat, sample.start_lng,
    sample.end_location, sample.end_lat, sample.end_lng,
    CURRENT_TIMESTAMP - INTERVAL '45 minutes',
    CURRENT_TIMESTAMP - INTERVAL '35 minutes',
    CURRENT_TIMESTAMP + INTERVAL '70 minutes',
    'IN_PROGRESS', sample.progress, sample.risk_level,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE
FROM (
    VALUES
        ('SF-DEMO-1001', '29C-123.45', 'DEMO-B2-1001', 'Kho Long Biên', 21.04520::double precision, 105.87940::double precision, 'KCN Thăng Long', 21.15480::double precision, 105.78510::double precision, 48, 'LOW'),
        ('SF-DEMO-1002', '30H-456.78', 'DEMO-C-1002', 'Bến xe Yên Nghĩa', 20.95160::double precision, 105.74720::double precision, 'Sân bay Nội Bài', 21.21870::double precision, 105.80420::double precision, 63, 'MEDIUM')
) AS sample(
    trip_code, plate_number, license_number, start_location, start_lat, start_lng,
    end_location, end_lat, end_lng, progress, risk_level
)
JOIN vehicles vehicle ON vehicle.plate_number = sample.plate_number
JOIN drivers driver ON driver.license_number = sample.license_number
ON CONFLICT (trip_code) DO NOTHING;

INSERT INTO telemetry_logs (
    vehicle_id, driver_id, trip_id, lat, lng, speed, heading,
    battery_level, gps_status, created_at, client_event_id,
    recorded_at, received_at
)
SELECT
    vehicle.id, driver.id, trip.id, sample.lat, sample.lng, sample.speed,
    sample.heading, sample.battery, 'GOOD', CURRENT_TIMESTAMP,
    sample.client_event_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    VALUES
        ('29C-123.45', 'DEMO-B2-1001', 'SF-DEMO-1001', 21.02890::double precision, 105.86220::double precision, 42.0::double precision, 315.0::double precision, 91, 'demo-map-v19-1001'),
        ('30H-456.78', 'DEMO-C-1002', 'SF-DEMO-1002', 21.01580::double precision, 105.80480::double precision, 35.0::double precision, 18.0::double precision, 83, 'demo-map-v19-1002'),
        ('29D-789.01', 'DEMO-C-1003', NULL, 21.04150::double precision, 105.79020::double precision, 0.0::double precision, 0.0::double precision, 76, 'demo-map-v19-1003')
) AS sample(
    plate_number, license_number, trip_code, lat, lng, speed,
    heading, battery, client_event_id
)
JOIN vehicles vehicle ON vehicle.plate_number = sample.plate_number
JOIN drivers driver ON driver.license_number = sample.license_number
LEFT JOIN trips trip ON trip.trip_code = sample.trip_code
WHERE NOT EXISTS (
    SELECT 1 FROM telemetry_logs existing
    WHERE existing.driver_id = driver.id
      AND existing.client_event_id = sample.client_event_id
);

INSERT INTO flood_reports (
    lat, lng, address, severity, source, reported_by_driver_id,
    confidence, status, verified_at, expired_at,
    created_at, updated_at, deleted, client_event_id, received_at,
    geometry_type, radius_meters, hazard_type
)
SELECT
    sample.lat, sample.lng, sample.address, sample.severity, 'DRIVER_REPORT', driver.id,
    sample.confidence, 'VERIFIED', CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP + INTERVAL '7 days',
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE, sample.client_event_id,
    CURRENT_TIMESTAMP, 'POINT', sample.radius_meters, sample.hazard_type
FROM (
    VALUES
        (21.00240::double precision, 105.81510::double precision, '[MẪU] Ngập nhẹ tại hầm chui Lê Văn Lương', 'MEDIUM', 0.82::double precision, 180.0::double precision, 'FLOOD', 'demo-hazard-v19-1001', 'DEMO-B2-1001'),
        (20.98880::double precision, 105.80270::double precision, '[MẪU] Nước dâng trên đường Nguyễn Xiển', 'HIGH', 0.91::double precision, 240.0::double precision, 'FLOOD', 'demo-hazard-v19-1002', 'DEMO-C-1002'),
        (21.03610::double precision, 105.78920::double precision, '[MẪU] Ùn tắc Vành đai 3 - Cầu Giấy', 'HIGH', 0.88::double precision, 320.0::double precision, 'TRAFFIC_JAM', 'demo-hazard-v19-1003', 'DEMO-C-1003')
) AS sample(
    lat, lng, address, severity, confidence, radius_meters,
    hazard_type, client_event_id, license_number
)
JOIN drivers driver ON driver.license_number = sample.license_number
WHERE NOT EXISTS (
    SELECT 1 FROM flood_reports existing
    WHERE existing.reported_by_driver_id = driver.id
      AND existing.client_event_id = sample.client_event_id
);
