-- SafeFleet full MySQL database script
-- Chay file nay de reset toan bo database: xoa DB cu, tao DB moi, tao bang, index, foreign key va seed data.
-- Default demo password for all users: 123456

SET NAMES utf8mb4;
SET SQL_MODE = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS safefleet;
CREATE DATABASE safefleet
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE safefleet;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- 1. RBAC / Account
-- =========================================================

CREATE TABLE permissions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id),
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(80) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    status VARCHAR(30) NOT NULL,
    role_id BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id),
    INDEX idx_users_email (email),
    INDEX idx_users_status (status),
    INDEX idx_users_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- 2. Driver / Vehicle / Device
-- =========================================================

CREATE TABLE drivers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(120),
    address VARCHAR(255),
    license_number VARCHAR(50) NOT NULL UNIQUE,
    license_class VARCHAR(20) NOT NULL,
    license_expired_at DATE NOT NULL,
    status VARCHAR(30) NOT NULL,
    current_vehicle_id BIGINT,
    safety_score INT NOT NULL DEFAULT 100,
    driving_time_today_minutes INT NOT NULL DEFAULT 0,
    continuous_driving_minutes INT NOT NULL DEFAULT 0,
    total_trips INT NOT NULL DEFAULT 0,
    total_alerts INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_drivers_user FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_drivers_status (status),
    INDEX idx_drivers_license_class (license_class),
    INDEX idx_drivers_safety_score (safety_score),
    INDEX idx_drivers_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE vehicles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    plate_number VARCHAR(30) NOT NULL UNIQUE,
    vehicle_type VARCHAR(30) NOT NULL,
    brand VARCHAR(80),
    model VARCHAR(80),
    manufacture_year INT,
    load_capacity DECIMAL(10, 2),
    seat_count INT,
    fuel_type VARCHAR(30),
    status VARCHAR(30) NOT NULL,
    current_driver_id BIGINT,
    gps_device_id BIGINT,
    camera_device_id BIGINT,
    inspection_expired_at DATE,
    insurance_expired_at DATE,
    last_lat DOUBLE,
    last_lng DOUBLE,
    last_speed DOUBLE,
    last_updated_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_vehicles_plate_number (plate_number),
    INDEX idx_vehicles_type_status (vehicle_type, status),
    INDEX idx_vehicles_status (status),
    INDEX idx_vehicles_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE devices (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    type VARCHAR(40) NOT NULL,
    status VARCHAR(30) NOT NULL,
    vehicle_id BIGINT,
    phone VARCHAR(20),
    serial_number VARCHAR(80),
    firmware_version VARCHAR(40),
    last_seen_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_devices_type_status (type, status),
    INDEX idx_devices_vehicle (vehicle_id),
    INDEX idx_devices_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE drivers
    ADD CONSTRAINT fk_drivers_current_vehicle FOREIGN KEY (current_vehicle_id) REFERENCES vehicles(id);

ALTER TABLE vehicles
    ADD CONSTRAINT fk_vehicles_current_driver FOREIGN KEY (current_driver_id) REFERENCES drivers(id),
    ADD CONSTRAINT fk_vehicles_gps_device FOREIGN KEY (gps_device_id) REFERENCES devices(id),
    ADD CONSTRAINT fk_vehicles_camera_device FOREIGN KEY (camera_device_id) REFERENCES devices(id);

ALTER TABLE devices
    ADD CONSTRAINT fk_devices_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id);

CREATE TABLE device_connection_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id BIGINT NOT NULL,
    status VARCHAR(30) NOT NULL,
    lat DOUBLE,
    lng DOUBLE,
    note VARCHAR(255),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_device_logs_device FOREIGN KEY (device_id) REFERENCES devices(id),
    INDEX idx_device_logs_device_created (device_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- 3. Trip / Telemetry
-- =========================================================

CREATE TABLE trips (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    trip_code VARCHAR(50) NOT NULL UNIQUE,
    vehicle_id BIGINT,
    driver_id BIGINT,
    start_location VARCHAR(255) NOT NULL,
    start_lat DOUBLE,
    start_lng DOUBLE,
    end_location VARCHAR(255) NOT NULL,
    end_lat DOUBLE,
    end_lng DOUBLE,
    waypoints_json JSON,
    planned_route_json JSON,
    actual_route_json JSON,
    planned_start_time DATETIME(6),
    actual_start_time DATETIME(6),
    estimated_end_time DATETIME(6),
    actual_end_time DATETIME(6),
    status VARCHAR(30) NOT NULL,
    progress INT NOT NULL DEFAULT 0,
    risk_level VARCHAR(30) NOT NULL,
    cancel_reason VARCHAR(255),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_trips_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    INDEX idx_trips_status (status),
    INDEX idx_trips_vehicle_status (vehicle_id, status),
    INDEX idx_trips_driver_status (driver_id, status),
    INDEX idx_trips_planned_start (planned_start_time),
    INDEX idx_trips_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE trip_timelines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    trip_id BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    actor_id BIGINT,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_trip_timelines_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_trip_timelines_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_trip_timelines_trip_created (trip_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE telemetry_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    vehicle_id BIGINT NOT NULL,
    driver_id BIGINT,
    trip_id BIGINT,
    lat DOUBLE NOT NULL,
    lng DOUBLE NOT NULL,
    speed DOUBLE,
    heading DOUBLE,
    battery_level INT,
    gps_status VARCHAR(30) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_telemetry_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_telemetry_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_telemetry_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_telemetry_vehicle_created (vehicle_id, created_at),
    INDEX idx_telemetry_trip_created (trip_id, created_at),
    INDEX idx_telemetry_driver_created (driver_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- 4. Safety / Driving Time
-- =========================================================

CREATE TABLE safety_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_type VARCHAR(40) NOT NULL,
    severity VARCHAR(30) NOT NULL,
    vehicle_id BIGINT,
    driver_id BIGINT,
    trip_id BIGINT,
    lat DOUBLE,
    lng DOUBLE,
    speed DOUBLE,
    confidence DOUBLE,
    evidence_url VARCHAR(500),
    status VARCHAR(30) NOT NULL,
    handled_by BIGINT,
    handled_at DATETIME(6),
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_safety_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_safety_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_safety_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_safety_handled_by FOREIGN KEY (handled_by) REFERENCES users(id),
    INDEX idx_safety_status_severity_created (status, severity, created_at),
    INDEX idx_safety_vehicle_created (vehicle_id, created_at),
    INDEX idx_safety_driver_created (driver_id, created_at),
    INDEX idx_safety_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE driving_sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    driver_id BIGINT NOT NULL,
    vehicle_id BIGINT,
    trip_id BIGINT,
    status VARCHAR(30) NOT NULL,
    started_at DATETIME(6) NOT NULL,
    paused_at DATETIME(6),
    resumed_at DATETIME(6),
    ended_at DATETIME(6),
    continuous_minutes INT NOT NULL DEFAULT 0,
    total_minutes INT NOT NULL DEFAULT 0,
    over_driving_alert_created BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_driving_sessions_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_driving_sessions_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_driving_sessions_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_driving_sessions_driver_status (driver_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE driver_work_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    driver_id BIGINT NOT NULL,
    trip_id BIGINT,
    work_date DATE NOT NULL,
    driving_minutes INT NOT NULL DEFAULT 0,
    rest_minutes INT NOT NULL DEFAULT 0,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_driver_work_logs_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_driver_work_logs_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_driver_work_logs_driver_date (driver_id, work_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- 5. Incident / Flood / Maintenance / Notification / Settings / Audit
-- =========================================================

CREATE TABLE incidents (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    incident_code VARCHAR(50) NOT NULL UNIQUE,
    type VARCHAR(40) NOT NULL,
    severity VARCHAR(30) NOT NULL,
    vehicle_id BIGINT,
    driver_id BIGINT,
    trip_id BIGINT,
    lat DOUBLE,
    lng DOUBLE,
    description VARCHAR(1000),
    status VARCHAR(30) NOT NULL,
    assigned_to BIGINT,
    accepted_at DATETIME(6),
    resolved_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_incidents_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_incidents_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_incidents_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_incidents_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id),
    INDEX idx_incidents_status_severity (status, severity),
    INDEX idx_incidents_vehicle_created (vehicle_id, created_at),
    INDEX idx_incidents_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE incident_timelines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    incident_id BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    actor_id BIGINT,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_incident_timelines_incident FOREIGN KEY (incident_id) REFERENCES incidents(id),
    CONSTRAINT fk_incident_timelines_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_incident_timelines_incident_created (incident_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE flood_reports (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    lat DOUBLE NOT NULL,
    lng DOUBLE NOT NULL,
    address VARCHAR(255),
    severity VARCHAR(30) NOT NULL,
    source VARCHAR(40) NOT NULL,
    reported_by_driver_id BIGINT,
    image_url VARCHAR(500),
    confidence DOUBLE,
    status VARCHAR(30) NOT NULL,
    verified_by BIGINT,
    verified_at DATETIME(6),
    expired_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_flood_reported_by_driver FOREIGN KEY (reported_by_driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_flood_verified_by FOREIGN KEY (verified_by) REFERENCES users(id),
    INDEX idx_flood_status_severity (status, severity),
    INDEX idx_flood_location (lat, lng),
    INDEX idx_flood_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE maintenance_orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    maintenance_code VARCHAR(50) NOT NULL UNIQUE,
    vehicle_id BIGINT NOT NULL,
    type VARCHAR(30) NOT NULL,
    title VARCHAR(150) NOT NULL,
    description VARCHAR(1000),
    scheduled_date DATE,
    completed_date DATE,
    cost DECIMAL(12, 2),
    status VARCHAR(30) NOT NULL,
    priority VARCHAR(30) NOT NULL,
    assigned_to BIGINT,
    note VARCHAR(1000),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_maintenance_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id),
    INDEX idx_maintenance_vehicle_status (vehicle_id, status),
    INDEX idx_maintenance_scheduled_date (scheduled_date),
    INDEX idx_maintenance_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    recipient_id BIGINT,
    type VARCHAR(40) NOT NULL,
    title VARCHAR(150) NOT NULL,
    content VARCHAR(500) NOT NULL,
    reference_type VARCHAR(50),
    reference_id BIGINT,
    read_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_id) REFERENCES users(id),
    INDEX idx_notifications_recipient_created (recipient_id, created_at),
    INDEX idx_notifications_read_at (read_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE system_settings (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_group VARCHAR(40) NOT NULL,
    setting_value TEXT NOT NULL,
    value_type VARCHAR(30) NOT NULL,
    description VARCHAR(255),
    updated_by BIGINT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_system_settings_updated_by FOREIGN KEY (updated_by) REFERENCES users(id),
    INDEX idx_system_settings_group (setting_group),
    INDEX idx_system_settings_deleted (deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    actor_id BIGINT,
    action VARCHAR(120) NOT NULL,
    target_type VARCHAR(80),
    target_id BIGINT,
    ip_address VARCHAR(80),
    user_agent VARCHAR(255),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_audit_logs_actor_created (actor_id, created_at),
    INDEX idx_audit_logs_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Flyway compatibility:
-- Backend dang bat Flyway. Baseline version 2 giup app khong chay lai V1/V2 khi ban da import file SQL doc lap nay.
CREATE TABLE flyway_schema_history (
    installed_rank INT NOT NULL,
    version VARCHAR(50),
    description VARCHAR(200) NOT NULL,
    type VARCHAR(20) NOT NULL,
    script VARCHAR(1000) NOT NULL,
    checksum INT,
    installed_by VARCHAR(100) NOT NULL,
    installed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_time INT NOT NULL,
    success BOOLEAN NOT NULL,
    CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank),
    INDEX flyway_schema_history_s_idx (success)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================
-- 6. Seed data
-- =========================================================

START TRANSACTION;

INSERT INTO permissions (id, code, description) VALUES
(1, 'ACCOUNT_READ', 'Read accounts'),
(2, 'ACCOUNT_WRITE', 'Create and update accounts'),
(3, 'VEHICLE_READ', 'Read vehicles'),
(4, 'VEHICLE_WRITE', 'Create and update vehicles'),
(5, 'DRIVER_READ', 'Read drivers'),
(6, 'DRIVER_WRITE', 'Create and update drivers'),
(7, 'TRIP_READ', 'Read trips'),
(8, 'TRIP_WRITE', 'Create and dispatch trips'),
(9, 'SAFETY_READ', 'Read safety events'),
(10, 'SAFETY_HANDLE', 'Handle safety events'),
(11, 'INCIDENT_READ', 'Read incidents'),
(12, 'INCIDENT_HANDLE', 'Handle incidents'),
(13, 'FLOOD_READ', 'Read flood reports'),
(14, 'FLOOD_WRITE', 'Create and verify flood reports'),
(15, 'REPORT_READ', 'Read reports'),
(16, 'SETTING_WRITE', 'Update system settings');

INSERT INTO roles (id, name, description) VALUES
(1, 'ADMIN', 'System administrator'),
(2, 'FLEET_MANAGER', 'Fleet manager'),
(3, 'DISPATCHER', 'Trip dispatcher'),
(4, 'SAFETY_OFFICER', 'Safety monitoring officer'),
(5, 'RESCUE_TEAM', 'Rescue team member'),
(6, 'DRIVER', 'Driver mobile app user');

INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions;

INSERT INTO role_permissions (role_id, permission_id) VALUES
(2, 1), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 11), (2, 13), (2, 15),
(3, 3), (3, 5), (3, 7), (3, 8), (3, 11), (3, 12), (3, 13),
(4, 3), (4, 5), (4, 7), (4, 9), (4, 10), (4, 11), (4, 13), (4, 15),
(5, 11), (5, 12),
(6, 7), (6, 9), (6, 13);

-- BCrypt hash for password: 123456
SET @pwd = '$2a$10$CR12WGOuw0fPrtAEo9r0g.TR2CbpEaXMJdOY4Z/NUduNSTU/Y3tAG';

INSERT INTO users (id, username, email, password_hash, full_name, phone, status, role_id) VALUES
(1, 'admin', 'admin@safefleet.vn', @pwd, 'Quan tri he thong', '0901000001', 'ACTIVE', 1),
(2, 'manager', 'manager@safefleet.vn', @pwd, 'Quan ly doi xe', '0901000002', 'ACTIVE', 2),
(3, 'dispatcher', 'dispatcher@safefleet.vn', @pwd, 'Dieu phoi Ha Noi', '0901000003', 'ACTIVE', 3),
(4, 'safety', 'safety@safefleet.vn', @pwd, 'Nhan vien an toan', '0901000004', 'ACTIVE', 4),
(5, 'rescue', 'rescue@safefleet.vn', @pwd, 'Doi cuu ho', '0901000005', 'ACTIVE', 5),
(6, 'driver01', 'driver01@safefleet.vn', @pwd, 'Nguyen Van An', '0988000001', 'ACTIVE', 6),
(7, 'driver02', 'driver02@safefleet.vn', @pwd, 'Tran Minh Duc', '0988000002', 'ACTIVE', 6),
(8, 'driver03', 'driver03@safefleet.vn', @pwd, 'Le Quang Huy', '0988000003', 'ACTIVE', 6),
(9, 'driver04', 'driver04@safefleet.vn', @pwd, 'Pham Tuan Anh', '0988000004', 'ACTIVE', 6),
(10, 'driver05', 'driver05@safefleet.vn', @pwd, 'Do Van Nam', '0988000005', 'ACTIVE', 6),
(11, 'driver06', 'driver06@safefleet.vn', @pwd, 'Hoang Manh Cuong', '0988000006', 'ACTIVE', 6),
(12, 'driver07', 'driver07@safefleet.vn', @pwd, 'Vu Thanh Long', '0988000007', 'ACTIVE', 6),
(13, 'driver08', 'driver08@safefleet.vn', @pwd, 'Bui Hai Dang', '0988000008', 'ACTIVE', 6),
(14, 'driver09', 'driver09@safefleet.vn', @pwd, 'Dang Quoc Viet', '0988000009', 'ACTIVE', 6),
(15, 'driver10', 'driver10@safefleet.vn', @pwd, 'Phan Van Son', '0988000010', 'ACTIVE', 6),
(16, 'driver11', 'driver11@safefleet.vn', @pwd, 'Nguyen Duc Thang', '0988000011', 'ACTIVE', 6),
(17, 'driver12', 'driver12@safefleet.vn', @pwd, 'Tran Bao Khanh', '0988000012', 'ACTIVE', 6),
(18, 'driver13', 'driver13@safefleet.vn', @pwd, 'Le Thanh Tung', '0988000013', 'ACTIVE', 6),
(19, 'driver14', 'driver14@safefleet.vn', @pwd, 'Pham Dinh Khoa', '0988000014', 'ACTIVE', 6),
(20, 'driver15', 'driver15@safefleet.vn', @pwd, 'Do Minh Quan', '0988000015', 'ACTIVE', 6);

INSERT INTO drivers (id, user_id, full_name, phone, email, address, license_number, license_class, license_expired_at, status, safety_score, driving_time_today_minutes, continuous_driving_minutes, total_trips, total_alerts) VALUES
(1, 6, 'Nguyen Van An', '0988000001', 'driver01@safefleet.vn', 'Ha Dong', 'HN-B2-00001', 'B2', DATE_ADD(CURDATE(), INTERVAL 24 MONTH), 'AVAILABLE', 96, 0, 0, 12, 1),
(2, 7, 'Tran Minh Duc', '0988000002', 'driver02@safefleet.vn', 'Cau Giay', 'HN-B2-00002', 'B2', DATE_ADD(CURDATE(), INTERVAL 25 MONTH), 'AVAILABLE', 93, 12, 30, 18, 1),
(3, 8, 'Le Quang Huy', '0988000003', 'driver03@safefleet.vn', 'My Dinh', 'HN-C-00003', 'C', DATE_ADD(CURDATE(), INTERVAL 26 MONTH), 'AVAILABLE', 90, 24, 60, 10, 1),
(4, 9, 'Pham Tuan Anh', '0988000004', 'driver04@safefleet.vn', 'Nguyen Trai', 'HN-B2-00004', 'B2', DATE_ADD(CURDATE(), INTERVAL 27 MONTH), 'AVAILABLE', 87, 36, 90, 14, 1),
(5, 10, 'Do Van Nam', '0988000005', 'driver05@safefleet.vn', 'Dai lo Thang Long', 'HN-C-00005', 'C', DATE_ADD(CURDATE(), INTERVAL 28 MONTH), 'AVAILABLE', 84, 48, 120, 9, 1),
(6, 11, 'Hoang Manh Cuong', '0988000006', 'driver06@safefleet.vn', 'Kieu Mai', 'HN-B2-00006', 'B2', DATE_ADD(CURDATE(), INTERVAL 29 MONTH), 'AVAILABLE', 81, 60, 0, 22, 1),
(7, 12, 'Vu Thanh Long', '0988000007', 'driver07@safefleet.vn', 'Phu Dien', 'HN-C-00007', 'C', DATE_ADD(CURDATE(), INTERVAL 30 MONTH), 'AVAILABLE', 78, 72, 30, 11, 1),
(8, 13, 'Bui Hai Dang', '0988000008', 'driver08@safefleet.vn', 'Ho Tung Mau', 'HN-B2-00008', 'B2', DATE_ADD(CURDATE(), INTERVAL 31 MONTH), 'AVAILABLE', 75, 84, 60, 13, 1),
(9, 14, 'Dang Quoc Viet', '0988000009', 'driver09@safefleet.vn', 'Pham Van Dong', 'HN-C-00009', 'C', DATE_ADD(CURDATE(), INTERVAL 32 MONTH), 'AVAILABLE', 72, 96, 90, 7, 1),
(10, 15, 'Phan Van Son', '0988000010', 'driver10@safefleet.vn', 'Ha Dong', 'HN-B2-00010', 'B2', DATE_ADD(CURDATE(), INTERVAL 33 MONTH), 'AVAILABLE', 69, 108, 120, 16, 1),
(11, 16, 'Nguyen Duc Thang', '0988000011', 'driver11@safefleet.vn', 'Cau Giay', 'HN-C-00011', 'C', DATE_ADD(CURDATE(), INTERVAL 34 MONTH), 'AVAILABLE', 66, 120, 0, 8, 1),
(12, 17, 'Tran Bao Khanh', '0988000012', 'driver12@safefleet.vn', 'My Dinh', 'HN-B2-00012', 'B2', DATE_ADD(CURDATE(), INTERVAL 35 MONTH), 'AVAILABLE', 63, 132, 30, 6, 1),
(13, 18, 'Le Thanh Tung', '0988000013', 'driver13@safefleet.vn', 'Nguyen Trai', 'HN-C-00013', 'C', DATE_ADD(CURDATE(), INTERVAL 36 MONTH), 'HIGH_RISK', 48, 144, 180, 5, 1),
(14, 19, 'Pham Dinh Khoa', '0988000014', 'driver14@safefleet.vn', 'Phu Dien', 'HN-B2-00014', 'B2', DATE_ADD(CURDATE(), INTERVAL 37 MONTH), 'AVAILABLE', 57, 156, 150, 9, 1),
(15, 20, 'Do Minh Quan', '0988000015', 'driver15@safefleet.vn', 'Ho Tung Mau', 'HN-C-00015', 'C', DATE_ADD(CURDATE(), INTERVAL 38 MONTH), 'AVAILABLE', 54, 168, 120, 4, 1);

INSERT INTO devices (id, device_code, name, type, status, phone, serial_number, firmware_version, last_seen_at) VALUES
(1, 'DEV-001', 'GPS Tracker 001', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00001', '1.0.1', NOW(6) - INTERVAL 3 MINUTE),
(2, 'DEV-002', 'GPS Tracker 002', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00002', '1.0.2', NOW(6) - INTERVAL 6 MINUTE),
(3, 'DEV-003', 'GPS Tracker 003', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00003', '1.0.3', NOW(6) - INTERVAL 9 MINUTE),
(4, 'DEV-004', 'GPS Tracker 004', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00004', '1.0.4', NOW(6) - INTERVAL 12 MINUTE),
(5, 'DEV-005', 'GPS Tracker 005', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00005', '1.0.5', NOW(6) - INTERVAL 15 MINUTE),
(6, 'DEV-006', 'GPS Tracker 006', 'GPS_TRACKER', 'ONLINE', NULL, 'SN-HN-00006', '1.0.6', NOW(6) - INTERVAL 18 MINUTE),
(7, 'DEV-007', 'Cabin Camera 001', 'CABIN_CAMERA', 'ONLINE', NULL, 'SN-HN-00007', '1.0.7', NOW(6) - INTERVAL 21 MINUTE),
(8, 'DEV-008', 'Cabin Camera 002', 'CABIN_CAMERA', 'ONLINE', NULL, 'SN-HN-00008', '1.0.8', NOW(6) - INTERVAL 24 MINUTE),
(9, 'DEV-009', 'Driver Phone 001', 'DRIVER_PHONE', 'OFFLINE', '0988000001', 'SN-HN-00009', '1.0.9', NULL),
(10, 'DEV-010', 'IoT Flood Sensor 001', 'IOT_FLOOD_SENSOR', 'OFFLINE', NULL, 'SN-HN-00010', '1.0.10', NULL);

INSERT INTO vehicles (id, plate_number, vehicle_type, brand, model, manufacture_year, load_capacity, seat_count, fuel_type, status, current_driver_id, gps_device_id, camera_device_id, inspection_expired_at, insurance_expired_at, last_lat, last_lng, last_speed, last_updated_at) VALUES
(1, '30H-100.01', 'TRUCK', 'Hyundai', 'Mighty', 2020, 1200.00, 3, 'ELECTRIC', 'AVAILABLE', 1, 1, 7, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 20.9719, 105.7788, 0.0, NOW(6)),
(2, '30H-101.02', 'VAN', 'Thaco', 'Frontier', 2021, 1450.00, 3, 'DIESEL', 'AVAILABLE', 2, 2, 8, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0362, 105.7906, 36.0, NOW(6) - INTERVAL 5 MINUTE),
(3, '30H-102.03', 'BUS', 'Toyota', 'Hiace', 2022, 1700.00, 29, 'DIESEL', 'AVAILABLE', 3, 3, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0285, 105.7784, 37.0, NOW(6) - INTERVAL 10 MINUTE),
(4, '30H-103.04', 'TRUCK', 'Ford', 'Transit', 2023, 1950.00, 3, 'DIESEL', 'AVAILABLE', 4, 4, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 20.9902, 105.8057, 38.0, NOW(6) - INTERVAL 15 MINUTE),
(5, '30H-104.05', 'VAN', 'Isuzu', 'NQR', 2024, 2200.00, 3, 'ELECTRIC', 'AVAILABLE', 5, 5, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0123, 105.7621, 39.0, NOW(6) - INTERVAL 20 MINUTE),
(6, '30H-105.06', 'BUS', 'Hyundai', 'Mighty', 2020, 2450.00, 29, 'DIESEL', 'AVAILABLE', 6, 6, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0521, 105.7353, 0.0, NOW(6) - INTERVAL 25 MINUTE),
(7, '30H-106.07', 'TRUCK', 'Thaco', 'Frontier', 2021, 2700.00, 3, 'DIESEL', 'AVAILABLE', 7, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0379, 105.7752, 41.0, NOW(6) - INTERVAL 30 MINUTE),
(8, '30H-107.08', 'VAN', 'Toyota', 'Hiace', 2022, 2950.00, 3, 'DIESEL', 'MAINTENANCE', 8, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0386, 105.7465, 42.0, NOW(6) - INTERVAL 35 MINUTE),
(9, '30H-108.09', 'BUS', 'Ford', 'Transit', 2023, 3200.00, 29, 'ELECTRIC', 'AVAILABLE', 9, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0631, 105.8014, 43.0, NOW(6) - INTERVAL 40 MINUTE),
(10, '30H-109.10', 'TRUCK', 'Isuzu', 'NQR', 2024, 3450.00, 3, 'DIESEL', 'OFFLINE', 10, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 6 MONTH), DATE_ADD(CURDATE(), INTERVAL 9 MONTH), 21.0348, 105.8083, 44.0, NOW(6) - INTERVAL 45 MINUTE),
(11, '30H-110.11', 'VAN', 'Hyundai', 'Mighty', 2020, 3700.00, 3, 'DIESEL', 'AVAILABLE', 11, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 20 DAY), DATE_ADD(CURDATE(), INTERVAL 25 DAY), 20.9842, 105.7954, 0.0, NOW(6) - INTERVAL 50 MINUTE),
(12, '30H-111.12', 'BUS', 'Thaco', 'Frontier', 2021, 3950.00, 29, 'DIESEL', 'AVAILABLE', 12, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 21 DAY), DATE_ADD(CURDATE(), INTERVAL 26 DAY), 21.0204, 105.7821, 46.0, NOW(6) - INTERVAL 55 MINUTE),
(13, '30H-112.13', 'TRUCK', 'Toyota', 'Hiace', 2022, 4200.00, 3, 'ELECTRIC', 'AVAILABLE', 13, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 22 DAY), DATE_ADD(CURDATE(), INTERVAL 27 DAY), 21.0465, 105.7649, 47.0, NOW(6) - INTERVAL 60 MINUTE),
(14, '30H-113.14', 'VAN', 'Ford', 'Transit', 2023, 4450.00, 3, 'DIESEL', 'AVAILABLE', 14, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 23 DAY), DATE_ADD(CURDATE(), INTERVAL 28 DAY), 21.0189, 105.8121, 48.0, NOW(6) - INTERVAL 65 MINUTE),
(15, '30H-114.15', 'BUS', 'Isuzu', 'NQR', 2024, 4700.00, 29, 'DIESEL', 'AVAILABLE', 15, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 24 DAY), DATE_ADD(CURDATE(), INTERVAL 29 DAY), 21.0703, 105.7832, 49.0, NOW(6) - INTERVAL 70 MINUTE),
(16, '30H-115.16', 'TRUCK', 'Hyundai', 'Mighty', 2020, 4950.00, 3, 'DIESEL', 'AVAILABLE', NULL, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 8 MONTH), DATE_ADD(CURDATE(), INTERVAL 11 MONTH), 20.9977, 105.8321, 0.0, NOW(6) - INTERVAL 75 MINUTE),
(17, '30H-116.17', 'VAN', 'Thaco', 'Frontier', 2021, 5200.00, 3, 'ELECTRIC', 'AVAILABLE', NULL, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 8 MONTH), DATE_ADD(CURDATE(), INTERVAL 11 MONTH), 21.0242, 105.8211, 51.0, NOW(6) - INTERVAL 80 MINUTE),
(18, '30H-117.18', 'BUS', 'Toyota', 'Hiace', 2022, 5450.00, 29, 'DIESEL', 'AVAILABLE', NULL, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 8 MONTH), DATE_ADD(CURDATE(), INTERVAL 11 MONTH), 21.0567, 105.8123, 52.0, NOW(6) - INTERVAL 85 MINUTE),
(19, '30H-118.19', 'TRUCK', 'Ford', 'Transit', 2023, 5700.00, 3, 'DIESEL', 'AVAILABLE', NULL, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 8 MONTH), DATE_ADD(CURDATE(), INTERVAL 11 MONTH), 20.9634, 105.7945, 53.0, NOW(6) - INTERVAL 90 MINUTE),
(20, '30H-119.20', 'VAN', 'Isuzu', 'NQR', 2024, 5950.00, 3, 'DIESEL', 'AVAILABLE', NULL, NULL, NULL, DATE_ADD(CURDATE(), INTERVAL 8 MONTH), DATE_ADD(CURDATE(), INTERVAL 11 MONTH), 21.0412, 105.7305, 54.0, NOW(6) - INTERVAL 95 MINUTE);

UPDATE drivers SET current_vehicle_id = id WHERE id BETWEEN 1 AND 15;
UPDATE devices SET vehicle_id = id WHERE id BETWEEN 1 AND 6;
UPDATE devices SET vehicle_id = id - 6 WHERE id BETWEEN 7 AND 8;

INSERT INTO device_connection_logs (device_id, status, lat, lng, note, created_at) VALUES
(1, 'ONLINE', 20.9719, 105.7788, 'Seed online GPS', NOW(6) - INTERVAL 30 MINUTE),
(2, 'ONLINE', 21.0362, 105.7906, 'Seed online GPS', NOW(6) - INTERVAL 25 MINUTE),
(3, 'ONLINE', 21.0285, 105.7784, 'Seed online GPS', NOW(6) - INTERVAL 20 MINUTE),
(9, 'OFFLINE', NULL, NULL, 'Driver phone offline', NOW(6) - INTERVAL 15 MINUTE),
(10, 'OFFLINE', NULL, NULL, 'Flood sensor maintenance', NOW(6) - INTERVAL 10 MINUTE);

INSERT INTO trips (id, trip_code, vehicle_id, driver_id, start_location, start_lat, start_lng, end_location, end_lat, end_lng, waypoints_json, planned_route_json, actual_route_json, planned_start_time, actual_start_time, estimated_end_time, actual_end_time, status, progress, risk_level) VALUES
(1, 'DEMO-TRIP-001', 1, 1, 'Ha Dong', 20.9719, 105.7788, 'Kieu Mai', 21.0526, 105.7350, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 5 DAY, NOW(6) - INTERVAL 5 DAY + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 5 DAY + INTERVAL 2 HOUR, NOW(6) - INTERVAL 5 DAY + INTERVAL 2 HOUR + INTERVAL 5 MINUTE, 'COMPLETED', 100, 'HIGH'),
(2, 'DEMO-TRIP-002', 2, 2, 'Cau Giay', 21.0362, 105.7906, 'Phu Dien', 21.0383, 105.7754, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 4 DAY, NOW(6) - INTERVAL 4 DAY + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 4 DAY + INTERVAL 2 HOUR, NOW(6) - INTERVAL 4 DAY + INTERVAL 2 HOUR + INTERVAL 10 MINUTE, 'COMPLETED', 100, 'LOW'),
(3, 'DEMO-TRIP-003', 3, 3, 'My Dinh', 21.0285, 105.7784, 'Ho Tung Mau', 21.0390, 105.7462, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 3 DAY, NOW(6) - INTERVAL 3 DAY + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 3 DAY + INTERVAL 2 HOUR, NOW(6) - INTERVAL 3 DAY + INTERVAL 2 HOUR + INTERVAL 12 MINUTE, 'COMPLETED', 100, 'LOW'),
(4, 'DEMO-TRIP-004', 4, 4, 'Nguyen Trai', 20.9902, 105.8057, 'Pham Van Dong', 21.0631, 105.8014, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 2 DAY, NOW(6) - INTERVAL 2 DAY + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 2 DAY + INTERVAL 2 HOUR, NOW(6) - INTERVAL 2 DAY + INTERVAL 2 HOUR + INTERVAL 8 MINUTE, 'COMPLETED', 100, 'LOW'),
(5, 'DEMO-TRIP-005', 5, 5, 'Dai lo Thang Long', 21.0123, 105.7621, 'Cau Giay', 21.0362, 105.7906, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 1 DAY, NOW(6) - INTERVAL 1 DAY + INTERVAL 10 MINUTE, NOW(6) - INTERVAL 1 DAY + INTERVAL 2 HOUR, NULL, 'IN_PROGRESS', 70, 'MEDIUM'),
(6, 'DEMO-TRIP-006', 6, 6, 'Kieu Mai', 21.0521, 105.7353, 'Ha Dong', 20.9719, 105.7788, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 8 HOUR, NOW(6) - INTERVAL 8 HOUR + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 6 HOUR, NULL, 'IN_PROGRESS', 65, 'LOW'),
(7, 'DEMO-TRIP-007', 7, 7, 'Phu Dien', 21.0379, 105.7752, 'Nguyen Trai', 20.9902, 105.8057, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) - INTERVAL 4 HOUR, NOW(6) - INTERVAL 4 HOUR + INTERVAL 5 MINUTE, NOW(6) - INTERVAL 2 HOUR, NULL, 'IN_PROGRESS', 50, 'LOW'),
(8, 'DEMO-TRIP-008', 8, 8, 'Ho Tung Mau', 21.0386, 105.7465, 'My Dinh', 21.0285, 105.7784, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) + INTERVAL 1 HOUR, NULL, NOW(6) + INTERVAL 3 HOUR, NULL, 'ASSIGNED', 0, 'LOW'),
(9, 'DEMO-TRIP-009', 9, 9, 'Pham Van Dong', 21.0631, 105.8014, 'Cau Giay', 21.0362, 105.7906, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) + INTERVAL 2 HOUR, NULL, NOW(6) + INTERVAL 4 HOUR, NULL, 'ASSIGNED', 0, 'MEDIUM'),
(10, 'DEMO-TRIP-010', 10, 10, 'Cau Giay', 21.0348, 105.8083, 'Dai lo Thang Long', 21.0123, 105.7621, JSON_ARRAY(), JSON_ARRAY(), JSON_ARRAY(), NOW(6) + INTERVAL 3 HOUR, NULL, NOW(6) + INTERVAL 5 HOUR, NULL, 'ASSIGNED', 0, 'LOW');

INSERT INTO trip_timelines (trip_id, action, actor_id, note, created_at) VALUES
(1, 'CREATED', 3, 'Seed trip created', NOW(6) - INTERVAL 5 DAY),
(1, 'COMPLETED', 3, 'Seed trip completed', NOW(6) - INTERVAL 5 DAY + INTERVAL 2 HOUR),
(5, 'STARTED', 3, 'Trip started', NOW(6) - INTERVAL 1 DAY),
(8, 'ASSIGNED', 3, 'Assigned to driver', NOW(6) - INTERVAL 2 HOUR),
(10, 'ASSIGNED', 3, 'Assigned to driver', NOW(6) - INTERVAL 1 HOUR);

INSERT INTO telemetry_logs (vehicle_id, driver_id, trip_id, lat, lng, speed, heading, battery_level, gps_status, created_at) VALUES
(1, 1, 1, 20.9719, 105.7788, 35.0, 90.0, 86, 'GOOD', NOW(6) - INTERVAL 5 DAY),
(1, 1, 1, 20.9820, 105.7850, 42.0, 95.0, 84, 'GOOD', NOW(6) - INTERVAL 5 DAY + INTERVAL 30 MINUTE),
(1, 1, 1, 20.9950, 105.7920, 40.0, 96.0, 82, 'GOOD', NOW(6) - INTERVAL 5 DAY + INTERVAL 60 MINUTE),
(5, 5, 5, 21.0123, 105.7621, 38.0, 70.0, 79, 'GOOD', NOW(6) - INTERVAL 2 HOUR),
(5, 5, 5, 21.0180, 105.7710, 45.0, 73.0, 77, 'GOOD', NOW(6) - INTERVAL 90 MINUTE),
(5, 5, 5, 21.0240, 105.7810, 50.0, 74.0, 75, 'GOOD', NOW(6) - INTERVAL 60 MINUTE),
(6, 6, 6, 21.0521, 105.7353, 0.0, 0.0, 91, 'WEAK', NOW(6) - INTERVAL 50 MINUTE),
(6, 6, 6, 21.0490, 105.7420, 28.0, 120.0, 89, 'GOOD', NOW(6) - INTERVAL 40 MINUTE),
(7, 7, 7, 21.0379, 105.7752, 39.0, 180.0, 72, 'GOOD', NOW(6) - INTERVAL 30 MINUTE),
(7, 7, 7, 21.0310, 105.7840, 43.0, 185.0, 70, 'GOOD', NOW(6) - INTERVAL 20 MINUTE);

INSERT INTO safety_events (id, event_type, severity, vehicle_id, driver_id, trip_id, lat, lng, speed, confidence, evidence_url, status, handled_by, handled_at, note, created_at) VALUES
(1, 'DROWSINESS', 'CRITICAL', 1, 1, 1, 20.9719, 105.7788, 40.0, 0.92, 'https://demo.safefleet.vn/evidence/001.jpg', 'ACKNOWLEDGED', 4, NOW(6) - INTERVAL 20 HOUR, 'Driver showed drowsiness signs', NOW(6) - INTERVAL 21 HOUR),
(2, 'PHONE_USAGE', 'HIGH', 2, 2, 2, 21.0362, 105.7906, 45.0, 0.88, 'https://demo.safefleet.vn/evidence/002.jpg', 'NEW', NULL, NULL, 'Phone usage detected', NOW(6) - INTERVAL 19 HOUR),
(3, 'DISTRACTION', 'MEDIUM', 3, 3, 3, 21.0285, 105.7784, 38.0, 0.78, 'https://demo.safefleet.vn/evidence/003.jpg', 'NEW', NULL, NULL, 'Driver distraction', NOW(6) - INTERVAL 18 HOUR),
(4, 'SPEEDING', 'HIGH', 4, 4, 4, 20.9902, 105.8057, 75.0, 0.91, 'https://demo.safefleet.vn/evidence/004.jpg', 'ACKNOWLEDGED', 4, NOW(6) - INTERVAL 17 HOUR, 'Speeding on Nguyen Trai', NOW(6) - INTERVAL 17 HOUR),
(5, 'OVER_DRIVING_TIME', 'HIGH', 5, 5, 5, 21.0123, 105.7621, 35.0, 1.00, NULL, 'NEW', NULL, NULL, 'Continuous driving warning', NOW(6) - INTERVAL 16 HOUR),
(6, 'ROUTE_DEVIATION', 'MEDIUM', 6, 6, 6, 21.0521, 105.7353, 32.0, 0.74, NULL, 'NEW', NULL, NULL, 'Route deviation detected', NOW(6) - INTERVAL 15 HOUR),
(7, 'ABNORMAL_STOP', 'MEDIUM', 7, 7, 7, 21.0379, 105.7752, 0.0, 0.80, NULL, 'NEW', NULL, NULL, 'Abnormal stop', NOW(6) - INTERVAL 14 HOUR),
(8, 'GPS_LOST', 'HIGH', 8, 8, 8, 21.0386, 105.7465, 0.0, 1.00, NULL, 'PROCESSING', 4, NOW(6) - INTERVAL 13 HOUR, 'GPS signal lost', NOW(6) - INTERVAL 13 HOUR),
(9, 'FLOOD_RISK', 'HIGH', 9, 9, 9, 21.0631, 105.8014, 25.0, 0.86, NULL, 'NEW', NULL, NULL, 'Flood risk ahead', NOW(6) - INTERVAL 12 HOUR),
(10, 'DROWSINESS', 'MEDIUM', 10, 10, 10, 21.0348, 105.8083, 41.0, 0.77, 'https://demo.safefleet.vn/evidence/010.jpg', 'NEW', NULL, NULL, 'Drowsiness warning', NOW(6) - INTERVAL 11 HOUR),
(11, 'PHONE_USAGE', 'LOW', 11, 11, NULL, 20.9842, 105.7954, 20.0, 0.66, NULL, 'RESOLVED', 4, NOW(6) - INTERVAL 10 HOUR, 'Resolved demo event', NOW(6) - INTERVAL 10 HOUR),
(12, 'DISTRACTION', 'HIGH', 12, 12, NULL, 21.0204, 105.7821, 48.0, 0.89, NULL, 'NEW', NULL, NULL, 'Distraction warning', NOW(6) - INTERVAL 9 HOUR),
(13, 'SPEEDING', 'CRITICAL', 13, 13, NULL, 21.0465, 105.7649, 92.0, 0.95, NULL, 'NEW', NULL, NULL, 'Critical speeding', NOW(6) - INTERVAL 8 HOUR),
(14, 'GPS_LOST', 'MEDIUM', 14, 14, NULL, 21.0189, 105.8121, 0.0, 1.00, NULL, 'NEW', NULL, NULL, 'GPS intermittent', NOW(6) - INTERVAL 7 HOUR),
(15, 'FLOOD_RISK', 'LOW', 15, 15, NULL, 21.0703, 105.7832, 18.0, 0.62, NULL, 'NEW', NULL, NULL, 'Low flood risk', NOW(6) - INTERVAL 6 HOUR);

INSERT INTO driving_sessions (driver_id, vehicle_id, trip_id, status, started_at, paused_at, resumed_at, ended_at, continuous_minutes, total_minutes, over_driving_alert_created) VALUES
(5, 5, 5, 'ACTIVE', NOW(6) - INTERVAL 185 MINUTE, NULL, NOW(6) - INTERVAL 185 MINUTE, NULL, 0, 0, FALSE),
(6, 6, 6, 'PAUSED', NOW(6) - INTERVAL 120 MINUTE, NOW(6) - INTERVAL 20 MINUTE, NOW(6) - INTERVAL 120 MINUTE, NULL, 100, 100, FALSE),
(1, 1, 1, 'FINISHED', NOW(6) - INTERVAL 5 DAY, NULL, NOW(6) - INTERVAL 5 DAY, NOW(6) - INTERVAL 5 DAY + INTERVAL 2 HOUR, 120, 120, FALSE);

INSERT INTO driver_work_logs (driver_id, trip_id, work_date, driving_minutes, rest_minutes, note) VALUES
(1, 1, CURDATE() - INTERVAL 5 DAY, 120, 15, 'Completed demo trip'),
(2, 2, CURDATE() - INTERVAL 4 DAY, 130, 20, 'Completed demo trip'),
(5, 5, CURDATE(), 185, 0, 'Active driving session');

INSERT INTO incidents (id, incident_code, type, severity, vehicle_id, driver_id, trip_id, lat, lng, description, status, assigned_to, accepted_at, resolved_at, created_at) VALUES
(1, 'INC-DEMO-001', 'SOS', 'CRITICAL', 1, 1, 1, 20.9719, 105.7788, 'SOS near Ha Dong', 'OPEN', NULL, NULL, NULL, NOW(6) - INTERVAL 5 HOUR),
(2, 'INC-DEMO-002', 'ACCIDENT', 'CRITICAL', 2, 2, 2, 21.0362, 105.7906, 'Accident near Cau Giay', 'PROCESSING', 5, NOW(6) - INTERVAL 4 HOUR, NULL, NOW(6) - INTERVAL 4 HOUR),
(3, 'INC-DEMO-003', 'VEHICLE_BREAKDOWN', 'HIGH', 3, 3, 3, 21.0285, 105.7784, 'Vehicle breakdown near My Dinh', 'PROCESSING', 5, NOW(6) - INTERVAL 3 HOUR, NULL, NOW(6) - INTERVAL 3 HOUR),
(4, 'INC-DEMO-004', 'GPS_LOST', 'HIGH', 4, 4, 4, 20.9902, 105.8057, 'GPS lost near Nguyen Trai', 'ACCEPTED', 5, NOW(6) - INTERVAL 2 HOUR, NULL, NOW(6) - INTERVAL 2 HOUR),
(5, 'INC-DEMO-005', 'FLOOD_STUCK', 'HIGH', 5, 5, 5, 21.0123, 105.7621, 'Flood stuck near Dai lo Thang Long', 'OPEN', NULL, NULL, NULL, NOW(6) - INTERVAL 1 HOUR);

INSERT INTO incident_timelines (incident_id, action, actor_id, note, created_at) VALUES
(1, 'SOS_CREATED', 6, 'Driver pressed SOS', NOW(6) - INTERVAL 5 HOUR),
(2, 'CREATED', 4, 'Created from critical AI alert', NOW(6) - INTERVAL 4 HOUR),
(2, 'ASSIGNED', 3, 'Assigned to rescue team', NOW(6) - INTERVAL 3 HOUR - INTERVAL 45 MINUTE),
(3, 'CREATED', 3, 'Dispatcher created vehicle breakdown incident', NOW(6) - INTERVAL 3 HOUR),
(4, 'ACCEPTED', 5, 'Rescue team accepted GPS lost incident', NOW(6) - INTERVAL 2 HOUR);

INSERT INTO flood_reports (id, lat, lng, address, severity, source, reported_by_driver_id, image_url, confidence, status, verified_by, verified_at, expired_at, created_at) VALUES
(1, 20.9718, 105.7790, 'Ha Dong', 'BLOCKED', 'DRIVER_REPORT', 1, 'https://demo.safefleet.vn/flood/001.jpg', 0.75, 'VERIFIED', 3, NOW(6) - INTERVAL 8 HOUR, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 9 HOUR),
(2, 21.0365, 105.7909, 'Cau Giay', 'MEDIUM', 'MANUAL', 2, 'https://demo.safefleet.vn/flood/002.jpg', 0.79, 'VERIFIED', 3, NOW(6) - INTERVAL 7 HOUR, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 8 HOUR),
(3, 21.0281, 105.7782, 'My Dinh', 'MEDIUM', 'DRIVER_REPORT', 3, 'https://demo.safefleet.vn/flood/003.jpg', 0.63, 'VERIFIED', 3, NOW(6) - INTERVAL 6 HOUR, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 7 HOUR),
(4, 20.9906, 105.8052, 'Nguyen Trai', 'HIGH', 'MANUAL', 4, 'https://demo.safefleet.vn/flood/004.jpg', 0.87, 'VERIFIED', 3, NOW(6) - INTERVAL 5 HOUR, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 6 HOUR),
(5, 21.0121, 105.7625, 'Dai lo Thang Long', 'BLOCKED', 'DRIVER_REPORT', 5, 'https://demo.safefleet.vn/flood/005.jpg', 0.71, 'UNVERIFIED', NULL, NULL, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 5 HOUR),
(6, 21.0526, 105.7350, 'Kieu Mai', 'MEDIUM', 'IOT_SENSOR', 6, 'https://demo.safefleet.vn/flood/006.jpg', 0.81, 'UNVERIFIED', NULL, NULL, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 4 HOUR),
(7, 21.0383, 105.7754, 'Phu Dien', 'HIGH', 'TRAFFIC_CAMERA', 7, 'https://demo.safefleet.vn/flood/007.jpg', 0.84, 'UNVERIFIED', NULL, NULL, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 3 HOUR),
(8, 21.0390, 105.7462, 'Ho Tung Mau', 'MEDIUM', 'WEATHER', 8, 'https://demo.safefleet.vn/flood/008.jpg', 0.68, 'UNVERIFIED', NULL, NULL, NOW(6) + INTERVAL 3 HOUR, NOW(6) - INTERVAL 2 HOUR);

INSERT INTO maintenance_orders (id, maintenance_code, vehicle_id, type, title, description, scheduled_date, completed_date, cost, status, priority, assigned_to, note) VALUES
(1, 'MTN-DEMO-001', 6, 'PERIODIC', 'Bao tri dinh ky xe 30H-105.06', 'Kiem tra phanh, lop, den va thiet bi GPS', CURDATE() + INTERVAL 1 DAY, NULL, 1500000.00, 'SCHEDULED', 'MEDIUM', 1, 'Seed maintenance order'),
(2, 'MTN-DEMO-002', 7, 'REPAIR', 'Sua chua GPS xe 30H-106.07', 'Kiem tra GPS mat ket noi va cap nguon', CURDATE() + INTERVAL 2 DAY, NULL, 2000000.00, 'SCHEDULED', 'HIGH', 1, 'Seed maintenance order'),
(3, 'MTN-DEMO-003', 8, 'PERIODIC', 'Bao tri xe dang nam xuong', 'Kiem tra tong quat truoc khi dua vao khai thac', CURDATE() + INTERVAL 3 DAY, NULL, 2500000.00, 'IN_PROGRESS', 'HIGH', 1, 'Seed maintenance order');

INSERT INTO notifications (recipient_id, type, title, content, reference_type, reference_id, read_at, created_at) VALUES
(NULL, 'AI_ALERT', 'Canh bao AI moi', 'DROWSINESS - CRITICAL', 'SAFETY_EVENT', 1, NULL, NOW(6) - INTERVAL 21 HOUR),
(NULL, 'SOS', 'SOS moi', 'SOS near Ha Dong', 'INCIDENT', 1, NULL, NOW(6) - INTERVAL 5 HOUR),
(NULL, 'FLOOD', 'Diem ngap moi', 'Nguyen Trai', 'FLOOD_REPORT', 4, NULL, NOW(6) - INTERVAL 6 HOUR),
(3, 'TRIP_DELAYED', 'Chuyen di co nguy co tre', 'DEMO-TRIP-005 dang cham tien do', 'TRIP', 5, NULL, NOW(6) - INTERVAL 1 HOUR),
(4, 'DRIVING_TIME', 'Tai xe gan qua gio lai', 'Driver 05 has driven more than 3 hours', 'DRIVER', 5, NULL, NOW(6) - INTERVAL 30 MINUTE);

INSERT INTO system_settings (id, setting_key, setting_group, setting_value, value_type, description, updated_by) VALUES
(1, 'driving.max_continuous_minutes', 'DRIVING_TIME', '240', 'INTEGER', 'Maximum continuous driving time in minutes', 1),
(2, 'driving.warn_1_minutes', 'DRIVING_TIME', '180', 'INTEGER', 'First early warning after 3 hours', 1),
(3, 'driving.warn_2_minutes', 'DRIVING_TIME', '210', 'INTEGER', 'Second early warning after 3 hours 30 minutes', 1),
(4, 'driving.critical_minutes', 'DRIVING_TIME', '230', 'INTEGER', 'Critical warning after 3 hours 50 minutes', 1),
(5, 'flood.expiration_minutes', 'FLOOD', '180', 'INTEGER', 'Flood report expiration time in minutes', 1),
(6, 'ai.drowsiness_threshold', 'AI_ALERT', '0.75', 'DECIMAL', 'Drowsiness AI confidence threshold', 1),
(7, 'sos.escalation_minutes', 'SOS_ESCALATION', '5', 'INTEGER', 'Minutes before SOS escalation', 1),
(8, 'map.default_center', 'MAP', '{"lat":21.0278,"lng":105.8342}', 'JSON', 'Default Hanoi map center', 1),
(9, 'notification.realtime_enabled', 'NOTIFICATION', 'true', 'BOOLEAN', 'Enable realtime notifications', 1);

INSERT INTO audit_logs (actor_id, action, target_type, target_id, ip_address, user_agent, created_at) VALUES
(1, 'SEED_DATABASE', 'DATABASE', NULL, '127.0.0.1', 'safefleet_full_database.sql', NOW(6));

INSERT INTO flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success) VALUES
(1, '2', 'Standalone full database baseline', 'BASELINE', '<< Flyway Baseline >>', NULL, CURRENT_USER(), 0, TRUE);

COMMIT;

-- =========================================================
-- 7. Quick check
-- =========================================================

SELECT 'roles' AS table_name, COUNT(*) AS total FROM roles
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'drivers', COUNT(*) FROM drivers
UNION ALL SELECT 'vehicles', COUNT(*) FROM vehicles
UNION ALL SELECT 'devices', COUNT(*) FROM devices
UNION ALL SELECT 'trips', COUNT(*) FROM trips
UNION ALL SELECT 'telemetry_logs', COUNT(*) FROM telemetry_logs
UNION ALL SELECT 'safety_events', COUNT(*) FROM safety_events
UNION ALL SELECT 'incidents', COUNT(*) FROM incidents
UNION ALL SELECT 'flood_reports', COUNT(*) FROM flood_reports
UNION ALL SELECT 'maintenance_orders', COUNT(*) FROM maintenance_orders
UNION ALL SELECT 'system_settings', COUNT(*) FROM system_settings;
