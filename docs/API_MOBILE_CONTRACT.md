# SafeFleet Mobile API Contract

Nguồn đầy đủ và hiện hành:

- `BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md`: sinh lại từ runtime V7 ngày 27/07/2026, gồm 153 operation, 134 path và 167 schema. `/v3/api-docs` của bản đang chạy vẫn là nguồn máy đọc ưu tiên.
- `web_quan_ly/backend/MOBILE_API_CONTRACT.md`: facade mobile và ví dụ nghiệp vụ.
- `http://localhost:8080/v3/api-docs`: nguồn máy đọc.

## Quy ước bắt buộc

- Base URL: `/api/v1`.
- Gửi `Authorization: Bearer <accessToken>`.
- Lưu access/refresh token trong secure storage.
- Khi retry safety/SOS/flood/workflow/offline item, giữ nguyên `clientEventId`; không sinh ID mới.
- Không tin `driverId`, `vehicleId`, `tripId` từ client: server tự ràng buộc theo JWT và assignment hiện hành.
- Chỉ xóa item offline sau khi server trả ACK thành công.

## Endpoint app chính

| Chức năng | Endpoint |
|---|---|
| Login/refresh/logout | `POST /auth/login`, `/auth/refresh`, `/auth/logout` |
| Khởi động app | `GET /mobile/bootstrap` |
| Hồ sơ/assignment | `GET /mobile/me`, `/mobile/current-assignment` |
| Chuyến hôm nay/chi tiết | `GET /mobile/trips/today`, `/mobile/trips/{id}` |
| Workflow nguyên tử | `POST /mobile/trips/{id}/{start-workflow|pause-workflow|resume-workflow|complete-workflow}` |
| Telemetry | `POST /mobile/telemetry`, `/mobile/telemetry/batch` |
| Đồng bộ telemetry offline | `POST /mobile/telemetry/batch` với ACK từng item |
| Safety | `POST /mobile/safety-events`, `GET /mobile/safety-events/today` |
| SOS/timeline | `POST /mobile/incidents/sos`, `GET /mobile/incidents/{id}/timeline` |
| Evidence | `POST /mobile/evidence` multipart; `GET /evidence/{id}`, `/evidence/{id}/content` |
| Flood | `POST /mobile/flood-reports/quick`, `GET /mobile/flood-points/nearby` |
| Navigation | `POST /mobile/navigation/routes`, `/reroute`, `/events`; `GET /mobile/navigation/current` |
| Notification | `GET /mobile/notifications`; `PATCH /mobile/notifications/{id}/read` |
| Push | `POST /mobile/push-tokens`; `DELETE /mobile/push-tokens/{deviceUuid}` |
| Agent | `POST /mobile/agent/command`, `POST /mobile/agent/confirm`, `POST /mobile/agent/cancel`, `GET /mobile/agent/history` |

Lệnh agent có tác động trạng thái chỉ tạo yêu cầu chờ xác nhận. App phải hiển thị nội dung dự kiến và gọi `confirm` hoặc `cancel`; không được tự thực thi chỉ từ kết quả phân loại intent.

## Payload safety tối thiểu

```json
{
  "eventType": "PHONE_USAGE",
  "severity": "HIGH",
  "lat": 21.0285,
  "lng": 105.8542,
  "speed": 32.0,
  "confidence": 0.94,
  "note": "On-device alert",
  "clientEventId": "uuid-stable"
}
```

Hai lần gửi cùng `clientEventId` trả cùng `data.id`. Sự kiện cùng tài xế/loại trong cooldown 30 giây cũng được gộp.

## Workflow offline/idempotent

Mọi action workflow nhận body tùy chọn:

```json
{
  "note": "Thao tác từ hàng đợi offline",
  "clientEventId": "workflow-uuid-stable"
}
```

Retry cùng user, operation, trip và `clientEventId` trả lại response đã lưu, không tạo thêm trip timeline, driving session hoặc navigation session. Dùng cùng ID cho operation/trip khác bị từ chối `400`.

## Flood offline/idempotent

```json
{
  "lat": 21.0321,
  "lng": 105.8123,
  "address": "Điểm ngập do tài xế báo",
  "severity": "HIGH",
  "imageUrl": null,
  "clientEventId": "flood-uuid-stable"
}
```

Retry trả cùng `data.id`; `receivedAt` là thời điểm server nhận lần đầu.

## Payload SOS tối thiểu

```json
{
  "lat": 21.0285,
  "lng": 105.8542,
  "severity": "CRITICAL",
  "description": "Tài xế yêu cầu hỗ trợ",
  "clientEventId": "uuid-stable"
}
```

SOS giới hạn 3 request/phút/user. Agent command giới hạn 10 request/phút/user. Vượt giới hạn trả `429`.

## Evidence

`POST /mobile/evidence` dùng `multipart/form-data`:

- đúng một trong `safetyEventId` hoặc `incidentId`;
- `capturedAt` tùy chọn;
- `file` bắt buộc, JPEG/PNG/WebP, tối đa 8 MB.

Response không trả filesystem path; chỉ trả metadata, SHA-256 và `protectedContentUrl`. Tải file cần JWT và ownership, response có `Cache-Control: no-store`.

## STOMP

- Native: `ws://<host>:8080/ws-native`.
- SockJS: `/ws`.
- Frame `CONNECT` bắt buộc header `Authorization:Bearer <accessToken>`.
- Topic: `/topic/telemetry`, `/topic/safety-events`, `/topic/incidents`, `/topic/flood-reports`, `/topic/notifications`.
- Kết nối mất thì backoff và dùng REST polling 30 giây.
