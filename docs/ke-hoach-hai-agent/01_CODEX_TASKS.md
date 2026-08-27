# Task plan của Codex

Codex phụ trách backend, AI, data, infra, CI/CD, API contract và tích hợp kỹ thuật. Mỗi lần chỉ nhận một task `READY`, trừ khi hai task hoàn toàn độc lập và không đụng cùng file.

## W0 — Baseline và contract

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| C-000 | P0 | Chốt baseline kỹ thuật | Baseline commit đã được người dùng duyệt | Ghi SHA; chạy lại backend/AI/compose config; không sửa/xóa thay đổi chưa commit của người dùng; ghi kết quả vào handoff |
| C-001 | P0 | Lập ma trận API/DB/feature flag cho toàn bộ task | C-000, CL-001 input | Contract request/response/error/RBAC/idempotency; migration plan; route WebSocket nếu có; Claude có thể dựng client mà không suy đoán |
| C-002 | P0 | Ổn định test lifecycle | C-000 | Tắt scheduler/background job ở test profile; toàn bộ backend test pass và không còn log truy cập DB sau khi container đóng |

## W1 — Production safety

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| C-101 | P0 | PII minimization/redaction cho AI | C-001 | Allowlist theo tool/use case; redact prompt, tool output và log trước provider; unit/integration test với email, SĐT, token, biển số/định danh theo chính sách; audit chỉ giữ metadata cần thiết |
| C-102 | P0 | Chuẩn hóa auth/session backend | C-001 | Access token ngắn thống nhất config; refresh rotation/revocation; contract hỗ trợ web BFF/HttpOnly cookie; CORS/CSRF rõ; test hết hạn, reuse refresh và logout |
| C-103 | P0 | FCM server production-ready | C-001 | Fail-fast cấu hình production; không commit credential; quản lý token/device; retry có giới hạn, invalid-token cleanup, metrics/log; Firebase được mock/emulate trong CI; checklist staging E2E |
| C-104 | P0 | CI/CD và VPS deployment gate | C-000 | Workflow build/test/scan; image GHCR theo Git SHA; SBOM/vulnerability threshold; inventory và runbook rotate secret; Caddy/TLS/health/smoke/rollback; cấu hình chỉ public 80/443; không tuyên bố live khi chưa deploy staging thật |
| C-105 | P0 | Backup/restore production | C-000 | Backup PostgreSQL/MinIO mã hóa; offsite target qua secret; retention; restore script vào môi trường cô lập; checksum; runbook và bằng chứng drill staging |
| C-106 | P1 | Observability baseline | C-104 | Prometheus scrape, Grafana dashboard, Loki/log correlation, Alertmanager rules cho API/AI/DB/FCM/backup; không log secret/PII |

## W2 — API và AI cho tính năng còn thiếu

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| C-201 | P1 | Device management API | C-001 | CRUD, gán/bỏ gán tài xế/xe, trạng thái và connection logs; RBAC/audit/pagination; migration + PostgreSQL tests; contract cho CL-201 |
| C-202 | P1 | Trip replay, incident và alert workflow API | C-001 | Telemetry replay/timeline; assign dispatcher/rescue; timeline note; dismiss alert; create/link incident; state transition validation, idempotency, WebSocket event và tests; contract cho CL-202/203 |
| C-203 | P1 | Warehouse, maintenance, document expiry API | C-001 | Issue list/detail/confirm receipt; due maintenance; document expiry query/notification; RBAC/audit/tests; contract cho CL-204/205 |
| C-204 | P1 | Reporting/aggregation API | C-001 | Tổng quãng đường, phút lái thực tế; kỳ ngày/tháng/năm; breakdown tài xế/xe/ngập/sự cố; timezone Asia/Saigon, pagination/export job nếu dữ liệu lớn; đối soát SQL và tests; contract cho CL-206 |
| C-205 | P1 | RAG document lifecycle | C-101 | Upload → validate → chunk → version → approve/publish → retire; trạng thái và audit; chỉ bản approved được retrieval; import chính sách có nguồn do người có thẩm quyền cung cấp; nếu chưa có thì giữ sample được gắn nhãn và báo data blocker, không bịa chính sách; RAG eval regression; contract cho CL-207 |
| C-206 | P1 | SOS timeline contract | C-001 | API/event trả timeline đầy đủ, phân quyền tài xế chỉ thấy dữ liệu của mình; test thứ tự/thời gian/dữ liệu rỗng; contract cho CL-208 |

## W3 — Vận hành và field readiness

| ID | P | Công việc | Phụ thuộc | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| C-301 | P1 | Routing graph lifecycle | C-104 | Job tải/build graph có checksum/version; canary route; rollback graph; health/fallback Valhalla→OSRM; tài liệu cập nhật định kỳ |
| C-302 | P1 | Evidence retention/recovery | C-105 | Chính sách lưu/xóa/hold theo loại evidence; scheduled cleanup an toàn; soft-delete/restore theo phạm vi; audit và test không xóa nhầm evidence đang được tham chiếu |
| C-303 | P1 | OCR model supply chain | C-104 | Model manifest/version/checksum; tải từ private artifact bằng secret; runtime health báo model version; CI kiểm tra bundle mà không đưa model/secret vào Git |
| C-304 | P1 | Load/performance baseline | C-106, W2 verified | Kịch bản tải trip/telemetry/WebSocket/report/agent; p95/error rate/resource; xác định bằng số liệu có cần Redis hay scale-out |
| C-305 | P1 | Báo cáo nghiệm thu kỹ thuật v3 | G3 | Tổng hợp test, staging, field input của Claude, security/backup/restore; không dùng phần trăm hoàn thành thiếu mẫu số/bằng chứng |

## W4 — Có điều kiện, không tự động triển khai

| ID | P | Công việc | Điều kiện kích hoạt | Đầu ra/tiêu chí nghiệm thu |
|---|---:|---|---|---|
| C-401 | P2 | Redis/scale-out realtime và queue | C-304 chứng minh single-node không đạt SLO | Thiết kế consistency/idempotency; distributed WebSocket/queue/cache; failure test và rollback feature flag |
| C-402 | P2 | Management agent mutation tools | Người dùng duyệt danh sách thao tác | Tool nghiệp vụ whitelist, confirmation, RBAC, idempotency, audit và preview; tuyệt đối không raw SQL; test prompt injection và cross-tenant/scope |
| C-403 | P2 | Live traffic/provider map backend | Người dùng chọn provider/SLA hoặc phương án self-host | Adapter cô lập provider; timeout/quota/cache/fallback; nguồn ETA được gắn metadata; degraded mode và cost/operations runbook; contract cho CL-401 |

## Thứ tự thực hiện khuyến nghị

`C-000 → C-001 → C-002 → C-101 → C-102 → C-103 → C-104 → C-105 → C-106 → C-201…C-206 → C-301…C-305`

Các task W2 có thể xen kẽ theo từng vertical slice với Claude: Codex publish contract, Claude ACK, Codex hoàn tất API, Claude tích hợp, rồi chạy gate.
