ALTER TABLE flood_reports
    ADD COLUMN hazard_type VARCHAR(30) NOT NULL DEFAULT 'FLOOD';

ALTER TABLE flood_reports
    ADD CONSTRAINT chk_flood_hazard_type
        CHECK (hazard_type IN ('FLOOD', 'TRAFFIC_JAM'));

CREATE INDEX idx_flood_hazard_type_status
    ON flood_reports (hazard_type, status);
