# BÁO CÁO RÀ SOÁT TÍNH NĂNG CHƯA HOÀN THIỆN SAFEFLEET

Ngày rà soát: 27/08/2026  
Phạm vi: mã nguồn và runtime local của web quản lý, app tài xế, Spring Boot, AI Agent/RAG/OCR, PostgreSQL/pgvector, MinIO, Valhalla và cấu hình production/CI/CD.

## 1. Kết luận ngắn

Hệ thống **đã có đầy đủ khung nghiệp vụ cốt lõi**, không còn tình trạng các màn quản lý tài xế/tài khoản/chuyến chỉ là mock. Luồng dài giao chuyến → tài xế nhận → checklist → bắt đầu → tạm nghỉ/tiếp tục → hoàn thành được kiểm thử với PostgreSQL thật. Phát hiện ngủ gật dùng model STGT TFLite, hiển thị nguy cơ 1–10 và có kiểm thử thuật toán.

Tuy nhiên, hệ thống **chưa thể coi là hoàn thiện production**. Có 9 nhóm chưa triển khai hoặc chưa kích hoạt, và 12 nhóm mới hoàn thiện một phần. Các khoảng trống lớn nhất là:

1. FCM production chưa bật; runtime hiện tại có `FCM_ENABLED=false`, không có Firebase credential và chưa có push token đăng ký.
2. Chưa có lớp giảm thiểu/ẩn dữ liệu nhạy cảm trước khi kết quả tool được gửi tới OpenAI.
3. Web còn thiếu một số thao tác quản trị đã có API: quản lý thiết bị đầy đủ, replay hành trình, assign/timeline sự cố, dismiss/chuyển cảnh báo thành sự cố, trang phiếu xuất kho và một số báo cáo chi tiết.
4. Báo cáo kỳ chưa có tổng quãng đường và thời gian lái thực tế; web báo cáo chỉ hiển thị hai nhóm số liệu cơ bản.
5. RAG mới có 5 văn bản mẫu, 30 chunk; chưa có quy trình/UI quản lý kho quy định đầy đủ.
6. Cấu hình VPS, Caddy và CI/CD đã được viết nhưng chưa có bằng chứng đã chạy trên VPS/GitHub production.
7. Backup mới nằm trên cùng VPS, chưa mã hóa/copy off-site và chưa tự động restore drill.
8. Chưa có Redis, Grafana/Loki/Alertmanager, vulnerability gate và quy trình xoay secret.
9. Dẫn đường và ngủ gật đã qua test mô phỏng/unit nhưng chưa có biên bản pilot trên thiết bị/xe thật.

## 2. Cách đánh giá

| Ký hiệu | Ý nghĩa |
|---|---|
| ✅ | Có UI/API/xử lý/dữ liệu phù hợp và đã có bằng chứng kiểm thử trong lượt này. |
| 🟡 | Có phần lớn code nhưng thiếu một mắt xích, cấu hình production hoặc kiểm thử hiện trường. |
| 🔴 | Không tìm thấy triển khai tương ứng, hoặc chỉ xuất hiện trong tài liệu kiến trúc đích. |
| 🔵 | Hạng mục mở rộng có chủ đích, chưa cần cho một instance nội bộ nhưng đã được liệt kê trong kiến trúc hoàn thiện. |

Không dùng số phần trăm chung để tránh lặp lại vấn đề “100% vì test quá dễ”. Mỗi kết luận phải có bằng chứng ở code, cấu hình, runtime hoặc test.

## 3. Đối chiếu các nhóm tính năng nghiệp vụ

| Nhóm tính năng đã liệt kê | Trạng thái | Bằng chứng hiện tại | Phần còn thiếu |
|---|---:|---|---|
| Đăng nhập, đăng xuất, refresh token, RBAC | ✅ | Spring Security/JWT; refresh rotation và logout được test với PostgreSQL thật | Chưa phải session production tối ưu; xem mục bảo mật |
| Quản lý tài khoản | ✅ | Route `/accounts`, API CRUD, RBAC | Không thiếu chức năng cốt lõi |
| Quản lý tài xế | ✅ | Route `/drivers`, API CRUD/report/history | Drawer web chưa khai thác đủ report/history chi tiết |
| Quản lý phương tiện | ✅ | Route `/vehicles`, API CRUD/routing profile/status | Drawer web chưa khai thác hết report/history |
| Quản lý thiết bị | 🟡 | API có CRUD, gắn xe, trạng thái và connection log; web có danh sách | Nút “Gắn thiết bị” chỉ hiện thông báo; chưa có form CRUD/gắn xe/connection log thật |
| Điều phối và vòng đời chuyến | ✅ | Integration test chạy đủ assign, accept, checklist, start, pause, resume, complete và idempotency | Không thiếu flow cốt lõi |
| Phiếu xuất kho | 🟡 | Dispatch tạo/cập nhật/phát hành phiếu; backend có API | Chưa có trang danh sách/chi tiết riêng và thao tác xác nhận nhận hàng trên web |
| Telemetry, vị trí realtime, WebSocket/polling | ✅ | API batch telemetry, GPS ordering, STOMP authorization, dashboard/bản đồ | Chưa kiểm thử tải thật nhiều xe; replay còn thiếu ở web |
| Lịch sử/replay hành trình | 🟡 | Backend có history/replay | Drawer chuyến trên web chưa có bản đồ phát lại và timeline GPS/trạng thái |
| Ngủ gật, nguy cơ 1–10, cảnh báo tại máy | 🟡 | Model STGT fold 1 TFLite có checksum/metadata; Flutter test mức 1–10, resampling, cooldown và PERCLOS đều đạt | Chưa có pilot camera/ánh sáng/kính/đường xóc trên thiết bị và xe thật; chưa có số liệu false positive/false negative hiện trường |
| SOS, sự cố và timeline | 🟡 | API tạo/nhận/xử lý/đóng, timeline; web xem timeline và tiếp nhận | App tài xế chưa hiển thị timeline xử lý SOS đầy đủ; web chưa có assign điều phối viên và thêm ghi chú timeline |
| Cảnh báo an toàn | 🟡 | Web xem, tiếp nhận và resolve; backend có đầy đủ action | Web chưa có dismiss và chuyển safety event thành incident |
| Điểm ngập/nguy hiểm | ✅ | Hình học point/line/polygon, xác minh/resolve, hazard snapshot và cảnh báo trên tuyến | Chất lượng vẫn phụ thuộc xác minh dữ liệu cộng đồng |
| Dẫn đường turn-by-turn/voice/off-route/reroute | 🟡 | Valhalla healthy, OSRM fallback; 30+ test engine/display/field-simulation đạt | Chưa pilot 30–50 tuyến thật, chưa tự động cập nhật Valhalla graph, chưa có live traffic ETA |
| Bản đồ và geocoding production | 🟡 | MapLibre/Photon/provider ngoài hoạt động ở mức tích hợp | Tile/geocoding công cộng chưa được self-host hoặc có SLA; offline map đầy đủ chưa có |
| OCR phiếu nhật trình | 🟡 | Mobile OCR, server OCR, queue offline, review lệch biển và export XLSX có test | Binary model OCR nằm ngoài Git; production build phụ thuộc kho model private/secrets chưa được xác minh trên CI |
| Thông báo trong ứng dụng | ✅ | Notification table/API/read state, polling fallback và thông báo khi giao chuyến được integration test | Không thiếu luồng in-app |
| Push notification trên thanh điện thoại | 🟡 | Client đăng ký token; backend có durable queue, retry/backoff và Firebase sender | Runtime hiện tại tắt FCM, thiếu credential, DB có 0 push token; chưa có test end-to-end trên điện thoại thật |
| Bảo trì | 🟡 | CRUD/order/due alerts/document-expiry API; web có danh sách và KPI hạn | Web chưa có trung tâm due/document-expiry đầy đủ và chưa dùng hết action backend |
| Báo cáo web | 🟡 | Có CSV, cảnh báo theo loại và chuyến theo ngày | Chưa có bộ lọc kỳ trên UI; chưa hiển thị report tài xế/xe/ngập/sự cố; thiếu dashboard báo cáo vận hành đầy đủ |
| Báo cáo ngày/tháng/năm qua Agent | 🟡 | Tool trả tổng chuyến, hoàn thành, active, tỷ lệ, trạng thái và theo ngày | Tool tự khai báo chưa có `totalDistanceKm` và `actualDrivingMinutes`; không được tự ước tính |
| Agent tài xế | ✅ | Tool giới hạn theo tài xế, confirmation cho lệnh ghi, idempotency và audit; test đạt | Chat không hoạt động offline hoàn toàn, chỉ một số lệnh nghiệp vụ có queue offline |
| Agent quản lý | 🟡 | 16 management tool đọc toàn đội; plan/check/replan và loop guard lần thứ ba có test | Không có tool ghi cho quản lý; đây là giới hạn có chủ đích nhưng chưa đáp ứng “toàn quyền thao tác” nếu yêu cầu đó vẫn còn |
| RAG quy định công ty | 🟡 | PostgreSQL/pgvector, hybrid search, citation và chunk theo heading; runtime có 5 document/30 chunk | Mới là corpus mẫu; chưa có UI/API duyệt, upload, kích hoạt/thu hồi phiên bản và chưa đủ toàn bộ quy định thật |
| Evidence/ảnh trên MinIO | ✅ | MinIO healthy; metadata/object key lưu trong PostgreSQL | Cần policy retention và kiểm thử phục hồi object ở production |
| Offline SQLite, sync queue, retry, idempotency | ✅ | Flutter queue test và backend command receipt/batch ACK test đạt | Không phải mọi chức năng đều offline; Agent/OpenAI và tải bản đồ vẫn cần mạng |

## 4. Các hạng mục kiến trúc production chưa hoàn thiện

| Hạng mục kiến trúc đích | Trạng thái | Kết luận |
|---|---:|---|
| PostgreSQL 17 + pgvector, Flyway | ✅ | Runtime healthy; 22 migration được validate và chạy trên PostgreSQL Testcontainers |
| MinIO private object storage | ✅ | Runtime healthy, chỉ bind localhost trong compose hiện tại |
| Valhalla graph Việt Nam | 🟡 | Container healthy và volume persistent; thiếu lịch cập nhật graph/canary tuyến production |
| Caddy HTTPS/WSS + domain | 🟡 | Có Caddyfile/compose VPS nhưng runtime đang là localhost:3001/8080; chưa có bằng chứng DNS, certificate và smoke production |
| CI/CD GitHub Actions + GHCR + rollback | 🟡 | Workflow, deploy script và rollback theo Git SHA đã có trong workspace | File đang chưa commit; chưa có bằng chứng GitHub Environment/secrets/GHCR/VPS job đã chạy thành công |
| Android/iOS release | 🔴 | CI mới build Android debug APK | Chưa có Android signing/AAB/Play track; chưa build iOS bằng macOS runner/App Store Connect |
| Backup PostgreSQL + MinIO | 🟡 | Có `pg_dump`, MinIO mirror, checksum, retention và systemd timer | Chưa mã hóa/copy off-site; chưa có restore script/drill tự động và bằng chứng khôi phục thành công |
| Redis queue/cache/distributed lock | 🔵 | Chỉ xuất hiện trong kiến trúc đích | Chưa có service, dependency hoặc code Redis; instance đơn hiện dùng PostgreSQL queue và lock DB |
| Prometheus metrics | 🟡 | Backend có Micrometer và `/actuator/prometheus` | Chưa có Prometheus server, scrape config và alert rule |
| Grafana/Loki/log shipper/Alertmanager | 🔴 | Không có service/config | Chưa có dashboard, log tập trung và cảnh báo ngoài hệ thống |
| Vulnerability gate | 🔴 | Workflow có SBOM/provenance | Chưa có Trivy/Grype/CodeQL/dependency scan với rule chặn CVE critical |
| Quy trình xoay secret | 🔴 | Có hợp đồng `.env.production.example` | Chưa có secret manager hoặc runbook/automation rotation |
| Scale-out backend/realtime/AI | 🔵 | Chưa có; không bắt buộc cho một VPS nội bộ | Chỉ thực hiện sau load test; Redis và distributed session/lock là tiền đề |

## 5. Khoảng trống bảo mật và riêng tư cần xử lý trước production

### P0 — dữ liệu gửi OpenAI chưa được giảm thiểu

Không tìm thấy hàm `redact`, `mask`, `sanitize` hoặc lớp PII policy trong AI service/management agent. Một số management tool có thể trả họ tên, email, điện thoại hoặc dữ liệu chuyến/vị trí; orchestrator đưa JSON kết quả tool vào hội thoại model. Điều này chưa khớp câu “Prompt đã giảm thiểu dữ liệu” trong kiến trúc đích.

Cần thêm một cổng policy trước provider OpenAI:

- allowlist trường theo từng tool;
- bỏ/mask email, điện thoại và định danh không cần thiết;
- làm tròn tọa độ khi câu hỏi không cần vị trí chính xác;
- ghi audit loại dữ liệu đã gửi, không ghi prompt chứa PII vào log;
- test bắt buộc rằng tool account/driver/trip không làm rò trường ngoài schema cho phép.

### P1 — session web/mobile chưa đạt mức hardening mục tiêu

- Access token mặc định là 1.440 phút, chưa phải token ngắn hạn như kiến trúc yêu cầu.
- Web lưu access/refresh token trong `localStorage`, làm tăng tác động nếu có XSS.
- Khi refresh thất bại trong lúc app đang mở, `ApiClient` xóa token nhưng chưa phát sự kiện trực tiếp để `SessionController` chuyển ngay sang `signedOut`.
- Chưa có test Flutter chuyên biệt cho restore session và chuyển trạng thái khi refresh thất bại.

Đề xuất: access token 10–20 phút; web dùng refresh token trong Secure/HttpOnly/SameSite cookie hoặc BFF session; có một auth-state event bus dùng chung cho mobile; thêm test trạng thái phiên.

## 6. Danh sách việc cần làm theo ưu tiên

### P0 — phải hoàn thành trước go-live

1. Thêm PII minimization gateway và test chống rò dữ liệu trước OpenAI.
2. Cấu hình Firebase project/client/server, bật FCM và chạy end-to-end giao chuyến → notification trên Android thật.
3. Commit và chạy CI/CD thật; cấu hình GitHub Environment, GHCR, VPS, DNS, HTTPS/WSS và smoke test sau deploy.
4. Hoàn thiện backup mã hóa off-site và chạy restore drill PostgreSQL + MinIO.
5. Tạo Android release signing/AAB; nếu phạm vi có iOS thì bổ sung pipeline iOS.
6. Rút ngắn access token và xử lý lại cách lưu phiên web.

### P1 — hoàn thiện nghiệp vụ/vận hành ngay sau P0

1. Bổ sung UI quản lý thiết bị, trip timeline/replay, incident assign/note, alert dismiss/create-incident và trang phiếu xuất kho.
2. Hoàn thiện báo cáo theo kỳ, tổng quãng đường, thời gian lái, chi tiết tài xế/xe/ngập/sự cố và bộ lọc/export tương ứng.
3. Nhập bộ quy định công ty thật; thêm quản lý tài liệu RAG có version/approval/retire.
4. Pilot ngủ gật trên nhiều điện thoại, ánh sáng, tư thế/kính và xe thật; đo confusion matrix/false alarm theo giờ lái.
5. Pilot dẫn đường 30–50 tuyến xe thật; self-host/proxy tile/geocoding hoặc ký provider SLA; tự động cập nhật Valhalla graph.
6. Bổ sung Prometheus/Grafana/Loki/alerting và cảnh báo push backlog, DB/evidence capacity, AI latency, backup age.
7. Thêm vulnerability gate và runbook xoay secret.

### P2 — chỉ làm khi cần scale

1. Redis cho distributed lock, queue và WebSocket scale-out.
2. Tách PostgreSQL/MinIO/Valhalla khỏi VPS và nhân bản backend/frontend/AI sau khi có load test.
3. Live/predicted traffic cho ETA nếu nghiệp vụ thực sự cần.

## 7. Kết quả kiểm thử trong lượt rà soát

| Thành phần | Kết quả |
|---|---|
| Backend Maven | **83 test đạt**, gồm PostgreSQL 17 Testcontainers và 22 Flyway migration; không có failure/error |
| Frontend | ESLint đạt; Next production build đạt, sinh 20 route kể cả trang gốc, login và not-found |
| AI Agent/MCP/RAG | **64 test đạt**; lần chạy đầu lỗi quyền thư mục temp Windows, chạy lại với basetemp trong workspace thì đạt toàn bộ |
| Flutter | `flutter analyze` không có issue; **114 test đạt, 3 preview test skip** |
| Runtime Docker | PostgreSQL, MinIO, Valhalla, AI, backend và frontend đều healthy |
| Android debug build | Đạt; tạo `build/app/outputs/flutter-apk/app-debug.apk` |

Lưu ý kỹ thuật: backend test đạt nhưng scheduler dọn điểm ngập vẫn chạy trong lúc Testcontainers đã đóng PostgreSQL, làm phát sinh log lỗi kết nối khi shutdown và kéo dài tiến trình khoảng 30 giây. Đây là lỗi vệ sinh test/lifecycle, không làm assertion thất bại, nhưng nên disable scheduler trong profile test.

## 8. Bằng chứng chính

- `docs/KIEN_TRUC_TONG_THE_HE_THONG_HOAN_THIEN.md`: danh sách kiến trúc/tính năng đích.
- `docs/WEB_UI_AUDIT_2026-08-25.md`: các API đã có nhưng web chưa khai thác.
- `docs/ROUTING_PRODUCTION_READINESS.md`: các khoảng trống field test, tile/geocoding và traffic ETA.
- `web_quan_ly/backend/src/test/java/com/safefleet/RealPostgreSqlApiIntegrationTest.java`: flow nghiệp vụ dài và PostgreSQL thật.
- `safe_fleet_driver_ui/test/stgt_drowsiness_engine_test.dart`: risk 1–10 và STGT TFLite.
- `safe_fleet_driver_ui/test/temporal_safety_engine_test.dart`: cảnh báo/cooldown/PERCLOS.
- `safefleet_ai/service/agent/orchestrator.py`: plan, post-tool check, replan và duplicate-result guard.
- `safefleet_ai/service/mcp/registry.py`: 35 tool, trong đó 16 management tool; tool ghi hiện chỉ dành cho tài xế và cần confirmation.
- `safefleet_ai/knowledge/`: 5 tài liệu quy định mẫu.
- `deploy/vps/` và `.github/workflows/ci-cd.yml`: cấu hình production mới ở mức chuẩn bị.

## 9. Kết luận cuối

SafeFleet hiện phù hợp để tiếp tục **nghiệm thu nội bộ/local integration**, nhưng chưa đạt “production hoàn chỉnh”. Không cần viết lại kiến trúc hay luồng chuyến. Trọng tâm đúng là đóng các khoảng trống P0: riêng tư Agent, FCM thật, triển khai VPS/CI/CD có bằng chứng, backup off-site/restore drill, mobile release và hardening session. Sau đó hoàn thiện các màn quản lý còn thiếu và chạy pilot thiết bị/xe thật cho ngủ gật cùng dẫn đường.
