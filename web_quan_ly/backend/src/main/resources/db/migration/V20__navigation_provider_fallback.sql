ALTER TABLE navigation_route_candidates
    ADD COLUMN provider_fallback BOOLEAN NOT NULL DEFAULT FALSE;
