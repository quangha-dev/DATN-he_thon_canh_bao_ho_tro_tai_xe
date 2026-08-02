# Báo cáo phân tích dự án và hợp đồng tích hợp app SafeFleet

> **Lưu ý phiên bản:** đây là bản khảo sát baseline trước các vòng hoàn thiện. Báo cáo hiện hành, sinh trực tiếp từ OpenAPI runtime V7 ngày 27/07/2026, là `BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md` với 153 operation, 134 path và 167 schema. Không dùng các nhận định “chưa có” trong bản baseline này để triển khai client mới.

> Vị trí dự án web quản lý: `web_quan_ly/`  
> Backend: `web_quan_ly/backend/`  
> Frontend quản trị: `web_quan_ly/frontend/`  
> Ngày đối chiếu mã nguồn: 26/07/2026  
> Phạm vi: controller, DTO, service, entity/repository, security, migration SQL, cấu hình, test và adapter API của frontend.

## 1. Kết luận nhanh

SafeFleet là hệ thống quản lý đội xe và hỗ trợ an toàn lái xe, gồm:

- Web quản trị/điều hành cho quản trị viên, quản lý đội xe, điều phối viên, cán bộ an toàn và đội cứu hộ.
- Backend Spring Boot cung cấp 131 REST endpoint, JWT/RBAC, MySQL/Flyway và WebSocket STOMP.
- Nhóm API `/api/v1/mobile/**` gồm 28 endpoint facade dành riêng cho app tài xế.
- Các chức năng chính: quản lý xe/tài xế/thiết bị, điều phối và vòng đời chuyến, GPS realtime, cảnh báo AI, giám sát giờ lái, SOS/sự cố/cứu hộ, cảnh báo ngập, bảo trì, thông báo, báo cáo và cấu hình runtime.
- “Agentic AI” hiện mới dừng ở ghi nhận/phân loại lệnh tài xế theo từ khóa. Nó chưa phải tác tử AI hoàn chỉnh và không tự thực thi SOS.

Nếu xây app tài xế, nên ưu tiên:

1. `POST /api/v1/auth/login`.
2. Toàn bộ `/api/v1/mobile/**`.
3. `POST /api/v1/locations/route` và `GET /api/v1/locations/autocomplete` nếu app cần tự tìm đường; hiện hai API này chưa cho role `DRIVER`, cần backend mở quyền hoặc tạo facade mobile.
4. STOMP `/ws` và các topic realtime nếu cần nhận sự kiện tức thời.

## 2. Mục tiêu và luồng nghiệp vụ của dự án

### 2.1. Mục tiêu

- Quản lý tập trung phương tiện, tài xế, thiết bị GPS/camera/điện thoại và trạng thái vận hành.
- Điều phối xe và tài xế đủ điều kiện cho chuyến.
- Theo dõi vị trí, tốc độ, pin và chất lượng GPS.
- Ghi nhận cảnh báo AI như buồn ngủ, dùng điện thoại, mất tập trung, quá tốc độ, quá giờ lái, lệch tuyến, dừng bất thường, mất GPS và rủi ro ngập.
- Xử lý SOS và sự cố theo timeline, phân công đội cứu hộ.
- Thu thập, xác minh và đánh giá điểm ngập trên tuyến.
- Theo dõi thời gian lái liên tục và tự tạo cảnh báo khi vượt ngưỡng.
- Cung cấp dashboard, báo cáo và cấu hình rule động.
- Cung cấp facade ổn định để app tài xế không phải ghép nhiều API quản trị.

### 2.2. Luồng vận hành chính

```text
Quản trị tạo tài khoản/xe/tài xế/thiết bị
  -> điều phối tạo và giao chuyến
  -> tài xế nhận chuyến
  -> gửi checklist trước chuyến
  -> bắt đầu chuyến/phiên lái
  -> app gửi GPS + cảnh báo AI
  -> backend lưu DB + phát WebSocket
  -> web điều hành theo dõi/xử lý cảnh báo, SOS, ngập
  -> tài xế tạm nghỉ/tiếp tục/hoàn thành
  -> backend cập nhật trạng thái xe, tài xế, chuyến và báo cáo
```

## 3. Kiến trúc và công nghệ

### 3.1. Backend

- Java 21, Spring Boot 3.3.7, Maven.
- Spring Web, Data JPA, Validation, Security, WebSocket.
- MySQL, Flyway `V1`–`V3`.
- JWT ký HMAC bằng `jjwt 0.12.6`.
- Swagger/OpenAPI: `/swagger-ui.html`, JSON: `/v3/api-docs`.
- WebSocket/STOMP + SockJS: `/ws`.
- Dịch vụ ngoài:
  - Photon/OpenStreetMap cho autocomplete.
  - OSRM cho tuyến đường.
  - Có fallback địa điểm Hà Nội và Haversine nếu dịch vụ ngoài lỗi.

### 3.2. Frontend quản trị

- Next.js 16.2.10, React 19.2.4, TypeScript, Tailwind CSS 4.
- Axios, MapLibre GL, Recharts, Framer Motion, Lucide.
- JWT và user được lưu trong `localStorage`.
- REST base URL mặc định: `http://localhost:8080/api/v1`.
- Frontend hiện gọi REST và chưa có STOMP client; dữ liệu “realtime” hiện được tải qua REST, chưa tự cập nhật theo topic.

### 3.3. Cấu hình chạy

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `SERVER_PORT` | `8080` | Cổng backend |
| `DB_URL` | MySQL `localhost:3306/safefleet` | JDBC URL |
| `DB_USERNAME` | `root` | User DB |
| `DB_PASSWORD` | `root` | Password DB |
| `JWT_SECRET` | secret demo trong `application.yml` | Khóa ký token; phải đổi khi production |
| `JWT_EXPIRATION_MINUTES` | `1440` | Token sống 24 giờ |
| `CORS_ALLOWED_ORIGINS` | localhost 3000/5173 | Origin web |
| `SEED_ENABLED` | `true` | Bật dữ liệu demo |
| `PHOTON_URL` | `https://photon.komoot.io/api/` | Autocomplete |
| `OSRM_URL` | public OSRM | Tính tuyến |
| `NEXT_PUBLIC_API_URL` | `http://localhost:8080/api/v1` | Base URL frontend |

## 4. Quy ước kết nối API

### 4.1. Base URL

```text
http://<host>:8080/api/v1
```

App Android emulator thường dùng `http://10.0.2.2:8080/api/v1`; thiết bị thật phải dùng IP LAN hoặc HTTPS domain truy cập được từ thiết bị.

### 4.2. Header

```http
Content-Type: application/json
Authorization: Bearer <accessToken>
```

Chỉ `POST /auth/login`, Swagger và `/ws/**` được public. Mọi REST API khác cần JWT.

### 4.3. Response chung

Mọi controller trả HTTP `200` khi thành công, kể cả create/delete:

```json
{
  "success": true,
  "message": "Success",
  "data": {},
  "timestamp": "2026-07-26T10:30:00"
}
```

App luôn đọc dữ liệu nghiệp vụ trong `data`, không đọc trực tiếp root.

Response phân trang:

```json
{
  "success": true,
  "message": "Success",
  "data": {
    "items": [],
    "page": 0,
    "size": 20,
    "totalElements": 0,
    "totalPages": 0
  },
  "timestamp": "2026-07-26T10:30:00"
}
```

Spring `Pageable` hỗ trợ:

- `page`: bắt đầu từ `0`.
- `size`: số phần tử.
- `sort`: ví dụ `createdAt,desc`; có thể lặp nhiều lần.

### 4.4. Ngày giờ và tọa độ

- `LocalDate`: `YYYY-MM-DD`.
- `LocalDateTime`: ISO-8601 không timezone, ví dụ `2026-07-26T10:30:00`.
- Backend cấu hình timezone `Asia/Ho_Chi_Minh`.
- Tọa độ: `lat [-90, 90]`, `lng [-180, 180]`.
- `RouteResponse.coordinates` theo GeoJSON/MapLibre: `[lng, lat]`, không phải `[lat, lng]`.

### 4.5. Error chung

```json
{
  "success": false,
  "message": "Dữ liệu không hợp lệ",
  "data": {
    "fieldName": "lý do"
  },
  "timestamp": "2026-07-26T10:30:00"
}
```

| HTTP | Trường hợp |
|---|---|
| `400` | Validation, JSON sai, enum sai, tham số sai, trạng thái nghiệp vụ không hợp lệ |
| `401` | Thiếu/sai/hết hạn JWT, sai thông tin đăng nhập |
| `403` | Sai role hoặc truy cập dữ liệu không thuộc tài xế |
| `404` | Không tìm thấy entity |
| `409` | Trùng/vi phạm ràng buộc dữ liệu |
| `405` | Sai HTTP method |
| `415` | Sai `Content-Type` |
| `500` | Lỗi hệ thống chưa được ánh xạ |

## 5. Xác thực và phân quyền

### 5.1. Role

| Viết tắt | Giá trị backend |
|---|---|
| A | `ADMIN` |
| FM | `FLEET_MANAGER` |
| DP | `DISPATCHER` |
| SO | `SAFETY_OFFICER` |
| RT | `RESCUE_TEAM` |
| DR | `DRIVER` |
| Any | Mọi tài khoản đã đăng nhập |

JWT chứa `sub=username`, `userId`, `email`, `iat`, `exp`. Role không nằm trong token; mỗi request backend tải lại user từ DB để dựng authority. Hiện không có refresh token, logout server-side hay blacklist token.

### 5.2. Login mẫu

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "usernameOrEmail": "driver01",
  "password": "123456"
}
```

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "<jwt>",
    "tokenType": "Bearer",
    "userId": 6,
    "driverId": 1,
    "username": "driver01",
    "email": "driver01@safefleet.vn",
    "fullName": "Nguyen Van An",
    "role": "DRIVER"
  },
  "timestamp": "2026-07-26T10:30:00"
}
```

Tài khoản seed dùng mật khẩu demo `123456`: `admin`, `manager`, `dispatcher`, `safety`, `rescue`, `driver01` hoặc email tương ứng `@safefleet.vn`.

## 6. Danh mục đầy đủ 131 REST API

Quy ước cột:

- `Input`: `path`, `query`, hoặc DTO body. Các DTO được định nghĩa ở mục 7.
- `Output`: kiểu của trường `data`; mọi kiểu đều nằm trong `ApiResponse<T>`.
- Endpoint phân trang trả `Page<T>`, tức `PageResponse<T>`.

### 6.1. Auth — 2 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /auth/login` | Public | body `LoginRequest` | `AuthResponse` | Đăng nhập bằng username/email |
| `GET /auth/me` | Any | Không | `CurrentUserResponse` | Kiểm tra token và lấy user hiện tại |

### 6.2. Accounts — 5 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /accounts` | A, FM | query `keyword?` + pageable | `Page<UserResponse>` | Tìm tài khoản |
| `GET /accounts/{id}` | A, FM | path `id` | `UserResponse` | Chi tiết tài khoản |
| `POST /accounts` | A | body `CreateUserRequest` | `UserResponse` | Tạo tài khoản nhân sự |
| `POST /accounts/drivers` | A, FM | body `CreateDriverAccountRequest` | `UserResponse` | Tạo đồng thời user DRIVER và hồ sơ tài xế |
| `PATCH /accounts/{id}/status` | A | path `id`, body `UpdateAccountStatusRequest` | `UserResponse` | Khóa/mở/vô hiệu hóa tài khoản |

### 6.3. Vehicles — 9 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /vehicles` | A, FM, DP, SO | `plateNumber?`, `vehicleType?`, `status?`, `gpsOnline?`, pageable | `Page<VehicleResponse>` | Lọc xe |
| `POST /vehicles` | A, FM | body `CreateVehicleRequest` | `VehicleResponse` | Tạo xe |
| `GET /vehicles/{id}` | A, FM, DP, SO | path `id` | `VehicleResponse` | Chi tiết xe |
| `PUT /vehicles/{id}` | A, FM | path `id`, body `UpdateVehicleRequest` | `VehicleResponse` | Cập nhật xe |
| `DELETE /vehicles/{id}` | A, FM | path `id` | `null` | Soft-delete xe |
| `GET /vehicles/{id}/realtime-status` | A, FM, DP, SO | path `id` | `VehicleRealtimeStatusResponse` | Trạng thái GPS hiện tại |
| `GET /vehicles/{id}/trips` | A, FM, DP, SO | path `id`, pageable | `Page<TripResponse>` | Lịch sử chuyến theo xe |
| `GET /vehicles/{id}/safety-events` | A, FM, DP, SO | path `id`, pageable | `Page<SafetyEventResponse>` | Lịch sử cảnh báo theo xe |
| `GET /vehicles/map/positions` | A, FM, DP, SO | Không | `List<VehicleRealtimeStatusResponse>` | Marker tất cả xe |

### 6.4. Drivers — 9 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /drivers` | A, FM, DP, SO | `keyword?`, `status?`, `licenseClass?`, `minSafetyScore?`, `maxSafetyScore?`, pageable | `Page<DriverResponse>` | Lọc tài xế |
| `POST /drivers` | A, FM | body `CreateDriverRequest` | `DriverResponse` | Tạo hồ sơ tài xế |
| `GET /drivers/{id}` | A, FM, DP, SO, DR | path `id` | `DriverResponse` | Chi tiết; DR chỉ xem chính mình |
| `PUT /drivers/{id}` | A, FM | path `id`, body `UpdateDriverRequest` | `DriverResponse` | Cập nhật tài xế |
| `DELETE /drivers/{id}` | A, FM | path `id` | `null` | Soft-delete tài xế |
| `GET /drivers/{id}/driving-time-today` | A, FM, DP, SO, DR | path `id` | `DrivingTimeTodayResponse` | Snapshot giờ lái hôm nay |
| `GET /drivers/{id}/trips` | A, FM, DP, SO, DR | path `id`, pageable | `Page<TripResponse>` | Lịch sử chuyến; DR chỉ của mình |
| `GET /drivers/{id}/safety-events` | A, FM, DP, SO, DR | path `id`, pageable | `Page<SafetyEventResponse>` | Lịch sử cảnh báo; DR chỉ của mình |
| `POST /drivers/{id}/recalculate-safety-score` | A, FM, SO | path `id` | `DriverResponse` | Tính lại `max(0,100-totalAlerts*3)` |

### 6.5. Devices — 8 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /devices` | A, FM, DP | `type?`, `status?`, `vehicleId?`, pageable | `Page<DeviceResponse>` | Lọc thiết bị |
| `GET /devices/{id}` | A, FM, DP | path `id` | `DeviceResponse` | Chi tiết thiết bị |
| `POST /devices` | A, FM | body `CreateDeviceRequest` | `DeviceResponse` | Tạo thiết bị |
| `PUT /devices/{id}` | A, FM | path `id`, body `UpdateDeviceRequest` | `DeviceResponse` | Cập nhật thiết bị |
| `DELETE /devices/{id}` | A, FM | path `id` | `null` | Soft-delete thiết bị |
| `POST /devices/{id}/assign-vehicle` | A, FM | path `id`, body `AssignDeviceVehicleRequest` | `DeviceResponse` | Gán thiết bị cho xe |
| `PATCH /devices/{id}/status` | A, FM, DP | path `id`, body `UpdateDeviceStatusRequest` | `DeviceResponse` | Heartbeat/trạng thái; tạo connection log |
| `GET /devices/{id}/connection-logs` | A, FM, DP | path `id`, pageable | `Page<DeviceConnectionLogResponse>` | Lịch sử kết nối |

### 6.6. Dispatch — 2 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /dispatch/suggestions` | A, FM, DP | `startLat?`, `startLng?`, `limit=10` | `List<DispatchSuggestionResponse>` | Xếp hạng cặp xe-tài xế |
| `GET /dispatch/availability` | A, FM, DP | `vehicleId`, `driverId` | `AvailabilityResponse` | Kiểm tra khả dụng trước khi giao |

### 6.7. Locations — 2 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /locations/autocomplete` | A, FM, DP, SO | `query` 2–120 ký tự, `limit=6` (1–10) | `List<LocationSuggestionResponse>` | Photon, fallback địa điểm Hà Nội |
| `POST /locations/route` | A, FM, DP, SO | body `RouteRequest` | `RouteResponse` | OSRM; fallback Haversine |

### 6.8. Trips — 11 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /trips` | A, FM, DP | body `CreateTripRequest` | `TripResponse` | Tạo chuyến; nếu có cả xe và tài xế thì trạng thái `ASSIGNED` |
| `GET /trips` | A, FM, DP, SO, DR | `status?`, `vehicleId?`, `driverId?`, `fromDate?`, `toDate?`, pageable | `Page<TripResponse>` | Lọc chuyến; DR tự bị scope về chính mình |
| `GET /trips/{id}` | A, FM, DP, SO, DR | path `id` | `TripResponse` | Chi tiết; DR chỉ chuyến của mình |
| `POST /trips/{id}/assign` | A, FM, DP | body `AssignTripRequest` | `TripResponse` | Giao xe/tài xế cho chuyến DRAFT/CANCELLED |
| `POST /trips/{id}/accept` | A, FM, DP, DR | body `TripActionRequest?` | `TripResponse` | `ASSIGNED -> ACCEPTED` |
| `POST /trips/{id}/start` | A, FM, DP, DR | body `TripActionRequest?` | `TripResponse` | `ASSIGNED/ACCEPTED -> IN_PROGRESS` |
| `POST /trips/{id}/pause` | A, FM, DP, DR | body `TripActionRequest?` | `TripResponse` | `IN_PROGRESS -> RESTING` |
| `POST /trips/{id}/resume` | A, FM, DP, DR | body `TripActionRequest?` | `TripResponse` | `RESTING -> IN_PROGRESS` |
| `POST /trips/{id}/complete` | A, FM, DP, DR | body `TripActionRequest?` | `TripResponse` | `IN_PROGRESS/RESTING -> COMPLETED` |
| `POST /trips/{id}/cancel` | A, FM, DP | body `CancelTripRequest` | `TripResponse` | Hủy chuyến chưa completed |
| `GET /trips/{id}/timeline` | A, FM, DP, SO, DR | path `id` | `List<TripTimelineResponse>` | Timeline trạng thái |

### 6.9. Telemetry — 4 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /telemetry` | A, FM, DP, DR | body `TelemetryRequest` | `TelemetryResponse` | Lưu GPS, cập nhật vị trí xe, phát WebSocket |
| `GET /telemetry/vehicles/current` | A, FM, DP, SO | Không | `List<VehicleRealtimeStatusResponse>` | Vị trí xe hiện tại |
| `GET /telemetry/trips/{tripId}/history` | A, FM, DP, SO, DR | path `tripId`, `from?`, `to?` datetime | `List<TelemetryResponse>` | Lịch sử GPS; chỉ lọc thời gian khi có đủ cả `from` và `to` |
| `GET /telemetry/trips/{tripId}/replay` | A, FM, DP, SO, DR | path `tripId` | `List<TelemetryResponse>` | Toàn bộ đường đi theo thời gian tăng dần |

### 6.10. Safety events — 7 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /safety-events` | A, FM, DP, SO, DR | body `CreateSafetyEventRequest` | `SafetyEventResponse` | Ghi cảnh báo AI, trừ safety score, phát realtime |
| `GET /safety-events` | A, FM, DP, SO, DR | `eventType?`, `severity?`, `status?`, `vehicleId?`, `driverId?`, `from?`, `to?`, pageable | `Page<SafetyEventResponse>` | Lọc cảnh báo; DR tự scope chính mình |
| `GET /safety-events/{id}` | A, FM, DP, SO, DR | path `id` | `SafetyEventResponse` | Chi tiết cảnh báo |
| `POST /safety-events/{id}/acknowledge` | A, FM, DP, SO | body `SafetyEventActionRequest?` | `SafetyEventResponse` | Chuyển `ACKNOWLEDGED` |
| `POST /safety-events/{id}/resolve` | A, FM, DP, SO | body `SafetyEventActionRequest?` | `SafetyEventResponse` | Chuyển `RESOLVED` |
| `POST /safety-events/{id}/dismiss` | A, FM, DP, SO | body `SafetyEventActionRequest?` | `SafetyEventResponse` | Chuyển `DISMISSED` |
| `POST /safety-events/{id}/create-incident` | A, FM, DP, SO | path `id` | `IncidentResponse` | Tạo incident và chuyển event sang `PROCESSING` |

### 6.11. Driving sessions — 5 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /driving-sessions/start` | A, FM, DP, DR | body `StartDrivingSessionRequest` | `DrivingSessionResponse` | Bắt đầu phiên lái; mỗi tài xế chỉ có một phiên active/paused |
| `POST /driving-sessions/{id}/pause` | A, FM, DP, DR | path `id` | `DrivingSessionResponse` | Cộng phút active, chuyển `PAUSED` |
| `POST /driving-sessions/{id}/resume` | A, FM, DP, DR | path `id` | `DrivingSessionResponse` | Chuyển `ACTIVE` |
| `POST /driving-sessions/{id}/finish` | A, FM, DP, DR | path `id` | `DrivingSessionResponse` | Kết thúc, cập nhật work log và snapshot tài xế |
| `GET /driving-sessions/drivers/{driverId}/remaining-time` | A, FM, DP, SO, DR | path `driverId` | `RemainingDrivingTimeResponse` | Tính phút còn lại; có thể sinh event quá giờ |

### 6.12. Incidents/SOS — 9 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /incidents/sos` | A, FM, DP, DR | body `SosRequest` | `IncidentResponse` | Tạo SOS, timeline, notification, WebSocket |
| `POST /incidents` | A, FM, DP, SO | body `CreateIncidentRequest` | `IncidentResponse` | Tạo sự cố thủ công |
| `GET /incidents` | A, FM, DP, SO, RT | `type?`, `severity?`, `status?`, `vehicleId?`, `driverId?`, pageable | `Page<IncidentResponse>` | Lọc sự cố |
| `GET /incidents/{id}` | A, FM, DP, SO, RT | path `id` | `IncidentResponse` | Chi tiết sự cố |
| `POST /incidents/{id}/accept` | A, DP, RT | path `id` | `IncidentResponse` | Chuyển `ACCEPTED` |
| `POST /incidents/{id}/assign` | A, DP | body `AssignIncidentRequest` | `IncidentResponse` | Gán user cứu hộ, chuyển `PROCESSING` |
| `POST /incidents/{id}/timeline` | A, DP, SO, RT | body `IncidentTimelineRequest` | `IncidentTimelineResponse` | Thêm mốc xử lý |
| `GET /incidents/{id}/timeline` | A, FM, DP, SO, RT | path `id` | `List<IncidentTimelineResponse>` | Đọc timeline |
| `POST /incidents/{id}/close` | A, DP, RT | body `IncidentTimelineRequest` | `IncidentResponse` | Chuyển `CLOSED`, đặt `resolvedAt` |

### 6.13. Flood reports — 7 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /flood-reports` | A, FM, DP, DR | body `CreateFloodReportRequest` | `FloodReportResponse` | Báo điểm ngập |
| `GET /flood-reports` | A, FM, DP, SO | `severity?`, `source?`, `status?`, pageable | `Page<FloodReportResponse>` | Danh sách điểm ngập |
| `GET /flood-reports/map` | A, FM, DP, SO | Không | `List<FloodReportResponse>` | Chỉ `UNVERIFIED`, `VERIFIED` |
| `POST /flood-reports/{id}/verify` | A, FM, DP | body `FloodActionRequest?` | `FloodReportResponse` | Xác minh và tăng confidence |
| `POST /flood-reports/{id}/resolve` | A, FM, DP | body `FloodActionRequest?` | `FloodReportResponse` | Đánh dấu hết ngập |
| `POST /flood-reports/route-check` | A, FM, DP, SO, DR | body `RouteCheckRequest` | `RouteRiskSummaryResponse` | Kiểm tra điểm route cách điểm ngập tối đa 0,5 km |
| `POST /flood-reports/route-risk-summary` | A, FM, DP, SO, DR | body `RouteCheckRequest` | `RouteRiskSummaryResponse` | Alias cùng logic `route-check` |

### 6.14. Maintenance — 7 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `POST /maintenance-orders` | A, FM | body `CreateMaintenanceOrderRequest` | `MaintenanceOrderResponse` | Tạo phiếu bảo trì |
| `GET /maintenance-orders` | A, FM, DP | `vehicleId?`, `status?`, `from?`, `to?`, pageable | `Page<MaintenanceOrderResponse>` | Lọc phiếu |
| `GET /maintenance-orders/{id}` | A, FM, DP | path `id` | `MaintenanceOrderResponse` | Chi tiết |
| `PUT /maintenance-orders/{id}` | A, FM | body `UpdateMaintenanceOrderRequest` | `MaintenanceOrderResponse` | Cập nhật |
| `DELETE /maintenance-orders/{id}` | A, FM | path `id` | `null` | Soft-delete |
| `GET /maintenance-orders/due-alerts` | A, FM, DP | Không | `List<MaintenanceOrderResponse>` | Việc OPEN/SCHEDULED/IN_PROGRESS đến hạn trong 7 ngày |
| `GET /maintenance-orders/document-expiry-alerts` | A, FM, DP | Không | `List<DocumentExpiryAlertResponse>` | Đăng kiểm/bảo hiểm còn <= 30 ngày, gồm cả đã quá hạn |

### 6.15. Notifications — 3 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /notifications` | Any | pageable | `Page<NotificationResponse>` | Thông báo global và của user |
| `PATCH /notifications/{id}/read` | Any | path `id` | `NotificationResponse` | Đánh dấu đã đọc |
| `PATCH /notifications/read-all` | Any | Không | `null` | Đánh dấu tất cả thông báo nhìn thấy |

### 6.16. Dashboard và reports — 9 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /dashboard/summary` | A, FM, DP, SO | Không | `DashboardSummaryResponse` | Tổng số và map theo trạng thái |
| `GET /reports/vehicles/status` | A, FM, DP, SO | Không | `Map<String,Long>` | Số xe theo mọi `VehicleStatus` |
| `GET /reports/safety-events/by-type` | A, FM, DP, SO | Không | `Map<String,Long>` | Số cảnh báo theo loại |
| `GET /reports/trips/by-day` | A, FM, DP | `from?`, `to?`; mặc định 7 ngày | `List<DailyTripCountResponse>` | Số chuyến theo ngày planned |
| `GET /reports/drivers/high-risk` | A, FM, SO | Không | `List<DriverResponse>` | Top 10 safety score thấp |
| `GET /reports/drivers/{id}` | A, FM, SO | path `id` | `DriverReport` | Driver + totalTrips + totalSafetyEvents + safetyScore |
| `GET /reports/vehicles/{id}` | A, FM, SO | path `id` | `VehicleReport` | Vehicle + totalTrips + totalSafetyEvents + lastSpeed |
| `GET /reports/flood` | A, FM, DP, SO | Không | `{bySeverity,byStatus}` | Thống kê điểm ngập |
| `GET /reports/incidents` | A, FM, DP, SO, RT | Không | `{byType,byStatus}` | Thống kê sự cố |

### 6.17. System settings — 4 API

| Method và path | Quyền | Input | Output | Mục đích |
|---|---|---|---|---|
| `GET /settings` | A, FM | Không | `List<SystemSettingResponse>` | Tất cả cấu hình |
| `GET /settings/{key}` | A, FM | path `key` | `SystemSettingResponse` | Cấu hình theo key |
| `PUT /settings/{key}` | A | path `key`, body `UpdateSystemSettingRequest` | `SystemSettingResponse` | Update hoặc tạo key mới |
| `GET /settings/groups/{group}` | A, FM | path enum `group` | `List<SystemSettingResponse>` | Lấy theo nhóm |

### 6.18. Mobile Driver App facade — 28 API

Tất cả endpoint dưới đây chỉ cho role `DRIVER`. Backend lấy user/driver hiện tại từ JWT ở nhiều luồng để giới hạn dữ liệu.

| Method và path | Input | Output | Mục đích/ghi chú |
|---|---|---|---|
| `GET /mobile/me` | Không | `MobileProfileResponse` | User + hồ sơ driver |
| `GET /mobile/safety-summary` | Không | `MobileSafetySummaryResponse` | Điểm an toàn và phút lái |
| `GET /mobile/config` | Không | `MobileConfigResponse` | Rule runtime cho app |
| `GET /mobile/current-assignment` | Không | `MobileCurrentAssignmentResponse` | Chuyến active sớm nhất hoặc `trip:null` |
| `GET /mobile/trips/today` | Không | `List<TripResponse>` | Chuyến có plannedStartTime trong hôm nay |
| `GET /mobile/trips/{id}` | path `id` | `TripResponse` | Chỉ chuyến của tài xế |
| `GET /mobile/trips/{id}/summary` | path `id` | `MobileTripSummaryResponse` | Trip + checklist + nextAction |
| `POST /mobile/trips/{id}/pre-trip-checklist` | body `MobilePreTripChecklistRequest` | `MobilePreTripChecklistResponse` | `passed=true` khi cả 7 mục đều true |
| `POST /mobile/trips/{id}/accept` | body `TripActionRequest?` | `TripResponse` | Nhận chuyến |
| `POST /mobile/trips/{id}/start` | body `TripActionRequest?` | `TripResponse` | Bắt đầu chuyến |
| `POST /mobile/trips/{id}/pause` | body `TripActionRequest?` | `TripResponse` | Tạm nghỉ |
| `POST /mobile/trips/{id}/resume` | body `TripActionRequest?` | `TripResponse` | Tiếp tục |
| `POST /mobile/trips/{id}/complete` | body `TripActionRequest?` | `TripResponse` | Hoàn thành |
| `POST /mobile/telemetry` | body `TelemetryRequest` | `TelemetryResponse` | Gửi GPS; `driverId` phải là chính mình |
| `GET /mobile/safety-events/today` | pageable | `Page<SafetyEventResponse>` | Cảnh báo hôm nay của tài xế |
| `POST /mobile/safety-events` | body `CreateSafetyEventRequest` | `SafetyEventResponse` | Gửi cảnh báo AI; `driverId` phải là chính mình |
| `POST /mobile/incidents/sos` | body `SosRequest` | `IncidentResponse` | Backend ép/kiểm tra driver hiện tại |
| `GET /mobile/incidents` | `status?`, pageable | `Page<IncidentResponse>` | Sự cố của tài xế |
| `GET /mobile/incidents/{id}` | path `id` | `IncidentResponse` | Có kiểm tra sở hữu |
| `POST /mobile/flood-reports` | body `CreateFloodReportRequest` | `FloodReportResponse` | Nếu gửi driverId thì phải là chính mình |
| `POST /mobile/flood-reports/quick` | body `MobileQuickFloodReportRequest` | `FloodReportResponse` | Khuyên dùng; backend tự gắn driver/source |
| `GET /mobile/flood-points/nearby` | `lat`, `lng`, `radiusKm?` | `List<FloodReportResponse>` | Mặc định 3 km; clamp 0,1–20 km |
| `POST /mobile/route-check` | body `RouteCheckRequest` | `RouteRiskSummaryResponse` | Kiểm tra rủi ro ngập |
| `POST /mobile/agent/command` | body `MobileAgentCommandRequest` | `MobileAgentCommandResponse` | Phân loại từ khóa SOS/ngập/nghỉ |
| `GET /mobile/agent/history` | pageable | `Page<MobileAgentCommandResponse>` | Lịch sử lệnh của user |
| `GET /mobile/notifications` | pageable | `Page<NotificationResponse>` | Thông báo của user/global |
| `PATCH /mobile/notifications/{id}/read` | path `id` | `NotificationResponse` | Đánh dấu đọc |
| `PATCH /mobile/notifications/read-all` | Không | `null` | Đọc tất cả |

## 7. Định nghĩa input DTO

Ký hiệu: `!` bắt buộc; `?` tùy chọn. Chuỗi có giới hạn được ghi `max`.

### 7.1. Auth/account

| DTO | Trường |
|---|---|
| `LoginRequest` | `usernameOrEmail!: string`, `password!: string` |
| `CreateUserRequest` | `username!: string(max80)`, `email!: email(max120)`, `password!: string(6..100)`, `fullName!: string(max150)`, `phone?: string(max20)`, `role!: RoleName` |
| `CreateDriverAccountRequest` | như user + `phone!`, `address?`, `licenseNumber!`, `licenseClass!`, `licenseExpiredAt!: date` |
| `UpdateAccountStatusRequest` | `status!: AccountStatus` |

### 7.2. Vehicle/driver/device

| DTO | Trường |
|---|---|
| `CreateVehicleRequest` | `plateNumber!`, `vehicleType!`, `brand?`, `model?`, `year?`, `loadCapacity? >=0`, `seatCount? >=0`, `fuelType?`, `status?`, `currentDriverId?`, `gpsDeviceId?`, `cameraDeviceId?`, `inspectionExpiredAt?`, `insuranceExpiredAt?` |
| `UpdateVehicleRequest` | như create nhưng không có plate; `vehicleType!`, `status!` |
| `CreateDriverRequest` | `userId?`, `fullName!`, `phone!`, `email?`, `address?`, `licenseNumber!`, `licenseClass!`, `licenseExpiredAt!`, `status?`, `currentVehicleId?` |
| `UpdateDriverRequest` | `fullName!`, `phone!`, `email?`, `address?`, `licenseClass!`, `licenseExpiredAt!`, `status!`, `currentVehicleId?` |
| `CreateDeviceRequest` | `deviceCode!`, `name!`, `type!`, `status?`, `vehicleId?`, `phone?`, `serialNumber?`, `firmwareVersion?` |
| `UpdateDeviceRequest` | `name!`, `type!`, `status!`, `vehicleId?`, `phone?`, `serialNumber?`, `firmwareVersion?` |
| `AssignDeviceVehicleRequest` | `vehicleId!` |
| `UpdateDeviceStatusRequest` | `status!`, `lat?`, `lng?`, `note?: string(max255)` |

### 7.3. Trip/telemetry/driving

| DTO | Trường |
|---|---|
| `CreateTripRequest` | `vehicleId?`, `driverId?`, `startLocation!`, `startLat?`, `startLng?`, `endLocation!`, `endLat?`, `endLng?`, `waypoints?: string`, `plannedRoute?: string`, `plannedStartTime?: datetime`, `estimatedEndTime?: datetime`, `riskLevel?` |
| `AssignTripRequest` | `vehicleId!`, `driverId!` |
| `TripActionRequest` | `note?: string(max500)` |
| `CancelTripRequest` | `reason!: string(max255)` |
| `TelemetryRequest` | `vehicleId!`, `driverId?`, `tripId?`, `lat!`, `lng!`, `speed?`, `heading?`, `batteryLevel?`, `gpsStatus?`, `createdAt?: datetime` |
| `StartDrivingSessionRequest` | `driverId!`, `vehicleId?`, `tripId?` |
| `MobilePreTripChecklistRequest` | 7 boolean: `exteriorChecked`, `tiresChecked`, `brakeChecked`, `lightsChecked`, `cameraChecked`, `gpsChecked`, `documentsChecked`; `note?` |

### 7.4. Safety/SOS/flood

| DTO | Trường |
|---|---|
| `CreateSafetyEventRequest` | `eventType!`, `severity!`, `vehicleId?`, `driverId?`, `tripId?`, `lat?`, `lng?`, `speed?`, `confidence? 0..1`, `evidenceUrl?`, `createdAt?`, `note?` |
| `SafetyEventActionRequest` | `note?: string(max500)` |
| `SosRequest` | `vehicleId?`, `driverId?`, `tripId?`, `lat!`, `lng!`, `severity?` (mặc định CRITICAL), `description?` |
| `CreateIncidentRequest` | `type!`, `severity!`, `vehicleId?`, `driverId?`, `tripId?`, `lat?`, `lng?`, `description?` |
| `AssignIncidentRequest` | `rescueUserId!`, `note?` |
| `IncidentTimelineRequest` | `action!: string(max80)`, `note?: string(max500)` |
| `CreateFloodReportRequest` | `lat!`, `lng!`, `address?`, `severity!`, `source!`, `reportedByDriverId?`, `imageUrl?` |
| `MobileQuickFloodReportRequest` | `lat!`, `lng!`, `address?`, `severity!`, `imageUrl?` |
| `FloodActionRequest` | `note?: string(max500)`; service hiện không lưu note này |
| `RouteCheckRequest` | `points!: non-empty List<RoutePointRequest>` |
| `RoutePointRequest` | `lat!`, `lng!` |

### 7.5. Location/maintenance/settings/agent

| DTO | Trường |
|---|---|
| `RouteRequest` | `startLat!`, `startLng!`, `endLat!`, `endLng!` |
| `CreateMaintenanceOrderRequest` | `vehicleId!`, `type!`, `title!`, `description?`, `scheduledDate?`, `completedDate?`, `cost?`, `status?`, `priority?`, `assignedTo?`, `note?` |
| `UpdateMaintenanceOrderRequest` | như create; `status!`, `priority!` |
| `UpdateSystemSettingRequest` | `group!`, `value!: string`, `valueType!`, `description?` |
| `MobileAgentCommandRequest` | `commandType?` (mặc định TEXT), `tripId?`, `transcript!: string(max1000)` |

## 8. Định nghĩa output DTO

### 8.1. User và mobile profile

| DTO | Trường `data` |
|---|---|
| `AuthResponse` | `accessToken`, `tokenType`, `userId`, `driverId`, `username`, `email`, `fullName`, `role` |
| `CurrentUserResponse` | `userId`, `driverId`, `username`, `email`, `fullName`, `status`, `role` |
| `UserResponse` | `id`, `username`, `email`, `fullName`, `phone`, `status`, `role`, `createdAt` |
| `MobileProfileResponse` | `userId`, `username`, `email`, `fullName`, `phone`, `role`, `driver: DriverResponse` |
| `MobileSafetySummaryResponse` | `driverId`, `status`, `safetyScore`, `drivingTimeTodayMinutes`, `continuousDrivingMinutes`, `remainingContinuousDrivingMinutes`, `totalTrips`, `totalAlerts` |
| `MobileConfigResponse` | `maxContinuousDrivingMinutes`, `warningLevel1Minutes`, `warningLevel2Minutes`, `criticalWarningMinutes`, `phoneUsageSpeedThresholdKmh`, `phoneUsageDurationThresholdSeconds`, `floodReportExpirationMinutes` |

### 8.2. Fleet và trip

| DTO | Trường `data` |
|---|---|
| `VehicleResponse` | `id`, `plateNumber`, `vehicleType`, `brand`, `model`, `year`, `loadCapacity`, `seatCount`, `fuelType`, `status`, `currentDriverId/name`, `gpsDeviceId/code`, `cameraDeviceId/code`, `inspectionExpiredAt`, `insuranceExpiredAt`, `lastLat`, `lastLng`, `lastSpeed`, `lastUpdatedAt` |
| `VehicleRealtimeStatusResponse` | `vehicleId`, `plateNumber`, `status`, `lat`, `lng`, `speed`, `lastUpdatedAt`, `gpsOnline` |
| `DriverResponse` | `id`, `userId`, `fullName`, `phone`, `email`, `address`, `licenseNumber`, `licenseClass`, `licenseExpiredAt`, `status`, `currentVehicleId/plate`, `safetyScore`, `drivingTimeTodayMinutes`, `continuousDrivingMinutes`, `totalTrips`, `totalAlerts` |
| `DrivingTimeTodayResponse` | `driverId`, `drivingTimeTodayMinutes`, `continuousDrivingMinutes`, `remainingContinuousDrivingMinutes` |
| `DeviceResponse` | `id`, `deviceCode`, `name`, `type`, `status`, `vehicleId`, `vehiclePlateNumber`, `phone`, `serialNumber`, `firmwareVersion`, `lastSeenAt` |
| `DeviceConnectionLogResponse` | `id`, `deviceId`, `status`, `lat`, `lng`, `note`, `createdAt` |
| `TripResponse` | `id`, `tripCode`, vehicle/driver id+name, điểm đầu/cuối+tọa độ, `waypoints`, `plannedRoute`, `actualRoute`, các mốc thời gian, `status`, `progress`, `riskLevel` |
| `TripTimelineResponse` | `id`, `tripId`, `action`, `actorId`, `actorName`, `note`, `createdAt` |
| `MobileCurrentAssignmentResponse` | `trip: TripResponse|null`, `checklistSubmitted` |
| `MobileTripSummaryResponse` | `trip`, `checklistSubmitted`, `nextAction`: `ACCEPT`, `START`, `PAUSE_OR_COMPLETE`, `RESUME`, `NONE` |
| `MobilePreTripChecklistResponse` | ids trip/driver/vehicle, 7 boolean, `passed`, `note`, `createdAt` |

### 8.3. Telemetry, safety, incident, flood

| DTO | Trường `data` |
|---|---|
| `TelemetryResponse` | `id`, `vehicleId`, `vehiclePlateNumber`, `driverId`, `tripId`, `lat`, `lng`, `speed`, `heading`, `batteryLevel`, `gpsStatus`, `createdAt` |
| `SafetyEventResponse` | `id`, `eventType`, `severity`, vehicle/driver/trip, `lat`, `lng`, `speed`, `confidence`, `evidenceUrl`, `status`, handler id/name/time, `note`, `createdAt` |
| `DrivingSessionResponse` | `id`, `driverId`, `vehicleId`, `tripId`, `status`, `startedAt`, `pausedAt`, `resumedAt`, `endedAt`, `continuousMinutes`, `totalMinutes`, `overDrivingAlertCreated` |
| `RemainingDrivingTimeResponse` | `driverId`, `sessionId`, `status`, `maxContinuousMinutes`, `continuousDrivingMinutes`, `remainingMinutes`, `warningLevel` |
| `IncidentResponse` | `id`, `incidentCode`, `type`, `severity`, vehicle/driver/trip, `lat`, `lng`, `description`, `status`, assignee id/name, `createdAt`, `acceptedAt`, `resolvedAt` |
| `IncidentTimelineResponse` | `id`, `incidentId`, `action`, actor id/name, `note`, `createdAt` |
| `FloodReportResponse` | `id`, `lat`, `lng`, `address`, `severity`, `source`, reporter id/name, `imageUrl`, `confidence`, `status`, `verifiedBy`, `verifiedAt`, `expiredAt`, `createdAt` |
| `RouteRiskSummaryResponse` | `risky`, `highestSeverity`, `matchedFloodPoints`, `matchedReports` |

### 8.4. Khác

| DTO | Trường `data` |
|---|---|
| `DispatchSuggestionResponse` | `vehicleId`, `plateNumber`, `driverId`, `driverName`, `score`, `distanceKm`, `reasons[]` |
| `AvailabilityResponse` | `vehicleId`, `vehicleAvailable`, `driverId`, `driverAvailable`, `assignable`, `reasons[]` |
| `LocationSuggestionResponse` | `id`, `name`, `address`, `lat`, `lng`, `source` (`PHOTON`/`LOCAL`) |
| `RouteResponse` | `distanceKm`, `durationMinutes`, `coordinates`, `provider`, `fallback`, `message` |
| `MaintenanceOrderResponse` | id/code, vehicle id/plate, type/title/description/dates/cost/status/priority, assignee id/name, note |
| `DocumentExpiryAlertResponse` | `vehicleId`, `plateNumber`, `documentType`, `expiredAt`, `daysRemaining` |
| `NotificationResponse` | `id`, `type`, `title`, `content`, `referenceType`, `referenceId`, `read`, `createdAt` |
| `SystemSettingResponse` | `id`, `key`, `group`, `value`, `valueType`, `description`, `updatedBy`, `updatedAt` |
| `DashboardSummaryResponse` | tổng xe/tài xế/chuyến, ba map theo status, `openSafetyEvents`, `openIncidents` |
| `DailyTripCountResponse` | `date`, `totalTrips` |
| `MobileAgentCommandResponse` | `id`, `commandType`, `tripId`, `transcript`, `normalizedCommand`, `status`, `responseText`, `createdAt` |

## 9. Enum bắt buộc dùng đúng chữ hoa

| Enum | Giá trị |
|---|---|
| `RoleName` | `ADMIN`, `FLEET_MANAGER`, `DISPATCHER`, `SAFETY_OFFICER`, `RESCUE_TEAM`, `DRIVER` |
| `AccountStatus` | `ACTIVE`, `LOCKED`, `DISABLED`, `PENDING` |
| `VehicleType` | `TRUCK`, `VAN`, `BUS`, `CAR`, `PICKUP`, `MOTORBIKE` |
| `VehicleStatus` | `AVAILABLE`, `RUNNING`, `RESTING`, `MAINTENANCE`, `OFFLINE`, `INACTIVE` |
| `FuelType` | `DIESEL`, `GASOLINE`, `ELECTRIC`, `HYBRID` |
| `DriverStatus` | `AVAILABLE`, `DRIVING`, `RESTING`, `SUSPENDED`, `HIGH_RISK`, `INACTIVE` |
| `DeviceType` | `GPS_TRACKER`, `CABIN_CAMERA`, `DASH_CAMERA`, `DRIVER_PHONE`, `IOT_FLOOD_SENSOR` |
| `DeviceStatus` | `ONLINE`, `OFFLINE`, `MAINTENANCE`, `INACTIVE` |
| `TripStatus` | `DRAFT`, `ASSIGNED`, `ACCEPTED`, `IN_PROGRESS`, `RESTING`, `COMPLETED`, `DELAYED`, `INCIDENT`, `CANCELLED` |
| `RiskLevel` | `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` |
| `GpsStatus` | `GOOD`, `WEAK`, `LOST`, `OFFLINE` |
| `SafetyEventType` | `DROWSINESS`, `PHONE_USAGE`, `DISTRACTION`, `SPEEDING`, `OVER_DRIVING_TIME`, `ROUTE_DEVIATION`, `ABNORMAL_STOP`, `GPS_LOST`, `FLOOD_RISK` |
| `SafetyEventStatus` | `NEW`, `ACKNOWLEDGED`, `PROCESSING`, `RESOLVED`, `DISMISSED` |
| `AlertSeverity` | `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` |
| `DrivingSessionStatus` | `ACTIVE`, `PAUSED`, `FINISHED` |
| `IncidentType` | `SOS`, `ACCIDENT`, `VEHICLE_BREAKDOWN`, `DRIVER_UNRESPONSIVE`, `FLOOD_STUCK`, `GPS_LOST`, `MANUAL` |
| `IncidentStatus` | `OPEN`, `ACCEPTED`, `PROCESSING`, `ESCALATED`, `RESOLVED`, `CLOSED`, `CANCELLED` |
| `FloodSeverity` | `NONE`, `LOW`, `MEDIUM`, `HIGH`, `BLOCKED` |
| `FloodSource` | `DRIVER_REPORT`, `IOT_SENSOR`, `TRAFFIC_CAMERA`, `WEATHER`, `MANUAL` |
| `FloodStatus` | `UNVERIFIED`, `VERIFIED`, `EXPIRED`, `REJECTED`, `RESOLVED` |
| `MaintenanceType` | `PERIODIC`, `REPAIR`, `INSPECTION`, `INSURANCE`, `EMERGENCY` |
| `MaintenanceStatus` | `OPEN`, `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `MaintenancePriority` | `LOW`, `MEDIUM`, `HIGH`, `URGENT` |
| `NotificationType` | `AI_ALERT`, `SOS`, `FLOOD`, `GPS_LOST`, `DRIVING_TIME`, `TRIP_DELAYED`, `MAINTENANCE`, `SYSTEM` |
| `SettingGroup` | `DRIVING_TIME`, `AI_ALERT`, `SOS_ESCALATION`, `MAP`, `FLOOD`, `NOTIFICATION`, `SYSTEM` |
| `SettingValueType` | `STRING`, `INTEGER`, `DECIMAL`, `BOOLEAN`, `JSON` |
| `AgentCommandType` | `TEXT`, `VOICE` |
| `AgentCommandStatus` | `RECEIVED`, `UNDERSTOOD`, `UNSUPPORTED`, `FAILED` |

## 10. WebSocket/STOMP

### 10.1. Kết nối

```text
ws://<host>:8080/ws
```

Endpoint có SockJS. Broker prefix: `/topic`, `/queue`; app destination prefix: `/app`.

### 10.2. Topic

| Topic | Payload | Khi phát |
|---|---|---|
| `/topic/vehicles/positions` | `VehicleRealtimeStatusResponse` | Mỗi telemetry mới |
| `/topic/vehicles/{vehicleId}/position` | `VehicleRealtimeStatusResponse` | Telemetry của một xe |
| `/topic/safety-events` | `SafetyEventResponse` | Cảnh báo mới |
| `/topic/incidents` | `IncidentResponse` | Incident/SOS mới |
| `/topic/notifications` | `NotificationResponse` | Notification mới |
| `/topic/flood-reports` | `FloodReportResponse` | Tạo/xác minh/resolve điểm ngập |

Hiện `/ws/**` public và `setAllowedOriginPatterns("*")`; chưa có authorization theo topic. Không nên gửi dữ liệu nhạy cảm lên topic trước khi bổ sung xác thực WebSocket.

## 11. Rule nghiệp vụ quan trọng cho app

### 11.1. Vòng đời chuyến

```text
DRAFT/CANCELLED --assign--> ASSIGNED --accept--> ACCEPTED
ASSIGNED/ACCEPTED --start--> IN_PROGRESS
IN_PROGRESS --pause--> RESTING --resume--> IN_PROGRESS
IN_PROGRESS/RESTING --complete--> COMPLETED
mọi trạng thái trừ COMPLETED --cancel--> CANCELLED
```

- Start đặt progress tối thiểu `5`, xe `RUNNING`, tài xế `DRIVING`.
- Pause đặt xe/tài xế `RESTING`.
- Complete đặt progress `100`, xe/tài xế `AVAILABLE`, tăng `driver.totalTrips`.
- App mobile hiện chưa bắt buộc checklist phải `passed` trước khi start; đây mới là dữ liệu tham khảo.

### 11.2. Điều kiện giao chuyến

Khi `TripService.assign/create`:

- Xe phải `AVAILABLE` hoặc `RESTING`.
- Đăng kiểm chưa hết hạn.
- Có GPS và GPS `ONLINE`.
- Tài xế `AVAILABLE` hoặc `RESTING`.
- `continuousDrivingMinutes < 210`.
- `safetyScore >= 50`.

API gợi ý dispatch chặt khác một chút: chỉ xe/tài xế `AVAILABLE`, driver score `>=60`. Điểm gợi ý = safety score + 10 nếu xe có last update − phút lái/10 − khoảng cách (tối đa trừ 30).

### 11.3. Safety score

- Event LOW trừ 1, MEDIUM trừ 3, HIGH trừ 7, CRITICAL trừ 12.
- Tăng `totalAlerts`.
- Score dưới 50 chuyển tài xế sang `HIGH_RISK`, trừ khi đang `SUSPENDED`.
- API “recalculate” dùng công thức khác: `100 - totalAlerts * 3`.

### 11.4. Giờ lái

Setting seed:

- Tối đa liên tục: 240 phút.
- Warning 1: 180.
- Warning 2: 210.
- Critical: 230.
- `remaining-time` trả `NORMAL`, `WARNING_1`, `WARNING_2`, `CRITICAL`, `OVER_LIMIT`.
- Chỉ khi gọi `remaining-time` và đã vượt giới hạn thì backend mới tạo event `OVER_DRIVING_TIME`; không có scheduler nền trong mã hiện tại.

### 11.5. Điểm ngập

- Báo cáo hết hạn mặc định sau 180 phút nhưng mã hiện chưa có scheduler tự chuyển `EXPIRED`; API map vẫn dựa vào status.
- Confidence gốc theo source: driver 0,45; IoT 0,65; camera 0,60; weather 0,50; manual 0,70.
- Cộng tối đa 0,30 theo số báo cáo lân cận trong 0,3 km; xác minh cộng 0,20; tối đa 0,99.
- Route risk chỉ xét điểm `MEDIUM` trở lên và khoảng cách <= 0,5 km tới ít nhất một route point.
- App phải gửi đủ polyline point; chỉ gửi điểm đầu/cuối có thể bỏ sót ngập giữa tuyến.

### 11.6. Agent command

- Chuẩn hóa lowercase tiếng Việt.
- Chứa `sos/cứu hộ/cuu ho`: trả lời yêu cầu xác nhận SOS.
- Chứa `ngập/ngap/lụt/lut`: yêu cầu gửi route.
- Chứa `nghỉ/nghi/dừng/dung`: hướng dẫn pause.
- Khác: `UNSUPPORTED`.
- Không tự gọi API SOS/pause/route; app phải hiển thị bước xác nhận rồi gọi API tương ứng.

## 12. Mô hình dữ liệu

Các bảng chính:

- RBAC: `users`, `roles`, `permissions`, `role_permissions`.
- Đội xe: `drivers`, `vehicles`, `devices`, `device_connection_logs`.
- Chuyến: `trips`, `trip_timelines`, `telemetry_logs`.
- An toàn: `safety_events`, `driving_sessions`, `driver_work_logs`.
- Sự cố: `incidents`, `incident_timelines`.
- Ngập: `flood_reports`.
- Bảo trì: `maintenance_orders`.
- Hệ thống: `notifications`, `system_settings`, `audit_logs`.
- Mobile V3: `pre_trip_checklists`, `agent_commands`.

Quan hệ chính:

```text
User 1---0..1 Driver
Role 1---n User
Vehicle 0..1---0..1 current Driver
Vehicle 1---n Device/Telemetry/Trip/SafetyEvent/Incident/Maintenance
Driver 1---n Trip/Telemetry/SafetyEvent/DrivingSession/Incident/FloodReport
Trip 1---n Timeline/Telemetry/SafetyEvent/Incident/Checklist/AgentCommand
Incident 1---n IncidentTimeline
```

`audit_logs` đã có schema nhưng chưa thấy service/controller ghi audit trong mã hiện tại.

## 13. Các màn hình web hiện có

| Route | Chức năng |
|---|---|
| `/login` | Login JWT |
| `/command-center` | KPI, ưu tiên cảnh báo/SOS, chuyến đang chạy |
| `/realtime-map` | Bản đồ xe, điểm ngập, sự cố |
| `/dispatch` | Chọn điểm thật, tính route, gợi ý xe-tài xế, tạo chuyến |
| `/trips` | Danh sách/trạng thái chuyến |
| `/vehicles` | Danh sách và chi tiết xe |
| `/drivers` | Danh sách, điểm an toàn, giờ lái |
| `/alerts` | Feed cảnh báo, acknowledge/resolve |
| `/incidents` | Phòng xử lý SOS, timeline, accept/close |
| `/flood-map` | Map điểm ngập, verify/resolve |
| `/reports` | Biểu đồ cảnh báo và chuyến |
| `/accounts` | Danh sách, đổi trạng thái tài khoản |
| `/settings` | Cấu hình runtime |

Metadata frontend có nhắc `/devices`, `/maintenance`, `/permissions`, nhưng hiện không có page tương ứng trong source app router/sidebar.

## 14. Luồng tích hợp app tài xế đề xuất

### 14.1. Khởi động/session

1. Login, lưu `accessToken`, `driverId`, user.
2. Gọi `/auth/me` hoặc `/mobile/me` để xác thực session.
3. Gọi song song:
   - `/mobile/config`
   - `/mobile/safety-summary`
   - `/mobile/current-assignment`
   - `/mobile/notifications?page=0&size=20&sort=createdAt,desc`
4. Nếu nhận 401: xóa local token và về login. Vì chưa có refresh token, không thể refresh im lặng.

### 14.2. Chuyến

1. `/mobile/trips/today`.
2. `/mobile/trips/{id}/summary`.
3. Accept.
4. Gửi checklist.
5. Start trip.
6. Nên đồng thời start driving session bằng API core; facade mobile chưa bọc driving session.
7. Gửi telemetry định kỳ.
8. Pause/resume cả trip và driving session để hai state machine đồng bộ.
9. Complete trip và finish driving session.

Lưu ý: `TripService` và `DrivingTimeService` là hai state machine riêng; gọi một bên không tự gọi bên còn lại.

### 14.3. GPS

Payload khuyên dùng:

```json
{
  "vehicleId": 1,
  "driverId": 1,
  "tripId": 10,
  "lat": 21.0285,
  "lng": 105.8542,
  "speed": 42.5,
  "heading": 90.0,
  "batteryLevel": 88,
  "gpsStatus": "GOOD",
  "createdAt": "2026-07-26T10:30:00"
}
```

Nên queue local khi mất mạng, giữ `createdAt` lúc đo và retry theo batch tuần tự. Backend hiện nhận từng bản ghi, chưa có batch endpoint hay idempotency key.

### 14.4. SOS

```json
{
  "vehicleId": 1,
  "driverId": 1,
  "tripId": 10,
  "lat": 21.0285,
  "lng": 105.8542,
  "severity": "CRITICAL",
  "description": "Tài xế nhấn SOS"
}
```

Sau thành công, lưu `incident.id`, hiển thị trạng thái và polling `/mobile/incidents/{id}` hoặc dùng WebSocket. Hiện backend không có endpoint mobile đọc timeline incident.

### 14.5. Báo ngập

Khuyên dùng `/mobile/flood-reports/quick` vì backend tự gắn `DRIVER_REPORT` và driver theo JWT.

```json
{
  "lat": 21.0285,
  "lng": 105.8542,
  "address": "Phạm Văn Đồng, Hà Nội",
  "severity": "HIGH",
  "imageUrl": "https://cdn.example.com/flood/abc.jpg"
}
```

Backend chỉ nhận URL ảnh, không có upload file. App cần upload ảnh sang storage riêng trước.

## 15. Khoảng trống và rủi ro cần xử lý trước production

### Ưu tiên cao

1. Secret JWT và mật khẩu DB có giá trị mặc định trong source; phải đưa sang secret manager/env.
2. Chưa có HTTPS, refresh token, revoke/logout server-side.
3. WebSocket public, wildcard origin, chưa kiểm soát subscribe topic.
4. `NotificationService.markRead(id)` không kiểm tra notification có thuộc/hiển thị cho user hiện tại; người dùng biết id có thể đánh dấu bản ghi khác.
5. `MobileController` cho gửi `TelemetryRequest`/`CreateSafetyEventRequest` chứa `vehicleId`, `tripId`; service chỉ kiểm tra `driverId` thuộc user, chưa kiểm tra vehicle/trip thực sự gắn với driver ở mọi trường hợp.
6. `MobileAppService.createFloodReport` dùng DTO tổng quát; nên dùng endpoint `quick` để backend không tin `source`.
7. Không có idempotency cho SOS, event, telemetry, checklist, flood; retry có thể tạo bản ghi trùng.

### Ưu tiên trung bình

1. Mobile chưa có facade cho driving session, location, telemetry history, incident timeline.
2. Trip và driving session không tự đồng bộ.
3. Checklist không chặn start trip.
4. Không có scheduler tự expire flood, tự escalation SOS, tự cảnh báo giờ lái.
5. Rule `phoneUsageSpeedThresholdKmh=10` và `phoneUsageDurationThresholdSeconds=3` đang hard-code trong mobile config.
6. `FloodActionRequest.note` được nhận nhưng không được lưu.
7. Update setting kiểu JSON chỉ kiểm tra ký tự đầu `{`/`[`, không parse JSON thật.
8. Frontend quản trị chưa subscribe WebSocket.
9. Chưa có API upload ảnh/video evidence.
10. Không thấy rate limit, request correlation id, device authentication hay push notification FCM/APNs.

### Bất nhất cần biết khi viết client

- API trả create/delete bằng HTTP 200, không dùng 201/204.
- `waypoints` và route trong `TripResponse` là chuỗi JSON/text, không phải object chuẩn hóa.
- Route coordinates là `[lng,lat]`; route-check points lại là `{lat,lng}`.
- `confidence` backend là `0..1`; frontend web hiện có đoạn map trực tiếp sang phần trăm nhưng không nhân 100.
- `incident.close` yêu cầu `IncidentTimelineRequest.action` non-blank dù service có nhánh fallback nếu action null.
- Endpoint mobile `GET /mobile/trips/{id}` an toàn nhờ gọi `TripService.get`, nhưng ownership nên tiếp tục được test regression.

## 16. Checklist xây app

- [ ] Cấu hình base URL theo dev/staging/prod.
- [ ] Tạo interceptor gắn Bearer token.
- [ ] Parse unified `ApiResponse<T>` và `PageResponse<T>`.
- [ ] Xử lý 400/401/403/404/409 riêng.
- [ ] Sinh enum đúng chữ hoa.
- [ ] Dùng ISO local datetime thống nhất timezone.
- [ ] Tách state trip và driving session.
- [ ] Queue/retry telemetry và event khi offline.
- [ ] Chống gửi trùng SOS/flood/checklist ở phía app trong khi backend chưa idempotent.
- [ ] Upload evidence lên storage rồi gửi URL.
- [ ] Xin quyền location/background location/notification/camera phù hợp nền tảng.
- [ ] Dùng `/mobile/flood-reports/quick`.
- [ ] Xác nhận người dùng trước khi agent command kích hoạt SOS hoặc thay đổi trạng thái.
- [ ] Kiểm thử quyền bằng tài khoản DRIVER, không chỉ ADMIN.
- [ ] Đánh giá bảo mật WebSocket trước khi subscribe production.
- [ ] Bổ sung API còn thiếu hoặc thống nhất contract trước khi đóng băng phiên bản app.

## 17. Nguồn sự thật trong repository

Ưu tiên khi có khác biệt:

1. Controller + DTO + service trong `web_quan_ly/backend/src/main/java`.
2. Security config và global exception handler.
3. Migration SQL trong `web_quan_ly/backend/src/main/resources/db/migration`.
4. Test integration/controller.
5. `MOBILE_API_CONTRACT.md`.
6. Adapter frontend `web_quan_ly/frontend/lib/safeFleetApi.ts`.

Swagger runtime là cách nhanh nhất để xác nhận contract sau mỗi lần backend thay đổi:

```text
http://localhost:8080/swagger-ui.html
http://localhost:8080/v3/api-docs
```

## 18. Phụ lục Mobile V2 — cập nhật 2026-07-29

Các mục “khoảng trống” ở trên phản ánh thời điểm khảo sát ban đầu. Bản triển khai hiện
tại đã bổ sung dẫn đường độc lập, offline/idempotency cho luồng trọng yếu, Agent xác
nhận, hồ sơ, tổng quan tháng và AI service. Hai contract mới dành cho app:

### GET `/api/v1/mobile/activity/monthly?month=YYYY-MM`

Quyền: `DRIVER`. `month` không bắt buộc, mặc định tháng hiện tại theo timezone server.
Backend luôn lấy `driverId` từ JWT, client không được truyền tài xế khác.

Đầu ra trong `ApiResponse.data`:

```json
{
  "month": "2026-07",
  "safetyScore": 80,
  "totalTrips": 2,
  "completedTrips": 2,
  "drivingMinutes": 0,
  "restMinutes": 0,
  "alertCount": 3,
  "criticalAlertCount": 0,
  "days": [
    {
      "date": "2026-07-01",
      "trips": 0,
      "drivingMinutes": 0,
      "restMinutes": 0,
      "alerts": 0
    }
  ]
}
```

Dữ liệu nguồn: `trips`, `driver_work_logs`, `safety_events` trong MySQL thật.

### POST `/api/v1/mobile/agent/chat`

Quyền: `DRIVER`. Dùng cho hội thoại thông thường; không thực thi SOS, báo ngập hoặc
thay đổi trạng thái chuyến. Các hành động đó tiếp tục dùng `/mobile/agent/command` và
endpoint confirm riêng.

Đầu vào:

```json
{
  "messages": [
    {"role": "user", "content": "Tuyến nào ít ngập hơn?"},
    {"role": "assistant", "content": "Hãy mở Bản đồ để tôi dùng dữ liệu mới nhất."}
  ]
}
```

Ràng buộc: 1–20 messages, `role` chỉ `user|assistant`, content 1–4000 ký tự.

Đầu ra:

```json
{
  "responseText": "...",
  "model": "gpt-4o-mini",
  "source": "OPENAI"
}
```

Khi chưa cấu hình key, `source=LOCAL_FALLBACK`, `model=local-safe-fallback`; app vẫn
dùng được các lệnh an toàn cốt lõi. `OPENAI_API_KEY` chỉ đặt tại AI service, không đặt
trong Flutter. Request OpenAI dùng `store=false`.

### Luồng bản đồ tránh ngập mobile

1. `GET /mobile/locations/autocomplete?query=...&limit=6`.
2. `GET /mobile/flood-points/nearby?lat=...&lng=...&radiusKm=20`.
3. `POST /mobile/navigation/routes` với tọa độ đầu/cuối.
4. Backend lấy các route OSRM, chấm giao cắt/vùng đệm với flood points còn hiệu lực,
   chọn tuyến rủi ro thấp nhất và tạo navigation session trong MySQL.
5. Geometry trả theo GeoJSON `[lng, lat]`; Flutter phải đảo thành `LatLng(lat, lng)`.

Kiểm thử E2E gần nhất: origin Hồ Hoàn Kiếm → Mỹ Đình, 3 phương án, tuyến đề xuất
8,0 km/15 phút; báo cáo flood thật `id=12` làm nearby count tăng từ 0 lên 1 và app cập
nhật “1 điểm ngập đang hiển thị”.
