# Mobile API Contract - SafeFleet Driver App

## Base URL

```text
http://localhost:8080/api/v1
```

## WebSocket URL

```text
ws://localhost:8080/ws
```

## Auth flow

Mobile dùng lại JWT hiện có.

### Login

```http
POST /auth/login
Content-Type: application/json
```

Request:

```json
{
  "usernameOrEmail": "driver01",
  "password": "123456"
}
```

Response hiện tại:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "...",
    "tokenType": "Bearer",
    "userId": 6,
    "driverId": 1,
    "username": "driver01",
    "email": "driver01@safefleet.vn",
    "fullName": "Nguyen Van An",
    "role": "DRIVER"
  },
  "timestamp": "2026-07-08T09:00:00"
}
```

### Auth header

```http
Authorization: Bearer <token>
```

## Unified response

```json
{
  "success": true,
  "message": "Success",
  "data": {},
  "timestamp": "2026-07-08T09:00:00"
}
```

## Existing APIs mobile có thể dùng ngay

### Current user

```http
GET /auth/me
```

### Trip lifecycle

```http
GET /trips
GET /trips/{id}
POST /trips/{id}/accept
POST /trips/{id}/start
POST /trips/{id}/pause
POST /trips/{id}/resume
POST /trips/{id}/complete
GET /trips/{id}/timeline
```

### Telemetry

```http
POST /telemetry
```

Request:

```json
{
  "vehicleId": 1,
  "driverId": 1,
  "tripId": 1,
  "lat": 21.0285,
  "lng": 105.8542,
  "speed": 42.5,
  "heading": 90.0,
  "batteryLevel": 88,
  "gpsStatus": "GOOD"
}
```

### Safety event

```http
POST /safety-events
```

### SOS

```http
POST /incidents/sos
```

### Flood report

```http
POST /flood-reports
GET /flood-reports/map
POST /flood-reports/route-check
```

### Notification

```http
GET /notifications
PATCH /notifications/{id}/read
PATCH /notifications/read-all
```

## Mobile facade APIs đã bổ sung

Các endpoint này nằm dưới:

```text
/api/v1/mobile
```

### Profile/config

```http
GET /mobile/me
GET /mobile/safety-summary
GET /mobile/current-assignment
GET /mobile/config
```

### Trips

```http
GET /mobile/trips/today
GET /mobile/trips/{id}
POST /mobile/trips/{id}/accept
POST /mobile/trips/{id}/pre-trip-checklist
POST /mobile/trips/{id}/start
POST /mobile/trips/{id}/pause
POST /mobile/trips/{id}/resume
POST /mobile/trips/{id}/complete
GET /mobile/trips/{id}/summary
```

### Telemetry/safety

```http
POST /mobile/telemetry
GET /mobile/safety-events/today
POST /mobile/safety-events
```

### Incident/flood/agent/notification

```http
POST /mobile/incidents/sos
GET /mobile/incidents
GET /mobile/incidents/{id}
POST /mobile/flood-reports
GET /mobile/flood-points/nearby
POST /mobile/flood-reports/quick
POST /mobile/route-check
POST /mobile/agent/command
GET /mobile/agent/history
GET /mobile/notifications
PATCH /mobile/notifications/{id}/read
PATCH /mobile/notifications/read-all
```

## WebSocket topics

Không đổi topic hiện có:

```text
/topic/vehicles/positions
/topic/vehicles/{vehicleId}/position
/topic/safety-events
/topic/incidents
/topic/notifications
/topic/flood-reports
```

## Enums

### TripStatus backend

```text
DRAFT
ASSIGNED
ACCEPTED
IN_PROGRESS
RESTING
COMPLETED
DELAYED
INCIDENT
CANCELLED
```

Mobile có thể map:

```text
PLANNED -> DRAFT
PAUSED -> RESTING
```

### SafetyEventType

```text
DROWSINESS
PHONE_USAGE
DISTRACTION
SPEEDING
OVER_DRIVING_TIME
ROUTE_DEVIATION
ABNORMAL_STOP
GPS_LOST
FLOOD_RISK
```

### Severity

```text
LOW
MEDIUM
HIGH
CRITICAL
```

### IncidentStatus backend

```text
OPEN
ACCEPTED
PROCESSING
ESCALATED
RESOLVED
CLOSED
CANCELLED
```

### FloodSeverity

```text
NONE
LOW
MEDIUM
HIGH
BLOCKED
```

## API mới bổ sung

### `GET /mobile/me`

Trả về user hiện tại và hồ sơ driver gắn với user.

### `GET /mobile/config`

Trả về rule lái xe và threshold cơ bản:

```json
{
  "maxContinuousDrivingMinutes": 240,
  "warningLevel1Minutes": 180,
  "warningLevel2Minutes": 210,
  "criticalWarningMinutes": 230,
  "phoneUsageSpeedThresholdKmh": 10,
  "phoneUsageDurationThresholdSeconds": 3,
  "floodReportExpirationMinutes": 180
}
```

### `GET /mobile/current-assignment`

Trả về chuyến active đầu tiên của tài xế với trạng thái:

```text
ASSIGNED, ACCEPTED, IN_PROGRESS, RESTING
```

### `POST /mobile/trips/{id}/pre-trip-checklist`

Request:

```json
{
  "exteriorChecked": true,
  "tiresChecked": true,
  "brakeChecked": true,
  "lightsChecked": true,
  "cameraChecked": true,
  "gpsChecked": true,
  "documentsChecked": true,
  "note": "Đã kiểm tra trước chuyến"
}
```

Response `data.passed = true` khi tất cả hạng mục đều đạt.

### `POST /mobile/flood-reports/quick`

Mobile không cần gửi `reportedByDriverId`, backend tự lấy theo JWT.

Request:

```json
{
  "lat": 21.0285,
  "lng": 105.8542,
  "address": "Phạm Văn Đồng",
  "severity": "HIGH",
  "imageUrl": "https://example.com/flood.jpg"
}
```

### `GET /mobile/flood-points/nearby`

```http
GET /mobile/flood-points/nearby?lat=21.0285&lng=105.8542&radiusKm=3
```

`radiusKm` mặc định là `3`, giới hạn trong khoảng `0.1` đến `20`.

### `POST /mobile/agent/command`

Request:

```json
{
  "commandType": "VOICE",
  "tripId": 1,
  "transcript": "Tôi cần SOS cứu hộ"
}
```

Backend hiện ghi log lệnh và phân loại cơ bản:

```text
UNDERSTOOD
UNSUPPORTED
FAILED
```

Lệnh SOS chưa tự tạo incident để tránh kích hoạt cứu hộ khi chưa có bước xác nhận từ app.

## Kiểm thử đã chạy

```powershell
mvn.cmd -q test
```

Kết quả: PASS với MySQL thật `jdbc:mysql://localhost:3306/QuanLyCongViecDuAn`.
