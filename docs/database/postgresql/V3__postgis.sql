-- Spatial projection of existing lat/lng columns.
-- Requires a PostgreSQL image with PostGIS installed.

SET search_path TO safefleet, public;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

ALTER TABLE vehicles ADD COLUMN last_position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN last_lat IS NULL OR last_lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(last_lng, last_lat), 4326)::public.geography
        END
    ) STORED;
CREATE INDEX idx_vehicles_last_position ON vehicles USING gist (last_position) WHERE last_position IS NOT NULL;

ALTER TABLE device_connection_logs ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN lat IS NULL OR lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography
        END
    ) STORED;
CREATE INDEX idx_device_logs_position ON device_connection_logs USING gist (position) WHERE position IS NOT NULL;

ALTER TABLE telemetry_logs ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography) STORED;
CREATE INDEX idx_telemetry_position ON telemetry_logs USING gist (position);

ALTER TABLE safety_events ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN lat IS NULL OR lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography
        END
    ) STORED;
CREATE INDEX idx_safety_position ON safety_events USING gist (position) WHERE position IS NOT NULL;

ALTER TABLE incidents ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN lat IS NULL OR lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography
        END
    ) STORED;
CREATE INDEX idx_incidents_position ON incidents USING gist (position) WHERE position IS NOT NULL;

ALTER TABLE flood_reports ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography) STORED;
CREATE INDEX idx_flood_position ON flood_reports USING gist (position);

ALTER TABLE navigation_sessions
    ADD COLUMN origin_position public.geography(Point, 4326)
        GENERATED ALWAYS AS (public.ST_SetSRID(public.ST_MakePoint(origin_lng, origin_lat), 4326)::public.geography) STORED,
    ADD COLUMN destination_position public.geography(Point, 4326)
        GENERATED ALWAYS AS (public.ST_SetSRID(public.ST_MakePoint(destination_lng, destination_lat), 4326)::public.geography) STORED;
CREATE INDEX idx_navigation_origin ON navigation_sessions USING gist (origin_position);
CREATE INDEX idx_navigation_destination ON navigation_sessions USING gist (destination_position);

ALTER TABLE navigation_route_candidates
    ADD COLUMN route_geometry public.geometry(LineString, 4326);
CREATE INDEX idx_navigation_route_geometry ON navigation_route_candidates USING gist (route_geometry)
    WHERE route_geometry IS NOT NULL;

ALTER TABLE navigation_events ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN lat IS NULL OR lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography
        END
    ) STORED;
CREATE INDEX idx_navigation_events_position ON navigation_events USING gist (position) WHERE position IS NOT NULL;

ALTER TABLE warehouse_issue_confirmations ADD COLUMN position public.geography(Point, 4326)
    GENERATED ALWAYS AS (
        CASE WHEN lat IS NULL OR lng IS NULL THEN NULL
             ELSE public.ST_SetSRID(public.ST_MakePoint(lng, lat), 4326)::public.geography
        END
    ) STORED;
