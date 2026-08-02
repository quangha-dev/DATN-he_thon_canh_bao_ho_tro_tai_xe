# Ma trận yêu cầu và Definition of Done — SafeFleet

> Cập nhật: 27/07/2026. `PASS` có bằng chứng chạy; `PASS-FALLBACK` dùng phương án dự phòng được master prompt cho phép; `BLOCKED-EXTERNAL` cần credential/phần cứng/dataset ngoài repository.

## Ma trận tổng thể

| Nhóm | Trạng thái | Bằng chứng |
|---|---:|---|
| Cấu trúc repository | PASS | Giữ `web_quan_ly`; bổ sung `safe_fleet_driver_ui`, `safefleet_ai`, `docker`, `docs` |
| Docker full stack | PASS | MySQL/backend/frontend/AI/MinIO đều healthy; build và config PASS |
| MySQL/Flyway | PASS | MySQL 8.4 thật; V1–V7; `ddl-auto=validate`; 9 integration test |
| Auth/security | PASS | JWT access+refresh rotation+logout, BCrypt, RBAC, ownership, rate limit |
| WebSocket | PASS | JWT STOMP CONNECT → CONNECTED; anonymous → ERROR; origin cụ thể |
| Seed Hà Nội | PASS | 8 điểm `[DEMO]`, `source=MANUAL` |
| Backend quản lý | PASS | OpenAPI runtime V7: 153 operation/134 path/167 schema |
| Mobile facade/workflow | PASS | Bootstrap, assignment, trips, workflow nguyên tử, telemetry/sync, SOS, safety, flood, notification |
| Offline/idempotency | PASS | SQLite priority queue đủ SOS/safety/workflow/flood/telemetry, stable ACK, `clientEventId`, cooldown và workflow receipt |
| Navigation | PASS-FALLBACK | Photon/OSRM + fallback, 3 alternatives, flood score, detour, off-route/reroute |
| Evidence | PASS | MinIO private mặc định, MIME/magic/SHA/ownership, anonymous 403, object stat và persistence qua restart; local storage là fallback |
| Notification/push | PASS-FALLBACK | Per-user read, STOMP, push token, queue; chưa có FCM credential nên REST polling |
| AI service | PASS | 10 pytest, train/evaluate/export/benchmark, Docker metadata/intent |
| AI on-device | PASS-HYBRID | STGT fold 1 TFLite mặc định + ML Kit temporal chuyển đổi/fallback + cooldown; không stream camera; còn gate pilot thiết bị thật |
| Web UI | PASS | Next 16.2.12, 17 route build gồm `_not-found`, Command Center MapLibre/realtime, tone trắng |
| Flutter app | PASS build | Analyze 0 issue, 9 test khai báo gồm SQLite thật, APK debug; release từ chối thiếu keystore; không có Android device để test phần cứng |
| Dependency production | PASS | `npm audit --omit=dev`: 0 vulnerability |
| Tài liệu | PASS | Contract/runbook/DB/progress đã đồng bộ; báo cáo OpenAPI được sinh lại từ runtime V7 |

## Definition of Done chi tiết

### Docker

- [x] Compose config hợp lệ.
- [x] Tất cả image tự build.
- [x] Tất cả container chính healthy.
- [x] Service app chạy non-root.
- [x] MySQL/evidence giữ dữ liệu sau restart.
- [x] Healthcheck PowerShell.
- [x] Script backup/restore có trong repository.
- [x] Dump thật và restore vào database tạm; chữ ký 12 chỉ số trùng nguồn, tự dọn sạch.
- [ ] Thực hành disaster restore trên máy staging riêng.

### Backend/database

- [x] Compile và 25/25 test.
- [x] 9 integration test trên schema MySQL sạch.
- [x] Swagger/OpenAPI runtime.
- [x] Ownership/negative authorization.
- [x] Stable idempotency và cooldown.
- [x] Flood/workflow replay giữ stable ID/session và không nhân đôi receipt/timeline.
- [x] Workflow transaction.
- [x] Navigation scoring/reroute.
- [x] SOS/timeline/status.
- [x] Evidence protected access.
- [x] Notification per-user/push fallback.

### Frontend

- [x] Lint.
- [x] Production build đủ 17 route entry, gồm route `_not-found` do Next.js sinh.
- [x] Trang Thiết bị và Bảo trì đọc backend thật, có menu/RBAC.
- [x] Chạy trong Docker.
- [x] Đọc backend thật.
- [x] MapLibre và dữ liệu điều hành.
- [x] STOMP realtime + polling fallback.
- [x] Dependency runtime không có advisory.

### Mobile

- [x] App Flutter đủ luồng login/bootstrap/trip/navigation/SOS/flood/notification.
- [x] Secure token refresh/logout.
- [x] SQLite offline queue ưu tiên.
- [x] AI camera xử lý cục bộ.
- [x] Safety/SOS ghi MySQL qua API thật.
- [x] Analyze/test/APK build.
- [ ] Pilot Android vật lý: camera trước, GPS nền, pin/nhiệt, mất mạng dài.
- [ ] Release signing và store compliance.

### AI

- [x] FastAPI health/intent/metadata.
- [x] Temporal engine drowsiness/phone usage.
- [x] Train/evaluate/export/benchmark scripts.
- [x] Metadata canonical khớp SHA với Flutter asset.
- [x] 10/10 pytest.
- [ ] Dataset cabin thực tế có consent để huấn luyện/đánh giá custom phone detector.
- [x] Tích hợp STGT fold 1 TFLite và công tắc chuyển sang ML Kit temporal.
- [ ] Xác thực độ chính xác STGT với iris extractor tương thích và pilot cabin trên thiết bị thật.

## Bằng chứng vòng cuối

| Bài kiểm tra | Kết quả |
|---|---|
| Maven | 25 tests, 0 failures, 0 errors, 0 skipped |
| Docker health | rebuild source mới PASS; backend/web/AI/MinIO HTTP 200; 5 service healthy |
| Safety replay | cùng client ID → cùng event ID |
| SOS replay | cùng client ID → cùng incident ID |
| Context protection | spoofed driver ID bị thay bằng driver trong JWT |
| Evidence | MinIO private; PNG 1.443 byte + SHA-256 + anonymous/cross-driver 403 + persistence restart |
| Backup/restore | V7: 117.313 byte; SHA-256; source/restored signature `20|15|20|11|18|7|11|2|2|7|11|2` trùng; cleanup PASS |
| Push | raw token không trả về; item chuyển polling fallback |
| STOMP | authenticated CONNECTED, anonymous ERROR |
| Frontend | full lint và Next production/Docker build PASS; `/devices` và `/maintenance` có trong route output |
| Browser E2E | Admin: Thiết bị 10 bản ghi, Bảo trì 3 phiếu, tìm kiếm mỗi trang lọc đúng 1, console 0 lỗi; Driver: menu ẩn và URL trực tiếp không lộ dữ liệu |
| Flutter | analyze 0 issue; 9/9 test PASS; debug APK PASS từ vòng trước; release signing guard PASS |
| AI | 10/10 test; 10.000-sample benchmark PASS |

## Blocker ngoài repository

Các mục sau không được giả lập là đã hoàn thành:

- Firebase/FCM credential.
- Domain, TLS certificate, secret manager và keystore phát hành.
- Điện thoại Android vật lý/emulator.
- Dataset camera cabin có quyền sử dụng và nhãn phù hợp.
- SLA production cho geocoding/routing.

Fallback hiện tại giúp MVP chạy được ngay local/LAN, nhưng checklist trên phải hoàn tất trước rollout thương mại.
