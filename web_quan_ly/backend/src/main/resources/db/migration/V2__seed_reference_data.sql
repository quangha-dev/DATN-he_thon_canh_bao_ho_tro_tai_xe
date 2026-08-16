INSERT INTO roles (name, description, created_at, updated_at, deleted) VALUES
('ADMIN', 'System administrator', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('FLEET_MANAGER', 'Fleet manager', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('DISPATCHER', 'Trip dispatcher', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('SAFETY_OFFICER', 'Safety monitoring officer', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('RESCUE_TEAM', 'Rescue team member', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('DRIVER', 'Driver mobile app user', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE);

INSERT INTO system_settings (setting_key, setting_group, setting_value, value_type, description, created_at, updated_at, deleted) VALUES
('driving.max_continuous_minutes', 'DRIVING_TIME', '240', 'INTEGER', 'Maximum continuous driving time in minutes', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('driving.warn_1_minutes', 'DRIVING_TIME', '180', 'INTEGER', 'First early warning hours', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('driving.warn_2_minutes', 'DRIVING_TIME', '210', 'INTEGER', 'Second early warning hours 30 minutes', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('driving.critical_minutes', 'DRIVING_TIME', '230', 'INTEGER', 'Critical warning hours 50 minutes', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('flood.expiration_minutes', 'FLOOD', '180', 'INTEGER', 'Flood report expiration time in minutes', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('ai.drowsiness_threshold', 'AI_ALERT', '0.75', 'DECIMAL', 'Drowsiness AI confidence threshold', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('sos.escalation_minutes', 'SOS_ESCALATION', '5', 'INTEGER', 'Minutes before SOS escalation', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('map.default_center', 'MAP', '{"lat":21.0278,"lng":105.8342}', 'TEXT', 'Default Hanoi map center', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE),
('notification.realtime_enabled', 'NOTIFICATION', 'true', 'BOOLEAN', 'Enable realtime notifications', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), FALSE);
