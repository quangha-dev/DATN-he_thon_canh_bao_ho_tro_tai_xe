ALTER TABLE navigation_route_candidates
    ADD COLUMN route_token TEXT,
    ADD COLUMN navigation_waypoints_json TEXT;
