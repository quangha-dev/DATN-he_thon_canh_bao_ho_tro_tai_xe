ALTER TABLE document_ocr_jobs
    ADD COLUMN voucher_date DATE NULL,
    ADD COLUMN voucher_number VARCHAR(64) NULL,
    ADD COLUMN vehicle_plate VARCHAR(32) NULL,
    ADD COLUMN driver_name VARCHAR(255) NULL,
    ADD COLUMN trip_count INT NULL,
    ADD COLUMN raw_text TEXT NULL,
    ADD COLUMN project_address_confidence DECIMAL(5,4) NULL,
    ADD COLUMN voucher_date_confidence DECIMAL(5,4) NULL,
    ADD COLUMN voucher_number_confidence DECIMAL(5,4) NULL,
    ADD COLUMN vehicle_plate_confidence DECIMAL(5,4) NULL,
    ADD COLUMN driver_name_confidence DECIMAL(5,4) NULL;
