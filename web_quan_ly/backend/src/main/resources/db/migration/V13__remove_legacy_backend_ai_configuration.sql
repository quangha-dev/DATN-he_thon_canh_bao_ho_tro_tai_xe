-- OpenAI configuration is owned by safefleet_ai and persisted encrypted in
-- the ai_data volume. Keep this as a forward migration so existing production
-- databases never require history edits or destructive Flyway repair.
DROP TABLE IF EXISTS agent_ai_configurations;
