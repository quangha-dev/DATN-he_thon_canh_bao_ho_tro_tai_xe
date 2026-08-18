# ERD — Entity Relationship Diagram — SafeFleet

> **Nguồn:** Toàn bộ bảng, cột, kiểu dữ liệu và quan hệ được trích xuất từ 13 file Flyway migration SQL (`V1__init_schema.sql` → `V13__remove_legacy_backend_ai_configuration.sql`).
> Chú ý: Bảng `agent_ai_configurations` (V12) bị xoá bởi V13 → không có trong ERD cuối.

---

## ERD Tổng Thể — Nhóm theo Domain

```mermaid
erDiagram

    %% ══════════════════════════════════════
    %% DOMAIN: ACCOUNT & SECURITY (V1)
    %% ══════════════════════════════════════
    permissions {
        bigint id PK
        varchar_100 code UK
        varchar_255 description
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    roles {
        bigint id PK
        varchar_50 name UK
        varchar_255 description
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    role_permissions {
        bigint role_id PK,FK
        bigint permission_id PK,FK
    }

    users {
        bigint id PK
        varchar_80 username UK
        varchar_120 email UK
        varchar_255 password_hash
        varchar_150 full_name
        varchar_20 phone
        varchar_30 status
        bigint role_id FK
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    audit_logs {
        bigint id PK
        bigint actor_id FK
        varchar_120 action
        varchar_80 target_type
        bigint target_id
        varchar_80 ip_address
        varchar_255 user_agent
        timestamp_6 created_at
    }

    system_settings {
        bigint id PK
        varchar_100 setting_key UK
        varchar_40 setting_group
        text setting_value
        varchar_30 value_type
        varchar_255 description
        bigint updated_by FK
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: VEHICLE & DRIVER (V1)
    %% ══════════════════════════════════════
    drivers {
        bigint id PK
        bigint user_id FK_UK
        varchar_150 full_name
        varchar_20 phone
        varchar_120 email
        varchar_255 address
        varchar_50 license_number UK
        varchar_20 license_class
        date license_expired_at
        varchar_30 status
        bigint current_vehicle_id FK
        int safety_score
        int driving_time_today_minutes
        int continuous_driving_minutes
        int total_trips
        int total_alerts
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    vehicles {
        bigint id PK
        varchar_30 plate_number UK
        varchar_30 vehicle_type
        varchar_80 brand
        varchar_80 model
        int manufacture_year
        decimal_10_2 load_capacity
        int seat_count
        varchar_30 fuel_type
        varchar_30 status
        bigint current_driver_id FK
        bigint gps_device_id FK
        bigint camera_device_id FK
        date inspection_expired_at
        date insurance_expired_at
        double last_lat
        double last_lng
        double last_speed
        timestamp_6 last_updated_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    devices {
        bigint id PK
        varchar_50 device_code UK
        varchar_120 name
        varchar_40 type
        varchar_30 status
        bigint vehicle_id FK
        varchar_20 phone
        varchar_80 serial_number
        varchar_40 firmware_version
        timestamp_6 last_seen_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    device_connection_logs {
        bigint id PK
        bigint device_id FK
        varchar_30 status
        double lat
        double lng
        varchar_255 note
        timestamp_6 created_at
    }

    mobile_devices {
        bigint id PK
        bigint user_id FK
        varchar_100 device_uuid UK
        varchar_30 platform
        varchar_120 app_version
        varchar_255 model_name
        varchar_50 os_version
        timestamp_6 registered_at
        timestamp_6 last_seen_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: TRIP (V1)
    %% ══════════════════════════════════════
    trips {
        bigint id PK
        varchar_50 trip_code UK
        bigint vehicle_id FK
        bigint driver_id FK
        varchar_255 start_location
        double start_lat
        double start_lng
        varchar_255 end_location
        double end_lat
        double end_lng
        text waypoints_json
        text planned_route_json
        text actual_route_json
        timestamp_6 planned_start_time
        timestamp_6 actual_start_time
        timestamp_6 estimated_end_time
        timestamp_6 actual_end_time
        varchar_30 status
        int progress
        varchar_30 risk_level
        varchar_255 cancel_reason
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    trip_timelines {
        bigint id PK
        bigint trip_id FK
        varchar_80 action
        bigint actor_id FK
        varchar_500 note
        timestamp_6 created_at
    }

    pre_trip_checklists {
        bigint id PK
        bigint trip_id FK
        bigint driver_id FK
        bigint vehicle_id FK
        boolean exterior_checked
        boolean tires_checked
        boolean brake_checked
        boolean lights_checked
        boolean camera_checked
        boolean gps_checked
        boolean documents_checked
        text checklist_json
        varchar_500 note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: SAFETY (V1)
    %% ══════════════════════════════════════
    safety_events {
        bigint id PK
        varchar_40 event_type
        varchar_30 severity
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        double speed
        double confidence
        varchar_500 evidence_url
        varchar_30 status
        bigint handled_by FK
        timestamp_6 handled_at
        varchar_500 note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    driving_sessions {
        bigint id PK
        bigint driver_id FK
        bigint vehicle_id FK
        bigint trip_id FK
        varchar_30 status
        timestamp_6 started_at
        timestamp_6 paused_at
        timestamp_6 resumed_at
        timestamp_6 ended_at
        int continuous_minutes
        int total_minutes
        boolean over_driving_alert_created
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    driver_work_logs {
        bigint id PK
        bigint driver_id FK
        bigint trip_id FK
        date work_date
        int driving_minutes
        int rest_minutes
        varchar_500 note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: TELEMETRY (V1)
    %% ══════════════════════════════════════
    telemetry_logs {
        bigint id PK
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        double speed
        double heading
        int battery_level
        varchar_30 gps_status
        timestamp_6 created_at
    }

    %% ══════════════════════════════════════
    %% DOMAIN: INCIDENT & FLOOD (V1)
    %% ══════════════════════════════════════
    incidents {
        bigint id PK
        varchar_50 incident_code UK
        varchar_40 type
        varchar_30 severity
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        varchar_1000 description
        varchar_30 status
        bigint assigned_to FK
        timestamp_6 accepted_at
        timestamp_6 resolved_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    incident_timelines {
        bigint id PK
        bigint incident_id FK
        varchar_80 action
        bigint actor_id FK
        varchar_500 note
        timestamp_6 created_at
    }

    flood_reports {
        bigint id PK
        double lat
        double lng
        varchar_255 address
        varchar_30 severity
        varchar_40 source
        bigint reported_by_driver_id FK
        varchar_500 image_url
        double confidence
        varchar_30 status
        bigint verified_by FK
        timestamp_6 verified_at
        timestamp_6 expired_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: MAINTENANCE (V1)
    %% ══════════════════════════════════════
    maintenance_orders {
        bigint id PK
        varchar_50 maintenance_code UK
        bigint vehicle_id FK
        varchar_30 type
        varchar_150 title
        varchar_1000 description
        date scheduled_date
        date completed_date
        decimal_12_2 cost
        varchar_30 status
        varchar_30 priority
        bigint assigned_to FK
        varchar_1000 note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: NOTIFICATION (V1 + V4)
    %% ══════════════════════════════════════
    notifications {
        bigint id PK
        bigint recipient_id FK
        varchar_40 type
        varchar_150 title
        varchar_500 content
        varchar_50 reference_type
        bigint reference_id
        timestamp_6 read_at
        timestamp_6 created_at
    }

    push_tokens {
        bigint id PK
        bigint user_id FK
        bigint device_id FK
        varchar_30 provider
        varchar_512 token
        boolean enabled
        timestamp_6 last_used_at
        timestamp_6 created_at
        timestamp_6 updated_at
    }

    pending_push_notifications {
        bigint id PK
        bigint notification_id FK
        bigint user_id FK
        bigint push_token_id FK
        varchar_150 title
        varchar_500 body
        text data_json
        varchar_30 status
        int attempt_count
        timestamp_6 next_attempt_at
        timestamp_6 sent_at
        varchar_1000 last_error
        timestamp_6 created_at
    }

    notification_reads {
        bigint notification_id PK,FK
        bigint user_id PK,FK
        timestamp_6 read_at
    }

    %% ══════════════════════════════════════
    %% DOMAIN: NAVIGATION (V4)
    %% ══════════════════════════════════════
    navigation_sessions {
        bigint id PK
        varchar session_uuid UK
        bigint driver_id FK
        bigint vehicle_id FK
        bigint trip_id FK
        bigint selected_candidate_id FK
        varchar_30 status
        double origin_lat
        double origin_lng
        double destination_lat
        double destination_lng
        timestamp_6 started_at
        timestamp_6 ended_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    navigation_route_candidates {
        bigint id PK
        bigint navigation_session_id FK
        int route_index
        varchar_120 label
        int distance_meters
        int duration_seconds
        decimal_7_3 risk_score
        int flood_intersection_count
        boolean is_recommended
        text geometry_json
        text warnings_json
        varchar_40 provider
        decimal_10_3 total_score
        decimal_10_3 flood_penalty
        decimal_10_3 vehicle_restriction_penalty
        decimal_10_3 driver_time_penalty
        boolean safe
        boolean blocked
        text steps_json
        timestamp_6 created_at
    }

    navigation_events {
        bigint id PK
        bigint navigation_session_id FK
        varchar_40 event_type
        double lat
        double lng
        int distance_to_hazard_meters
        text payload_json
        int distance_to_route_meters
        decimal_8_2 gps_accuracy_meters
        timestamp_6 occurred_at
        timestamp_6 created_at
    }

    %% ══════════════════════════════════════
    %% DOMAIN: EVIDENCE (V4)
    %% ══════════════════════════════════════
    safety_event_evidence {
        bigint id PK
        bigint safety_event_id FK
        bigint incident_id FK
        bigint uploaded_by FK
        varchar_500 object_key UK
        varchar_255 original_filename
        varchar_120 content_type
        bigint size_bytes
        varchar_64 sha256
        timestamp_6 captured_at
        timestamp_6 created_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: SYNC / OFFLINE (V5 + V6)
    %% ══════════════════════════════════════
    sync_batches {
        bigint id PK
        bigint user_id FK
        bigint driver_id FK
        varchar batch_uuid UK
        varchar_30 status
        int total_items
        int processed_items
        int failed_items
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    sync_batch_items {
        bigint id PK
        bigint sync_batch_id FK
        int item_index
        varchar_100 client_event_id
        varchar_40 item_type
        varchar_30 item_status
        bigint entity_id
        varchar_500 error_message
        timestamp_6 created_at
    }

    mobile_command_receipts {
        bigint id PK
        bigint user_id FK
        varchar_100 client_event_id
        varchar_50 operation
        bigint trip_id FK
        text response_json
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: AI AGENT (V3 + V7)
    %% ══════════════════════════════════════
    agent_commands {
        bigint id PK
        bigint user_id FK
        bigint driver_id FK
        bigint trip_id FK
        varchar_30 command_type
        varchar_1000 transcript
        varchar_255 normalized_command
        varchar_30 status
        varchar_1000 response_text
        varchar_40 interpreted_intent
        double confidence
        boolean requires_confirmation
        varchar_30 classification_source
        varchar_40 executed_reference_type
        bigint executed_reference_id
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% DOMAIN: WAREHOUSE (V8)
    %% ══════════════════════════════════════
    warehouse_issue_documents {
        bigint id PK
        bigint trip_id FK_UK
        varchar_50 issue_number UK
        date issue_date
        varchar_30 status
        int document_version
        varchar_200 company_name
        varchar_255 company_address
        varchar_500 issue_reason
        varchar_150 warehouse_name
        varchar_200 project_name
        varchar_150 recipient_name
        varchar_20 recipient_phone
        varchar_255 delivery_address
        bigint prepared_by_user_id FK
        varchar_150 driver_name
        bigint driver_id FK
        bigint vehicle_id FK
        varchar_500 quantity_in_words
        varchar_1000 notes
        timestamp_6 issued_at
        timestamp_6 completed_at
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    warehouse_issue_items {
        bigint id PK
        bigint document_id FK
        int line_number
        varchar_80 item_code
        varchar_255 description
        varchar_255 specification
        varchar_40 unit
        decimal_14_3 requested_quantity
        decimal_14_3 issued_quantity
        decimal_14_3 returned_quantity
        decimal_14_3 delivered_quantity
        varchar_500 condition_note
        varchar_500 confirmation_note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    warehouse_issue_confirmations {
        bigint id PK
        bigint document_id FK
        varchar_30 role_type
        varchar_30 status
        varchar_150 signer_name
        varchar_20 signer_phone
        timestamp_6 signed_at
        double lat
        double lng
        varchar_500 evidence_url
        varchar_500 note
        bigint created_by_user_id FK
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    warehouse_issue_audit_logs {
        bigint id PK
        bigint document_id FK
        varchar_50 action
        varchar_30 from_status
        varchar_30 to_status
        bigint actor_user_id FK
        varchar_150 actor_name
        varchar_500 note
        timestamp_6 created_at
    }

    %% ══════════════════════════════════════
    %% DOMAIN: OCR (V9 + V10 + V11)
    %% ══════════════════════════════════════
    document_ocr_jobs {
        bigint id PK
        bigint owner_user_id FK
        varchar_20 status
        varchar_255 original_filename
        varchar_80 content_type
        bytea image_data
        varchar_500 project_address
        varchar_120 engine
        bigint elapsed_ms
        varchar_500 error_message
        timestamp_6 started_at
        timestamp_6 completed_at
        date voucher_date
        varchar_64 voucher_number
        varchar_32 vehicle_plate
        varchar_255 driver_name
        int trip_count
        text raw_text
        decimal_5_4 project_address_confidence
        decimal_5_4 voucher_date_confidence
        decimal_5_4 vehicle_plate_confidence
        decimal_5_4 driver_name_confidence
        bigint driver_id FK
        bigint trip_id FK
        varchar_32 expected_vehicle_plate
        varchar_32 plate_review_status
        varchar_255 plate_review_reason
        bigint reviewed_by_user_id FK
        timestamp_6 reviewed_at
        varchar_500 review_note
        timestamp_6 created_at
        timestamp_6 updated_at
        boolean deleted
    }

    %% ══════════════════════════════════════
    %% RELATIONSHIPS
    %% ══════════════════════════════════════

    roles ||--o{ role_permissions : "has"
    permissions ||--o{ role_permissions : "in"
    roles ||--o{ users : "assigned to"
    users ||--o{ audit_logs : "performs"
    users ||--o{ system_settings : "updates"

    users ||--o| drivers : "has profile"
    drivers ||--o| vehicles : "currently drives"
    vehicles ||--o{ devices : "has"
    devices ||--o{ device_connection_logs : "logs"
    users ||--o{ mobile_devices : "registers"

    vehicles ||--o{ trips : "assigned to"
    drivers ||--o{ trips : "assigned to"
    trips ||--o{ trip_timelines : "has"
    trips ||--o{ pre_trip_checklists : "checked before"
    users ||--o{ trip_timelines : "acts on"

    drivers ||--o{ safety_events : "triggers"
    vehicles ||--o{ safety_events : "involved in"
    trips ||--o{ safety_events : "during"
    users ||--o{ safety_events : "handles"
    drivers ||--o{ driving_sessions : "has"
    vehicles ||--o{ driving_sessions : "used in"
    trips ||--o{ driving_sessions : "for"
    drivers ||--o{ driver_work_logs : "has"
    trips ||--o{ driver_work_logs : "logs"

    vehicles ||--o{ telemetry_logs : "sends"
    drivers ||--o{ telemetry_logs : "generates"
    trips ||--o{ telemetry_logs : "during"

    vehicles ||--o{ incidents : "involved in"
    drivers ||--o{ incidents : "involved in"
    trips ||--o{ incidents : "during"
    users ||--o{ incidents : "assigned"
    incidents ||--o{ incident_timelines : "has"
    users ||--o{ incident_timelines : "acts on"

    drivers ||--o{ flood_reports : "reports"
    users ||--o{ flood_reports : "verifies"

    vehicles ||--o{ maintenance_orders : "for"
    users ||--o{ maintenance_orders : "assigned"

    users ||--o{ notifications : "receives"
    notifications ||--o{ pending_push_notifications : "queued as"
    users ||--o{ push_tokens : "has"
    mobile_devices ||--o{ push_tokens : "registers"
    push_tokens ||--o{ pending_push_notifications : "sent via"
    notifications ||--o{ notification_reads : "read by"
    users ||--o{ notification_reads : "reads"

    drivers ||--o{ navigation_sessions : "starts"
    vehicles ||--o{ navigation_sessions : "used in"
    trips ||--o{ navigation_sessions : "for"
    navigation_sessions ||--o{ navigation_route_candidates : "has"
    navigation_sessions ||--o{ navigation_events : "generates"
    navigation_sessions ||--|| navigation_route_candidates : "selects"

    safety_events ||--o{ safety_event_evidence : "evidenced by"
    incidents ||--o{ safety_event_evidence : "evidenced by"
    users ||--o{ safety_event_evidence : "uploads"

    users ||--o{ sync_batches : "submits"
    drivers ||--o{ sync_batches : "from"
    sync_batches ||--o{ sync_batch_items : "contains"
    users ||--o{ mobile_command_receipts : "has"
    trips ||--o{ mobile_command_receipts : "for"

    users ||--o{ agent_commands : "sends"
    drivers ||--o{ agent_commands : "for"
    trips ||--o{ agent_commands : "about"

    trips ||--o| warehouse_issue_documents : "has"
    users ||--o{ warehouse_issue_documents : "prepared by"
    drivers ||--o{ warehouse_issue_documents : "driver"
    vehicles ||--o{ warehouse_issue_documents : "vehicle"
    warehouse_issue_documents ||--o{ warehouse_issue_items : "contains"
    warehouse_issue_documents ||--o{ warehouse_issue_confirmations : "confirmed by"
    warehouse_issue_documents ||--o{ warehouse_issue_audit_logs : "audited"
    users ||--o{ warehouse_issue_confirmations : "created by"
    users ||--o{ warehouse_issue_audit_logs : "actor"

    users ||--o{ document_ocr_jobs : "owns"
    drivers ||--o{ document_ocr_jobs : "linked to"
    trips ||--o{ document_ocr_jobs : "for"
    users ||--o{ document_ocr_jobs : "reviews"
```

---

## Tổng Hợp Bảng Theo Domain

| Domain | Bảng | Migration |
|---|---|---|
| **Account & Security** | `permissions`, `roles`, `role_permissions`, `users`, `audit_logs`, `system_settings` | V1 |
| **Vehicle & Driver** | `drivers`, `vehicles`, `devices`, `device_connection_logs`, `mobile_devices` | V1, V4 |
| **Trip** | `trips`, `trip_timelines`, `pre_trip_checklists` | V1, V3 |
| **Safety** | `safety_events`, `driving_sessions`, `driver_work_logs` | V1 |
| **Telemetry** | `telemetry_logs` | V1 |
| **Incident** | `incidents`, `incident_timelines` | V1 |
| **Flood** | `flood_reports` | V1 |
| **Maintenance** | `maintenance_orders` | V1 |
| **Notification** | `notifications`, `push_tokens`, `pending_push_notifications`, `notification_reads` | V1, V4 |
| **Navigation** | `navigation_sessions`, `navigation_route_candidates`, `navigation_events` | V4, V5 |
| **Evidence** | `safety_event_evidence` | V4 |
| **Sync / Offline** | `sync_batches`, `sync_batch_items`, `mobile_command_receipts` | V5, V6 |
| **AI Agent** | `agent_commands` | V3, V7 |
| **Warehouse** | `warehouse_issue_documents`, `warehouse_issue_items`, `warehouse_issue_confirmations`, `warehouse_issue_audit_logs` | V8 |
| **OCR** | `document_ocr_jobs` | V9, V10, V11 |
| ~~AI Config~~ | ~~`agent_ai_configurations`~~ | V12 → **xoá bởi V13** |

**Tổng cộng: 33 bảng** (sau khi V13 xoá `agent_ai_configurations`)

---

## Bảng Nguồn Source Code

| Thành phần | File SQL | Chi tiết |
|---|---|---|
| Schema ban đầu (18 bảng) | `V1__init_schema.sql` | permissions, roles, users, drivers, vehicles, devices, trips, trip_timelines, telemetry_logs, safety_events, driving_sessions, driver_work_logs, incidents, incident_timelines, flood_reports, maintenance_orders, notifications, system_settings, audit_logs |
| Seed data reference | `V2__seed_reference_data.sql` | Dữ liệu mặc định roles, permissions |
| pre_trip_checklists, agent_commands | `V3__add_mobile_driver_app_support.sql` | Thêm 2 bảng hỗ trợ mobile |
| navigation_sessions, navigation_route_candidates, navigation_events, safety_event_evidence, push_tokens, pending_push_notifications, notification_reads, mobile_devices | `V4__offline_navigation_evidence_and_push.sql` | 7 bảng mới |
| sync_batches, sync_batch_items | `V5__navigation_scoring_and_batch_ack.sql` | Thêm scoring columns + sync |
| mobile_command_receipts | `V6__mobile_workflow_idempotency.sql` | Idempotency cho mobile workflow |
| agent_commands mở rộng | `V7__agent_intent_confirmation.sql` | Thêm 6 cột: interpreted_intent, confidence, requires_confirmation, classification_source, executed_reference_type, executed_reference_id |
| warehouse 4 bảng | `V8__warehouse_issue_documents.sql` | warehouse_issue_documents, items, confirmations, audit_logs |
| document_ocr_jobs | `V9__document_ocr_jobs.sql` | OCR job tracking |
| document_ocr_jobs mở rộng | `V10__document_ocr_full_fields.sql` | Thêm 11 cột confidence fields |
| document_ocr_jobs review | `V11__document_plate_review.sql` | Thêm plate review workflow |
| agent_ai_configurations | `V12__agent_ai_configuration.sql` | Lịch sử — tạo bảng (retained for Flyway) |
| Xoá agent_ai_configurations | `V13__remove_legacy_backend_ai_configuration.sql` | `DROP TABLE IF EXISTS agent_ai_configurations` |
