CREATE TABLE mobile_command_receipts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    client_event_id VARCHAR(100) NOT NULL,
    operation VARCHAR(50) NOT NULL,
    trip_id BIGINT,
    response_json LONGTEXT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6),
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_mobile_receipt_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_mobile_receipt_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    UNIQUE KEY uk_mobile_receipt_user_event (user_id, client_event_id),
    INDEX idx_mobile_receipt_trip_created (trip_id, created_at)
);
