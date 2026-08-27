# Giao thức phối hợp Codex–Claude

## 1. Chuẩn bị Git an toàn

Worktree hiện tại có thể chứa nhiều thay đổi của người dùng. Trước khi hai agent code:

1. Người dùng hoặc Integration Lead rà soát và tạo **baseline commit**; không tự ý bỏ file bằng `git reset --hard`, `git checkout --` hoặc clean.
2. Tạo hai worktree từ đúng một SHA:
   - nhánh `codex/system-completion-platform`
   - nhánh `claude/system-completion-clients`
3. Tạo nhánh tích hợp `integration/system-completion` từ cùng SHA.
4. Không cho hai agent chạy trong cùng một thư mục làm việc.

Codex không được merge thay đổi của Claude khi chưa có handoff hoàn chỉnh. Claude không được sửa backend để “chữa nhanh” một contract thiếu.

## 2. Trạng thái task

`BACKLOG → READY → IN_PROGRESS → CONTRACT_READY → REVIEW → INTEGRATED → VERIFIED`

- `BLOCKED` có lý do, bằng chứng và người cần xử lý.
- `CONTRACT_READY` chỉ áp dụng task có consumer khác tầng.
- `VERIFIED` cần test sau tích hợp, không chỉ test trên nhánh riêng.
- Mỗi agent chỉ sửa trạng thái trong file task/handoff do mình sở hữu.

## 3. Contract-first

Với mọi vertical slice xuyên backend/client:

1. Claude ghi use case và các trạng thái UI cần dữ liệu vào `CLAUDE_HANDOFF.md`.
2. Codex công bố contract: path/method, DTO, validation, error code, RBAC, pagination, idempotency, realtime event và example.
3. Claude ACK hoặc nêu đúng điểm thiếu; không tạo tên field/endpoint thay thế.
4. Codex implement API + tests và ghi commit SHA.
5. Claude tích hợp client + tests và ghi commit SHA.
6. Codex đưa hai commit vào nhánh integration; cả hai chạy gate liên quan.

Thay đổi breaking sau khi Claude ACK phải tăng version hoặc có compatibility window và được ghi trong cả hai handoff.

## 4. Quy tắc file và xung đột

- Migration/schema/API contract: Codex là single writer.
- Web/Flutter/design system: Claude là single writer.
- `.github`, deploy và Compose: Codex là single writer; Claude gửi yêu cầu pipeline trong handoff.
- Tài liệu chung: chỉ Integration Lead sửa. Hai agent ghi kết quả vào handoff riêng.
- Nếu cần chạm file ngoài vùng sở hữu: dừng task tại ranh giới, ghi patch đề xuất/điều kiện; agent sở hữu thực hiện.
- Không format/bulk rewrite file ngoài task.

## 5. Mẫu handoff bắt buộc

```md
## [TASK-ID] Tên task — YYYY-MM-DD HH:mm
- Status: REVIEW | BLOCKED | VERIFIED
- Baseline SHA:
- Commit SHA:
- Phạm vi đã làm:
- API/migration/config thay đổi:
- File chính đã đổi:
- Lệnh test và kết quả:
- Cách kiểm tra thủ công:
- Secret/feature flag cần cấu hình:
- Rủi ro/blocker/công việc còn lại:
- Task phía agent kia có thể bắt đầu:
```

Không dùng câu “đã xong” nếu thiếu commit, test hoặc phần consumer.

## 6. Cổng kiểm thử

### G0 — Baseline

- Backend PostgreSQL/Testcontainers pass.
- AI pytest pass.
- Frontend lint + production build pass.
- Flutter analyze + test + Android debug build pass.
- Docker Compose config hợp lệ; core services health được kiểm tra nếu môi trường cho phép.

### G1 — Production safety

- PII redaction tests và log review pass.
- Auth expiry/refresh/logout trên web và mobile pass.
- FCM staging tới ít nhất hai thiết bị/trạng thái app; invalid-token cleanup pass.
- Android release AAB cài/smoke được.
- CI build/scan/deploy staging/smoke/rollback có bằng chứng.
- Backup mã hóa và restore drill staging pass.

### G2 — Business completeness

- Mỗi tính năng W2 có API+UI+RBAC+audit+test.
- Long flow nghiệp vụ qua PostgreSQL thật pass.
- Report được đối soát với truy vấn/dataset cố định.
- Chỉ tài liệu RAG approved được trả lời và eval không regression.

### G3 — Field/operations

- Pilot ngủ gật có confusion matrix/false alert rate/latency.
- 30–50 route test có log và kết luận.
- Observability phát hiện được lỗi giả lập API/AI/DB/FCM/backup.
- Evidence retention và OCR model lifecycle được diễn tập.
- Báo cáo v3 phân biệt rõ code, staging, field và production verification.

### G4 — Scale/optional

- Chỉ chạy khi có quyết định kích hoạt P2.
- Có benchmark trước/sau và rollback flag.

## 7. Test matrix tối thiểu sau mỗi merge

| Khu vực thay đổi | Test bắt buộc |
|---|---|
| Backend/migration | Unit + PostgreSQL Testcontainers + API/RBAC/idempotency liên quan |
| AI/RAG/OCR | Pytest + redaction/tool-loop/RAG eval hoặc model health liên quan |
| Web | Lint + production build + component test + browser E2E của flow bị ảnh hưởng |
| Flutter | Analyze + unit/widget test + release/debug build phù hợp + device smoke nếu notification/camera/navigation |
| Infra | Compose/config validate + health/smoke; scan image; rollback rehearsal khi thay deploy |

## 8. Xử lý blocker và bất đồng

1. Ưu tiên kiến trúc trong `00_SHARED_CONTEXT.md` và dữ liệu từ báo cáo rà soát.
2. Nếu contract không đủ, Claude ghi case cụ thể; Codex không suy đoán UX, Claude không suy đoán schema.
3. Nếu cùng một lỗi/lệnh được thử hai lần với kết quả giống hệt, không lặp lần ba. Ghi bằng chứng, đổi kế hoạch hoặc báo blocker.
4. Quyết định mở rộng phạm vi, dùng dịch vụ trả phí, deploy thật, gửi FCM diện rộng, thay/xóa dữ liệu hoặc thêm agent mutation phải do người dùng phê duyệt.

## 9. Thứ tự tích hợp mỗi wave

1. Codex contract commit.
2. Claude client commit dựa trên contract.
3. Codex backend/infra final commit.
4. Rebase/cherry-pick có kiểm soát vào `integration/system-completion`.
5. G0/G1/G2/G3 tương ứng.
6. Hai handoff được cập nhật; chỉ sau đó chuyển task `VERIFIED`.

