# Báo cáo hiện trạng hệ thống và hợp đồng API SafeFleet

> Sinh tự động từ OpenAPI của backend đang chạy tại `http://localhost:8080` ngày 27/07/2026. Báo cáo này là nguồn tích hợp hiện hành; file `BAO_CAO_TICH_HOP_APP_SAFEFLEET.md` là bản khảo sát baseline trước các vòng hoàn thiện.

## 1. Kết luận triển khai

SafeFleet hiện là một MVP end-to-end gồm web điều hành đội xe, backend Spring Boot, MySQL thật, ứng dụng Flutter cho tài xế, AI service FastAPI và hạ tầng Docker. Luồng dữ liệu chính đã được kiểm tra bằng dữ liệu thật: tài xế đăng nhập, gửi cảnh báo/SOS/ảnh bằng chứng; backend xác lập đúng tài xế từ JWT, ghi MySQL, phát realtime và web quản lý có thể tiếp nhận/cập nhật trạng thái.

Hệ thống giải quyết các nỗi đau trọng tâm: điều phối thiếu dữ liệu tức thời, khó theo dõi giờ lái và rủi ro tài xế, báo ngập rời rạc, SOS thiếu vòng đời xử lý, mất mạng làm mất dữ liệu, và thiếu bằng chứng có kiểm soát truy cập.

## 2. Cấu trúc và trách nhiệm module

| Module | Công nghệ | Trách nhiệm | Đầu vào chính | Đầu ra chính |
|---|---|---|---|---|
| `web_quan_ly/backend` | Java 21, Spring Boot 3.3.7, JPA, Flyway | Auth/RBAC, nghiệp vụ đội xe, mobile facade, navigation, realtime, evidence, push fallback | REST JSON/multipart, STOMP CONNECT, GPS/safety/SOS | JSON envelope, STOMP topic, MySQL, MinIO private (local fallback) |
| `web_quan_ly/frontend` | Next.js 16.2.12, React 19, MapLibre | 16 route ứng dụng gồm Command Center, thiết bị và bảo trì | REST backend, STOMP realtime | Dashboard, bản đồ, bảng điều phối, workflow sự cố |
| `safe_fleet_driver_ui` | Flutter 3.44.5, Dart 3.12.2 | App tài xế, GPS, offline queue, dẫn đường, AI cabin cục bộ | Camera trước, GPS, thao tác tài xế, REST | Cảnh báo tại máy, telemetry/safety/SOS/flood, UI chuyến đi |
| `safefleet_ai` | Python 3.11, FastAPI | Intent fallback, metadata model, train/evaluate/export/benchmark | Transcript, dữ liệu hiệu chuẩn | Intent, confidence, metadata/export |
| `docker-compose.yml` | Docker Compose | MySQL/backend/frontend/AI/MinIO, healthcheck và volume | `.env` | Stack local có thể khởi động thống nhất |

## 3. Cổng, URL và dữ liệu bền vững

| Thành phần | URL/cổng host | Health | Dữ liệu bền vững |
|---|---|---|---|
| Web | `http://localhost:3000` | HTTP `/` | stateless |
| Backend | `http://localhost:8080` | `/actuator/health` | MySQL + MinIO private; `evidence_data` chỉ dùng khi chọn local fallback |
| OpenAPI | `http://localhost:8080/v3/api-docs` | HTTP 200 | — |
| Swagger UI | `http://localhost:8080/swagger-ui/index.html` | HTTP 200 | — |
| AI | `http://localhost:8000` | `/health` | model metadata bind mount |
| MySQL | `127.0.0.1:3307` | container healthcheck | `mysql_data` |
| MinIO | `http://localhost:9000`, console `:9001` | `/minio/health/live` | `minio_data` |

Không đưa password, JWT secret hoặc access token vào mã nguồn/tài liệu. App Android emulator dùng `http://10.0.2.2:8080/api/v1`; điện thoại thật dùng `http://<IP-LAN-PC>:8080/api/v1`.

## 4. Chức năng đã có

- Access token + refresh token xoay vòng, logout/revoke, BCrypt, RBAC và ownership theo tài xế.
- Quản lý tài khoản, tài xế, xe, thiết bị, chuyến, điều phối, bảo trì, ngập, cảnh báo, sự cố và báo cáo.
- Mobile bootstrap, assignment, checklist/workflow chuyến, driving session, telemetry đơn/batch có ACK ổn định.
- Offline queue ưu tiên `SOS → safety CRITICAL → safety HIGH → workflow → flood → telemetry`; chỉ xóa sau ACK server.
- Safety/SOS/flood/workflow dùng `clientEventId` chống gửi lặp; safety có cooldown 30 giây; server bỏ qua `driverId/vehicleId/tripId` giả mạo từ app.
- Navigation Photon/OSRM có fallback, ba phương án, chấm rủi ro ngập, detour, turn-by-turn, off-route 75 m/15 giây và reroute.
- Evidence JPEG/PNG/WebP tối đa 8 MB, kiểm magic bytes, SHA-256, filename/path an toàn, tải có JWT/ownership và `no-store`.
- Push token theo thiết bị; khi chưa có Firebase, notification chuyển `POLLING_FALLBACK` để app đọc REST.
- STOMP native `/ws-native` và SockJS `/ws`; JWT bắt buộc ở frame CONNECT, CORS dùng origin cấu hình rõ ràng.
- AI cabin xử lý camera ngay trên thiết bị: mắt/PERCLOS, head pose, yawn, nhãn điện thoại, tốc độ/thời lượng/cooldown; không stream video liên tục lên server.
- Web Command Center tone trắng/navy/teal, MapLibre, STOMP realtime và REST polling dự phòng 30 giây.

## 5. Quy ước API cho app

Base URL: `/api/v1`. Trừ login/refresh và health/OpenAPI, API nghiệp vụ dùng `Authorization: Bearer <accessToken>`.

Response thông thường:

```json
{
  "success": true,
  "message": "Thông báo",
  "data": {},
  "timestamp": "2026-07-27T02:00:00+07:00"
}
```

Mã lỗi quan trọng: `400` payload/rule sai, `401` thiếu hoặc hết JWT, `403` sai role/ownership, `404` không tồn tại, `409` xung đột trạng thái, `429` vượt rate limit, `500` lỗi ngoài dự kiến. Client phải giữ `clientEventId` ổn định khi retry và không tự sinh ID mới cho cùng một sự kiện.

## 6. Luồng tích hợp app tài xế khuyến nghị

1. Login, lưu token trong secure storage; refresh im lặng khi access token hết hạn.
2. Gọi `GET /mobile/bootstrap`, cache danh mục cần offline và hiển thị assignment/trip hiện hành.
3. Bắt đầu workflow/checklist; mở driving session và thu GPS theo chu kỳ phù hợp.
4. Khi online gửi telemetry batch; khi offline ghi queue SQLite cùng `clientEventId`, `createdAt` và priority.
5. AI camera phát cảnh báo cục bộ trước; chỉ gửi metadata safety event và evidence người dùng cho phép/chính sách yêu cầu.
6. SOS được ưu tiên cao nhất; server lấy tài xế/chuyến/xe từ JWT context và trả lại ID ổn định khi retry.
7. Navigation dùng alternative do backend khuyến nghị; gửi vị trí để kiểm off-route/reroute.
8. Subscribe notification hoặc polling; hiển thị timeline incident và trạng thái đội điều hành đã accept/dispatch/resolve.
9. Logout gọi API revoke rồi xóa secure storage và queue nhạy cảm đã đồng bộ.

## 7. WebSocket/STOMP

Kết nối native tới `ws://<host>:8080/ws-native`, sau khi mở socket gửi:

```text
CONNECT
accept-version:1.2
Authorization:Bearer <accessToken>
heart-beat:10000,10000

\0
```

Topic chính: `/topic/telemetry`, `/topic/safety-events`, `/topic/incidents`, `/topic/flood-reports`, `/topic/notifications`. Kết nối không JWT nhận frame `ERROR`; client cần exponential backoff và REST polling dự phòng.

## 8. Bằng chứng kiểm thử ngày 27/07/2026

| Hạng mục | Kết quả |
|---|---|
| Backend Maven | 25/25 PASS; 9 integration trên Testcontainers MySQL 8.4 |
| Flyway | V1–V7 validate/migrate PASS; `ddl-auto=validate` |
| API Docker thật | Login, push, safety replay, SOS replay, accept/timeline, evidence/403 PASS |
| MySQL query thật | safety id 17, evidence id 1 SHA dài 64/68 bytes, SOS id 7 `ACCEPTED`, push `POLLING_FALLBACK` |
| Evidence persistence | Tải 68 bytes trước và sau restart backend; PASS |
| WebSocket | JWT → `CONNECTED`; anonymous → `ERROR` |
| Frontend | full lint PASS; production build 17 route entry PASS; browser smoke Thiết bị/Bảo trì/RBAC PASS |
| Dependency production | `npm audit --omit=dev`: 0 vulnerability |
| Flutter | analyze 0 issue; 9/9 test PASS (gồm SQLite queue thật); Android debug APK build PASS từ vòng trước |
| AI | 10/10 pytest PASS; benchmark 10.000 mẫu p95 khoảng 0,006 ms; sample evaluation F1 1,0 |
| Docker | 5 service `healthy`; backend/web/AI/MinIO HTTP 200 |
| Evidence/MinIO | upload PNG, SHA-256, bucket private, object `mc stat`, download đúng hash sau restart PASS |
| Backup/restore | dump 116.313 byte; restore database tạm và chữ ký 12 chỉ số khớp; tự dọn sạch PASS |

APK debug: `safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk`.

## 9. Hạn chế còn lại trước triển khai thương mại

- Không có thiết bị/emulator Android kết nối trong phiên kiểm thử; camera, GPS nền, quyền hệ điều hành và nhiệt/pin phải được pilot trên điện thoại thật.
- FCM chưa có credential nên đang dùng REST polling fallback. Cần Firebase project/service account trước khi phát hành.
- Phone usage hiện dùng ML Kit image labeling + temporal rules, chưa phải custom YOLO đã huấn luyện theo cabin Việt Nam. Repo có train/evaluate/export ONNX/TFLite nhưng cần dataset đồng thuận và hiệu chuẩn thực địa.
- APK kiểm thử hiện là debug; release build đã buộc dùng keystore qua biến môi trường và chủ động từ chối nếu thiếu. Cần keystore thật, Play signing, HTTPS/domain và secret manager trước phát hành.
- Photon/OSRM public có thể giới hạn tải hoặc gián đoạn; production nên tự host hoặc dùng nhà cung cấp có SLA.
- Evidence mặc định Docker dùng bucket MinIO private và đã kiểm tra persistence; protected local volume vẫn là fallback có chủ đích khi cấu hình `EVIDENCE_STORAGE_PROVIDER=local`.
- Full `npm audit` còn advisory trong công cụ ESLint/minimatch chỉ dùng lúc phát triển; runtime production audit bằng `--omit=dev` bằng 0.
- Plugin ML Kit/MapLibre hiện vẫn áp dụng Kotlin Gradle Plugin kiểu cũ; Flutter stable hiện build được nhưng cần theo dõi bản plugin cho lần nâng Flutter sau.

## 10. Lệnh vận hành nhanh

```powershell
Copy-Item .env.example .env
docker compose config --quiet
docker compose build
docker compose up -d
.\docker\scripts\health-check.ps1
node .\docker\scripts\websocket-smoke.mjs
```

Dừng nhưng giữ dữ liệu: `docker compose down`. Không dùng `-v` nếu không chủ ý xóa volume.

## 11. Danh mục đầy đủ 155 API

OpenAPI có 136 path và 155 operation. Input/output bên dưới được lấy trực tiếp từ code runtime, không nhập tay.

| Method | Path | Nhóm | Mục đích | Auth | Input | Output |
|---|---|---|---|---|---|---|
| `GET` | `/api/v1/vehicles/{id}` | Vehicles | Get vehicle detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVehicleResponse` |
| `PUT` | `/api/v1/vehicles/{id}` | Vehicles | Update vehicle | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateVehicleRequest`; `application/json`, bắt buộc | `200` `ApiResponseVehicleResponse` |
| `DELETE` | `/api/v1/vehicles/{id}` | Vehicles | Soft delete vehicle | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVoid` |
| `GET` | `/api/v1/settings/{key}` | System Settings | Get setting by key | Theo security toàn cục | `key` (path, bắt buộc): `string` | `200` `ApiResponseSystemSettingResponse` |
| `PUT` | `/api/v1/settings/{key}` | System Settings | Update setting by key | Theo security toàn cục | `key` (path, bắt buộc): `string`<br>body `UpdateSystemSettingRequest`; `application/json`, bắt buộc | `200` `ApiResponseSystemSettingResponse` |
| `GET` | `/api/v1/maintenance-orders/{id}` | Maintenance | Get maintenance order detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseMaintenanceOrderResponse` |
| `PUT` | `/api/v1/maintenance-orders/{id}` | Maintenance | Update maintenance order | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateMaintenanceOrderRequest`; `application/json`, bắt buộc | `200` `ApiResponseMaintenanceOrderResponse` |
| `DELETE` | `/api/v1/maintenance-orders/{id}` | Maintenance | Soft delete maintenance order | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVoid` |
| `GET` | `/api/v1/drivers/{id}` | Drivers | Get driver detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDriverResponse` |
| `PUT` | `/api/v1/drivers/{id}` | Drivers | Update driver profile | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateDriverRequest`; `application/json`, bắt buộc | `200` `ApiResponseDriverResponse` |
| `DELETE` | `/api/v1/drivers/{id}` | Drivers | Soft delete driver | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVoid` |
| `GET` | `/api/v1/devices/{id}` | Devices | Get device detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDeviceResponse` |
| `PUT` | `/api/v1/devices/{id}` | Devices | Update device | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateDeviceRequest`; `application/json`, bắt buộc | `200` `ApiResponseDeviceResponse` |
| `DELETE` | `/api/v1/devices/{id}` | Devices | Delete device | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVoid` |
| `GET` | `/api/v1/vehicles` | Vehicles | Search vehicles by plate, type, status and GPS online state | Theo security toàn cục | `plateNumber` (query, tùy chọn): `string`<br>`vehicleType` (query, tùy chọn): `string enum[TRUCK, VAN, BUS, CAR, PICKUP, MOTORBIKE]`<br>`status` (query, tùy chọn): `string enum[AVAILABLE, RUNNING, RESTING, MAINTENANCE, OFFLINE, INACTIVE]`<br>`gpsOnline` (query, tùy chọn): `boolean`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseVehicleResponse` |
| `POST` | `/api/v1/vehicles` | Vehicles | Create vehicle | Theo security toàn cục | body `CreateVehicleRequest`; `application/json`, bắt buộc | `200` `ApiResponseVehicleResponse` |
| `GET` | `/api/v1/trips` | Trips | Search trips by status, vehicle, driver and date | Theo security toàn cục | `status` (query, tùy chọn): `string enum[DRAFT, ASSIGNED, ACCEPTED, IN_PROGRESS, RESTING, COMPLETED, DELAYED, INCIDENT, CANCELLED]`<br>`vehicleId` (query, tùy chọn): `integer (int64)`<br>`driverId` (query, tùy chọn): `integer (int64)`<br>`fromDate` (query, tùy chọn): `string (date)`<br>`toDate` (query, tùy chọn): `string (date)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseTripResponse` |
| `POST` | `/api/v1/trips` | Trips | Create trip | Theo security toàn cục | body `CreateTripRequest`; `application/json`, bắt buộc | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/start` | Trips | Start trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/resume` | Trips | Resume trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/pause` | Trips | Pause trip for rest | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/complete` | Trips | Complete trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/cancel` | Trips | Cancel trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `CancelTripRequest`; `application/json`, bắt buộc | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/assign` | Trips | Assign trip to vehicle and driver | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `AssignTripRequest`; `application/json`, bắt buộc | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/trips/{id}/accept` | Trips | Driver accepts assigned trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/telemetry` | Telemetry | App submits GPS and speed telemetry | Theo security toàn cục | body `TelemetryRequest`; `application/json`, bắt buộc | `200` `ApiResponseTelemetryResponse` |
| `GET` | `/api/v1/safety-events` | Safety Events | Search safety events | Theo security toàn cục | `eventType` (query, tùy chọn): `string enum[DROWSINESS, PHONE_USAGE, DISTRACTION, SPEEDING, OVER_DRIVING_TIME, ROUTE_DEVIATION, ABNORMAL_STOP, GPS_LOST, FLOOD_RISK]`<br>`severity` (query, tùy chọn): `string enum[LOW, MEDIUM, HIGH, CRITICAL]`<br>`status` (query, tùy chọn): `string enum[NEW, ACKNOWLEDGED, PROCESSING, RESOLVED, DISMISSED]`<br>`vehicleId` (query, tùy chọn): `integer (int64)`<br>`driverId` (query, tùy chọn): `integer (int64)`<br>`from` (query, tùy chọn): `string (date-time)`<br>`to` (query, tùy chọn): `string (date-time)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseSafetyEventResponse` |
| `POST` | `/api/v1/safety-events` | Safety Events | App submits AI safety event | Theo security toàn cục | body `CreateSafetyEventRequest`; `application/json`, bắt buộc | `200` `ApiResponseSafetyEventResponse` |
| `POST` | `/api/v1/safety-events/{id}/resolve` | Safety Events | Resolve safety event | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `SafetyEventActionRequest`; `application/json` | `200` `ApiResponseSafetyEventResponse` |
| `POST` | `/api/v1/safety-events/{id}/dismiss` | Safety Events | Dismiss safety event | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `SafetyEventActionRequest`; `application/json` | `200` `ApiResponseSafetyEventResponse` |
| `POST` | `/api/v1/safety-events/{id}/create-incident` | Safety Events | Create incident from safety event | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseIncidentResponse` |
| `POST` | `/api/v1/safety-events/{id}/acknowledge` | Safety Events | Acknowledge safety event | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `SafetyEventActionRequest`; `application/json` | `200` `ApiResponseSafetyEventResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/start` | Mobile Driver App | Start trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/start-workflow` | Mobile Driver App | Atomically start trip, driving and navigation workflows | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseMobileWorkflowResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/resume` | Mobile Driver App | Resume trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/resume-workflow` | Mobile Driver App | Atomically resume trip, driving and navigation workflows | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseMobileWorkflowResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/pre-trip-checklist` | Mobile Driver App | Submit pre-trip checklist | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `MobilePreTripChecklistRequest`; `application/json`, bắt buộc | `200` `ApiResponseMobilePreTripChecklistResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/pause` | Mobile Driver App | Pause trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/pause-workflow` | Mobile Driver App | Atomically pause trip, driving and navigation workflows | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseMobileWorkflowResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/complete` | Mobile Driver App | Complete trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/complete-workflow` | Mobile Driver App | Atomically complete trip, driving and navigation workflows | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseMobileWorkflowResponse` |
| `POST` | `/api/v1/mobile/trips/{id}/accept` | Mobile Driver App | Accept assigned trip | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `TripActionRequest`; `application/json` | `200` `ApiResponseTripResponse` |
| `POST` | `/api/v1/mobile/telemetry` | Mobile Driver App | Send telemetry from driver app | Theo security toàn cục | body `TelemetryRequest`; `application/json`, bắt buộc | `200` `ApiResponseTelemetryResponse` |
| `POST` | `/api/v1/mobile/telemetry/batch` | Mobile Driver App | Ingest an offline telemetry batch with per-item acknowledgements | Theo security toàn cục | body `MobileTelemetryBatchRequest`; `application/json`, bắt buộc | `200` `ApiResponseMobileTelemetryBatchResponse` |
| `POST` | `/api/v1/mobile/safety-events` | Mobile Driver App | Submit AI safety event from driver app | Theo security toàn cục | body `CreateSafetyEventRequest`; `application/json`, bắt buộc | `200` `ApiResponseSafetyEventResponse` |
| `POST` | `/api/v1/mobile/route-check` | Mobile Driver App | Check flood risk for route | Theo security toàn cục | body `RouteCheckRequest`; `application/json`, bắt buộc | `200` `ApiResponseRouteRiskSummaryResponse` |
| `POST` | `/api/v1/mobile/push-tokens` | Mobile Driver App | Register or refresh this device push token | Theo security toàn cục | body `MobilePushTokenRequest`; `application/json`, bắt buộc | `200` `ApiResponseMobilePushTokenResponse` |
| `POST` | `/api/v1/mobile/navigation/routes` | Mobile Navigation | Create alternatives, score active floods and select the least-risk route | Theo security toàn cục | body `NavigationRouteRequest`; `application/json`, bắt buộc | `200` `ApiResponseNavigationSessionResponse` |
| `POST` | `/api/v1/mobile/navigation/reroute` | Mobile Navigation | Recalculate a driver-owned active navigation session | Theo security toàn cục | body `NavigationRerouteRequest`; `application/json`, bắt buộc | `200` `ApiResponseNavigationSessionResponse` |
| `POST` | `/api/v1/mobile/navigation/events` | Mobile Navigation | Store navigation event and confirm off-route after 15 continuous seconds | Theo security toàn cục | body `NavigationEventRequest`; `application/json`, bắt buộc | `200` `ApiResponseNavigationEventResponse` |
| `POST` | `/api/v1/mobile/incidents/sos` | Mobile Driver App | Send SOS from driver app | Theo security toàn cục | body `SosRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentResponse` |
| `POST` | `/api/v1/mobile/flood-reports` | Mobile Driver App | Submit flood report | Theo security toàn cục | body `CreateFloodReportRequest`; `application/json`, bắt buộc | `200` `ApiResponseFloodReportResponse` |
| `POST` | `/api/v1/mobile/flood-reports/quick` | Mobile Driver App | Submit quick flood report using current driver | Theo security toàn cục | body `MobileQuickFloodReportRequest`; `application/json`, bắt buộc | `200` `ApiResponseFloodReportResponse` |
| `POST` | `/api/v1/mobile/evidence` | Protected Evidence | Upload protected safety/SOS evidence | Theo security toàn cục | `safetyEventId` (query, tùy chọn): `integer (int64)`<br>`incidentId` (query, tùy chọn): `integer (int64)`<br>`capturedAt` (query, tùy chọn): `string (date-time)`<br>body `object`; `multipart/form-data` | `200` `ApiResponseEvidenceResponse` |
| `POST` | `/api/v1/mobile/agent/commands/{id}/confirm` | Mobile Driver App | Confirm and execute an understood driver agent command | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `MobileAgentConfirmRequest`; `application/json` | `200` `ApiResponseMobileAgentCommandResponse` |
| `POST` | `/api/v1/mobile/agent/commands/{id}/cancel` | Mobile Driver App | Cancel an understood driver agent command | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseMobileAgentCommandResponse` |
| `POST` | `/api/v1/mobile/agent/command` | Mobile Driver App | Submit driver agent command | Theo security toàn cục | body `MobileAgentCommandRequest`; `application/json`, bắt buộc | `200` `ApiResponseMobileAgentCommandResponse` |
| `POST` | `/api/v1/mobile/agent/chat` | Mobile Driver App | Chat with the SafeFleet driver assistant | Theo security toàn cục | body `MobileAgentChatRequest`; `application/json`, bắt buộc | `200` `ApiResponseMobileAgentChatResponse` |
| `GET` | `/api/v1/maintenance-orders` | Maintenance | Search maintenance orders | Theo security toàn cục | `vehicleId` (query, tùy chọn): `integer (int64)`<br>`status` (query, tùy chọn): `string enum[OPEN, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED]`<br>`from` (query, tùy chọn): `string (date)`<br>`to` (query, tùy chọn): `string (date)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseMaintenanceOrderResponse` |
| `POST` | `/api/v1/maintenance-orders` | Maintenance | Create maintenance order | Theo security toàn cục | body `CreateMaintenanceOrderRequest`; `application/json`, bắt buộc | `200` `ApiResponseMaintenanceOrderResponse` |
| `POST` | `/api/v1/locations/route` | Locations | Calculate route distance and ETA using OSRM with local fallback | Theo security toàn cục | body `RouteRequest`; `application/json`, bắt buộc | `200` `ApiResponseRouteResponse` |
| `GET` | `/api/v1/incidents` | Incidents | Search incidents | Theo security toàn cục | `type` (query, tùy chọn): `string enum[SOS, ACCIDENT, VEHICLE_BREAKDOWN, DRIVER_UNRESPONSIVE, FLOOD_STUCK, GPS_LOST, MANUAL]`<br>`severity` (query, tùy chọn): `string enum[LOW, MEDIUM, HIGH, CRITICAL]`<br>`status` (query, tùy chọn): `string enum[OPEN, ACCEPTED, PROCESSING, ESCALATED, RESOLVED, CLOSED, CANCELLED]`<br>`vehicleId` (query, tùy chọn): `integer (int64)`<br>`driverId` (query, tùy chọn): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseIncidentResponse` |
| `POST` | `/api/v1/incidents` | Incidents | Create manual incident | Theo security toàn cục | body `CreateIncidentRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentResponse` |
| `GET` | `/api/v1/incidents/{id}/timeline` | Incidents | Get incident timeline | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseListIncidentTimelineResponse` |
| `POST` | `/api/v1/incidents/{id}/timeline` | Incidents | Add incident timeline note | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `IncidentTimelineRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentTimelineResponse` |
| `POST` | `/api/v1/incidents/{id}/close` | Incidents | Close incident | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `IncidentTimelineRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentResponse` |
| `POST` | `/api/v1/incidents/{id}/assign` | Incidents | Assign incident to rescue team user | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `AssignIncidentRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentResponse` |
| `POST` | `/api/v1/incidents/{id}/accept` | Incidents | Accept incident | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseIncidentResponse` |
| `POST` | `/api/v1/incidents/sos` | Incidents | Driver submits SOS | Theo security toàn cục | body `SosRequest`; `application/json`, bắt buộc | `200` `ApiResponseIncidentResponse` |
| `GET` | `/api/v1/flood-reports` | Flood Reports | View flood points as table | Theo security toàn cục | `severity` (query, tùy chọn): `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]`<br>`source` (query, tùy chọn): `string enum[DRIVER_REPORT, IOT_SENSOR, TRAFFIC_CAMERA, WEATHER, MANUAL]`<br>`status` (query, tùy chọn): `string enum[UNVERIFIED, VERIFIED, EXPIRED, REJECTED, RESOLVED]`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseFloodReportResponse` |
| `POST` | `/api/v1/flood-reports` | Flood Reports | App reports flood point | Theo security toàn cục | body `CreateFloodReportRequest`; `application/json`, bắt buộc | `200` `ApiResponseFloodReportResponse` |
| `POST` | `/api/v1/flood-reports/{id}/verify` | Flood Reports | Verify flood point | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `FloodActionRequest`; `application/json` | `200` `ApiResponseFloodReportResponse` |
| `POST` | `/api/v1/flood-reports/{id}/resolve` | Flood Reports | Mark flood point as resolved | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `FloodActionRequest`; `application/json` | `200` `ApiResponseFloodReportResponse` |
| `POST` | `/api/v1/flood-reports/route-risk-summary` | Flood Reports | Get route flood risk summary | Theo security toàn cục | body `RouteCheckRequest`; `application/json`, bắt buộc | `200` `ApiResponseRouteRiskSummaryResponse` |
| `POST` | `/api/v1/flood-reports/route-check` | Flood Reports | Check whether route intersects risky flood points | Theo security toàn cục | body `RouteCheckRequest`; `application/json`, bắt buộc | `200` `ApiResponseRouteRiskSummaryResponse` |
| `POST` | `/api/v1/driving-sessions/{id}/resume` | Driving Time | App resumes driving session | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDrivingSessionResponse` |
| `POST` | `/api/v1/driving-sessions/{id}/pause` | Driving Time | App pauses driving session | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDrivingSessionResponse` |
| `POST` | `/api/v1/driving-sessions/{id}/finish` | Driving Time | App finishes driving session | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDrivingSessionResponse` |
| `POST` | `/api/v1/driving-sessions/start` | Driving Time | App starts driving session | Theo security toàn cục | body `StartDrivingSessionRequest`; `application/json`, bắt buộc | `200` `ApiResponseDrivingSessionResponse` |
| `GET` | `/api/v1/drivers` | Drivers | Search drivers | Theo security toàn cục | `keyword` (query, tùy chọn): `string`<br>`status` (query, tùy chọn): `string enum[AVAILABLE, DRIVING, RESTING, SUSPENDED, HIGH_RISK, INACTIVE]`<br>`licenseClass` (query, tùy chọn): `string`<br>`minSafetyScore` (query, tùy chọn): `integer (int32)`<br>`maxSafetyScore` (query, tùy chọn): `integer (int32)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseDriverResponse` |
| `POST` | `/api/v1/drivers` | Drivers | Create driver profile | Theo security toàn cục | body `CreateDriverRequest`; `application/json`, bắt buộc | `200` `ApiResponseDriverResponse` |
| `POST` | `/api/v1/drivers/{id}/recalculate-safety-score` | Drivers | Recalculate basic driver safety score | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDriverResponse` |
| `GET` | `/api/v1/devices` | Devices | Search devices | Theo security toàn cục | `type` (query, tùy chọn): `string enum[GPS_TRACKER, CABIN_CAMERA, DASH_CAMERA, DRIVER_PHONE, IOT_FLOOD_SENSOR]`<br>`status` (query, tùy chọn): `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]`<br>`vehicleId` (query, tùy chọn): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseDeviceResponse` |
| `POST` | `/api/v1/devices` | Devices | Create device | Theo security toàn cục | body `CreateDeviceRequest`; `application/json`, bắt buộc | `200` `ApiResponseDeviceResponse` |
| `POST` | `/api/v1/devices/{id}/assign-vehicle` | Devices | Assign device to vehicle | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `AssignDeviceVehicleRequest`; `application/json`, bắt buộc | `200` `ApiResponseDeviceResponse` |
| `POST` | `/api/v1/auth/refresh` | Auth | Rotate refresh token and issue a new token pair | Theo security toàn cục | body `RefreshTokenRequest`; `application/json`, bắt buộc | `200` `ApiResponseAuthResponse` |
| `POST` | `/api/v1/auth/logout` | Auth | Revoke a refresh token | Theo security toàn cục | body `RefreshTokenRequest`; `application/json`, bắt buộc | `200` `ApiResponseVoid` |
| `POST` | `/api/v1/auth/login` | Auth | Login by username/email and password | Theo security toàn cục | body `LoginRequest`; `application/json`, bắt buộc | `200` `ApiResponseAuthResponse` |
| `GET` | `/api/v1/accounts` | Accounts | Search accounts | Theo security toàn cục | `keyword` (query, tùy chọn): `string`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseUserResponse` |
| `POST` | `/api/v1/accounts` | Accounts | Create staff account | Theo security toàn cục | body `CreateUserRequest`; `application/json`, bắt buộc | `200` `ApiResponseUserResponse` |
| `POST` | `/api/v1/accounts/drivers` | Accounts | Create driver account and driver profile | Theo security toàn cục | body `CreateDriverAccountRequest`; `application/json`, bắt buộc | `200` `ApiResponseUserResponse` |
| `PATCH` | `/api/v1/notifications/{id}/read` | Notifications | Mark notification as read | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseNotificationResponse` |
| `PATCH` | `/api/v1/notifications/read-all` | Notifications | Mark all notifications as read | Theo security toàn cục | Không có | `200` `ApiResponseVoid` |
| `PATCH` | `/api/v1/mobile/notifications/{id}/read` | Mobile Driver App | Mark notification as read | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseNotificationResponse` |
| `PATCH` | `/api/v1/mobile/notifications/read-all` | Mobile Driver App | Mark all notifications as read | Theo security toàn cục | Không có | `200` `ApiResponseVoid` |
| `PATCH` | `/api/v1/devices/{id}/status` | Devices | Update online/offline status | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateDeviceStatusRequest`; `application/json`, bắt buộc | `200` `ApiResponseDeviceResponse` |
| `PATCH` | `/api/v1/accounts/{id}/status` | Accounts | Change account status | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>body `UpdateAccountStatusRequest`; `application/json`, bắt buộc | `200` `ApiResponseUserResponse` |
| `GET` | `/api/v1/vehicles/{id}/trips` | Vehicles | Get vehicle trip history | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseTripResponse` |
| `GET` | `/api/v1/vehicles/{id}/safety-events` | Vehicles | Get vehicle safety alert history | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseSafetyEventResponse` |
| `GET` | `/api/v1/vehicles/{id}/realtime-status` | Vehicles | Get current realtime vehicle state | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseVehicleRealtimeStatusResponse` |
| `GET` | `/api/v1/vehicles/map/positions` | Vehicles | Get current positions for all vehicles on map | Theo security toàn cục | Không có | `200` `ApiResponseListVehicleRealtimeStatusResponse` |
| `GET` | `/api/v1/trips/{id}` | Trips | Get trip detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseTripResponse` |
| `GET` | `/api/v1/trips/{id}/timeline` | Trips | Get trip timeline | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseListTripTimelineResponse` |
| `GET` | `/api/v1/telemetry/vehicles/current` | Telemetry | Get all current vehicle positions | Theo security toàn cục | Không có | `200` `ApiResponseListVehicleRealtimeStatusResponse` |
| `GET` | `/api/v1/telemetry/trips/{tripId}/replay` | Telemetry | Replay trip GPS path | Theo security toàn cục | `tripId` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseListTelemetryResponse` |
| `GET` | `/api/v1/telemetry/trips/{tripId}/history` | Telemetry | Get GPS history of a trip | Theo security toàn cục | `tripId` (path, bắt buộc): `integer (int64)`<br>`from` (query, tùy chọn): `string (date-time)`<br>`to` (query, tùy chọn): `string (date-time)` | `200` `ApiResponseListTelemetryResponse` |
| `GET` | `/api/v1/settings` | System Settings | Get all settings | Theo security toàn cục | Không có | `200` `ApiResponseListSystemSettingResponse` |
| `GET` | `/api/v1/settings/groups/{group}` | System Settings | Get settings by group | Theo security toàn cục | `group` (path, bắt buộc): `string enum[DRIVING_TIME, AI_ALERT, SOS_ESCALATION, MAP, FLOOD, NOTIFICATION, SYSTEM]` | `200` `ApiResponseListSystemSettingResponse` |
| `GET` | `/api/v1/safety-events/{id}` | Safety Events | Get safety event detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseSafetyEventResponse` |
| `GET` | `/api/v1/reports/vehicles/{id}` | Reports | Vehicle report | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseMapStringObject` |
| `GET` | `/api/v1/reports/vehicles/status` | Reports | Vehicle count by status | Theo security toàn cục | Không có | `200` `ApiResponseMapStringLong` |
| `GET` | `/api/v1/reports/trips/by-day` | Reports | Trip count by day | Theo security toàn cục | `from` (query, tùy chọn): `string (date)`<br>`to` (query, tùy chọn): `string (date)` | `200` `ApiResponseListDailyTripCountResponse` |
| `GET` | `/api/v1/reports/safety-events/by-type` | Reports | Safety alert count by event type | Theo security toàn cục | Không có | `200` `ApiResponseMapStringLong` |
| `GET` | `/api/v1/reports/incidents` | Reports | Incident report | Theo security toàn cục | Không có | `200` `ApiResponseMapStringMapStringLong` |
| `GET` | `/api/v1/reports/flood` | Reports | Flood report | Theo security toàn cục | Không có | `200` `ApiResponseMapStringMapStringLong` |
| `GET` | `/api/v1/reports/drivers/{id}` | Reports | Driver report | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseMapStringObject` |
| `GET` | `/api/v1/reports/drivers/high-risk` | Reports | Top high-risk drivers | Theo security toàn cục | Không có | `200` `ApiResponseListDriverResponse` |
| `GET` | `/api/v1/notifications` | Notifications | Get current user notifications | Theo security toàn cục | `pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseNotificationResponse` |
| `GET` | `/api/v1/mobile/trips/{id}` | Mobile Driver App | Get mobile trip detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseTripResponse` |
| `GET` | `/api/v1/mobile/trips/{id}/summary` | Mobile Driver App | Get mobile trip summary | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseMobileTripSummaryResponse` |
| `GET` | `/api/v1/mobile/trips/today` | Mobile Driver App | Get today's trips for driver | Theo security toàn cục | Không có | `200` `ApiResponseListTripResponse` |
| `GET` | `/api/v1/mobile/safety-summary` | Mobile Driver App | Get current driver safety summary | Theo security toàn cục | Không có | `200` `ApiResponseMobileSafetySummaryResponse` |
| `GET` | `/api/v1/mobile/safety-events/today` | Mobile Driver App | Get today's safety events for driver | Theo security toàn cục | `pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseSafetyEventResponse` |
| `GET` | `/api/v1/mobile/notifications` | Mobile Driver App | Get current user notifications | Theo security toàn cục | `pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseNotificationResponse` |
| `GET` | `/api/v1/mobile/navigation/current` | Mobile Navigation | Get current navigation session with offline-cacheable geometry and steps | Theo security toàn cục | Không có | `200` `ApiResponseNavigationSessionResponse` |
| `GET` | `/api/v1/mobile/me` | Mobile Driver App | Get current driver mobile profile | Theo security toàn cục | Không có | `200` `ApiResponseMobileProfileResponse` |
| `GET` | `/api/v1/mobile/locations/autocomplete` | Mobile Navigation | Search Hanoi destinations through backend Photon proxy with local fallback | Theo security toàn cục | `query` (query, bắt buộc): `string`<br>`limit` (query, tùy chọn): `integer (int32)` | `200` `ApiResponseListLocationSuggestionResponse` |
| `GET` | `/api/v1/mobile/incidents` | Mobile Driver App | Get driver incidents | Theo security toàn cục | `status` (query, tùy chọn): `string enum[OPEN, ACCEPTED, PROCESSING, ESCALATED, RESOLVED, CLOSED, CANCELLED]`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseIncidentResponse` |
| `GET` | `/api/v1/mobile/incidents/{id}` | Mobile Driver App | Get driver incident detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseIncidentResponse` |
| `GET` | `/api/v1/mobile/incidents/{id}/timeline` | Mobile Driver App | Get owned incident timeline | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseListIncidentTimelineResponse` |
| `GET` | `/api/v1/mobile/flood-points/nearby` | Mobile Driver App | Get nearby active flood points | Theo security toàn cục | `lat` (query, bắt buộc): `number (double)`<br>`lng` (query, bắt buộc): `number (double)`<br>`radiusKm` (query, tùy chọn): `number (double)` | `200` `ApiResponseListFloodReportResponse` |
| `GET` | `/api/v1/mobile/driving-sessions/current` | Mobile Driver App | Get current driving session | Theo security toàn cục | Không có | `200` `ApiResponseDrivingSessionResponse` |
| `GET` | `/api/v1/mobile/current-assignment` | Mobile Driver App | Get current active assignment for driver | Theo security toàn cục | Không có | `200` `ApiResponseMobileCurrentAssignmentResponse` |
| `GET` | `/api/v1/mobile/config` | Mobile Driver App | Get mobile runtime config | Theo security toàn cục | Không có | `200` `ApiResponseMobileConfigResponse` |
| `GET` | `/api/v1/mobile/bootstrap` | Mobile Driver App | Bootstrap all data required for the driver home screen | Theo security toàn cục | Không có | `200` `ApiResponseMobileBootstrapResponse` |
| `GET` | `/api/v1/mobile/agent/history` | Mobile Driver App | Get driver agent command history | Theo security toàn cục | `pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseMobileAgentCommandResponse` |
| `GET` | `/api/v1/mobile/activity/monthly` | Mobile Driver App | Get authenticated driver's monthly activity overview | Theo security toàn cục | `month` (query, tùy chọn): `string` | `200` `ApiResponseMobileMonthlyActivityResponse` |
| `GET` | `/api/v1/maintenance-orders/due-alerts` | Maintenance | Get maintenance orders due soon | Theo security toàn cục | Không có | `200` `ApiResponseListMaintenanceOrderResponse` |
| `GET` | `/api/v1/maintenance-orders/document-expiry-alerts` | Maintenance | Get vehicle inspection and insurance expiry alerts | Theo security toàn cục | Không có | `200` `ApiResponseListDocumentExpiryAlertResponse` |
| `GET` | `/api/v1/locations/autocomplete` | Locations | Autocomplete real locations using OpenStreetMap Photon | Theo security toàn cục | `query` (query, bắt buộc): `string`<br>`limit` (query, tùy chọn): `integer (int32)` | `200` `ApiResponseListLocationSuggestionResponse` |
| `GET` | `/api/v1/incidents/{id}` | Incidents | Get incident detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseIncidentResponse` |
| `GET` | `/api/v1/flood-reports/map` | Flood Reports | View flood points as map markers | Theo security toàn cục | Không có | `200` `ApiResponseListFloodReportResponse` |
| `GET` | `/api/v1/evidence/{id}` | Protected Evidence | Get protected evidence metadata | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseEvidenceResponse` |
| `GET` | `/api/v1/evidence/{id}/content` | Protected Evidence | Stream protected evidence after ownership/RBAC check | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `string (binary)` |
| `GET` | `/api/v1/driving-sessions/drivers/{driverId}/remaining-time` | Driving Time | Check how long driver can continue driving | Theo security toàn cục | `driverId` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseRemainingDrivingTimeResponse` |
| `GET` | `/api/v1/drivers/{id}/trips` | Drivers | Get driver trip history | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseTripResponse` |
| `GET` | `/api/v1/drivers/{id}/safety-events` | Drivers | Get driver safety alert history | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseSafetyEventResponse` |
| `GET` | `/api/v1/drivers/{id}/driving-time-today` | Drivers | Get today's driving time | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseDrivingTimeTodayResponse` |
| `GET` | `/api/v1/dispatch/suggestions` | Dispatch | Suggest suitable vehicle and driver pairs | Theo security toàn cục | `startLat` (query, tùy chọn): `number (double)`<br>`startLng` (query, tùy chọn): `number (double)`<br>`limit` (query, tùy chọn): `integer (int32)` | `200` `ApiResponseListDispatchSuggestionResponse` |
| `GET` | `/api/v1/dispatch/availability` | Dispatch | Check vehicle and driver availability before assignment | Theo security toàn cục | `vehicleId` (query, bắt buộc): `integer (int64)`<br>`driverId` (query, bắt buộc): `integer (int64)` | `200` `ApiResponseAvailabilityResponse` |
| `GET` | `/api/v1/devices/{id}/connection-logs` | Devices | Get device connection logs | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)`<br>`pageable` (query, bắt buộc): `Pageable` | `200` `ApiResponsePageResponseDeviceConnectionLogResponse` |
| `GET` | `/api/v1/dashboard/summary` | Dashboard | Get fleet dashboard summary | Theo security toàn cục | Không có | `200` `ApiResponseDashboardSummaryResponse` |
| `GET` | `/api/v1/auth/me` | Auth | Get current authenticated profile | Theo security toàn cục | Không có | `200` `ApiResponseCurrentUserResponse` |
| `GET` | `/api/v1/accounts/{id}` | Accounts | Get account detail | Theo security toàn cục | `id` (path, bắt buộc): `integer (int64)` | `200` `ApiResponseUserResponse` |
| `DELETE` | `/api/v1/mobile/push-tokens/{deviceUuid}` | Mobile Driver App | Disable push tokens belonging to this device | Theo security toàn cục | `deviceUuid` (path, bắt buộc): `string` | `200` `ApiResponseVoid` |

## 12. Định nghĩa 174 schema input/output

Các trường có dấu `*` là bắt buộc theo OpenAPI. Enum phải gửi đúng chữ hoa như mô tả.

### ApiResponseAuthResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `AuthResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseAvailabilityResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `AvailabilityResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseCurrentUserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `CurrentUserResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseDashboardSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `DashboardSummaryResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseDeviceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `DeviceResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseDriverResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `DriverResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseDrivingSessionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `DrivingSessionResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseDrivingTimeTodayResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `DrivingTimeTodayResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseEvidenceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `EvidenceResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseFloodReportResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `FloodReportResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseIncidentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `IncidentResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseIncidentTimelineResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `IncidentTimelineResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListDailyTripCountResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`DailyTripCountResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListDispatchSuggestionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`DispatchSuggestionResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListDocumentExpiryAlertResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`DocumentExpiryAlertResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListDriverResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`DriverResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListFloodReportResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`FloodReportResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListIncidentTimelineResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`IncidentTimelineResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListLocationSuggestionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`LocationSuggestionResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListMaintenanceOrderResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`MaintenanceOrderResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListSystemSettingResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`SystemSettingResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListTelemetryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`TelemetryResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListTripResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`TripResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListTripTimelineResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`TripTimelineResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseListVehicleRealtimeStatusResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | array<`VehicleRealtimeStatusResponse`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMaintenanceOrderResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MaintenanceOrderResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMapStringLong

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | map<string, `integer (int64)`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMapStringMapStringLong

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | map<string, map<string, `integer (int64)`>> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMapStringObject

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | map<string, `object`> | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileAgentChatResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileAgentChatResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileAgentCommandResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileAgentCommandResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileBootstrapResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileBootstrapResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileConfigResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileConfigResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileCurrentAssignmentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileCurrentAssignmentResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileMonthlyActivityResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileMonthlyActivityResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobilePreTripChecklistResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobilePreTripChecklistResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileProfileResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileProfileResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobilePushTokenResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobilePushTokenResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileSafetySummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileSafetySummaryResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileTelemetryBatchResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileTelemetryBatchResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileTripSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileTripSummaryResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseMobileWorkflowResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `MobileWorkflowResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseNavigationEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `NavigationEventResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseNavigationSessionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `NavigationSessionResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseNotificationResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `NotificationResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseDeviceConnectionLogResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseDeviceConnectionLogResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseDeviceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseDeviceResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseDriverResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseDriverResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseFloodReportResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseFloodReportResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseIncidentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseIncidentResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseMaintenanceOrderResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseMaintenanceOrderResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseMobileAgentCommandResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseMobileAgentCommandResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseNotificationResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseNotificationResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseSafetyEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseSafetyEventResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseTripResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseTripResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseUserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseUserResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponsePageResponseVehicleResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `PageResponseVehicleResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseRemainingDrivingTimeResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `RemainingDrivingTimeResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseRouteResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `RouteResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseRouteRiskSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `RouteRiskSummaryResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseSafetyEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `SafetyEventResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseSystemSettingResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `SystemSettingResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseTelemetryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `TelemetryResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseTripResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `TripResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseUserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `UserResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseVehicleRealtimeStatusResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `VehicleRealtimeStatusResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseVehicleResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `VehicleResponse` | — |
| `timestamp` | `string (date-time)` | — |

### ApiResponseVoid

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `success` | `boolean` | — |
| `message` | `string` | — |
| `data` | `object` | — |
| `timestamp` | `string (date-time)` | — |

### AssignDeviceVehicleRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId*` | `integer (int64)` | bắt buộc |

### AssignIncidentRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `rescueUserId*` | `integer (int64)` | bắt buộc |
| `note` | `string` | minLength 0; maxLength 500 |

### AssignTripRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId*` | `integer (int64)` | bắt buộc |
| `driverId*` | `integer (int64)` | bắt buộc |

### AuthResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `accessToken` | `string` | — |
| `refreshToken` | `string` | — |
| `tokenType` | `string` | — |
| `expiresInSeconds` | `integer (int64)` | — |
| `userId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `username` | `string` | — |
| `email` | `string` | — |
| `fullName` | `string` | — |
| `role` | `string enum[ADMIN, FLEET_MANAGER, DISPATCHER, SAFETY_OFFICER, RESCUE_TEAM, DRIVER]` | — |

### AvailabilityResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `vehicleAvailable` | `boolean` | — |
| `driverId` | `integer (int64)` | — |
| `driverAvailable` | `boolean` | — |
| `assignable` | `boolean` | — |
| `reasons` | array<`string`> | — |

### CancelTripRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `reason*` | `string` | bắt buộc; minLength 0; maxLength 255 |

### CreateDeviceRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `deviceCode*` | `string` | bắt buộc; minLength 0; maxLength 50 |
| `name*` | `string` | bắt buộc; minLength 0; maxLength 120 |
| `type*` | `string enum[GPS_TRACKER, CABIN_CAMERA, DASH_CAMERA, DRIVER_PHONE, IOT_FLOOD_SENSOR]` | bắt buộc |
| `status` | `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]` | — |
| `vehicleId` | `integer (int64)` | — |
| `phone` | `string` | minLength 0; maxLength 20 |
| `serialNumber` | `string` | minLength 0; maxLength 80 |
| `firmwareVersion` | `string` | minLength 0; maxLength 40 |

### CreateDriverAccountRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `username*` | `string` | bắt buộc; minLength 0; maxLength 80 |
| `email*` | `string` | bắt buộc; minLength 0; maxLength 120 |
| `password*` | `string` | bắt buộc; minLength 6; maxLength 100 |
| `fullName*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `phone*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `address` | `string` | minLength 0; maxLength 255 |
| `licenseNumber*` | `string` | bắt buộc; minLength 0; maxLength 50 |
| `licenseClass*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `licenseExpiredAt*` | `string (date)` | bắt buộc |

### CreateDriverRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `userId` | `integer (int64)` | — |
| `fullName*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `phone*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `email` | `string` | minLength 0; maxLength 120 |
| `address` | `string` | minLength 0; maxLength 255 |
| `licenseNumber*` | `string` | bắt buộc; minLength 0; maxLength 50 |
| `licenseClass*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `licenseExpiredAt*` | `string (date)` | bắt buộc |
| `status` | `string enum[AVAILABLE, DRIVING, RESTING, SUSPENDED, HIGH_RISK, INACTIVE]` | — |
| `currentVehicleId` | `integer (int64)` | — |

### CreateFloodReportRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `lat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `lng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `address` | `string` | minLength 0; maxLength 255 |
| `severity*` | `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]` | bắt buộc |
| `source*` | `string enum[DRIVER_REPORT, IOT_SENSOR, TRAFFIC_CAMERA, WEATHER, MANUAL]` | bắt buộc |
| `reportedByDriverId` | `integer (int64)` | — |
| `imageUrl` | `string` | minLength 0; maxLength 500 |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### CreateIncidentRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `type*` | `string enum[SOS, ACCIDENT, VEHICLE_BREAKDOWN, DRIVER_UNRESPONSIVE, FLOOD_STUCK, GPS_LOST, MANUAL]` | bắt buộc |
| `severity*` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | bắt buộc |
| `vehicleId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `description` | `string` | minLength 0; maxLength 1000 |

### CreateMaintenanceOrderRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId*` | `integer (int64)` | bắt buộc |
| `type*` | `string enum[PERIODIC, REPAIR, INSPECTION, INSURANCE, EMERGENCY]` | bắt buộc |
| `title*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `description` | `string` | minLength 0; maxLength 1000 |
| `scheduledDate` | `string (date)` | — |
| `completedDate` | `string (date)` | — |
| `cost` | `number` | — |
| `status` | `string enum[OPEN, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED]` | — |
| `priority` | `string enum[LOW, MEDIUM, HIGH, URGENT]` | — |
| `assignedTo` | `integer (int64)` | — |
| `note` | `string` | minLength 0; maxLength 1000 |

### CreateSafetyEventRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `eventType*` | `string enum[DROWSINESS, PHONE_USAGE, DISTRACTION, SPEEDING, OVER_DRIVING_TIME, ROUTE_DEVIATION, ABNORMAL_STOP, GPS_LOST, FLOOD_RISK]` | bắt buộc |
| `severity*` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | bắt buộc |
| `vehicleId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `lat` | `number (double)` | min -90; max 90 |
| `lng` | `number (double)` | min -180; max 180 |
| `speed` | `number (double)` | — |
| `confidence` | `number (double)` | min 0; max 1 |
| `evidenceUrl` | `string` | minLength 0; maxLength 500 |
| `createdAt` | `string (date-time)` | — |
| `note` | `string` | minLength 0; maxLength 500 |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### CreateTripRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `startLocation*` | `string` | bắt buộc; minLength 0; maxLength 255 |
| `startLat` | `number (double)` | — |
| `startLng` | `number (double)` | — |
| `endLocation*` | `string` | bắt buộc; minLength 0; maxLength 255 |
| `endLat` | `number (double)` | — |
| `endLng` | `number (double)` | — |
| `waypoints` | `string` | — |
| `plannedRoute` | `string` | — |
| `plannedStartTime` | `string (date-time)` | — |
| `estimatedEndTime` | `string (date-time)` | — |
| `riskLevel` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | — |

### CreateUserRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `username*` | `string` | bắt buộc; minLength 0; maxLength 80 |
| `email*` | `string` | bắt buộc; minLength 0; maxLength 120 |
| `password*` | `string` | bắt buộc; minLength 6; maxLength 100 |
| `fullName*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `phone` | `string` | minLength 0; maxLength 20 |
| `role*` | `string enum[ADMIN, FLEET_MANAGER, DISPATCHER, SAFETY_OFFICER, RESCUE_TEAM, DRIVER]` | bắt buộc |

### CreateVehicleRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `plateNumber*` | `string` | bắt buộc; minLength 0; maxLength 30 |
| `vehicleType*` | `string enum[TRUCK, VAN, BUS, CAR, PICKUP, MOTORBIKE]` | bắt buộc |
| `brand` | `string` | minLength 0; maxLength 80 |
| `model` | `string` | minLength 0; maxLength 80 |
| `year` | `integer (int32)` | — |
| `loadCapacity` | `number` | — |
| `seatCount` | `integer (int32)` | — |
| `fuelType` | `string enum[DIESEL, GASOLINE, ELECTRIC, HYBRID]` | — |
| `status` | `string enum[AVAILABLE, RUNNING, RESTING, MAINTENANCE, OFFLINE, INACTIVE]` | — |
| `currentDriverId` | `integer (int64)` | — |
| `gpsDeviceId` | `integer (int64)` | — |
| `cameraDeviceId` | `integer (int64)` | — |
| `inspectionExpiredAt` | `string (date)` | — |
| `insuranceExpiredAt` | `string (date)` | — |

### CurrentUserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `userId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `username` | `string` | — |
| `email` | `string` | — |
| `fullName` | `string` | — |
| `status` | `string enum[ACTIVE, LOCKED, DISABLED, PENDING]` | — |
| `role` | `string enum[ADMIN, FLEET_MANAGER, DISPATCHER, SAFETY_OFFICER, RESCUE_TEAM, DRIVER]` | — |

### DailyActivity

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `date` | `string (date)` | — |
| `trips` | `integer (int32)` | — |
| `drivingMinutes` | `integer (int32)` | — |
| `restMinutes` | `integer (int32)` | — |
| `alerts` | `integer (int32)` | — |

### DailyTripCountResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `date` | `string (date)` | — |
| `totalTrips` | `integer (int64)` | — |

### DashboardSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `totalVehicles` | `integer (int64)` | — |
| `vehiclesByStatus` | map<string, `integer (int64)`> | — |
| `totalDrivers` | `integer (int64)` | — |
| `driversByStatus` | map<string, `integer (int64)`> | — |
| `totalTrips` | `integer (int64)` | — |
| `tripsByStatus` | map<string, `integer (int64)`> | — |
| `openSafetyEvents` | `integer (int64)` | — |
| `openIncidents` | `integer (int64)` | — |

### DeviceConnectionLogResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `deviceId` | `integer (int64)` | — |
| `status` | `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `note` | `string` | — |
| `createdAt` | `string (date-time)` | — |

### DeviceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `deviceCode` | `string` | — |
| `name` | `string` | — |
| `type` | `string enum[GPS_TRACKER, CABIN_CAMERA, DASH_CAMERA, DRIVER_PHONE, IOT_FLOOD_SENSOR]` | — |
| `status` | `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `phone` | `string` | — |
| `serialNumber` | `string` | — |
| `firmwareVersion` | `string` | — |
| `lastSeenAt` | `string (date-time)` | — |

### DispatchSuggestionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `plateNumber` | `string` | — |
| `driverId` | `integer (int64)` | — |
| `driverName` | `string` | — |
| `score` | `number (double)` | — |
| `distanceKm` | `number (double)` | — |
| `reasons` | array<`string`> | — |

### DocumentExpiryAlertResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `plateNumber` | `string` | — |
| `documentType` | `string` | — |
| `expiredAt` | `string (date)` | — |
| `daysRemaining` | `integer (int64)` | — |

### DriverResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `userId` | `integer (int64)` | — |
| `fullName` | `string` | — |
| `phone` | `string` | — |
| `email` | `string` | — |
| `address` | `string` | — |
| `licenseNumber` | `string` | — |
| `licenseClass` | `string` | — |
| `licenseExpiredAt` | `string (date)` | — |
| `status` | `string enum[AVAILABLE, DRIVING, RESTING, SUSPENDED, HIGH_RISK, INACTIVE]` | — |
| `currentVehicleId` | `integer (int64)` | — |
| `currentVehiclePlateNumber` | `string` | — |
| `safetyScore` | `integer (int32)` | — |
| `drivingTimeTodayMinutes` | `integer (int32)` | — |
| `continuousDrivingMinutes` | `integer (int32)` | — |
| `totalTrips` | `integer (int32)` | — |
| `totalAlerts` | `integer (int32)` | — |

### DrivingSessionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `vehicleId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `status` | `string enum[ACTIVE, PAUSED, FINISHED]` | — |
| `startedAt` | `string (date-time)` | — |
| `pausedAt` | `string (date-time)` | — |
| `resumedAt` | `string (date-time)` | — |
| `endedAt` | `string (date-time)` | — |
| `continuousMinutes` | `integer (int32)` | — |
| `totalMinutes` | `integer (int32)` | — |
| `overDrivingAlertCreated` | `boolean` | — |

### DrivingTimeTodayResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `driverId` | `integer (int64)` | — |
| `drivingTimeTodayMinutes` | `integer (int32)` | — |
| `continuousDrivingMinutes` | `integer (int32)` | — |
| `remainingContinuousDrivingMinutes` | `integer (int32)` | — |

### EvidenceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `safetyEventId` | `integer (int64)` | — |
| `incidentId` | `integer (int64)` | — |
| `originalFilename` | `string` | — |
| `contentType` | `string` | — |
| `sizeBytes` | `integer (int64)` | — |
| `sha256` | `string` | — |
| `capturedAt` | `string (date-time)` | — |
| `createdAt` | `string (date-time)` | — |
| `protectedContentUrl` | `string` | — |

### FloodActionRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `note` | `string` | minLength 0; maxLength 500 |

### FloodReportResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `address` | `string` | — |
| `severity` | `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]` | — |
| `source` | `string enum[DRIVER_REPORT, IOT_SENSOR, TRAFFIC_CAMERA, WEATHER, MANUAL]` | — |
| `reportedByDriverId` | `integer (int64)` | — |
| `reportedByDriverName` | `string` | — |
| `imageUrl` | `string` | — |
| `clientEventId` | `string` | — |
| `receivedAt` | `string (date-time)` | — |
| `confidence` | `number (double)` | — |
| `status` | `string enum[UNVERIFIED, VERIFIED, EXPIRED, REJECTED, RESOLVED]` | — |
| `verifiedBy` | `integer (int64)` | — |
| `verifiedAt` | `string (date-time)` | — |
| `expiredAt` | `string (date-time)` | — |
| `createdAt` | `string (date-time)` | — |

### IncidentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `incidentCode` | `string` | — |
| `type` | `string enum[SOS, ACCIDENT, VEHICLE_BREAKDOWN, DRIVER_UNRESPONSIVE, FLOOD_STUCK, GPS_LOST, MANUAL]` | — |
| `severity` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `driverId` | `integer (int64)` | — |
| `driverName` | `string` | — |
| `tripId` | `integer (int64)` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `description` | `string` | — |
| `status` | `string enum[OPEN, ACCEPTED, PROCESSING, ESCALATED, RESOLVED, CLOSED, CANCELLED]` | — |
| `assignedTo` | `integer (int64)` | — |
| `assignedToName` | `string` | — |
| `createdAt` | `string (date-time)` | — |
| `acceptedAt` | `string (date-time)` | — |
| `resolvedAt` | `string (date-time)` | — |

### IncidentTimelineRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `action*` | `string` | bắt buộc; minLength 0; maxLength 80 |
| `note` | `string` | minLength 0; maxLength 500 |

### IncidentTimelineResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `incidentId` | `integer (int64)` | — |
| `action` | `string` | — |
| `actorId` | `integer (int64)` | — |
| `actorName` | `string` | — |
| `note` | `string` | — |
| `createdAt` | `string (date-time)` | — |

### LocationSuggestionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `string` | — |
| `name` | `string` | — |
| `address` | `string` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `source` | `string` | — |

### LoginRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `usernameOrEmail*` | `string` | bắt buộc |
| `password*` | `string` | bắt buộc |

### MaintenanceOrderResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `maintenanceCode` | `string` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `type` | `string enum[PERIODIC, REPAIR, INSPECTION, INSURANCE, EMERGENCY]` | — |
| `title` | `string` | — |
| `description` | `string` | — |
| `scheduledDate` | `string (date)` | — |
| `completedDate` | `string (date)` | — |
| `cost` | `number` | — |
| `status` | `string enum[OPEN, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED]` | — |
| `priority` | `string enum[LOW, MEDIUM, HIGH, URGENT]` | — |
| `assignedTo` | `integer (int64)` | — |
| `assignedToName` | `string` | — |
| `note` | `string` | — |

### Message

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `role` | `string` | pattern `user\|assistant` |
| `content*` | `string` | bắt buộc; minLength 0; maxLength 4000 |

### MobileAgentChatRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `messages*` | array<`Message`> | bắt buộc |

### MobileAgentChatResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `responseText` | `string` | — |
| `model` | `string` | — |
| `source` | `string` | — |

### MobileAgentCommandRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `commandType` | `string enum[TEXT, VOICE]` | — |
| `tripId` | `integer (int64)` | — |
| `transcript*` | `string` | bắt buộc; minLength 0; maxLength 1000 |

### MobileAgentCommandResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `commandType` | `string enum[TEXT, VOICE]` | — |
| `tripId` | `integer (int64)` | — |
| `transcript` | `string` | — |
| `normalizedCommand` | `string` | — |
| `intent` | `string enum[START_TRIP, PAUSE_TRIP, RESUME_TRIP, COMPLETE_TRIP, GET_DRIVING_TIME, REPORT_FLOOD, SEND_SOS, READ_LATEST_WARNING, UNKNOWN]` | — |
| `confidence` | `number (double)` | — |
| `requiresConfirmation` | `boolean` | — |
| `classificationSource` | `string` | — |
| `status` | `string enum[RECEIVED, UNDERSTOOD, EXECUTED, CANCELLED, UNSUPPORTED, FAILED]` | — |
| `responseText` | `string` | — |
| `executedReferenceType` | `string` | — |
| `executedReferenceId` | `integer (int64)` | — |
| `createdAt` | `string (date-time)` | — |

### MobileAgentConfirmRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `lat` | `number (double)` | min -90; max 90 |
| `lng` | `number (double)` | min -180; max 180 |
| `floodSeverity` | `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]` | — |
| `address` | `string` | minLength 0; maxLength 255 |
| `description` | `string` | minLength 0; maxLength 1000 |

### MobileBootstrapResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `profile` | `MobileProfileResponse` | — |
| `safety` | `MobileSafetySummaryResponse` | — |
| `config` | `MobileConfigResponse` | — |
| `currentAssignment` | `MobileCurrentAssignmentResponse` | — |
| `todayTrips` | array<`TripResponse`> | — |
| `activeFloodPoints` | array<`FloodReportResponse`> | — |
| `notifications` | array<`NotificationResponse`> | — |
| `serverTime` | `string (date-time)` | — |

### MobileConfigResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `maxContinuousDrivingMinutes` | `integer (int32)` | — |
| `warningLevel1Minutes` | `integer (int32)` | — |
| `warningLevel2Minutes` | `integer (int32)` | — |
| `criticalWarningMinutes` | `integer (int32)` | — |
| `phoneUsageSpeedThresholdKmh` | `integer (int32)` | — |
| `phoneUsageDurationThresholdSeconds` | `integer (int32)` | — |
| `floodReportExpirationMinutes` | `integer (int32)` | — |

### MobileCurrentAssignmentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `trip` | `TripResponse` | — |
| `checklistSubmitted` | `boolean` | — |

### MobileMonthlyActivityResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `month` | `object` | — |
| `safetyScore` | `integer (int32)` | — |
| `totalTrips` | `integer (int32)` | — |
| `completedTrips` | `integer (int32)` | — |
| `drivingMinutes` | `integer (int32)` | — |
| `restMinutes` | `integer (int32)` | — |
| `alertCount` | `integer (int32)` | — |
| `criticalAlertCount` | `integer (int32)` | — |
| `days` | array<`DailyActivity`> | — |

### MobilePreTripChecklistRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `exteriorChecked` | `boolean` | — |
| `tiresChecked` | `boolean` | — |
| `brakeChecked` | `boolean` | — |
| `lightsChecked` | `boolean` | — |
| `cameraChecked` | `boolean` | — |
| `gpsChecked` | `boolean` | — |
| `documentsChecked` | `boolean` | — |
| `note` | `string` | minLength 0; maxLength 500 |

### MobilePreTripChecklistResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `vehicleId` | `integer (int64)` | — |
| `exteriorChecked` | `boolean` | — |
| `tiresChecked` | `boolean` | — |
| `brakeChecked` | `boolean` | — |
| `lightsChecked` | `boolean` | — |
| `cameraChecked` | `boolean` | — |
| `gpsChecked` | `boolean` | — |
| `documentsChecked` | `boolean` | — |
| `passed` | `boolean` | — |
| `note` | `string` | — |
| `createdAt` | `string (date-time)` | — |

### MobileProfileResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `userId` | `integer (int64)` | — |
| `username` | `string` | — |
| `email` | `string` | — |
| `fullName` | `string` | — |
| `phone` | `string` | — |
| `role` | `string` | — |
| `driver` | `DriverResponse` | — |

### MobilePushTokenRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `deviceUuid*` | `string` | bắt buộc; minLength 0; maxLength 100 |
| `platform*` | `string` | bắt buộc; pattern `ANDROID\|IOS` |
| `provider*` | `string` | bắt buộc; pattern `FCM\|APNS\|MOCK` |
| `token*` | `string` | bắt buộc; minLength 0; maxLength 512 |
| `appVersion` | `string` | minLength 0; maxLength 40 |
| `osVersion` | `string` | minLength 0; maxLength 80 |
| `deviceModel` | `string` | minLength 0; maxLength 120 |

### MobilePushTokenResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `deviceUuid` | `string` | — |
| `platform` | `string` | — |
| `provider` | `string` | — |
| `enabled` | `boolean` | — |
| `lastSeenAt` | `string (date-time)` | — |

### MobileQuickFloodReportRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `lat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `lng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `address` | `string` | minLength 0; maxLength 255 |
| `severity*` | `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]` | bắt buộc |
| `imageUrl` | `string` | minLength 0; maxLength 500 |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### MobileSafetySummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `driverId` | `integer (int64)` | — |
| `status` | `string enum[AVAILABLE, DRIVING, RESTING, SUSPENDED, HIGH_RISK, INACTIVE]` | — |
| `safetyScore` | `integer (int32)` | — |
| `drivingTimeTodayMinutes` | `integer (int32)` | — |
| `continuousDrivingMinutes` | `integer (int32)` | — |
| `remainingContinuousDrivingMinutes` | `integer (int32)` | — |
| `totalTrips` | `integer (int32)` | — |
| `totalAlerts` | `integer (int32)` | — |

### MobileTelemetryBatchItemResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `clientEventId` | `string` | — |
| `status` | `string` | — |
| `telemetryId` | `integer (int64)` | — |
| `message` | `string` | — |

### MobileTelemetryBatchRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `batchId*` | `string` | bắt buộc; minLength 0; maxLength 100 |
| `items*` | array<`TelemetryRequest`> | bắt buộc |

### MobileTelemetryBatchResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `batchId` | `string` | — |
| `acceptedCount` | `integer (int32)` | — |
| `duplicateCount` | `integer (int32)` | — |
| `rejectedCount` | `integer (int32)` | — |
| `items` | array<`MobileTelemetryBatchItemResponse`> | — |

### MobileTripSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `trip` | `TripResponse` | — |
| `checklistSubmitted` | `boolean` | — |
| `nextAction` | `string` | — |

### MobileWorkflowResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `action` | `string` | — |
| `trip` | `TripResponse` | — |
| `drivingSession` | `DrivingSessionResponse` | — |
| `navigationSessionId` | `string` | — |

### NavigationEventRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `sessionId*` | `string` | bắt buộc |
| `eventType*` | `string` | bắt buộc; minLength 0; maxLength 40 |
| `lat` | `number (double)` | min -90; max 90 |
| `lng` | `number (double)` | min -180; max 180 |
| `distanceToRouteMeters` | `number (double)` | — |
| `gpsAccuracyMeters` | `number (double)` | — |
| `occurredAt` | `string (date-time)` | — |
| `metadata` | `string` | minLength 0; maxLength 1000 |

### NavigationEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `eventId` | `integer (int64)` | — |
| `sessionId` | `string` | — |
| `eventType` | `string` | — |
| `offRoute` | `boolean` | — |
| `offRouteDurationSeconds` | `integer (int32)` | — |
| `rerouteRequired` | `boolean` | — |
| `occurredAt` | `string (date-time)` | — |

### NavigationRerouteRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `sessionId*` | `string` | bắt buộc |
| `currentLat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `currentLng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `gpsAccuracyMeters` | `number (double)` | — |
| `reason` | `string` | — |

### NavigationRouteCandidateResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `routeIndex` | `integer (int32)` | — |
| `label` | `string` | — |
| `distanceMeters` | `integer (int32)` | — |
| `durationSeconds` | `integer (int32)` | — |
| `totalScore` | `number (double)` | — |
| `floodPenalty` | `number (double)` | — |
| `vehicleRestrictionPenalty` | `number (double)` | — |
| `driverTimePenalty` | `number (double)` | — |
| `floodIntersectionCount` | `integer (int32)` | — |
| `safe` | `boolean` | — |
| `blocked` | `boolean` | — |
| `recommended` | `boolean` | — |
| `provider` | `string` | — |
| `fallback` | `boolean` | — |
| `geometry` | array<array<`number (double)`>> | — |
| `steps` | array<`NavigationStepResponse`> | — |
| `warnings` | array<`string`> | — |

### NavigationRouteRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `originLat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `originLng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `destinationLat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `destinationLng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `destinationName` | `string` | minLength 0; maxLength 255 |
| `tripId` | `integer (int64)` | — |

### NavigationSessionResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `sessionId` | `string` | — |
| `tripId` | `integer (int64)` | — |
| `vehicleId` | `integer (int64)` | — |
| `status` | `string` | — |
| `originLat` | `number (double)` | — |
| `originLng` | `number (double)` | — |
| `destinationLat` | `number (double)` | — |
| `destinationLng` | `number (double)` | — |
| `destinationName` | `string` | — |
| `safe` | `boolean` | — |
| `selectedRouteIndex` | `integer (int32)` | — |
| `routes` | array<`NavigationRouteCandidateResponse`> | — |
| `startedAt` | `string (date-time)` | — |
| `updatedAt` | `string (date-time)` | — |

### NavigationStepResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `instruction` | `string` | — |
| `roadName` | `string` | — |
| `distanceMeters` | `number (double)` | — |
| `durationSeconds` | `number (double)` | — |
| `maneuverType` | `string` | — |
| `modifier` | `string` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |

### NotificationResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `type` | `string enum[AI_ALERT, SOS, FLOOD, GPS_LOST, DRIVING_TIME, TRIP_DELAYED, MAINTENANCE, SYSTEM]` | — |
| `title` | `string` | — |
| `content` | `string` | — |
| `referenceType` | `string` | — |
| `referenceId` | `integer (int64)` | — |
| `read` | `boolean` | — |
| `createdAt` | `string (date-time)` | — |

### Pageable

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `page` | `integer (int32)` | min 0 |
| `size` | `integer (int32)` | min 1 |
| `sort` | array<`string`> | — |

### PageResponseDeviceConnectionLogResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`DeviceConnectionLogResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseDeviceResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`DeviceResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseDriverResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`DriverResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseFloodReportResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`FloodReportResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseIncidentResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`IncidentResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseMaintenanceOrderResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`MaintenanceOrderResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseMobileAgentCommandResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`MobileAgentCommandResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseNotificationResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`NotificationResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseSafetyEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`SafetyEventResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseTripResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`TripResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseUserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`UserResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### PageResponseVehicleResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `items` | array<`VehicleResponse`> | — |
| `page` | `integer (int32)` | — |
| `size` | `integer (int32)` | — |
| `totalElements` | `integer (int64)` | — |
| `totalPages` | `integer (int32)` | — |

### RefreshTokenRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `refreshToken*` | `string` | bắt buộc |

### RemainingDrivingTimeResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `driverId` | `integer (int64)` | — |
| `sessionId` | `integer (int64)` | — |
| `status` | `string enum[ACTIVE, PAUSED, FINISHED]` | — |
| `maxContinuousMinutes` | `integer (int32)` | — |
| `continuousDrivingMinutes` | `integer (int32)` | — |
| `remainingMinutes` | `integer (int32)` | — |
| `warningLevel` | `string` | — |

### RouteCheckRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `points*` | array<`RoutePointRequest`> | bắt buộc |

### RoutePointRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `lat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `lng*` | `number (double)` | bắt buộc; min -180; max 180 |

### RouteRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `startLat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `startLng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `endLat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `endLng*` | `number (double)` | bắt buộc; min -180; max 180 |

### RouteResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `distanceKm` | `number (double)` | — |
| `durationMinutes` | `integer (int64)` | — |
| `coordinates` | array<array<`number (double)`>> | — |
| `provider` | `string` | — |
| `fallback` | `boolean` | — |
| `message` | `string` | — |

### RouteRiskSummaryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `risky` | `boolean` | — |
| `highestSeverity` | `string enum[NONE, LOW, MEDIUM, HIGH, BLOCKED]` | — |
| `matchedFloodPoints` | `integer (int32)` | — |
| `matchedReports` | array<`FloodReportResponse`> | — |

### SafetyEventActionRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `note` | `string` | minLength 0; maxLength 500 |

### SafetyEventResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `clientEventId` | `string` | — |
| `eventType` | `string enum[DROWSINESS, PHONE_USAGE, DISTRACTION, SPEEDING, OVER_DRIVING_TIME, ROUTE_DEVIATION, ABNORMAL_STOP, GPS_LOST, FLOOD_RISK]` | — |
| `severity` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `driverId` | `integer (int64)` | — |
| `driverName` | `string` | — |
| `tripId` | `integer (int64)` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `speed` | `number (double)` | — |
| `confidence` | `number (double)` | — |
| `evidenceUrl` | `string` | — |
| `status` | `string enum[NEW, ACKNOWLEDGED, PROCESSING, RESOLVED, DISMISSED]` | — |
| `handledBy` | `integer (int64)` | — |
| `handledByName` | `string` | — |
| `handledAt` | `string (date-time)` | — |
| `note` | `string` | — |
| `createdAt` | `string (date-time)` | — |
| `receivedAt` | `string (date-time)` | — |

### SosRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `driverId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `lat*` | `number (double)` | bắt buộc |
| `lng*` | `number (double)` | bắt buộc |
| `severity` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | — |
| `description` | `string` | minLength 0; maxLength 1000 |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### StartDrivingSessionRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `driverId*` | `integer (int64)` | bắt buộc |
| `vehicleId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |

### SystemSettingResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `key` | `string` | — |
| `group` | `string enum[DRIVING_TIME, AI_ALERT, SOS_ESCALATION, MAP, FLOOD, NOTIFICATION, SYSTEM]` | — |
| `value` | `string` | — |
| `valueType` | `string enum[STRING, INTEGER, DECIMAL, BOOLEAN, JSON]` | — |
| `description` | `string` | — |
| `updatedBy` | `integer (int64)` | — |
| `updatedAt` | `string (date-time)` | — |

### TelemetryRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId*` | `integer (int64)` | bắt buộc |
| `driverId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `lat*` | `number (double)` | bắt buộc; min -90; max 90 |
| `lng*` | `number (double)` | bắt buộc; min -180; max 180 |
| `speed` | `number (double)` | — |
| `heading` | `number (double)` | — |
| `batteryLevel` | `integer (int32)` | — |
| `gpsStatus` | `string enum[GOOD, WEAK, LOST, OFFLINE]` | — |
| `createdAt` | `string (date-time)` | — |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### TelemetryResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `driverId` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `speed` | `number (double)` | — |
| `heading` | `number (double)` | — |
| `batteryLevel` | `integer (int32)` | — |
| `gpsStatus` | `string enum[GOOD, WEAK, LOST, OFFLINE]` | — |
| `createdAt` | `string (date-time)` | — |
| `clientEventId` | `string` | — |
| `recordedAt` | `string (date-time)` | — |
| `receivedAt` | `string (date-time)` | — |

### TripActionRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `note` | `string` | minLength 0; maxLength 500 |
| `clientEventId` | `string` | minLength 0; maxLength 100 |

### TripResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `tripCode` | `string` | — |
| `vehicleId` | `integer (int64)` | — |
| `vehiclePlateNumber` | `string` | — |
| `driverId` | `integer (int64)` | — |
| `driverName` | `string` | — |
| `startLocation` | `string` | — |
| `startLat` | `number (double)` | — |
| `startLng` | `number (double)` | — |
| `endLocation` | `string` | — |
| `endLat` | `number (double)` | — |
| `endLng` | `number (double)` | — |
| `waypoints` | `string` | — |
| `plannedRoute` | `string` | — |
| `actualRoute` | `string` | — |
| `plannedStartTime` | `string (date-time)` | — |
| `actualStartTime` | `string (date-time)` | — |
| `estimatedEndTime` | `string (date-time)` | — |
| `actualEndTime` | `string (date-time)` | — |
| `status` | `string enum[DRAFT, ASSIGNED, ACCEPTED, IN_PROGRESS, RESTING, COMPLETED, DELAYED, INCIDENT, CANCELLED]` | — |
| `progress` | `integer (int32)` | — |
| `riskLevel` | `string enum[LOW, MEDIUM, HIGH, CRITICAL]` | — |

### TripTimelineResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `tripId` | `integer (int64)` | — |
| `action` | `string` | — |
| `actorId` | `integer (int64)` | — |
| `actorName` | `string` | — |
| `note` | `string` | — |
| `createdAt` | `string (date-time)` | — |

### UpdateAccountStatusRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `status*` | `string enum[ACTIVE, LOCKED, DISABLED, PENDING]` | bắt buộc |

### UpdateDeviceRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `name*` | `string` | bắt buộc; minLength 0; maxLength 120 |
| `type*` | `string enum[GPS_TRACKER, CABIN_CAMERA, DASH_CAMERA, DRIVER_PHONE, IOT_FLOOD_SENSOR]` | bắt buộc |
| `status*` | `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]` | bắt buộc |
| `vehicleId` | `integer (int64)` | — |
| `phone` | `string` | minLength 0; maxLength 20 |
| `serialNumber` | `string` | minLength 0; maxLength 80 |
| `firmwareVersion` | `string` | minLength 0; maxLength 40 |

### UpdateDeviceStatusRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `status*` | `string enum[ONLINE, OFFLINE, MAINTENANCE, INACTIVE]` | bắt buộc |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `note` | `string` | minLength 0; maxLength 255 |

### UpdateDriverRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `fullName*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `phone*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `email` | `string` | minLength 0; maxLength 120 |
| `address` | `string` | minLength 0; maxLength 255 |
| `licenseClass*` | `string` | bắt buộc; minLength 0; maxLength 20 |
| `licenseExpiredAt*` | `string (date)` | bắt buộc |
| `status*` | `string enum[AVAILABLE, DRIVING, RESTING, SUSPENDED, HIGH_RISK, INACTIVE]` | bắt buộc |
| `currentVehicleId` | `integer (int64)` | — |

### UpdateMaintenanceOrderRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId*` | `integer (int64)` | bắt buộc |
| `type*` | `string enum[PERIODIC, REPAIR, INSPECTION, INSURANCE, EMERGENCY]` | bắt buộc |
| `title*` | `string` | bắt buộc; minLength 0; maxLength 150 |
| `description` | `string` | minLength 0; maxLength 1000 |
| `scheduledDate` | `string (date)` | — |
| `completedDate` | `string (date)` | — |
| `cost` | `number` | — |
| `status*` | `string enum[OPEN, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED]` | bắt buộc |
| `priority*` | `string enum[LOW, MEDIUM, HIGH, URGENT]` | bắt buộc |
| `assignedTo` | `integer (int64)` | — |
| `note` | `string` | minLength 0; maxLength 1000 |

### UpdateSystemSettingRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `group*` | `string enum[DRIVING_TIME, AI_ALERT, SOS_ESCALATION, MAP, FLOOD, NOTIFICATION, SYSTEM]` | bắt buộc |
| `value*` | `string` | bắt buộc |
| `valueType*` | `string enum[STRING, INTEGER, DECIMAL, BOOLEAN, JSON]` | bắt buộc |
| `description` | `string` | minLength 0; maxLength 255 |

### UpdateVehicleRequest

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleType*` | `string enum[TRUCK, VAN, BUS, CAR, PICKUP, MOTORBIKE]` | bắt buộc |
| `brand` | `string` | minLength 0; maxLength 80 |
| `model` | `string` | minLength 0; maxLength 80 |
| `year` | `integer (int32)` | — |
| `loadCapacity` | `number` | — |
| `seatCount` | `integer (int32)` | — |
| `fuelType` | `string enum[DIESEL, GASOLINE, ELECTRIC, HYBRID]` | — |
| `status*` | `string enum[AVAILABLE, RUNNING, RESTING, MAINTENANCE, OFFLINE, INACTIVE]` | bắt buộc |
| `currentDriverId` | `integer (int64)` | — |
| `gpsDeviceId` | `integer (int64)` | — |
| `cameraDeviceId` | `integer (int64)` | — |
| `inspectionExpiredAt` | `string (date)` | — |
| `insuranceExpiredAt` | `string (date)` | — |

### UserResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `username` | `string` | — |
| `email` | `string` | — |
| `fullName` | `string` | — |
| `phone` | `string` | — |
| `status` | `string enum[ACTIVE, LOCKED, DISABLED, PENDING]` | — |
| `role` | `string enum[ADMIN, FLEET_MANAGER, DISPATCHER, SAFETY_OFFICER, RESCUE_TEAM, DRIVER]` | — |
| `createdAt` | `string (date-time)` | — |

### VehicleRealtimeStatusResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `vehicleId` | `integer (int64)` | — |
| `plateNumber` | `string` | — |
| `status` | `string enum[AVAILABLE, RUNNING, RESTING, MAINTENANCE, OFFLINE, INACTIVE]` | — |
| `lat` | `number (double)` | — |
| `lng` | `number (double)` | — |
| `speed` | `number (double)` | — |
| `lastUpdatedAt` | `string (date-time)` | — |
| `gpsOnline` | `boolean` | — |

### VehicleResponse

| Trường | Kiểu | Ràng buộc/mô tả |
|---|---|---|
| `id` | `integer (int64)` | — |
| `plateNumber` | `string` | — |
| `vehicleType` | `string enum[TRUCK, VAN, BUS, CAR, PICKUP, MOTORBIKE]` | — |
| `brand` | `string` | — |
| `model` | `string` | — |
| `year` | `integer (int32)` | — |
| `loadCapacity` | `number` | — |
| `seatCount` | `integer (int32)` | — |
| `fuelType` | `string enum[DIESEL, GASOLINE, ELECTRIC, HYBRID]` | — |
| `status` | `string enum[AVAILABLE, RUNNING, RESTING, MAINTENANCE, OFFLINE, INACTIVE]` | — |
| `currentDriverId` | `integer (int64)` | — |
| `currentDriverName` | `string` | — |
| `gpsDeviceId` | `integer (int64)` | — |
| `gpsDeviceCode` | `string` | — |
| `cameraDeviceId` | `integer (int64)` | — |
| `cameraDeviceCode` | `string` | — |
| `inspectionExpiredAt` | `string (date)` | — |
| `insuranceExpiredAt` | `string (date)` | — |
| `lastLat` | `number (double)` | — |
| `lastLng` | `number (double)` | — |
| `lastSpeed` | `number (double)` | — |
| `lastUpdatedAt` | `string (date-time)` | — |

## 13. Nguồn sự thật và tài liệu liên quan

- OpenAPI runtime: `/v3/api-docs` và Swagger UI.
- Mobile contract bổ sung: `web_quan_ly/backend/MOBILE_API_CONTRACT.md`.
- Master prompt và nhật ký loop: `docs/CODEX_FULL_PROGRESS.md`.
- DB evidence: `docs/DATABASE_VERIFICATION.md`.
- Runbook: `docs/DOCKER_RUNBOOK.md`.
- Kiểm thử thiết bị: `docs/LOCAL_DEVICE_TEST.md`.
- Quyết định kỹ thuật/fallback: `docs/CODEX_DECISIONS.md`.

Không suy đoán field ngoài OpenAPI. Khi backend thay đổi, chạy lại `node .\docker\scripts\export-api-report.mjs` và commit báo cáo mới cùng code.

