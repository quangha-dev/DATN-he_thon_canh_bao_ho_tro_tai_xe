# Context chung bắt buộc cho Codex và Claude

## 1. Phạm vi sản phẩm

SafeFleet là hệ thống nội bộ hỗ trợ vận hành đội xe và cảnh báo an toàn. Hệ thống chỉ có hai actor nghiệp vụ:

- **Tài xế** dùng ứng dụng Flutter: nhận chuyến, thực hiện chuyến, dẫn đường, gửi telemetry/SOS, nhận cảnh báo/ngủ gật/thông báo và hỏi đáp agent.
- **Quản lý** dùng web Next.js: quản lý nguồn lực và chuyến, giám sát thời gian thực, xử lý cảnh báo/sự cố, báo cáo, quản trị tài liệu và sử dụng agent quản lý.

`ADMIN`, `DISPATCHER`, `SAFETY_MANAGER` là vai trò con để giới hạn quyền của actor Quản lý, không phải actor nghiệp vụ mới.

## 2. Kiến trúc đích cần bảo toàn

| Tầng | Công nghệ/trách nhiệm |
|---|---|
| Mobile | Flutter, Android trước; offline queue/idempotency; FCM; telemetry và drowsiness |
| Web | Next.js cho Quản lý; không giữ token dài hạn trong `localStorage` |
| Business API | Spring Boot modular monolith; nguồn sự thật của nghiệp vụ, RBAC, audit và WebSocket |
| AI | FastAPI; Agent/MCP/RAG/OCR; chỉ gọi business tools có schema, không cho LLM truy cập raw SQL |
| Data | PostgreSQL 17 + pgvector, Flyway forward-only; MinIO lưu bằng chứng |
| Routing | Valhalla chính, OSRM fallback; dịch vụ bản đồ/geocoding được cô lập sau adapter |
| Edge/Deploy | Caddy, Docker Compose trên VPS; chỉ public 80/443; image theo Git SHA |
| External | OpenAI, Firebase FCM, tiles/geocoding; phải có timeout, retry có giới hạn và quan sát được |

Redis, live traffic và full offline map là kiến trúc mở rộng, không phải điều kiện mặc định cho lần go-live đầu nếu chưa có số liệu tải.

## 3. Hiện trạng đã kiểm chứng

- Backend: 83 test pass bằng PostgreSQL Testcontainers; 22 migration Flyway.
- Frontend: lint và production build pass.
- AI service: 64 test pass.
- Flutter: analyze sạch; 114 test pass; 3 preview test skip.
- Android debug APK build thành công.
- Docker core service từng được kiểm tra healthy.
- Đã có: auth/JWT/refresh/RBAC, tài khoản, tài xế, phương tiện, vòng đời chuyến, telemetry/realtime, vùng ngập, thông báo in-app, driver agent, MinIO và offline queue/idempotency.
- Drowsiness risk 1–10 và model/test logic đã có nhưng chưa được pilot đủ trên thiết bị/xe thực.
- Management agent có khoảng 16 read-only tools; chưa có mutation tools an toàn.

Các con số trên là baseline, không phải cam kết production. Agent phải chạy lại test sau khi nhận đúng baseline commit.

## 4. Khoảng trống phải xử lý

### Production và bảo mật

- FCM production đang tắt/chưa có credential và chưa chứng minh end-to-end.
- Chưa có PII minimization/redaction trước OpenAI.
- Access token mặc định giữa cấu hình ứng dụng và Docker chưa đồng nhất; web dùng `localStorage`.
- Flutter chưa phát sự kiện đăng xuất ngay khi refresh thất bại và thiếu test restore session.
- Chưa có Android signing/AAB/Play release; iOS chưa có pipeline.
- CI/CD/VPS/Caddy có file cấu hình nhưng chưa có bằng chứng triển khai thật.
- Backup mới ở local; thiếu bản mã hóa offsite, restore script và restore drill.
- Thiếu vulnerability gate, secret rotation runbook và stack quan sát production hoàn chỉnh.

### Nghiệp vụ web/mobile

- Web thiếu: CRUD/gán thiết bị/log kết nối; replay telemetry/timeline chuyến; phân công sự cố/cứu hộ và ghi timeline; dismiss cảnh báo/tạo incident; danh sách/chi tiết kho và xác nhận nhận; trung tâm bảo trì/hết hạn giấy tờ; lịch sử sâu tài xế/phương tiện.
- Báo cáo thiếu lọc kỳ, báo cáo theo tài xế/phương tiện/ngập/sự cố, tổng quãng đường và số phút lái thực tế, tổng hợp ngày/tháng/năm.
- Mobile chưa hiển thị đầy đủ timeline SOS.

### AI/RAG/OCR

- RAG hiện chỉ có dữ liệu mẫu nhỏ; chưa có upload/version/approve/retire và bộ chính sách công ty thật.
- OCR production model bundle nằm ngoài Git; CI/runtime chưa chứng minh cách nhận và kiểm tra model an toàn.
- Agent quản lý chỉ đọc. Mutation là P2 có điều kiện, tuyệt đối không biến thành SQL/chat-to-database tự do.

### Kiểm chứng thực địa và vận hành

- Chưa có thống kê false-positive/false-negative cho ngủ gật trên nhiều thiết bị, ánh sáng và kính.
- Routing chưa được thử 30–50 tuyến thực địa; thiếu tự động cập nhật graph.
- Thiếu evidence retention/recovery policy.
- Scheduler có thể chạy sau khi Testcontainers đóng DB; phải tắt scheduler ở test profile.

## 5. Ranh giới sở hữu mã nguồn

### Codex sở hữu

- `web_quan_ly/backend/**`
- `safefleet_ai/**`
- migration và schema PostgreSQL
- `deploy/**`, `docker/**`, `docker-compose*.yml`
- `.github/**`
- tài liệu API contract và runbook hạ tầng

### Claude sở hữu

- `web_quan_ly/frontend/**`
- `safe_fleet_driver_ui/**`
- client fixtures/tests và tài liệu nghiệm thu UX/thiết bị

### Vùng dùng chung

- `docs/**`, file root và cấu hình xuyên tầng chỉ được sửa theo giao thức handoff.
- Codex là người ghi API contract/schema. Claude đề xuất thay đổi trong handoff, không tự sửa backend/migration.
- Claude là người quyết định biểu diễn UI theo design system hiện tại. Codex không tự tái thiết kế client.

## 6. Nguyên tắc kỹ thuật bắt buộc

1. PostgreSQL là database duy nhất của production; không thêm đường chạy SQLite/MySQL/H2 cho nghiệp vụ.
2. Migration Flyway forward-only, tên rõ, có test trên PostgreSQL thật/Testcontainers.
3. API có DTO/schema rõ, phân trang, validation, RBAC, audit; lỗi không lộ stack trace hoặc PII.
4. Mọi mutation quan trọng có idempotency hoặc optimistic locking phù hợp.
5. AI chỉ nhận dữ liệu tối thiểu cần thiết; redaction trước provider; tool output có allowlist.
6. Tool loop phải plan → execute → kiểm tra kết quả. Cùng tool với cùng tham số trả kết quả giống hệt hai lần thì không gọi lần ba; phải trả lời hoặc lập kế hoạch khác.
7. Không commit secret. Dùng biến môi trường/secret store và fail-fast khi cấu hình production thiếu.
8. Không thực hiện deploy thật, gửi notification thật diện rộng, thay secret hoặc xóa dữ liệu nếu chưa có credential và phê duyệt vận hành.
9. Giữ tương thích ngược trong một wave hoặc cung cấp migration plan rõ cho client.
10. Không dùng mock/fixture trong production path; mock chỉ dùng trong unit/integration test.
11. Không tự viết rồi coi tài liệu mock là chính sách công ty thật. Corpus production phải do người có thẩm quyền cung cấp/phê duyệt và lưu được nguồn, phiên bản, ngày hiệu lực.

## 7. Tiêu chuẩn chất lượng

- Correctness, relevance, completeness, coherence cho AI output.
- Faithfulness, answer relevancy, context recall và context precision cho RAG.
- Happy path chỉ là baseline; phải có test quyền, lỗi mạng/dịch vụ ngoài, idempotency và dữ liệu rỗng ở nơi có rủi ro.
- Báo cáo nghiệm thu phải ghi rõ môi trường và bằng chứng; phân biệt `code-ready`, `staging-verified`, `field-verified`, `production-verified`.
