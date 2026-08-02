# Backend Mobile Implementation Plan

## Mục tiêu backend cho mobile app
- Bổ sung các API cần thiết để app tài xế SafeFleet Driver App dùng được backend hiện có.
- Dùng lại JWT hiện tại: `POST /api/v1/auth/login`, `GET /api/v1/auth/me`.
- Giữ nguyên API prefix `/api/v1`, WebSocket endpoint `/ws`, topic realtime hiện có.
- Không tạo database riêng cho mobile, không cho mobile kết nối trực tiếp MySQL.

## Cấu trúc backend đã phát hiện
- Project: `backend`, artifact `safefleet-backend`, package gốc `com.safefleet`.
- Kiến trúc package-by-feature:
  - `auth`, `account`, `driver`, `vehicle`, `trip`, `dispatch`
  - `telemetry`, `safety`, `incident`, `flood`, `notification`
  - `device`, `maintenance`, `report`, `settings`, `location`
  - `common`, `config`, `infrastructure`
- Database migration hiện có:
  - `V1__init_schema.sql`
  - `V2__seed_reference_data.sql`

## API hiện có có thể dùng lại
- Auth: `POST /api/v1/auth/login`, `GET /api/v1/auth/me`
- Trip: `/api/v1/trips`, lifecycle `accept/start/pause/resume/complete/cancel`, `timeline`
- Telemetry: `POST /api/v1/telemetry`, `GET /api/v1/telemetry/trips/{tripId}/history`
- Safety event: `POST /api/v1/safety-events`, list/detail/action APIs
- Driving session: `/api/v1/driving-sessions/start`, pause/resume/finish, remaining time
- Incident/SOS: `POST /api/v1/incidents/sos`
- Flood: `POST /api/v1/flood-reports`, `/map`, `/route-check`
- Notification: `GET /api/v1/notifications`, `PATCH /{id}/read`, `PATCH /read-all`
- Settings: `GET /api/v1/settings`

## API còn thiếu cần bổ sung
- Mobile profile facade: thông tin tài xế hiện tại, safety summary, current assignment.
- Today trips facade: danh sách chuyến trong ngày của tài xế hiện tại.
- Pre-trip checklist: app cần gửi checklist trước chuyến.
- Mobile config: gom driving rules và ngưỡng mock AI cho app.
- Agent command: nhận text/voice transcript và lưu lịch sử lệnh trợ lý.
- Mobile nearby flood points: trả danh sách điểm ngập gần tọa độ hiện tại.

## Package/file dự kiến tạo mới
- `src/main/java/com/safefleet/mobile/controller/*`
- `src/main/java/com/safefleet/mobile/service/MobileAppService.java`
- `src/main/java/com/safefleet/mobile/dto/request/*`
- `src/main/java/com/safefleet/mobile/dto/response/*`
- `src/main/java/com/safefleet/mobile/entity/*`
- `src/main/java/com/safefleet/mobile/repository/*`
- `src/main/resources/db/migration/V3__add_mobile_driver_app_support.sql`

## File backend có thể cần sửa
- Chỉ sửa repository hiện có nếu thật sự cần query theo tài xế/ngày.
- Không sửa security/JWT trừ khi cần bổ sung rule access cho facade.

## Migration có cần tạo không
- Có. Tạo `V3__add_mobile_driver_app_support.sql`.
- Lý do: hiện chưa có bảng `pre_trip_checklists` và `agent_commands`.
- Không sửa `V1__init_schema.sql` hoặc `V2__seed_reference_data.sql`.

## Những phần không được động vào
- Không đổi `/api/v1`, `/ws`, các topic websocket.
- Không đổi JWT login flow.
- Không sửa web frontend.
- Không sửa mobile app.
- Không refactor service cũ diện rộng.
- Không đổi port backend.

## Rủi ro ảnh hưởng logic cũ
- Rủi ro thấp nếu mobile facade chỉ gọi lại service/repository hiện có.
- Cần bảo vệ quyền DRIVER: chỉ xem/gửi dữ liệu của chính tài xế hiện tại.
- Migration V3 chỉ thêm bảng mới, không thay bảng cũ.

## Cách kiểm tra backend sau khi code
- `mvn.cmd -q test`
- Nếu môi trường DB không sẵn sàng: `mvn.cmd -q -DskipTests package`
- Kiểm tra Swagger vẫn mở.
- Test login driver: `driver01 / 123456`.
- Test các API `/api/v1/mobile/*` với JWT DRIVER.
