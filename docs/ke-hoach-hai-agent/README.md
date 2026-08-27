# Kế hoạch hoàn thiện SafeFleet bằng Codex và Claude

Ngày lập: 2026-08-27  
Nguồn rà soát: `docs/BAO_CAO_RA_SOAT_TINH_NANG_CHUA_HOAN_THIEN_2026-08-27.md`

## 1. Mục tiêu

Bộ tài liệu này dùng để giao việc cho hai AI agent cùng hoàn thiện SafeFleet mà không sửa chồng, không tự phát minh API và không đánh dấu hoàn thành khi mới chỉ có giao diện hoặc backend.

- **Codex**: backend, AI service, PostgreSQL/Flyway, MinIO, bảo mật, báo cáo, RAG, hạ tầng, CI/CD và hợp đồng API.
- **Claude**: web quản lý, ứng dụng Flutter, trải nghiệm người dùng, kiểm thử client và kiểm thử hành trình nghiệp vụ.
- **Codex giữ vai trò tích hợp kỹ thuật**: quản lý schema/API contract và nhánh tích hợp.
- **Claude giữ vai trò nghiệm thu sản phẩm phía client**: xác nhận UI, trạng thái lỗi, quyền và hành trình người dùng.

Hai actor nghiệp vụ duy nhất vẫn là **Tài xế** và **Quản lý**. Các vai trò admin/dispatcher/safety chỉ là phân quyền con của Quản lý.

## 2. Bộ tài liệu bàn giao

| File | Mục đích | Chủ sở hữu khi thực thi |
|---|---|---|
| `00_SHARED_CONTEXT.md` | Context kiến trúc, hiện trạng, nguyên tắc chung | Chỉ Integration Lead cập nhật |
| `01_CODEX_TASKS.md` | Backlog và thứ tự thực hiện của Codex | Codex |
| `02_CLAUDE_TASKS.md` | Backlog và thứ tự thực hiện của Claude | Claude |
| `03_INTEGRATION_PROTOCOL.md` | Git, API contract, handoff, test gate và xử lý xung đột | Cả hai tuân thủ |
| `04_PROMPT_CODEX.md` | Prompt có thể giao trực tiếp cho Codex | Người điều phối |
| `05_PROMPT_CLAUDE.md` | Prompt có thể giao trực tiếp cho Claude | Người điều phối |
| `handoffs/CODEX_HANDOFF.md` | Nhật ký kết quả và blocker của Codex | Codex |
| `handoffs/CLAUDE_HANDOFF.md` | Nhật ký kết quả và blocker của Claude | Claude |

## 3. Thứ tự triển khai

Không giao toàn bộ backlog cho hai agent chạy tự do. Thực hiện theo các wave sau:

| Wave | Mục tiêu | Codex | Claude | Cổng kết thúc |
|---|---|---|---|---|
| W0 | Đóng băng baseline và hợp đồng | C-000, C-001 | CL-000, CL-001 | G0 |
| W1 | An toàn và sẵn sàng production | C-101 → C-106 | CL-101 → CL-104 | G1 |
| W2 | Hoàn thiện tính năng quản lý | C-201 → C-206 | CL-201 → CL-209 | G2 |
| W3 | Vận hành và kiểm chứng thực địa | C-301 → C-305 | CL-301 → CL-304 | G3 |
| W4 | Mở rộng có điều kiện | C-401 → C-402 | CL-401 → CL-402 | G4 |

Trong mỗi wave, task backend/API phải đạt trạng thái `CONTRACT_READY` trước khi task client phụ thuộc bắt đầu tích hợp. Claude có thể dựng UI bằng fixture theo đúng contract nhưng không tự tạo endpoint khác.

## 4. Ưu tiên thực tế

### P0 — bắt buộc trước production

1. Bảo vệ PII trước khi gọi OpenAI.
2. Căn chỉnh access/refresh token, loại bỏ token web khỏi `localStorage`, sửa đồng bộ phiên Flutter.
3. FCM production end-to-end và Android release signing/AAB.
4. CI/CD, Caddy/VPS, image scan, smoke test và rollback có bằng chứng.
5. Backup mã hóa ngoài máy chủ và diễn tập restore.
6. Sửa scheduler trong test profile để test không truy cập DB đã đóng.

### P1 — hoàn thiện nghiệp vụ đã liệt kê

1. Thiết bị; replay/timeline chuyến; sự cố; cảnh báo; kho; bảo trì/hết hạn giấy tờ.
2. Báo cáo ngày/tháng/năm, quãng đường và thời gian lái thực tế.
3. Quản trị tài liệu RAG với version/approve/retire và dữ liệu chính sách thật.
4. Timeline SOS trên ứng dụng tài xế.
5. Quan sát hệ thống, retention bằng chứng, OCR bundle và thử nghiệm thực địa.

### P2 — chỉ làm sau khi có số liệu hoặc quyết định sản phẩm

1. Redis/scale-out WebSocket/queue.
2. Live traffic ETA, nhà cung cấp bản đồ có SLA và bản đồ offline đầy đủ.
3. Tool ghi dữ liệu cho agent quản lý. Nếu bật, chỉ là các thao tác nghiệp vụ có whitelist, xác nhận, idempotency, RBAC và audit; không cấp raw SQL.

## 5. Definition of Done chung

Một task chỉ được chuyển `VERIFIED` khi có đủ:

- Mã nguồn cho toàn bộ vertical slice thuộc phạm vi task.
- Migration chỉ tiến, có rollback/runbook khi thay đổi dữ liệu.
- Test happy path, quyền truy cập và lỗi quan trọng; không làm giảm bộ test hiện có.
- Không commit secret, model private, keystore hoặc credential.
- Tài liệu cấu hình/vận hành và feature flag nếu có rủi ro rollout.
- Bằng chứng lệnh test, commit SHA, file đã đổi và rủi ro còn lại trong handoff.
- Client và API khớp cùng một contract; không dùng dữ liệu giả trong production path.
- Không báo “100%” nếu chưa có kiểm chứng thiết bị/VPS/dịch vụ ngoài thực tế.

## 6. Kết quả cuối chương trình

Chương trình hoàn thiện kết thúc khi G0–G3 đều đạt, toàn bộ task P0/P1 ở trạng thái `VERIFIED`, có báo cáo nghiệm thu v3 dựa trên bằng chứng, và các hạng mục P2 được ghi rõ là đã làm hoặc chủ động hoãn kèm lý do và ngưỡng kích hoạt.
