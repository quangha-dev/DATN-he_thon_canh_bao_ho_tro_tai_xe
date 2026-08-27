-- Hazard snapshot captured when a route is computed.
--
-- The driver app has to keep warning about closures while it is offline, and it
-- must warn about exactly the hazards the route was scored against - not
-- whatever happens to be in the database when connectivity returns. Freezing
-- the set onto the session makes the offline warning reproducible and makes a
-- reroute decision auditable after the fact.
ALTER TABLE navigation_sessions
    ADD COLUMN hazards_json TEXT;

-- Ad-hoc navigation (no trip attached) previously created a new row on every
-- search and had no way to finish, so ACTIVE sessions accumulated forever.
-- Sessions now carry an explicit completion reason.
ALTER TABLE navigation_sessions
    ADD COLUMN completion_reason VARCHAR(40);

CREATE INDEX idx_navigation_sessions_driver_updated
    ON navigation_sessions (driver_id, status, updated_at DESC);

-- Guidance steps are replayed on the device, so the columns they are built from
-- must never be silently truncated by a short candidate row.
ALTER TABLE navigation_route_candidates
    ALTER COLUMN label TYPE VARCHAR(160);
