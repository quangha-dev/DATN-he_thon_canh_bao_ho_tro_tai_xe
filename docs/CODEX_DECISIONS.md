# SafeFleet — Quyết định kỹ thuật

## ADR-001: MySQL integration test dùng Testcontainers

- Trạng thái: Accepted.
- Lý do: test cũ hard-code DB `QuanLyCongViecDuAn`, làm Flyway baseline nhầm schema và phá tính cô lập.
- Quyết định: mỗi suite integration khởi tạo MySQL 8.4 riêng, Flyway chạy từ V1, không H2.

## ADR-002: Frontend dùng same-origin `/api/v1`

- Trạng thái: Accepted.
- Lý do: tránh bake `localhost` vào bundle và giúp Docker/LAN/proxy nhất quán.
- Quyết định: browser gọi `/api/v1`; Next.js rewrite sang `BACKEND_INTERNAL_URL`.

## ADR-003: Chưa thêm Redis ở Phase 1

- Trạng thái: Accepted.
- Lý do: MySQL unique constraint đủ cho idempotency MVP; không thêm hạ tầng khi code chưa dùng.
- Có thể xem lại khi triển khai distributed rate limit/retry queue.

## ADR-004: MinIO có trong stack nhưng bucket private

- Trạng thái: Accepted.
- App không giữ secret MinIO. Backend sẽ cấp upload/download được bảo vệ ở phase evidence.

## ADR-005: AI service không xử lý camera realtime

- Trạng thái: Accepted.
- FastAPI chỉ làm intent fallback, metadata/evaluation. Drowsiness/phone detection chạy on-device.
