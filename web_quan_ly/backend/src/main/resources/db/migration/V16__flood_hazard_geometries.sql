ALTER TABLE flood_reports
    ADD COLUMN geometry_type VARCHAR(20) NOT NULL DEFAULT 'POINT',
    ADD COLUMN geometry_json TEXT,
    ADD COLUMN radius_meters DOUBLE PRECISION NOT NULL DEFAULT 120;

ALTER TABLE flood_reports
    ADD CONSTRAINT chk_flood_geometry_type
        CHECK (geometry_type IN ('POINT', 'SEGMENT', 'POLYGON')),
    ADD CONSTRAINT chk_flood_radius
        CHECK (radius_meters >= 20 AND radius_meters <= 2000);

CREATE INDEX idx_flood_geometry_type_status
    ON flood_reports (geometry_type, status);
