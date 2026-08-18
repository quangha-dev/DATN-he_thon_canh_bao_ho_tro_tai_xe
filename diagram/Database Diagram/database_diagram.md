# Database Diagram — SafeFleet

> **Nguồn:** Trích xuất từ 13 Flyway migration SQL (`V1__init_schema.sql` → `V13__remove_legacy_backend_ai_configuration.sql`).
> File này trình bày schema **tập trung theo domain cốt lõi** — phù hợp trình bày trong báo cáo DATN.

---

## Nhóm 1: Account & Phân Quyền

```mermaid
erDiagram
    permissions {
        bigint id PK
        varchar_100 code UK "e.g. TRIP_CREATE"
        varchar_255 description
        timestamp_6 created_at
        boolean deleted
    }

    roles {
        bigint id PK
        varchar_50 name UK "ADMIN|FLEET_MANAGER|DISPATCHER|SAFETY_OFFICER|RESCUE_TEAM|DRIVER"
        varchar_255 description
        timestamp_6 created_at
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
        varchar_30 status "ACTIVE|INACTIVE|LOCKED"
        bigint role_id FK
        timestamp_6 created_at
        boolean deleted
    }

    audit_logs {
        bigint id PK
        bigint actor_id FK
        varchar_120 action
        varchar_80 target_type
        bigint target_id
        varchar_80 ip_address
        timestamp_6 created_at
    }

    roles ||--o{ role_permissions : ""
    permissions ||--o{ role_permissions : ""
    roles ||--o{ users : "assigned"
    users ||--o{ audit_logs : "performs"
```

---

## Nhóm 2: Xe & Tài Xế

```mermaid
erDiagram
    users {
        bigint id PK
        varchar_80 username UK
        varchar_30 status
        bigint role_id FK
    }

    drivers {
        bigint id PK
        bigint user_id FK_UK "1 user → 1 driver profile"
        varchar_150 full_name
        varchar_50 license_number UK
        varchar_20 license_class "B1|B2|C|D|E|F"
        date license_expired_at
        varchar_30 status "AVAILABLE|DRIVING|RESTING|SUSPENDED|HIGH_RISK"
        bigint current_vehicle_id FK
        int safety_score "Mặc định 100, giảm theo cảnh báo"
        int driving_time_today_minutes
        int continuous_driving_minutes
        int total_trips
        int total_alerts
        timestamp_6 created_at
        boolean deleted
    }

    vehicles {
        bigint id PK
        varchar_30 plate_number UK
        varchar_30 vehicle_type "TRUCK|VAN|BUS|CAR|PICKUP|MOTORBIKE"
        varchar_80 brand
        varchar_80 model
        int manufacture_year
        varchar_30 fuel_type "GASOLINE|DIESEL|ELECTRIC|HYBRID|CNG"
        varchar_30 status "AVAILABLE|RUNNING|RESTING|MAINTENANCE|OFFLINE"
        bigint current_driver_id FK
        bigint gps_device_id FK
        bigint camera_device_id FK
        date inspection_expired_at
        date insurance_expired_at
        double last_lat
        double last_lng
        double last_speed
        timestamp_6 last_updated_at
        boolean deleted
    }

    devices {
        bigint id PK
        varchar_50 device_code UK
        varchar_40 type "GPS|CAMERA|SENSOR"
        varchar_30 status "ONLINE|OFFLINE|FAULTY"
        bigint vehicle_id FK
        varchar_80 serial_number
        varchar_40 firmware_version
        timestamp_6 last_seen_at
        boolean deleted
    }

    mobile_devices {
        bigint id PK
        bigint user_id FK
        varchar_100 device_uuid UK
        varchar_30 platform "ANDROID|IOS"
        varchar_120 app_version
        timestamp_6 registered_at
        timestamp_6 last_seen_at
    }

    users ||--o| drivers : "has profile"
    drivers ||--o| vehicles : "currently drives"
    vehicles ||--o{ devices : "GPS device"
    vehicles ||--o{ devices : "Camera device"
    devices ||--o{ vehicles : "mounted on"
    users ||--o{ mobile_devices : "registers"
```

---

## Nhóm 3: Chuyến Đi (Trip)

```mermaid
erDiagram
    trips {
        bigint id PK
        varchar_50 trip_code UK "Mã chuyến duy nhất"
        bigint vehicle_id FK
        bigint driver_id FK
        varchar_255 start_location
        double start_lat
        double start_lng
        varchar_255 end_location
        double end_lat
        double end_lng
        text waypoints_json "JSON mảng waypoint"
        text planned_route_json "GeoJSON route kế hoạch"
        text actual_route_json "GeoJSON route thực tế"
        timestamp_6 planned_start_time
        timestamp_6 actual_start_time
        timestamp_6 estimated_end_time
        timestamp_6 actual_end_time
        varchar_30 status "DRAFT|ASSIGNED|ACCEPTED|IN_PROGRESS|RESTING|COMPLETED|DELAYED|INCIDENT|CANCELLED"
        int progress "0..100 %"
        varchar_30 risk_level "LOW|MEDIUM|HIGH|CRITICAL"
        varchar_255 cancel_reason
        boolean deleted
    }

    trip_timelines {
        bigint id PK
        bigint trip_id FK
        varchar_80 action "CREATED|ASSIGNED|ACCEPTED|STARTED|PAUSED|RESUMED|COMPLETED|CANCELLED"
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
        boolean deleted
    }

    telemetry_logs {
        bigint id PK
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        double speed "km/h"
        double heading "degrees"
        int battery_level "%"
        varchar_30 gps_status "GOOD|WEAK|LOST|OFFLINE"
        timestamp_6 created_at
    }

    trips ||--o{ trip_timelines : "has timeline"
    trips ||--o| pre_trip_checklists : "checked before start"
    trips ||--o{ telemetry_logs : "GPS logs during trip"
```

---

## Nhóm 4: An Toàn & Giám Sát Lái Xe

```mermaid
erDiagram
    safety_events {
        bigint id PK
        varchar_40 event_type "DROWSINESS|PHONE_USAGE|DISTRACTION|SPEEDING|OVER_DRIVING_TIME|ROUTE_DEVIATION|ABNORMAL_STOP|GPS_LOST|FLOOD_RISK"
        varchar_30 severity "LOW|MEDIUM|HIGH|CRITICAL"
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        double speed
        double confidence "0.0..1.0"
        varchar_500 evidence_url
        varchar_30 status "NEW|ACKNOWLEDGED|RESOLVED|DISMISSED"
        bigint handled_by FK
        timestamp_6 handled_at
        varchar_500 note
        varchar_100 client_event_id "Idempotency key"
        timestamp_6 received_at
        boolean deleted
    }

    driving_sessions {
        bigint id PK
        bigint driver_id FK
        bigint vehicle_id FK
        bigint trip_id FK
        varchar_30 status "ACTIVE|PAUSED|FINISHED"
        timestamp_6 started_at
        timestamp_6 paused_at
        timestamp_6 resumed_at
        timestamp_6 ended_at
        int continuous_minutes "Phút lái liên tục"
        int total_minutes "Tổng phút lái"
        boolean over_driving_alert_created
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
        boolean deleted
    }

    safety_event_evidence {
        bigint id PK
        bigint safety_event_id FK
        bigint incident_id FK
        bigint uploaded_by FK
        varchar_500 object_key UK "MinIO object key"
        varchar_255 original_filename
        varchar_120 content_type
        bigint size_bytes "Max 8MB"
        varchar_64 sha256
        timestamp_6 captured_at
        boolean deleted
    }

    safety_events ||--o{ safety_event_evidence : "has evidence"
    driving_sessions ||--o{ driver_work_logs : "contributes to"
```

---

## Nhóm 5: Sự Cố & Điểm Ngập

```mermaid
erDiagram
    incidents {
        bigint id PK
        varchar_50 incident_code UK "INC-xxxxxxxx"
        varchar_40 type "SOS|ACCIDENT|VEHICLE_BREAKDOWN|DRIVER_UNRESPONSIVE|FLOOD_STUCK|GPS_LOST|MANUAL"
        varchar_30 severity "LOW|MEDIUM|HIGH|CRITICAL"
        bigint vehicle_id FK
        bigint driver_id FK
        bigint trip_id FK
        double lat
        double lng
        varchar_1000 description
        varchar_30 status "OPEN|ACCEPTED|PROCESSING|ESCALATED|RESOLVED|CLOSED|CANCELLED"
        bigint assigned_to FK
        timestamp_6 accepted_at
        timestamp_6 resolved_at
        varchar_100 client_event_id "Idempotency key"
        timestamp_6 received_at
        boolean deleted
    }

    incident_timelines {
        bigint id PK
        bigint incident_id FK
        varchar_80 action "SOS_CREATED|ACCEPTED|ASSIGNED|PROCESSING|RESOLVED|CLOSED"
        bigint actor_id FK
        varchar_500 note
        timestamp_6 created_at
    }

    flood_reports {
        bigint id PK
        double lat
        double lng
        varchar_255 address
        varchar_30 severity "NONE|LOW|MEDIUM|HIGH|BLOCKED"
        varchar_40 source "DRIVER|SYSTEM|MANUAL"
        bigint reported_by_driver_id FK
        double confidence "0.0..0.99 (tính tự động)"
        varchar_30 status "UNVERIFIED|VERIFIED|EXPIRED|REJECTED|RESOLVED"
        bigint verified_by FK
        timestamp_6 verified_at
        timestamp_6 expired_at "Default: +180 phút"
        varchar_100 client_event_id
        timestamp_6 received_at
        boolean deleted
    }

    incidents ||--o{ incident_timelines : "has timeline"
```

---

## Nhóm 6: Điều Hướng Tránh Ngập

```mermaid
erDiagram
    navigation_sessions {
        bigint id PK
        varchar session_uuid UK
        bigint driver_id FK
        bigint vehicle_id FK
        bigint trip_id FK
        bigint selected_candidate_id FK
        varchar_30 status "ACTIVE|COMPLETED|CANCELLED"
        double origin_lat
        double origin_lng
        double destination_lat
        double destination_lng
        timestamp_6 started_at
        timestamp_6 ended_at
        boolean deleted
    }

    navigation_route_candidates {
        bigint id PK
        bigint navigation_session_id FK
        int route_index "0,1,2 (3 tuyến OSRM)"
        varchar_120 label
        int distance_meters
        int duration_seconds
        decimal_7_3 risk_score "Tính từ flood + driver time"
        int flood_intersection_count
        boolean is_recommended "Tuyến an toàn nhất"
        text geometry_json "GeoJSON LineString"
        text warnings_json
        varchar_40 provider "OSRM|LOCAL_DEMO"
        decimal_10_3 total_score
        decimal_10_3 flood_penalty
        decimal_10_3 vehicle_restriction_penalty
        decimal_10_3 driver_time_penalty
        boolean safe
        boolean blocked
        text steps_json
    }

    navigation_events {
        bigint id PK
        bigint navigation_session_id FK
        varchar_40 event_type "OFF_ROUTE|FLOOD_NEARBY|REROUTE|ARRIVED"
        double lat
        double lng
        int distance_to_hazard_meters
        int distance_to_route_meters
        decimal_8_2 gps_accuracy_meters
        timestamp_6 occurred_at
    }

    navigation_sessions ||--o{ navigation_route_candidates : "3 alternatives (OSRM)"
    navigation_sessions ||--o{ navigation_events : "events during nav"
    navigation_sessions ||--|| navigation_route_candidates : "selected route"
```

---

## Nhóm 7: AI Agent & OCR

```mermaid
erDiagram
    agent_commands {
        bigint id PK
        bigint user_id FK
        bigint driver_id FK
        bigint trip_id FK
        varchar_30 command_type "TEXT|VOICE"
        varchar_1000 transcript "Nội dung giọng nói/văn bản"
        varchar_40 interpreted_intent "START_TRIP|PAUSE_TRIP|RESUME_TRIP|COMPLETE_TRIP|GET_DRIVING_TIME|REPORT_FLOOD|SEND_SOS|READ_LATEST_WARNING|UNKNOWN"
        double confidence "0.0..1.0"
        boolean requires_confirmation
        varchar_30 classification_source "LOCAL_RULE|OPENAI"
        varchar_30 status "RECEIVED|UNDERSTOOD|EXECUTED|CANCELLED|UNSUPPORTED|FAILED"
        varchar_1000 response_text
        varchar_40 executed_reference_type "TRIP|INCIDENT|FLOOD_REPORT"
        bigint executed_reference_id
        boolean deleted
    }

    document_ocr_jobs {
        bigint id PK
        bigint owner_user_id FK
        varchar_20 status "PENDING|PROCESSING|COMPLETED|FAILED"
        varchar_255 original_filename
        bytea image_data "Ảnh gốc"
        varchar_120 engine "hybrid|tesseract"
        bigint elapsed_ms
        date voucher_date "Ngày phiếu"
        varchar_64 voucher_number "Số phiếu"
        varchar_32 vehicle_plate "Biển số OCR"
        varchar_255 driver_name "Tên tài xế OCR"
        int trip_count
        decimal_5_4 vehicle_plate_confidence
        decimal_5_4 driver_name_confidence
        bigint driver_id FK
        bigint trip_id FK
        varchar_32 expected_vehicle_plate "Biển số kỳ vọng"
        varchar_32 plate_review_status "NOT_CHECKED|PLATE_MATCH|PLATE_MISMATCH"
        bigint reviewed_by_user_id FK
        timestamp_6 reviewed_at
        boolean deleted
    }
```

---

## Nhóm 8: Thông Báo & Push

```mermaid
erDiagram
    notifications {
        bigint id PK
        bigint recipient_id FK "NULL = global broadcast"
        varchar_40 type "AI_ALERT|SOS|FLOOD|SYSTEM|TRIP"
        varchar_150 title
        varchar_500 content
        varchar_50 reference_type "TRIP|INCIDENT|SAFETY_EVENT|FLOOD_REPORT"
        bigint reference_id
        timestamp_6 read_at
        timestamp_6 created_at
    }

    push_tokens {
        bigint id PK
        bigint user_id FK
        bigint device_id FK
        varchar_30 provider "FCM"
        varchar_512 token UK "FCM device token"
        boolean enabled
        timestamp_6 last_used_at
    }

    pending_push_notifications {
        bigint id PK
        bigint notification_id FK
        bigint user_id FK
        bigint push_token_id FK
        varchar_150 title
        varchar_500 body
        text data_json
        varchar_30 status "PENDING|SENT|FAILED|SKIPPED"
        int attempt_count "Max retry"
        timestamp_6 next_attempt_at
        timestamp_6 sent_at
        varchar_1000 last_error
    }

    notification_reads {
        bigint notification_id PK,FK
        bigint user_id PK,FK
        timestamp_6 read_at
    }

    notifications ||--o{ pending_push_notifications : "queued for push"
    notifications ||--o{ notification_reads : "read tracking"
    push_tokens ||--o{ pending_push_notifications : "sent via"
```

---

## Nhóm 9: Kho Hàng & Phiếu Xuất

```mermaid
erDiagram
    warehouse_issue_documents {
        bigint id PK
        bigint trip_id FK_UK "1 chuyến → 1 phiếu"
        varchar_50 issue_number UK
        date issue_date
        varchar_30 status "DRAFT|ISSUED|CONFIRMED|COMPLETED|CANCELLED"
        int document_version
        varchar_150 warehouse_name
        varchar_200 project_name
        varchar_150 recipient_name
        bigint prepared_by_user_id FK
        bigint driver_id FK
        bigint vehicle_id FK
        timestamp_6 issued_at
        timestamp_6 completed_at
        boolean deleted
    }

    warehouse_issue_items {
        bigint id PK
        bigint document_id FK
        int line_number
        varchar_255 description "Tên vật tư"
        varchar_40 unit "cái|kg|m|thùng"
        decimal_14_3 requested_quantity
        decimal_14_3 issued_quantity
        decimal_14_3 returned_quantity
        decimal_14_3 delivered_quantity
        varchar_500 condition_note
        boolean deleted
    }

    warehouse_issue_confirmations {
        bigint id PK
        bigint document_id FK
        varchar_30 role_type "DRIVER|RECIPIENT|WAREHOUSE_KEEPER"
        varchar_30 status "PENDING|SIGNED|REJECTED"
        varchar_150 signer_name
        timestamp_6 signed_at
        double lat
        double lng
        varchar_500 evidence_url "Ảnh chữ ký"
        bigint created_by_user_id FK
        boolean deleted
    }

    warehouse_issue_audit_logs {
        bigint id PK
        bigint document_id FK
        varchar_50 action "CREATED|ISSUED|CONFIRMED|COMPLETED|CANCELLED"
        varchar_30 from_status
        varchar_30 to_status
        bigint actor_user_id FK
        timestamp_6 created_at
    }

    warehouse_issue_documents ||--o{ warehouse_issue_items : "contains items"
    warehouse_issue_documents ||--o{ warehouse_issue_confirmations : "confirmed by 3 roles"
    warehouse_issue_documents ||--o{ warehouse_issue_audit_logs : "audit trail"
```

---

## Thống Kê Database

| Nhóm | Số bảng | Migration |
|---|---|---|
| Account & Phân quyền | 5 | V1 |
| Xe & Tài xế | 4 | V1, V4 |
| Chuyến đi | 3 | V1 |
| An toàn & Giám sát | 4 | V1, V4 |
| Sự cố & Điểm ngập | 3 | V1 |
| Điều hướng | 3 | V4, V5 |
| AI Agent & OCR | 2 | V3, V7, V9-V11 |
| Thông báo & Push | 4 | V1, V4 |
| Kho hàng & Phiếu xuất | 4 | V8 |
| Sync / Offline | 3 | V5, V6 |
| **Tổng** | **35 → 33 sau V13** | V1-V13 |
