ALTER TABLE document_ocr_jobs
    ADD COLUMN driver_id BIGINT NULL,
    ADD COLUMN trip_id BIGINT NULL,
    ADD COLUMN expected_vehicle_plate VARCHAR(32) NULL,
    ADD COLUMN plate_review_status VARCHAR(32) NOT NULL DEFAULT 'NOT_CHECKED',
    ADD COLUMN plate_review_reason VARCHAR(255) NULL,
    ADD COLUMN reviewed_by_user_id BIGINT NULL,
    ADD COLUMN reviewed_at TIMESTAMP(6) NULL,
    ADD COLUMN review_note VARCHAR(500) NULL,
    ADD CONSTRAINT fk_document_ocr_jobs_driver FOREIGN KEY (driver_id) REFERENCES drivers(id),
    ADD CONSTRAINT fk_document_ocr_jobs_trip FOREIGN KEY (trip_id) REFERENCES trips(id),
    ADD CONSTRAINT fk_document_ocr_jobs_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users(id);
CREATE INDEX idx_document_ocr_jobs_plate_review ON document_ocr_jobs (plate_review_status, created_at);
CREATE INDEX idx_document_ocr_jobs_driver ON document_ocr_jobs (driver_id, created_at);
CREATE INDEX idx_document_ocr_jobs_trip ON document_ocr_jobs (trip_id);
