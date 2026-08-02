ALTER TABLE agent_commands
    ADD COLUMN interpreted_intent VARCHAR(40) NULL AFTER normalized_command,
    ADD COLUMN confidence DOUBLE NULL AFTER interpreted_intent,
    ADD COLUMN requires_confirmation BOOLEAN NOT NULL DEFAULT FALSE AFTER confidence,
    ADD COLUMN classification_source VARCHAR(30) NULL AFTER requires_confirmation,
    ADD COLUMN executed_reference_type VARCHAR(40) NULL AFTER response_text,
    ADD COLUMN executed_reference_id BIGINT NULL AFTER executed_reference_type,
    ADD INDEX idx_agent_intent_status (interpreted_intent, status);
