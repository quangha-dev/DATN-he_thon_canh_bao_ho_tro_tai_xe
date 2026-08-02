# SafeFleet — Thang điểm chất lượng và mức hoàn thiện

Cập nhật: 27/07/2026. Thang điểm này đánh giá bản local/LAN có thể tái lập; các phụ thuộc cần thiết bị, dữ liệu có đồng thuận hoặc secret production được ghi riêng và không được giả lập để cộng điểm.

## Thang 100 điểm

| Nhóm | Điểm tối đa | Tiêu chí đạt trọn điểm |
|---|---:|---|
| Chức năng và luồng end-to-end | 25 | Các vai trò hoàn tất luồng chính trên web/app/backend, không còn màn hình lõi thiếu hoặc nút giả |
| Đúng đắn và bằng chứng kiểm thử | 20 | Unit/integration/contract/build/E2E xanh, test tái lập, bao phủ nhánh lỗi quan trọng |
| Bảo mật và quyền riêng tư | 15 | JWT/RBAC/ownership/idempotency, secret production, evidence private, dữ liệu camera tối thiểu |
| Tin cậy, offline và realtime | 15 | Hàng đợi ưu tiên/ACK/retry, WebSocket fallback, restart và backup/restore được xác minh |
| UX và khả năng tiếp cận | 10 | Luồng rõ ràng, responsive, trạng thái lỗi/loading/empty, keyboard/label, không hành động nguy hiểm mơ hồ |
| Vận hành và triển khai | 10 | Docker/runbook/healthcheck/observability, cấu hình production fail-fast, quy trình release rõ |
| Tài liệu và khả năng bảo trì | 5 | Contract, quyết định, tiến độ và số liệu đồng bộ với source; cấu trúc dễ tiếp tục |

Mức đánh giá: dưới 60 chưa dùng được; 60–74 prototype; 75–84 MVP có điều kiện; 85–91 MVP tốt/local pilot; 92–96 sẵn sàng pilot nghiêm túc; 97–100 chỉ khi đã có kiểm chứng production/thiết bị/dataset thực.

## Baseline trước vòng hoàn thiện 27/07/2026: 86/100

| Nhóm | Điểm | Nhận định chính |
|---|---:|---|
| Chức năng | 21/25 | Backend/mobile sâu, nhưng web chưa có Thiết bị/Bảo trì và một số thao tác quản trị còn thiên về quan sát |
| Kiểm thử | 17/20 | Backend/AI/Flutter có test; frontend chưa có E2E trình duyệt ổn định |
| Bảo mật | 14/15 | Kiểm soát tốt cho MVP; token web còn ở localStorage và secret production chưa cấp |
| Tin cậy | 14/15 | Offline/realtime/fallback tốt; chưa pilot dài trên mạng/thiết bị thật |
| UX | 8/10 | Giao diện nhất quán; thiếu hai miền nghiệp vụ và kiểm chứng accessibility toàn diện |
| Vận hành | 9/10 | Docker/runbook/backup tốt; TLS/FCM/release signing là cổng ngoài |
| Tài liệu | 3/5 | Master prompt rõ nhưng số API, migration và số test bị lệch source; README có link hỏng |

## Sau vòng 1: 90/100

| Nhóm | Điểm | Bằng chứng |
|---|---:|---|
| Chức năng | 23/25 | Đã thêm `/devices`, `/maintenance`, nối API thật, sidebar và RBAC |
| Kiểm thử | 18/20 | Full ESLint và Next.js production build PASS; backend 25/25, AI 10/10, Flutter analyze và 9/9 test PASS |
| Bảo mật | 14/15 | Không nới quyền; hai route mới dùng cùng role guard và JWT adapter |
| Tin cậy | 14/15 | Không thay đổi các bảo đảm ACK/retry/fallback đã có |
| UX | 9/10 | Có thống kê, tìm kiếm, lọc, loading/error/empty và label hỗ trợ đọc màn hình |
| Vận hành | 9/10 | Giữ nguyên Docker/runbook và build production |
| Tài liệu | 3/5 | Đã sửa các lệch chính; tại thời điểm vòng 1 báo cáo OpenAPI runtime chưa được sinh lại |

## Sau vòng 2 và hồi quy full stack: 93/100

| Nhóm | Điểm | Bằng chứng |
|---|---:|---|
| Chức năng | 23/25 | Các miền lõi chạy end-to-end; web đã phủ Thiết bị/Bảo trì; còn vài thao tác quản trị chưa có UI chỉnh sửa sâu |
| Kiểm thử | 18/20 | Backend 25/25, AI 10/10, Flutter 9/9, full frontend lint/build/Docker build và browser smoke PASS; chưa có browser E2E tái lập trong repository |
| Bảo mật | 14/15 | JWT/RBAC/ownership/STOMP/MinIO/agent confirmation PASS; token web localStorage là giới hạn production |
| Tin cậy | 15/15 | MySQL V7 sạch, offline ACK/retry, STOMP fallback, 5 service healthy, backup/restore V7 chữ ký trùng |
| UX | 9/10 | Browser xác minh hai trang tải dữ liệu thật, filter đúng và không có console error; chưa audit accessibility toàn diện |
| Vận hành | 10/10 | Rebuild full stack, health check, WebSocket smoke, backup/restore và cấu hình fail-fast đều có bằng chứng |
| Tài liệu | 4/5 | Contract/progress/scorecard đồng bộ; OpenAPI runtime 153 operation/134 path/167 schema đã sinh lại |

## Cổng còn lại để đạt từ 92 điểm

- Chuyển browser smoke hiện tại thành suite E2E lưu trong repository, mở rộng sang điều phối và SOS/realtime.
- Pilot Flutter trên thiết bị Android mục tiêu, mạng chập chờn, quyền camera/GPS/thông báo và FCM thật.
- Muốn vượt 96: cần domain/TLS, secret manager, release keystore, quan sát production và đánh giá mô hình trên dataset cabin có consent.

Không tuyên bố “hoàn thiện 100%” khi các cổng ngoài trên chưa có bằng chứng. Điểm được tăng chỉ khi có artifact hoặc kết quả kiểm thử tái lập.
