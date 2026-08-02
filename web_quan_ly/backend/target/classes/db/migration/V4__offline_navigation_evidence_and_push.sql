-- SafeFleet mobile/offline, navigation, evidence and per-user notification state.
-- All changes are additive so production upgrades remain compatible with V1-V3.

CREATE TABLE mobile_devices (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_uuid VARCHAR(100) NOT NULL,
    user_id BIGINT NOT NULL,
    platform VARCHAR(20) NOT NULL,
    app_version VARCHAR(40),
    os_version VARCHAR(80),
    device_model VARCHAR(120),
    last_seen_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_mobile_devices_user FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY uk_mobile_devices_uuid (device_uuid),
    INDEX idx_mobile_devices_user (user_id),
    INDEX idx_mobile_devices_last_seen (last_seen_at)
);

CREATE TABLE refresh_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    revoked_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_used_at DATETIME(6),
    CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY uk_refresh_tokens_hash (token_hash),
    INDEX idx_refresh_tokens_user_active (user_id, revoked_at, expires_at),
    INDEX idx_refresh_tokens_expires (expires_at)
);

CREATE TABLE idempotency_records (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    idempotency_key VARCHAR(120) NOT NULL,
    request_method VARCHAR(10) NOT NULL,
    request_path VARCHAR(255) NOT NULL,
    request_hash CHAR(64),
    response_status INT NOT NULL,
    response_body JSON,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_idempotency_records_user FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY uk_idempotency_user_key (user_id, idempotency_key),
    INDEX idx_idempotency_expires (expires_at)
);

CREATE TABLE sync_batches (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    batch_uuid VARCHAR(100) NOT NULL,
    user_id BIGINT NOT NULL,
    device_id BIGINT,
    item_count INT NOT NULL DEFAULT 0,
    accepted_count INT NOT NULL DEFAULT 0,
    duplicate_count INT NOT NULL DEFAULT 0,
    rejected_count INT NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL,
    error_summary VARCHAR(1000),
    received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    completed_at DATETIME(6),
    CONSTRAINT fk_sync_batches_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_sync_batches_device FOREIGN KEY (device_id) REFERENCES mobile_devices(id),
    UNIQUE KEY uk_sync_batches_uuid (batch_uuid),
    INDEX idx_sync_batches_user_received (user_id, received_at)
);

ALTER TABLE telemetry_logs
    ADD COLUMN client_event_id VARCHAR(100),
    ADD COLUMN sync_batch_id BIGINT,
    ADD COLUMN recorded_at DATETIME(6),
    ADD COLUMN received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ADD CONSTRAINT fk_telemetry_sync_batch FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
    ADD UNIQUE KEY uk_telemetry_driver_client_event (driver_id, client_event_id),
    ADD INDEX idx_telemetry_received_at (received_at);

ALTER TABLE safety_events
    ADD COLUMN client_event_id VARCHAR(100),
    ADD COLUMN sync_batch_id BIGINT,
    ADD COLUMN received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ADD CONSTRAINT fk_safety_sync_batch FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
    ADD UNIQUE KEY uk_safety_driver_client_event (driver_id, client_event_id),
    ADD INDEX idx_safety_received_at (received_at);

ALTER TABLE incidents
    ADD COLUMN client_event_id VARCHAR(100),
    ADD COLUMN sync_batch_id BIGINT,
    ADD COLUMN received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ADD CONSTRAINT fk_incidents_sync_batch FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
    ADD UNIQUE KEY uk_incident_driver_client_event (driver_id, client_event_id),
    ADD INDEX idx_incidents_received_at (received_at);

ALTER TABLE flood_reports
    ADD COLUMN client_event_id VARCHAR(100),
    ADD COLUMN sync_batch_id BIGINT,
    ADD COLUMN received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ADD CONSTRAINT fk_flood_sync_batch FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
    ADD UNIQUE KEY uk_flood_driver_client_event (reported_by_driver_id, client_event_id),
    ADD INDEX idx_flood_received_at (received_at);

CREATE TABLE navigation_sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    session_uuid VARCHAR(100) NOT NULL,
    driver_id BIGINT NOT NULL,
    vehicle_id BIGINT,
    trip_id BIGINT,
    origin_lat DOUBLE NOT NULL,
    origin_lng DOUBLE NOT NULL,
    destination_lat DOUBLE NOT NULL,
    destination_lng DOUBLE NOT NULL,
    destination_name VARCHAR(255),
    selected_candidate_id BIGINT,
    status VARCHAR(30) NOT NULL,
    started_at DATETIME(6),
    ended_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_navigation_sessions_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    CONSTRAINT fk_navigation_sessions_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id),
    CONSTRAINT fk_navigation_sessions_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    UNIQUE KEY uk_navigation_sessions_uuid (session_uuid),
    INDEX idx_navigation_sessions_driver_status (driver_id, status),
    INDEX idx_navigation_sessions_trip (trip_id)
);

CREATE TABLE navigation_route_candidates (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    navigation_session_id BIGINT NOT NULL,
    route_index INT NOT NULL,
    label VARCHAR(120) NOT NULL,
    distance_meters INT NOT NULL,
    duration_seconds INT NOT NULL,
    risk_score DECIMAL(7, 3) NOT NULL DEFAULT 0,
    flood_intersection_count INT NOT NULL DEFAULT 0,
    is_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    geometry_json JSON NOT NULL,
    warnings_json JSON,
    provider VARCHAR(40) NOT NULL DEFAULT 'LOCAL_DEMO',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_navigation_candidates_session
        FOREIGN KEY (navigation_session_id) REFERENCES navigation_sessions(id),
    UNIQUE KEY uk_navigation_candidate_index (navigation_session_id, route_index),
    INDEX idx_navigation_candidate_recommended (navigation_session_id, is_recommended)
);

ALTER TABLE navigation_sessions
    ADD CONSTRAINT fk_navigation_sessions_selected_candidate
        FOREIGN KEY (selected_candidate_id) REFERENCES navigation_route_candidates(id);

CREATE TABLE navigation_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    navigation_session_id BIGINT NOT NULL,
    event_type VARCHAR(40) NOT NULL,
    lat DOUBLE,
    lng DOUBLE,
    distance_to_hazard_meters INT,
    payload_json JSON,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_navigation_events_session
        FOREIGN KEY (navigation_session_id) REFERENCES navigation_sessions(id),
    INDEX idx_navigation_events_session_created (navigation_session_id, created_at),
    INDEX idx_navigation_events_type_created (event_type, created_at)
);

CREATE TABLE safety_event_evidence (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    safety_event_id BIGINT,
    incident_id BIGINT,
    uploaded_by BIGINT NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255),
    content_type VARCHAR(120) NOT NULL,
    size_bytes BIGINT NOT NULL,
    sha256 CHAR(64) NOT NULL,
    captured_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_evidence_safety_event FOREIGN KEY (safety_event_id) REFERENCES safety_events(id),
    CONSTRAINT fk_evidence_incident FOREIGN KEY (incident_id) REFERENCES incidents(id),
    CONSTRAINT fk_evidence_uploaded_by FOREIGN KEY (uploaded_by) REFERENCES users(id),
    UNIQUE KEY uk_evidence_object_key (object_key),
    INDEX idx_evidence_safety_event (safety_event_id),
    INDEX idx_evidence_incident (incident_id),
    INDEX idx_evidence_sha256 (sha256)
);

CREATE TABLE push_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    device_id BIGINT,
    provider VARCHAR(30) NOT NULL,
    token VARCHAR(512) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_used_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6),
    CONSTRAINT fk_push_tokens_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_push_tokens_device FOREIGN KEY (device_id) REFERENCES mobile_devices(id),
    UNIQUE KEY uk_push_tokens_provider_token (provider, token),
    INDEX idx_push_tokens_user_enabled (user_id, enabled)
);

CREATE TABLE pending_push_notifications (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    notification_id BIGINT,
    user_id BIGINT NOT NULL,
    push_token_id BIGINT,
    title VARCHAR(150) NOT NULL,
    body VARCHAR(500) NOT NULL,
    data_json JSON,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    attempt_count INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    sent_at DATETIME(6),
    last_error VARCHAR(1000),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_pending_push_notification FOREIGN KEY (notification_id) REFERENCES notifications(id),
    CONSTRAINT fk_pending_push_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_pending_push_token FOREIGN KEY (push_token_id) REFERENCES push_tokens(id),
    INDEX idx_pending_push_dispatch (status, next_attempt_at),
    INDEX idx_pending_push_user_created (user_id, created_at)
);

CREATE TABLE notification_reads (
    notification_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    read_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (notification_id, user_id),
    CONSTRAINT fk_notification_reads_notification FOREIGN KEY (notification_id) REFERENCES notifications(id),
    CONSTRAINT fk_notification_reads_user FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_notification_reads_user (user_id, read_at)
);
