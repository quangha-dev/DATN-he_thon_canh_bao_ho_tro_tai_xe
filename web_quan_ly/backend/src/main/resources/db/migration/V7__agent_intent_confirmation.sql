ALTER TABLE agent_commands
    ADD COLUMN interpreted_intent VARCHAR(40) NULL,
    ADD COLUMN confidence DOUBLE PRECISION NULL,
    ADD COLUMN requires_confirmation BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN classification_source VARCHAR(30) NULL,
    ADD COLUMN executed_reference_type VARCHAR(40) NULL,
    ADD COLUMN executed_reference_id BIGINT NULL;
CREATE INDEX idx_agent_intent_status ON agent_commands (interpreted_intent, status);
