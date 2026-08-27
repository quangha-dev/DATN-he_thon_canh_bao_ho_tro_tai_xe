ALTER TABLE vehicles
    ADD COLUMN IF NOT EXISTS height_meters NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS width_meters NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS length_meters NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS gross_weight_tons NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS axle_load_tons NUMERIC(6, 2),
    ADD COLUMN IF NOT EXISTS axle_count INTEGER,
    ADD COLUMN IF NOT EXISTS top_speed_kph NUMERIC(6, 2),
    ADD COLUMN IF NOT EXISTS hazardous_goods BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE telemetry_logs
    ADD COLUMN IF NOT EXISTS gps_accuracy_meters DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS position_accepted BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE vehicles
    DROP CONSTRAINT IF EXISTS chk_vehicle_routing_dimensions;

ALTER TABLE vehicles
    ADD CONSTRAINT chk_vehicle_routing_dimensions CHECK (
        (height_meters IS NULL OR height_meters BETWEEN 0.5 AND 6.0)
        AND (width_meters IS NULL OR width_meters BETWEEN 0.5 AND 4.0)
        AND (length_meters IS NULL OR length_meters BETWEEN 1.0 AND 30.0)
        AND (gross_weight_tons IS NULL OR gross_weight_tons BETWEEN 0.1 AND 100.0)
        AND (axle_load_tons IS NULL OR axle_load_tons BETWEEN 0.1 AND 30.0)
        AND (axle_count IS NULL OR axle_count BETWEEN 1 AND 12)
        AND (top_speed_kph IS NULL OR top_speed_kph BETWEEN 10.0 AND 252.0)
    );
