# SafeFleet MVP

SafeFleet là hệ thống cảnh báo và hỗ trợ tài xế gồm web điều phối, ứng dụng Flutter
cho tài xế, backend Spring Boot, dịch vụ AI cục bộ/OpenAI tùy chọn, PostgreSQL và kho
evidence MinIO riêng tư.

## Chạy nhanh bằng Docker

Yêu cầu: Docker Desktop với Compose v2.

```powershell
Copy-Item .env.example .env
```

Thay **toàn bộ** giá trị `change_me` trong `.env` bằng secret thật. Cấu hình mặc
định không seed dữ liệu demo. Chỉ dùng dữ liệu Hà Nội ở môi trường phát triển:

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev up -d --build
```

Chạy cấu hình gần production:

```powershell
docker compose config --quiet
docker compose up -d --build
docker compose ps
.\docker\scripts\health-check.ps1
node .\docker\scripts\websocket-smoke.mjs
```

Các địa chỉ mặc định:

| Thành phần | Địa chỉ |
|---|---|
| Web điều phối | `http://localhost:3000` |
| Backend / Swagger | `http://localhost:8080` / `/swagger-ui/index.html` |
| AI service | `http://localhost:8000` |
| MinIO console | `http://localhost:9001` |
| PostgreSQL từ máy host | `127.0.0.1:${POSTGRES_PORT:-5432}` |

## Kiểm thử

Chạy toàn bộ kiểm thử, dựng full stack và mở các giao diện web/Swagger/MinIO; nếu có Android emulator hoặc điện thoại kết nối, script cũng mở Flutter app:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1
```

Có thể bỏ qua Android hoặc diễn tập database khi cần chạy nhanh bằng `-SkipAndroid` và `-SkipDatabaseRestore`.

```powershell
# Backend: unit, controller và Testcontainers PostgreSQL thật
cd web_quan_ly\backend
$env:JAVA_HOME='D:\DEV\Kit\jdk-21'
mvn.cmd test

# Web
cd ..\frontend
npm run lint
npm run build

# Flutter
cd ..\..\safe_fleet_driver_ui
flutter analyze
flutter test
flutter build apk --debug

# AI
cd ..\safefleet_ai
docker build --target test -t safefleet-ai-test:local .
docker run --rm safefleet-ai-test:local
```

## Tài liệu bàn giao

- [Báo cáo hệ thống và toàn bộ API](./BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md)
- [Hợp đồng tích hợp ứng dụng tài xế](./BAO_CAO_TICH_HOP_APP_SAFEFLEET.md)
- [Tiến độ tổng thể và ngữ cảnh tiếp tục](./docs/CODEX_FULL_PROGRESS.md)
- [Các quyết định kiến trúc](./docs/CODEX_DECISIONS.md)
- [Runbook Docker, backup và restore](./docs/DOCKER_RUNBOOK.md)
- [Ma trận truy vết yêu cầu](./docs/REQUIREMENT_TRACEABILITY.md)
- [Thang điểm chất lượng và trạng thái hoàn thiện](./docs/QUALITY_SCORECARD.md)

## Rào chắn triển khai thật

- Không bật seed ở production.
- Backend profile Docker từ chối JWT yếu, mật khẩu DB/MinIO mặc định và CORS
  wildcard.
- Evidence dùng bucket MinIO private; URL xem có thời hạn.
- OpenAI mặc định tắt. Quy tắc cục bộ luôn được chạy trước; AI chỉ phân loại lệnh
  chưa nhận diện được và backend vẫn bắt buộc người dùng xác nhận hành động thay đổi
  trạng thái.
- APK release cần keystore thật; FCM cần credentials dự án; HTTPS cần domain và
  chứng thư. Các mục này không thể được giả lập bằng secret mẫu.
