ALTER TABLE navigation_route_candidates
    ADD COLUMN total_score DECIMAL(10, 3) NOT NULL DEFAULT 0 AFTER risk_score,
    ADD COLUMN flood_penalty DECIMAL(10, 3) NOT NULL DEFAULT 0 AFTER total_score,
    ADD COLUMN vehicle_restriction_penalty DECIMAL(10, 3) NOT NULL DEFAULT 0 AFTER flood_penalty,
    ADD COLUMN driver_time_penalty DECIMAL(10, 3) NOT NULL DEFAULT 0 AFTER vehicle_restriction_penalty,
    ADD COLUMN safe BOOLEAN NOT NULL DEFAULT TRUE AFTER driver_time_penalty,
    ADD COLUMN blocked BOOLEAN NOT NULL DEFAULT FALSE AFTER safe,
    ADD COLUMN steps_json JSON AFTER geometry_json;

ALTER TABLE navigation_events
    ADD COLUMN distance_to_route_meters INT AFTER distance_to_hazard_meters,
    ADD COLUMN gps_accuracy_meters DECIMAL(8, 2) AFTER distance_to_route_meters,
    ADD COLUMN occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) AFTER payload_json,
    ADD INDEX idx_navigation_events_session_occurred (navigation_session_id, occurred_at);

CREATE TABLE sync_batch_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    sync_batch_id BIGINT NOT NULL,
    item_index INT NOT NULL,
    client_event_id VARCHAR(100),
    item_type VARCHAR(40) NOT NULL,
    item_status VARCHAR(30) NOT NULL,
    entity_id BIGINT,
    error_message VARCHAR(500),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_sync_batch_items_batch FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
    UNIQUE KEY uk_sync_batch_item_event (sync_batch_id, client_event_id),
    UNIQUE KEY uk_sync_batch_item_index (sync_batch_id, item_index),
    INDEX idx_sync_batch_items_batch (sync_batch_id)
);
