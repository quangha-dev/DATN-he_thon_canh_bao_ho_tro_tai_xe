# SafeFleet Backend - Plan & Progress

Do an: "Nghien cuu va xay dung he thong Agentic AI ho tro an toan lai xe dua tren nhan dien hanh vi tai xe va canh bao cuu ho tu dong".

Ngay tao: 2026-07-08

## 1. Kien truc backend cuoi cung

Backend duoc thiet ke theo Package-by-Feature, khong tach lop technical layer toan cuc. Moi domain so huu controller, service, repository, dto, entity, enum va mapper rieng khi can.

Cong nghe chinh:
- Java 21, Spring Boot 3.x, Maven.
- Spring Web, Spring Data JPA, Spring Security, JWT.
- MySQL la database chinh.
- Flyway quan ly schema va seed data.
- WebSocket/STOMP cho realtime GPS, safety event, incident va notification.
- Swagger/OpenAPI voi Bearer Auth.
- Lombok, Jakarta Validation.
- Global exception handler va API response thong nhat.

Nguyen tac kien truc:
- Controller chi nhan request, validate, goi service va tra response.
- Service chua nghiep vu, transaction boundary va rule xu ly.
- Repository dung Spring Data JPA query method / JPQL.
- Entity khong lo truc tiep ra response; response DTO/mapper rieng.
- Security ap dung stateless JWT, RBAC theo role.
- Driver chi truy cap du lieu cua chinh minh thong qua service-level ownership check.
- Cac bang chinh co `created_at`, `updated_at`, `deleted`.

Realtime:
- `/ws` dung STOMP endpoint.
- Topic de xuat:
  - `/topic/vehicles/positions`
  - `/topic/vehicles/{vehicleId}/position`
  - `/topic/safety-events`
  - `/topic/incidents`
  - `/topic/notifications`

## 2. MySQL schema va quan he bang

Bang account/RBAC:
- `roles(id, name, description, created_at, updated_at)`
- `permissions(id, code, description, created_at, updated_at)`
- `role_permissions(role_id, permission_id)`
- `users(id, username, email, password_hash, full_name, phone, status, role_id, driver_id, created_at, updated_at, deleted)`

Bang vehicle/driver/device:
- `drivers(id, user_id, full_name, phone, email, address, license_number, license_class, license_expired_at, status, current_vehicle_id, safety_score, driving_time_today_minutes, continuous_driving_minutes, total_trips, total_alerts, created_at, updated_at, deleted)`
- `vehicles(id, plate_number, vehicle_type, brand, model, manufacture_year, load_capacity, seat_count, fuel_type, status, current_driver_id, gps_device_id, camera_device_id, inspection_expired_at, insurance_expired_at, last_lat, last_lng, last_speed, last_updated_at, created_at, updated_at, deleted)`
- `devices(id, device_code, name, type, status, vehicle_id, phone, serial_number, firmware_version, last_seen_at, created_at, updated_at, deleted)`
- `device_connection_logs(id, device_id, status, lat, lng, note, created_at)`

Bang trip/dispatch:
- `trips(id, trip_code, vehicle_id, driver_id, start_location, start_lat, start_lng, end_location, end_lat, end_lng, waypoints_json, planned_route_json, actual_route_json, planned_start_time, actual_start_time, estimated_end_time, actual_end_time, status, progress, risk_level, cancel_reason, created_at, updated_at, deleted)`
- `trip_timelines(id, trip_id, action, actor_id, note, created_at)`

Bang telemetry/safety/driving time:
- `telemetry_logs(id, vehicle_id, driver_id, trip_id, lat, lng, speed, heading, battery_level, gps_status, created_at)`
  - Index: `(vehicle_id, created_at)`, `(trip_id, created_at)`, `(driver_id, created_at)`.
- `safety_events(id, event_type, severity, vehicle_id, driver_id, trip_id, lat, lng, speed, confidence, evidence_url, status, handled_by, handled_at, note, created_at, updated_at)`
  - Index: `(status, severity, created_at)`, `(vehicle_id, created_at)`, `(driver_id, created_at)`.
- `driving_sessions(id, driver_id, vehicle_id, trip_id, status, started_at, paused_at, resumed_at, ended_at, continuous_minutes, total_minutes, created_at, updated_at)`
- `driver_work_logs(id, driver_id, trip_id, work_date, driving_minutes, rest_minutes, note, created_at, updated_at)`

Bang incident/flood/maintenance/notification/report/settings:
- `incidents(id, incident_code, type, severity, vehicle_id, driver_id, trip_id, lat, lng, description, status, assigned_to, created_at, accepted_at, resolved_at, updated_at, deleted)`
- `incident_timelines(id, incident_id, action, actor_id, note, created_at)`
- `flood_reports(id, lat, lng, address, severity, source, reported_by_driver_id, image_url, confidence, status, verified_by, verified_at, expired_at, created_at, updated_at, deleted)`
- `maintenance_orders(id, maintenance_code, vehicle_id, type, title, description, scheduled_date, completed_date, cost, status, priority, assigned_to, note, created_at, updated_at, deleted)`
- `notifications(id, recipient_id, type, title, content, reference_type, reference_id, read_at, created_at)`
- `system_settings(id, setting_key, setting_group, setting_value, value_type, description, updated_by, created_at, updated_at)`
- `audit_logs(id, actor_id, action, target_type, target_id, ip_address, user_agent, created_at)`

Quan he chinh:
- `users.role_id -> roles.id`
- `drivers.user_id -> users.id`
- `users.driver_id -> drivers.id`
- `vehicles.current_driver_id -> drivers.id`
- `vehicles.gps_device_id/camera_device_id -> devices.id`
- `drivers.current_vehicle_id -> vehicles.id`
- `trips.vehicle_id -> vehicles.id`, `trips.driver_id -> drivers.id`
- `telemetry_logs.vehicle_id/driver_id/trip_id -> vehicles/drivers/trips`
- `safety_events.vehicle_id/driver_id/trip_id/handled_by -> vehicles/drivers/trips/users`
- `incidents.vehicle_id/driver_id/trip_id/assigned_to -> vehicles/drivers/trips/users`

## 3. MongoDB decision

Khong dung MongoDB trong ban backend dau tien.

Ly do:
- Yeu cau seed va schema quan he rat manh, MySQL du dap ung do an va de demo.
- Telemetry trong do an co the luu MySQL voi index `(vehicle_id, created_at)` va `(trip_id, created_at)`.
- Neu sau nay tan suat GPS rat cao, co the tach `telemetry_logs` sang MongoDB/TimescaleDB ma khong anh huong domain chinh vi service dang bao boc repository.

## 4. API endpoints theo feature

Base path: `/api/v1`

Auth/Account:
- `POST /auth/login`
- `GET /auth/me`
- `POST /accounts`
- `POST /accounts/drivers`
- `GET /accounts`
- `GET /accounts/{id}`
- `PATCH /accounts/{id}/status`

Vehicle:
- `POST /vehicles`
- `GET /vehicles`
- `GET /vehicles/{id}`
- `PUT /vehicles/{id}`
- `DELETE /vehicles/{id}`
- `GET /vehicles/{id}/trips`
- `GET /vehicles/{id}/safety-events`
- `GET /vehicles/{id}/realtime-status`
- `GET /vehicles/map/positions`

Driver:
- `POST /drivers`
- `GET /drivers`
- `GET /drivers/{id}`
- `PUT /drivers/{id}`
- `DELETE /drivers/{id}`
- `GET /drivers/{id}/trips`
- `GET /drivers/{id}/safety-events`
- `GET /drivers/{id}/driving-time-today`
- `POST /drivers/{id}/recalculate-safety-score`

Trip/Dispatch:
- `POST /trips`
- `GET /trips`
- `GET /trips/{id}`
- `POST /trips/{id}/assign`
- `POST /trips/{id}/accept`
- `POST /trips/{id}/start`
- `POST /trips/{id}/pause`
- `POST /trips/{id}/resume`
- `POST /trips/{id}/complete`
- `POST /trips/{id}/cancel`
- `GET /trips/{id}/timeline`
- `GET /dispatch/suggestions`
- `GET /dispatch/availability`

Telemetry:
- `POST /telemetry`
- `GET /telemetry/vehicles/current`
- `GET /telemetry/trips/{tripId}/history`
- `GET /telemetry/trips/{tripId}/replay`

Safety:
- `POST /safety-events`
- `GET /safety-events`
- `GET /safety-events/{id}`
- `POST /safety-events/{id}/acknowledge`
- `POST /safety-events/{id}/resolve`
- `POST /safety-events/{id}/dismiss`
- `POST /safety-events/{id}/create-incident`

Driving Time:
- `POST /driving-sessions/start`
- `POST /driving-sessions/{id}/pause`
- `POST /driving-sessions/{id}/resume`
- `POST /driving-sessions/{id}/finish`
- `GET /driving-sessions/drivers/{driverId}/remaining-time`

Incident/SOS:
- `POST /incidents/sos`
- `POST /incidents`
- `GET /incidents`
- `GET /incidents/{id}`
- `POST /incidents/{id}/accept`
- `POST /incidents/{id}/assign`
- `POST /incidents/{id}/timeline`
- `POST /incidents/{id}/close`

Flood:
- `POST /flood-reports`
- `GET /flood-reports`
- `GET /flood-reports/map`
- `POST /flood-reports/{id}/verify`
- `POST /flood-reports/{id}/resolve`
- `POST /flood-reports/route-check`
- `POST /flood-reports/route-risk-summary`

Device:
- `POST /devices`
- `GET /devices`
- `GET /devices/{id}`
- `PUT /devices/{id}`
- `DELETE /devices/{id}`
- `POST /devices/{id}/assign-vehicle`
- `PATCH /devices/{id}/status`
- `GET /devices/{id}/connection-logs`

Maintenance:
- `POST /maintenance-orders`
- `GET /maintenance-orders`
- `GET /maintenance-orders/{id}`
- `PUT /maintenance-orders/{id}`
- `DELETE /maintenance-orders/{id}`
- `GET /maintenance-orders/due-alerts`
- `GET /maintenance-orders/document-expiry-alerts`

Notification:
- `GET /notifications`
- `PATCH /notifications/{id}/read`
- `PATCH /notifications/read-all`

Reports/Dashboard:
- `GET /dashboard/summary`
- `GET /reports/vehicles/status`
- `GET /reports/safety-events/by-type`
- `GET /reports/trips/by-day`
- `GET /reports/drivers/high-risk`
- `GET /reports/drivers/{id}`
- `GET /reports/vehicles/{id}`
- `GET /reports/flood`
- `GET /reports/incidents`

System Settings:
- `GET /settings`
- `GET /settings/{key}`
- `PUT /settings/{key}`
- `GET /settings/groups/{group}`

## 5. Package structure

```text
backend/
  pom.xml
  src/main/java/com/safefleet/
    SafeFleetApplication.java
    auth/
    account/
    vehicle/
    driver/
    trip/
    dispatch/
    telemetry/
    safety/
    incident/
    flood/
    device/
    maintenance/
    report/
    notification/
    settings/
    config/
    common/
    infrastructure/
  src/main/resources/
    application.yml
    db/migration/
      V1__init_schema.sql
      V2__seed_data.sql
```

## 6. Implementation progress

Legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Done

### Planning
- [x] Backend architecture proposed
- [x] MySQL schema proposed
- [x] MongoDB decision documented
- [x] API endpoints listed
- [x] Package structure proposed
- [x] Progress file created

### Project scaffold
- [x] Maven Spring Boot project
- [x] `application.yml`
- [x] README
- [x] Flyway migration folder

### Common foundation
- [x] Unified API response
- [x] Pagination response
- [x] Global exception handler
- [x] Base audit entity
- [x] Swagger/OpenAPI config
- [x] WebSocket/STOMP config

### Security/Auth/RBAC
- [x] User/Role/Permission entities
- [x] JWT service/filter
- [x] Spring Security config
- [x] Login API
- [x] Current profile API
- [x] Account admin APIs

### Phase 1
- [x] Vehicle domain
- [x] Driver domain
- [x] Trip domain
- [x] Telemetry realtime basic
- [x] Dashboard summary

### Phase 2
- [x] Safety event domain
- [x] Driving time rule/session domain
- [x] Incident/SOS domain
- [x] Notification realtime

### Phase 3
- [x] Flood report domain
- [x] Dispatch suggestion
- [x] Device management
- [x] Maintenance management
- [x] Reports
- [x] System settings

### Database/Seed
- [x] V1 schema
- [x] V2 reference seed data
- [x] Java demo seeder for Hanoi/Vietnam data
- [x] Standalone full MySQL reset/create/seed script

### Verification
- [x] Maven compile
- [x] Basic tests or smoke checks
- [x] API controller smoke tests for all endpoint groups
- [x] Real MySQL integration tests for authenticated API flows and exception cases
- [x] Frontend contract checks: CORS preflight, JWT/RBAC, driver ownership, and soft error messages

## 7. Current status log

- 2026-07-08: Created plan/progress file before code.
- 2026-07-08: Added Maven scaffold, Spring Boot entrypoint, `application.yml`, and README.
- 2026-07-08: Added common response, pagination, exception handling, base entity, Swagger, and WebSocket config.
- 2026-07-08: Added Auth/RBAC, account APIs, device APIs, vehicle APIs, and driver APIs with DTO/service/controller structure.
- 2026-07-08: Added Trip domain with lifecycle transitions, assignment validation, timelines, and vehicle/driver trip history endpoints.
- 2026-07-08: Added Telemetry realtime ingestion/history/replay and Dashboard summary endpoint.
- 2026-07-08: Added Notification, System Settings, Safety Event, Incident/SOS, and Driving Time Rule Engine.
- 2026-07-08: Added Flood Management, Dispatch suggestions, Maintenance, and Reports APIs.
- 2026-07-08: Added Flyway V1 schema, V2 reference settings/roles, Java demo seeder, and verified with `mvn -q -DskipTests compile` plus `mvn -q test`.
- 2026-07-08: Added standalone SQL file `backend/database/safefleet_full_database.sql` with `DROP DATABASE`, full schema, indexes, foreign keys, seed data, and Flyway baseline compatibility.
- 2026-07-08: Added `ApiControllerSmokeTest` to cover every current REST controller group with MockMvc standalone, unified response checks, and validation error checks.
- 2026-07-08: Fixed test compile import for `ResultActions`; reran `mvn -q test` successfully. Surefire result: 13 tests, 0 failures, 0 errors, 0 skipped.
- 2026-07-08: Added `RealMySqlApiIntegrationTest` for Flyway migration, real Spring Security/JWT, real JPA services, and HTTP calls through a random local port.
- 2026-07-08: First real MySQL test run failed before Spring context because MySQL user `admin123@` has no permission to create/drop `QuanLyCongViecDuAn_it`. Adjusted the integration test to use the provided real schema `QuanLyCongViecDuAn` and unique `IT-*` test data instead of destructive database reset.
- 2026-07-08: Fixed client-error exception handling for malformed JSON, enum/type mismatch query params, missing required request params, unsupported media type, and unsupported HTTP method.
- 2026-07-08: Fixed integration test runtime issues discovered against real MySQL/API: request `Content-Type` for empty action bodies, correct dispatch availability field `assignable`, correct route-risk field `risky`, and PATCH/401 HTTP client handling.
- 2026-07-08: Reran `mvn -q test` against real MySQL `QuanLyCongViecDuAn`. Surefire result: 17 tests, 0 failures, 0 errors, 0 skipped.
- 2026-07-08: Standardized frontend-facing error messages to short Vietnamese messages and added JSON `401/403` security responses.
- 2026-07-08: Added frontend contract integration checks for `http://localhost:5173` CORS preflight, missing/invalid token, RBAC denial, driver data ownership, invalid enum/query param, missing parameter, malformed JSON, not found, duplicate data, and invalid settings.
- 2026-07-08: Reran `mvn -q test` against real MySQL `QuanLyCongViecDuAn`. Surefire result: 18 tests, 0 failures, 0 errors, 0 skipped.
- 2026-07-08: Rebuilt backend jar with `mvn -q -DskipTests package`. Verified `run-backend-local.ps1` starts the new jar successfully on port 8080 in foreground; background process persistence is limited by the current desktop sandbox, so use the script to run locally for frontend development.
- 2026-07-08: Updated CORS to allow localhost development ports via origin patterns (`http://localhost:*`, `http://127.0.0.1:*`) so Next.js frontend on port 3001 can call backend APIs.
- 2026-07-08: Rechecked real frontend integration against running MySQL/backend: CORS preflight from `http://localhost:3001` returned 200, invalid login returned `Tên đăng nhập hoặc mật khẩu không đúng`, RBAC returned `Không có quyền truy cập` for unauthorized driver/rescue account access, and allowed driver trip/rescue incident APIs returned 200.
- 2026-07-08: Added `location` backend feature without Google key: `/api/v1/locations/autocomplete` uses Photon/OpenStreetMap with Hanoi local fallback, `/api/v1/locations/route` uses OSRM with Haversine fallback. Added backend validation for trip schedule: departure cannot be in the past and estimated end must be after departure.
- 2026-07-08: Real-tested location APIs through running backend: no-accent/accent Nguyen Trai autocomplete returns Hanoi fallback suggestion when Photon has no result; My Dinh to Ha Dong route returns OSRM provider, 8.3 km, 10 minutes, 243 geometry coordinates. Reran `mvn -q test` successfully.
