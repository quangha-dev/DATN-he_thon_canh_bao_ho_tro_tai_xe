CREATE TABLE permissions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id),
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id)
);

CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(80) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    status VARCHAR(30) NOT NULL,
    role_id BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id),
    INDEX idx_users_email (email),
    INDEX idx_users_status (status)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_drivers_user FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_drivers_status (status),
    INDEX idx_drivers_license_class (license_class),
    INDEX idx_drivers_safety_score (safety_score)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_vehicles_plate_number (plate_number),
    INDEX idx_vehicles_type_status (vehicle_type, status),
    INDEX idx_vehicles_status (status)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_devices_type_status (type, status),
    INDEX idx_devices_vehicle (vehicle_id)
);

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
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_device_logs_device FOREIGN KEY (device_id) REFERENCES devices(id),
    INDEX idx_device_logs_device_created (device_id, created_at)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_trips_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    INDEX idx_trips_status (status),
    INDEX idx_trips_vehicle_status (vehicle_id, status),
    INDEX idx_trips_driver_status (driver_id, status),
    INDEX idx_trips_planned_start (planned_start_time)
);

CREATE TABLE trip_timelines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    trip_id BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    actor_id BIGINT,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_trip_timelines_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_trip_timelines_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_trip_timelines_trip_created (trip_id, created_at)
);

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
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_telemetry_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_telemetry_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_telemetry_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_telemetry_vehicle_created (vehicle_id, created_at),
    INDEX idx_telemetry_trip_created (trip_id, created_at),
    INDEX idx_telemetry_driver_created (driver_id, created_at)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_safety_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_safety_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_safety_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_safety_handled_by FOREIGN KEY (handled_by) REFERENCES users(id),
    INDEX idx_safety_status_severity_created (status, severity, created_at),
    INDEX idx_safety_vehicle_created (vehicle_id, created_at),
    INDEX idx_safety_driver_created (driver_id, created_at),
    INDEX idx_safety_type (event_type)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_driving_sessions_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_driving_sessions_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_driving_sessions_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_driving_sessions_driver_status (driver_id, status)
);

CREATE TABLE driver_work_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    driver_id BIGINT NOT NULL,
    trip_id BIGINT,
    work_date DATE NOT NULL,
    driving_minutes INT NOT NULL DEFAULT 0,
    rest_minutes INT NOT NULL DEFAULT 0,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_driver_work_logs_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_driver_work_logs_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    INDEX idx_driver_work_logs_driver_date (driver_id, work_date)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_incidents_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_incidents_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_incidents_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    CONSTRAINT fk_incidents_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id),
    INDEX idx_incidents_status_severity (status, severity),
    INDEX idx_incidents_vehicle_created (vehicle_id, created_at)
);

CREATE TABLE incident_timelines (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    incident_id BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    actor_id BIGINT,
    note VARCHAR(500),
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_incident_timelines_incident FOREIGN KEY (incident_id) REFERENCES incidents(id),
    CONSTRAINT fk_incident_timelines_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_incident_timelines_incident_created (incident_id, created_at)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_flood_reported_by_driver FOREIGN KEY (reported_by_driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_flood_verified_by FOREIGN KEY (verified_by) REFERENCES users(id),
    INDEX idx_flood_status_severity (status, severity),
    INDEX idx_flood_location (lat, lng)
);

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
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_maintenance_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id),
    INDEX idx_maintenance_vehicle_status (vehicle_id, status),
    INDEX idx_maintenance_scheduled_date (scheduled_date)
);

CREATE TABLE notifications (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    recipient_id BIGINT,
    type VARCHAR(40) NOT NULL,
    title VARCHAR(150) NOT NULL,
    content VARCHAR(500) NOT NULL,
    reference_type VARCHAR(50),
    reference_id BIGINT,
    read_at DATETIME(6),
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_id) REFERENCES users(id),
    INDEX idx_notifications_recipient_created (recipient_id, created_at),
    INDEX idx_notifications_read_at (read_at)
);

CREATE TABLE system_settings (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_group VARCHAR(40) NOT NULL,
    setting_value TEXT NOT NULL,
    value_type VARCHAR(30) NOT NULL,
    description VARCHAR(255),
    updated_by BIGINT,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_system_settings_updated_by FOREIGN KEY (updated_by) REFERENCES users(id),
    INDEX idx_system_settings_group (setting_group)
);

CREATE TABLE audit_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    actor_id BIGINT,
    action VARCHAR(120) NOT NULL,
    target_type VARCHAR(80),
    target_id BIGINT,
    ip_address VARCHAR(80),
    user_agent VARCHAR(255),
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_id) REFERENCES users(id),
    INDEX idx_audit_logs_actor_created (actor_id, created_at),
    INDEX idx_audit_logs_target (target_type, target_id)
);
