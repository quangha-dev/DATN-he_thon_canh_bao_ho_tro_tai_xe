# CODEX FULL PROGRESS — SAFE FLEET MVP

## 2026-08-02 — Sửa tiếng Việt dữ liệu chuyến + tràn biểu đồ 1 px

- Xác định chữ giao diện/font Flutter không lỗi; chỉ 10 chuyến demo bị sai encoding do PowerShell pipe nội dung SQL qua console code page, làm dữ liệu DB biến thành dấu `?`/mojibake.
- Script seed nay khai báo `SET NAMES utf8mb4`, được copy nguyên byte vào container và chạy bằng MySQL client `--default-character-set=utf8mb4`; không còn truyền SQL Unicode qua PowerShell text pipeline.
- Không xóa/recreate chuyến vì GPS telemetry đã tham chiếu. Dùng `ON DUPLICATE KEY UPDATE` để giữ nguyên ID, telemetry và chỉ sửa văn bản/JSON tại chỗ.
- Xác minh response API bằng cách giải mã raw bytes UTF-8: địa điểm, công trình, người nhận và tên hàng đều khớp chính xác tiếng Việt, không còn ký tự thay thế.
- Biểu đồ Nhịp độ 4 tuần tăng vùng cao 132→142 px và giảm chiều cao cột cực đại để loại bỏ `BOTTOM OVERFLOWED BY 1.00 PIXELS` trên Xiaomi.
- Flutter analyze PASS, 15/15 test PASS, APK debug build/cài đè thành công; log khởi động không có overflow/FATAL/Flutter error.

## 2026-08-02 — Bộ dữ liệu đầy đủ cho báo cáo tài xế 001

- Giữ nguyên chính xác **1 tài xế / 1 xe**; API xác nhận `drivers=1`, `vehicles=1` sau khi nạp dữ liệu.
- Thêm script idempotent `docker/scripts/seed_driver001_monthly_demo.sql`, chỉ tra tài khoản `driver001` và xe biển `001`, tuyệt đối không tạo driver/vehicle.
- Tháng 08/2026 hiện có 10 chuyến: 8 hoàn thành, 1 đã giao chờ chạy, 1 hủy; 7/8 chuyến hoàn thành đúng hạn, tỷ lệ hoàn thành 80%, tổng tuyến 496,5 km.
- Thêm 780 phút lái, 145 phút nghỉ, 3 ngày hoạt động và dữ liệu cảnh báo phân bố theo ngày. Mỗi chuyến có phiếu xuất kho, người nhận và mặt hàng thực tế khác nhau.
- Điểm an toàn tài xế được đặt 94 để giao diện hiển thị cấp **SILVER – Tài xế an toàn**. Huy hiệu: Tài xế an toàn và Tháng lái xe bình an đã đạt; Đúng hẹn 97% tiến độ; Bền bỉ cung đường 99% tiến độ.
- API thật `/mobile/activity/monthly?month=2026-08` xác nhận: 10/8 chuyến, 80% hoàn thành, 88% đúng giờ, 496,5 km, 780/145 phút lái/nghỉ, 5 cảnh báo tổng và 0 nghiêm trọng.

## 2026-08-02 — Phiếu xuất kho điện tử + thành tích tài xế theo tháng

- Giữ nguyên dữ liệu tối giản: API thật xác nhận đúng **1 tài xế 001** và **1 xe 001**, liên kết cố định; không seed hoặc tạo thêm phương tiện.
- Form giao chuyến web được chuẩn hóa theo phiếu xuất kho người dùng cung cấp: số phiếu, ngày xuất, kho/ngăn/lô, công trình/đơn vị nhận, hạng mục, người nhận và số điện thoại.
- Hàng hóa chuyển từ một chuỗi tự do thành danh sách nhiều dòng gồm mã số, tên/nhãn hiệu/quy cách, đơn vị, số lượng xuất, số lượng trả và xác nhận/lưu ý. Có thêm/xóa dòng và validation bắt buộc.
- Payload chuyến giữ `warehouseDocument` dạng JSON trong `plannedRoute`, gồm người lập phiếu, tài xế giao hàng, xe, trạng thái xác nhận và toàn bộ danh sách vật tư; vẫn giữ `cargoInfo` tóm tắt để tương thích chuyến cũ.
- App tài xế đọc và hiển thị phiếu theo nhóm chứng từ, nơi xuất/nhận, danh sách vật tư, người lập và người giao; chuyến cũ vẫn hiển thị theo định dạng cũ.
- API báo cáo tháng bổ sung: tỷ lệ hoàn thành, số/tỷ lệ đúng giờ, tổng km, ngày hoạt động, ngày không cảnh báo, cấp/thành tích tháng và 4 huy hiệu có tiến độ.
- Màn **Báo cáo & thành tích** được thiết kế lại với chọn tháng, hero huy hiệu, vận hành, an toàn/sức khỏe, tiến độ huy hiệu và biểu đồ nhịp độ 4 tuần.
- Kiểm thử: browser local xác nhận form tải đúng cặp `001 × 001` và thêm dòng hàng thứ hai; frontend lint/build PASS; backend Maven + MySQL Testcontainers PASS; Flutter analyze PASS và 15/15 test PASS.
- Backend/frontend Docker đã rebuild và healthy; API tháng thật của `driver001` trả đủ trường mới. APK LAN đã build, cài đè và mở thành công trên Xiaomi Android 14.

## 2026-08-02 — Nâng cấp nhận diện buồn ngủ theo pipeline mô hình gốc

- Đã đối chiếu toàn bộ mã Python người dùng cung cấp với pipeline Flutter và tìm ra nguyên nhân chính: app cũ dùng xác suất mở mắt của ML Kit thay cho EAR hình học, MAR sai thang đo và chỉ xử lý khoảng 2 FPS trong khi mô hình được huấn luyện ở 25 FPS.
- Camera mobile nay trích xuất EAR/MAR trực tiếp từ contour khuôn mặt, fallback sang xác suất mắt khi contour không đủ rõ; tăng độ phân giải lên medium và chu kỳ nhận frame xuống 80 ms. Nhận diện điện thoại được chạy mỗi 5 frame để giảm tải.
- Adapter mô hình giữ đúng chuỗi 75 frame × 12 đặc trưng: 6 đặc trưng EAR/MAR/Pitch/Yaw/Roll/Iris, hiệu chuẩn mean/std riêng tài xế, Savitzky–Golay, chuẩn hóa và 6 delta theo thời gian.
- Đã chuyển đầy đủ logic hybrid từ Python: mắt nhắm EAR < 0,10, ngáp MAR > 0,60, EAR lệch baseline, làm mượt EMA bất đối xứng, xu hướng hồi quy, dự báo 2 giây, tích lũy buồn ngủ và giữ cảnh báo. Dấu z-score mắt được sửa thành âm vì EAR giảm mới tương ứng mắt nhắm.
- Bộ phát hiện temporal và mô hình TFLite nay chạy đồng thời; cảnh báo mạnh hơn được chọn theo từng loại thay vì mô hình chính làm mất cảnh báo temporal.
- Màn Giám sát tỉnh táo được thiết kế lại: khung khóa khuôn mặt, tiến độ hiệu chuẩn, điểm nguy cơ 0–10, dự báo 2 giây, EAR, MAR, góc đầu, FPS, biểu đồ 60 lần suy luận và cảnh báo gần nhất. Không lộ tên kỹ thuật STGT/Temporal cho tài xế.
- Metadata model đã sửa đúng tên đặc trưng và mô tả pipeline runtime. Flutter analyze không có lỗi; test đạt 14/14, bao gồm tensor 75×12 và tình huống EAR 0,07 phát cảnh báo nguy hiểm.
- APK debug LAN `http://192.168.163.80:8080/api/v1` đã build và cài đè thành công lên Xiaomi 22011211C Android 14 (`JVKNYLBALV4LZDI7`); MainActivity mở đúng và log khởi động không có FATAL/CameraAccessException.

## 2026-08-02 — Làm sạch giao diện mobile cho người dùng thật

- Đã xóa hoàn toàn màn `Debug Settings` và mọi lối mở cấu hình máy chủ thử nghiệm khỏi Login/Home.
- Màn đăng nhập không còn nhãn kỹ thuật `JWT + refresh token`, `MySQL thật`; thay bằng thông điệp ngắn về đăng nhập an toàn.
- Màn camera và màn lái xe không còn cho tài xế chọn `ST-GT/Temporal`; hệ thống tự dùng mô hình chính và fallback nội bộ, giao diện chỉ hiển thị trạng thái `Giám sát tỉnh táo`.
- Notification camera không còn tên model nội bộ; chỉ hiển thị camera trước và số cảnh báo. Các thông báo khởi động/dự phòng cũng được đổi sang ngôn ngữ người dùng.
- APK sạch đã build/cài lại; Flutter analyze PASS, 14/14 test PASS. E2E emulator xác nhận không còn chuỗi debug/model và đăng nhập `driver001` thành công.

## 2026-08-02 — GPS điện thoại thật + hồ sơ Web + logo sidebar

- App mobile khởi động `VehicleLocationTracker` ngay sau đăng nhập, lấy `driverId/currentVehicleId` từ bootstrap và gửi GPS thật của điện thoại cho xe được gán, không còn phụ thuộc việc mở màn hình lái xe.
- Android dùng foreground location stream 10 giây/5 mét, notification thường trực `SafeFleet đang chia sẻ vị trí`, wake lock, quyền background location và hàng đợi SQLite để tự đồng bộ lại khi có mạng. Màn Quyền thiết bị xin quyền vị trí foreground trước rồi xin `Luôn cho phép` theo đúng luồng Android.
- Đã xóa tọa độ seed của xe `001`; Web chỉ có vị trí sau khi điện thoại gửi telemetry thật.
- E2E emulator: tọa độ đầu `21.0277983, 105.8341983`; sau khi bấm Home và đổi GPS nhiều lần, MySQL/API cập nhật đến tọa độ cuối `21.0349, 105.8461` cho xe `001`. Notification foreground và lần khởi động lại sau cài APK đều đã được xác minh.
- Nút **Hồ sơ cá nhân** trên Header đã điều hướng đến `/profile`; trang mới hiển thị danh tính, tài khoản, vai trò, trạng thái và thông tin bảo mật từ phiên đăng nhập thật.
- Đã xóa nút `Thu gọn/Mở rộng` ở cuối sidebar; logo SafeFleet là nút duy nhất dùng để thu gọn/mở rộng, có aria-label và focus ring.
- Badge sidebar không còn số mẫu cứng `3/2`; lấy cảnh báo mới và sự cố chưa xử lý từ API. Browser E2E xác nhận `Cảnh báo AI 1`, không còn badge SOS giả.
- Test cuối: frontend lint PASS, production build PASS với 18 route gồm `/profile`; Flutter analyze PASS, Flutter 14/14 PASS, APK debug PASS; Docker health PASS.

## 2026-08-02 — Dọn database về bộ dữ liệu tối giản 1–1–1

- Đã tạo backup đầy đủ trước khi xóa: `backups/safefleet-before-minimal-20260802-191520.sql`.
- Đã xóa cứng toàn bộ dữ liệu nghiệp vụ cũ: chuyến đi, sự cố, điểm ngập, bảo trì, telemetry, navigation, driving session, notification, sync, token và log kiểm thử.
- Database hiện có đúng **1 tài xế**, **1 tài khoản DRIVER**, **1 xe** và **1 cảnh báo an toàn**; không chỉ ẩn bằng soft-delete.
- Cặp duy nhất: tài xế `001` / `driver001` (id `1`) và xe `001` (id `1`), liên kết hai chiều cố định.
- Cảnh báo duy nhất: `DROWSINESS`, mức `HIGH`, trạng thái `NEW`, liên kết driver/vehicle `1/1`.
- Đã đặt tổng chuyến của tài xế về `0`, tổng cảnh báo về `1`; giấy đăng kiểm/bảo hiểm xe được đẩy thêm 365 ngày để không sinh cảnh báo tài liệu phụ.
- Xác minh MySQL: drivers `1`, vehicles `1`, driver accounts `1`, safety events `1`; trips/incidents/flood/maintenance/notifications/telemetry đều `0`.
- Xác minh API thật: `/drivers`, `/vehicles`, `/safety-events` đều trả `totalElements=1`; mã trả về đúng `001`, `001`, cảnh báo `DROWSINESS` liên kết driver/vehicle `1/1`. Backend health `UP`.
- Đã xóa SQLite/cache và phiên đăng nhập cũ của app Android trên `emulator-5554`, sau đó mở lại ứng dụng ở trạng thái sạch để không còn chuyến ngoại tuyến cũ.

## 2026-08-02 — Môi trường test một tài xế 001 × một xe 001

- Đã tạo backup phục hồi trước khi dọn dữ liệu: `backups/safefleet-20260802-162416.sql`.
- Database hiện chỉ còn **1 tài xế hoạt động**, **1 xe hoạt động** và **1 tài khoản DRIVER hoạt động**; các bản ghi mẫu khác được soft-delete/vô hiệu hóa.
- Cặp cố định: tài xế mã `001`, Nguyễn Văn An, driver id `1`, tài khoản `driver001`; xe mã/biển `001`, vehicle id `1`. Mật khẩu test giữ nguyên `123456`.
- Seeder cho database mới cũng chỉ sinh một cặp 001, một GPS và một camera; không tái tạo 15 tài xế/20 xe như trước.
- Form web gộp hai select thành một lựa chọn **Tài xế + xe được phân công**, tự chọn khi chỉ có một cặp, hiển thị mã 001, GPS, bằng lái và trạng thái sẵn sàng.
- Thêm thông tin hàng hóa bắt buộc, người giao chuyến lấy tự động từ tài khoản web và ghi cùng payload kế hoạch chuyến; ghi chú điều phối vẫn được giữ riêng.
- API bắt buộc cả `plannedStartTime` và `estimatedEndTime`; frontend/backend đều chặn khi thời gian kết thúc không sau thời gian khởi hành. Backend cũng từ chối ghép tài xế hoặc xe đã được phân công cố định cho đối tượng khác.
- E2E thật: web tạo `TRIP-20260802164603-4693`, 18:00–19:00, Mỹ Đình → Hà Đông, hàng `Thiết bị điện tử · 120 kg · 04 kiện`, người giao `Quan tri he thong`; MySQL lưu driver/vehicle `1/1`, trạng thái `ASSIGNED`.
- App emulator đăng nhập `driver001`, trang chủ hiển thị đúng **1 chuyến** và trang Lịch trình hôm nay hiển thị mã chuyến, giờ 18:00, xe 001, điểm đi/đến và trạng thái Đã giao.
- Chi tiết chuyến mobile giải mã `plannedRoute` và hiển thị đúng hàng hóa, người giao chuyến, ghi chú điều phối; APK mới đã cài và xác minh trực tiếp trên emulator.
- Test cuối: backend 25/25 PASS (9 integration MySQL), Flutter analyze PASS, Flutter 14/14 PASS, APK debug PASS, frontend lint PASS, Next production build 17 route PASS, Docker backend/frontend rebuild và health PASS.

## 2026-08-02 — Đồng bộ giao chuyến web → đúng tài khoản mobile

- Đã kiểm tra toàn bộ lát cắt `web dispatch → POST /api/v1/trips → MySQL → GET /api/v1/mobile/trips/today` bằng dữ liệu thật.
- Web đã giao thành công chuyến `TRIP-20260802155534-7360` (DB id `14`) cho `driver01`/driver id `1`; JWT của `driver01` nhận đúng 1 bản ghi, JWT `driver02`/driver id `2` nhận 0 bản ghi của chuyến này.
- Sửa truy vấn lịch trong ngày để vẫn hiển thị chuyến có kế hoạch hôm nay, chuyến thực tế bắt đầu/kết thúc hôm nay và mọi chuyến đang hoạt động, đồng thời luôn giới hạn theo tài xế lấy từ JWT.
- Viết lại màn **Lịch trình hôm nay**: tổng quan tiến độ ngày, bộ lọc Tất cả/Chưa đi/Đang chạy/Đã đi, nhóm theo trạng thái, timeline điểm đi–đến, xe, thời lượng, rủi ro, tiến độ và CTA theo đúng vòng đời chuyến.
- Sửa chi tiết chuyến: chuyến đang chạy tiếp tục chế độ lái; chuyến hoàn thành/đã hủy hiển thị trạng thái kết thúc thay vì cho khởi động sai quy trình.
- Sửa geocoder fallback để form web vẫn chọn được `Bến xe Mỹ Đình`/`Hà Đông` khi Photon không phản hồi; E2E trình duyệt đã tính tuyến OSRM 8,3 km và giao chuyến thành công.
- Bằng chứng kiểm thử: Maven full suite PASS với MySQL 8.4 Testcontainers; `flutter analyze --no-pub` PASS; `flutter test --no-pub` 13/13 PASS; APK debug build/cài emulator PASS; không có RenderFlex/FATAL trên màn lịch trình.
- E2E emulator cuối: tài khoản Nguyễn Văn An/`driver01` hiển thị **3 chuyến**, gồm **2 Chưa đi**, **1 Đã đi**; card `TRIP-20260802155534-7360` hiện đúng 20:00, Mỹ Đình → Hà Đông, xe `30H-100.01`.
- Ảnh kiểm tra giao diện: `docs/screenshots/trips_today.png`; APK: `safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk`.

## 2026-08-02 — Android foreground cabin monitoring

- Thêm foreground service loại `camera`, notification channel thường trực và
  actions **Mở SafeFleet** / **Dừng giám sát**.
- Flutter camera được bàn giao sang native Camera2 khi Activity `paused/hidden`,
  sau đó trả lại Flutter khi `resumed` để tránh tranh chấp camera.
- ML Kit native tiếp tục phát hiện nhắm mắt, PERCLOS và head pose khi app nền;
  cảnh báo được đếm trên notification và chuyển về offline safety queue khi
  Flutter engine còn sống.
- Test emulator Android 15: service `isForeground=true`, type camera `0x40`,
  camera `Device status: ACTIVE` sau khi nhấn Home, notification cập nhật đúng,
  quay lại app không có fatal/SecurityException/CameraAccessException.
- Giới hạn còn lại: cần pilot camera trước trên điện thoại vật lý, đo pin/nhiệt và
  hiệu chuẩn cabin ban đêm trước khi phát hành production.

> Đây là tài liệu khôi phục công việc nếu phiên Codex bị gián đoạn hoặc hết quota.  
> Cập nhật gần nhất: 02/08/2026 — Asia/Ho_Chi_Minh.  
> Trạng thái tổng thể: **MVP LOCAL/LAN PASS — còn release gate bên ngoài: thiết bị Android, FCM, TLS/keystore và dataset custom detector**.

## A. Yêu cầu hiện tại của người dùng

> “đây là master promt để bạn thực hiện bạn cần tự động lên kế hoạch tự đồng kiểm tra test từng API kết quả đầu vào đầu ra có thể test ngay dữ liệu thật. và tự loop triển khai _test _ sửa đến khi hoàn thiện toàn bộ hệ thống và đánh giá hoàn thành khắc phục được nỗi đau người dùng và có thể sử dụng ngay ngoài ra bạn cũng cần tạo file markdow chứa toàn bộ master và pỏmet hiện tại kèm hướng giải quyết và tiến độ dự án hiện tại để phòng trường hợp hết qota bị dừng đột ngội thiết kế giao diện chuyên nghiệp nhưng bố cục cũng cần sáng tạo hạn chế màu mè quá mức tone trắng chủ đạo.”

## B. Nguyên tắc thực thi đã chốt

1. Không đánh dấu DONE chỉ vì code compile; mỗi hạng mục phải có test, API thật, query MySQL và bằng chứng.
2. Ưu tiên P0 theo lát cắt end-to-end: migration → backend → test → Docker → API thật → DB → web/mobile.
3. Giữ lại và tái sử dụng code hiện có; không xóa hoặc đổi tên module đang hoạt động.
4. Dùng MySQL làm nguồn dữ liệu nghiệp vụ duy nhất; SQLite mobile chỉ làm cache/offline queue.
5. Flutter chạy trên host/emulator/điện thoại, không chạy trong Docker.
6. Giao diện web/mobile dùng nền trắng chủ đạo, phân cấp thị giác rõ, ít màu trang trí, màu trạng thái có chủ đích.
7. Không để thiếu OpenAI/Firebase/dịch vụ trả phí chặn MVP; luôn có fallback đã test.
8. Sau mỗi vòng lặp cập nhật tài liệu này, `CODEX_DECISIONS.md`, kết quả test và bằng chứng DB.

## C. Tiến độ hiện tại

| Phase | Trạng thái | Kết quả/Bằng chứng |
|---|---|---|
| 0. Khảo sát repo và lưu master prompt | PASS | Đã lưu toàn bộ master/current prompt; báo cáo runtime V7 hiện có 153 operation/134 path/167 schema |
| 1. Nền tảng Docker + MySQL + health | PASS | 5 service healthy: MySQL 8.4, backend, frontend, AI, MinIO; volume bền vững và script health/backup/restore |
| 2. Migration P0 + ownership/idempotency/evidence/push | PASS-FALLBACK | Flyway V1–V7; refresh rotation, ownership, agent confirmation, MinIO private mặc định, local-storage fallback và push polling fallback |
| 3. Mobile workflow transaction thống nhất | PASS | start/pause/resume/complete đồng bộ Trip, DrivingSession, Driver, Vehicle, Timeline và NavigationSession; integration test MySQL thật |
| 4. Telemetry batch + safety cooldown + SOS | PASS | Stable ACK, stale-position protection, client ID, cooldown, rate limit và timeline |
| 5. Navigation Hà Nội tránh ngập | PASS | Photon/OSRM + fallback, 3 alternatives, turn steps, flood scoring, BLOCKED detour, off-route 75 m/15 s, reroute và DB session |
| 6. Flutter Driver App | PASS build / external device gate | 14 màn/luồng, secure auth, SQLite offline queue đủ mọi loại, GPS, MapLibre, AI on-device; source có 9 test, debug APK PASS |
| 7. Python AI service + tooling | PASS-FALLBACK | FastAPI + temporal engine + train/evaluate/export/benchmark; 10/10 test; custom dataset/model là gate ngoài |
| 8. Web realtime + giao diện trắng chuyên nghiệp | PASS | Next 16.2.12, MapLibre, STOMP JWT, polling fallback; đã thêm Thiết bị/Bảo trì; lint/build PASS |
| 9. Integration/E2E/DB verification | PASS | Backend 25/25 gồm 9 integration MySQL; API/DB/MinIO/restart/WebSocket và backup–restore database tạm PASS |
| 10. Hardening + tài liệu + DoD | PASS local/LAN | Non-root, CORS/JWT, production dependency audit 0; báo cáo OpenAPI V7 đã sinh lại |

## D. Hiện trạng repository đã xác minh

- Workspace root: `D:\DEV\Project\DATN\DATN-he_thon_canh_bao_ho_tro_tai_xe`.
- `web_quan_ly/backend`: Spring Boot 3.3.7/Java 21, 153 REST mapping, JWT/RBAC, STOMP JWT, MySQL/Flyway V1–V7, MinIO evidence/push/navigation/mobile workflow và agent confirmation.
- `web_quan_ly/frontend`: Next.js 16.2.12/React 19, 17 route build gồm `_not-found`, MapLibre, REST + STOMP realtime/polling.
- `safe_fleet_driver_ui`: Flutter 3.44.5, secure auth, GPS, offline queue, navigation và AI camera on-device.
- `safefleet_ai`: FastAPI + temporal rules + train/evaluate/export/benchmark.
- Docker: MySQL/backend/frontend/AI/MinIO, healthcheck và ba persistent volume.
- Tài liệu hiện hành:
  - `BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md`.
  - `docs/API_MOBILE_CONTRACT.md`.
  - `docs/DATABASE_VERIFICATION.md`.
  - `docs/REQUIREMENT_TRACEABILITY.md`.
- APK debug: `safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk`.
- Các blocker bên ngoài được liệt kê tại Loop 6, không có TODO P0 âm thầm trong code.

## E. Hướng giải quyết theo phase

### Phase 0 — Audit và guardrails

- Tạo tài liệu tiến độ, quyết định, runbook, contract, DB verification.
- Chụp baseline test backend/frontend.
- Lập ma trận yêu cầu master ↔ code ↔ test.

### Phase 1 — Docker/MySQL/health

- Tạo `.env.example`, compose production/dev, Dockerfile multi-stage.
- Thêm Actuator, Docker profile, `ddl-auto=validate`, stdout logging.
- MySQL app user, volume, healthcheck; MinIO; AI service skeleton; Adminer dev.
- Test `docker compose config/build/up/health/restart`.

### Phase 2 — Backend P0

- Migration tiếp theo cho mobile device, idempotency, sync batch, navigation, evidence, push queue.
- Ownership helper thống nhất.
- Notification ownership.
- Idempotency service và constraint.
- Protected evidence upload/presigned flow.
- Rate limit cơ bản cho SOS/agent.

### Phase 3 — Workflow và telemetry

- API workflow transaction start/pause/resume/complete.
- Checklist bắt buộc pass.
- Đồng bộ Trip/DrivingSession/Driver/Vehicle/Timeline/NavigationSession.
- Telemetry batch với `clientEventId`, `batchId`, ACK và chống bản ghi cũ ghi đè current position.

### Phase 4 — Navigation Hà Nội

- `RoutingProvider` + OSRM alternatives/steps.
- Flood filtering theo status/expiry/severity.
- Point-to-polyline, scoring, BLOCKED reject, detour fallback.
- Off-route 75 m/15 s, reroute, navigation events và current session.
- Cache response phù hợp và test deterministic.

### Phase 5 — Flutter

- Tạo app theo feature-first/Clean Architecture vừa đủ.
- Secure token storage, Dio client, Drift offline queue.
- Màn hình bắt buộc và driving mode voice-first.
- MapLibre, permission, background telemetry, queue priority.
- Unit/widget tests, analyze, Android build.

### Phase 6 — AI

- FastAPI intent fallback/metadata/evaluation.
- Training/evaluation/export/benchmark scripts.
- On-device contracts và model metadata; không train lúc container start.
- OpenAI structured fallback chỉ server-side và có confirmation.

### Phase 7 — Web và E2E

- Theme trắng chuyên nghiệp, layout sáng tạo nhưng tiết chế.
- STOMP auth/subscription và cập nhật map/safety/SOS/flood.
- Hoàn thiện devices/maintenance/navigation visibility nếu cần.
- Chạy flow app/API → MySQL → web và lưu bằng chứng.

### Phase 8 — Hardening và DoD

- Testcontainers MySQL, regression đầy đủ.
- Backup/restore, restart persistence, non-root image, secret scan.
- Tài liệu vận hành LAN/device, known limitations và báo cáo cuối.

## F. Nhật ký vòng lặp

### Loop 0 — 26/07/2026

- Trạng thái: DOING.
- Đã làm:
  - Đọc toàn bộ master prompt.
  - Xác minh cấu trúc thực tế.
  - Kiểm tra công cụ Docker/Flutter/Java/Maven/Node.
  - Tạo mục tiêu dài hạn trong Codex.
  - Tạo tài liệu khôi phục này.
- Tiếp theo:
  - Tạo tài liệu quyết định và ma trận gap.
  - Chạy baseline backend test, frontend lint/build.
  - Kiểm tra Docker daemon và MySQL hiện có.
- Chưa được phép kết luận DONE.

### Loop 1 — 26/07/2026

- Trạng thái: PASS phần baseline; DOING backend P0/full stack.
- Đã làm:
  - Tạo Docker Compose production/dev, Dockerfile multi-stage non-root, healthcheck, scripts vận hành và `.env.example`.
  - Tạo FastAPI AI service; 3/3 test PASS.
  - Nâng Testcontainers lên 2.0.5 tương thích Docker Engine 29.
  - Backend 19/19 test PASS; Flyway V1–V4 chạy trên MySQL 8.4 sạch.
  - Frontend lint và Docker production build PASS.
  - Thêm V4 cho mobile device, refresh token, idempotency, sync batch, telemetry client ID, navigation, evidence, push queue và notification read theo user.
  - Sửa seed ngập Hà Nội thành `[DEMO]`, nguồn `MANUAL`.
  - Bổ sung auth refresh rotation/logout và sửa notification ownership.
  - Tạo `docs/REQUIREMENT_TRACEABILITY.md`.
- Lỗi đã phát hiện và xử lý:
  - Integration test cũ dùng database ngoài dự án và credential hard-code → thay bằng Testcontainers MySQL.
  - Testcontainers 1.x gọi Docker API quá cũ → nâng 2.0.5.
  - Cổng host MySQL 3306 bị chiếm → SafeFleet chuyển sang 3307, không tác động dịch vụ ngoài phạm vi.
- Đang làm:
  - Build/regression source mới nhất và khởi động toàn stack.
  - Gọi API thật, query DB, kiểm tra restart/persistence.
- Chưa được phép kết luận DONE.

### Loop 2 — 26/07/2026

- Trạng thái: PASS backend workflow/offline sync; DOING navigation/mobile.
- Đã làm:
  - Bổ sung workflow transaction thống nhất `start/pause/resume/complete` và current driving session.
  - Bổ sung telemetry batch với `batchId`, `clientEventId`, ACK từng item, replay ổn định và ngăn dữ liệu offline cũ ghi đè vị trí mới.
  - Flyway V5 lưu ACK item và toàn bộ trường chấm điểm/navigation.
  - Integration test MySQL thật tăng lên 7 luồng và toàn bộ backend đạt 20/20.
  - Xây dựng navigation provider OSRM/Photon và fallback local xác định được; route có tối thiểu 3 alternatives, geometry đầy đủ và turn steps.
  - Hoàn thiện flood scoring theo point-to-polyline/severity/freshness, reject BLOCKED, detour vuông góc, off-route liên tục 15 giây và reroute.

### Loop 3 — 26/07/2026

- Trạng thái: PASS Flutter build; PASS UI web production build.
- Đã làm:
  - Tạo đầy đủ module `safe_fleet_driver_ui` với secure token, refresh retry, SQLite offline queue và cấu hình LAN/debug.
  - Hoàn thiện Login, Permission Setup, Home, Trips Today, Trip Detail, Checklist, Driving Mode, Flood, SOS, Notifications, Safety Summary, Agent và Debug Settings.
  - Driving Mode lấy GPS thật, gửi telemetry mỗi 5 giây, vẽ route/alternatives, phát hiện off-route/reroute và điều khiển workflow.
  - `flutter analyze --no-pub` PASS, `flutter test --no-pub` 2/2 PASS và tạo APK debug thành công.
  - Cải tiến web Command Center bằng bản đồ MapLibre thật, dữ liệu GPS/ngập/incident thật và thiết kế trắng/navy/teal tiết chế.
  - Frontend lint và Docker Next.js production build (17 route) PASS.

### Loop 4 — 26/07/2026

- Trạng thái: PASS full-stack Docker; DOING hardening P0.
- Đã làm:
  - Rebuild backend/frontend mới nhất, chạy 5 container healthy và health-check toàn stack PASS.
  - Gọi navigation API Docker với OSRM thật: geometry 326 điểm, 15 turn steps, flood penalty và giao cắt ngập được tính; lưu navigation session/candidates/events vào MySQL.
  - Gọi workflow driver thật từ Docker đến MySQL và hoàn thành chuyến.
  - Thêm scheduler tự chuyển report ngập hết hạn và bảo đảm OSRM trả thiếu alternative vẫn có đủ 3 phương án.
- Đang làm:
  - Protected evidence storage, push token/queue, safety cooldown, SOS idempotency/rate limit và WebSocket auth.
  - Tooling AI và on-device detection contract/runtime.
  - E2E cuối, query DB chứng minh, cập nhật API contract/traceability/báo cáo tích hợp.
- Điểm nối lại chính xác:
  - Docker đang chạy tại frontend `:3000`, backend `:8080`, AI `:8000`, MinIO `:9000/9001`, MySQL host `:3307`.
  - APK: `safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk`.
  - Không sửa migration V1–V5 đã áp dụng; mọi schema mới phải bắt đầu từ V6.
  - Chưa được phép kết luận DONE.

### Loop 7 — 27/07/2026

- Trạng thái: PASS vòng audit/source-sync/full-stack; tổng điểm local/LAN 93/100; còn cổng kiểm chứng ngoài repository.
- Đã làm:
  - Đọc toàn bộ tài liệu Markdown nội bộ và đối chiếu trực tiếp controller, migration, test và route hiện hành.
  - Xác nhận source có 153 REST mapping, Flyway V1–V7, backend 25 test (9 MySQL integration), AI 10 test và Flutter 9 test khai báo.
  - Bổ sung hai màn hình web còn thiếu `/devices` và `/maintenance`, dùng REST thật, menu và role guard hiện hành.
  - Full ESLint PASS; Next.js production build PASS với 17 route entry (16 route app và `_not-found`).
  - Backend 25/25, AI 10/10, Flutter analyze và 9/9 test PASS.
  - Rebuild 5 service Docker PASS; HTTP health 4/4; STOMP authenticated `CONNECTED`, anonymous `ERROR`.
  - Sinh lại OpenAPI runtime: 153 operation/134 path/167 schema.
  - Backup/restore V7 PASS; source/restored signature trùng và database tạm được dọn.
  - Browser smoke PASS: admin thấy 10 thiết bị/3 phiếu bảo trì, tìm kiếm lọc đúng; driver không thấy menu và không đọc được nội dung route bị chặn; console 0 lỗi.
  - Sửa link tài liệu hỏng, đồng bộ contract agent confirm/cancel và tạo `docs/QUALITY_SCORECARD.md`.
- Còn phải xác minh/tinh chỉnh:
  - Đóng gói browser smoke thành suite E2E tái lập; pilot Flutter/FCM/camera/GPS/mất mạng trên thiết bị thật.
  - Release production cần domain/TLS, secret manager, keystore và dataset cabin có consent.

---

# G. BẢN SAO ĐẦY ĐỦ MASTER PROMPT

## MASTER PROMPT DUY NHẤT CHO CODEX

### HOÀN THIỆN TOÀN BỘ SAFE FLEET MVP + DOCKER + DATABASE THẬT + MOBILE + AI + DẪN ĐƯỜNG HÀ NỘI

## 0. MỤC TIÊU

Bạn là Codex Agent chịu trách nhiệm hoàn thiện toàn bộ dự án SafeFleet theo hướng production-ready MVP.

Bạn phải tự:

- Khảo sát repository hiện tại.
- Xác định phần nào đã có, phần nào lỗi, phần nào chỉ là mock/UI.
- Hoàn thiện backend Spring Boot dùng chung cho web và app mobile.
- Hoàn thiện Flutter Driver App.
- Hoàn thiện web quản lý để đọc đúng dữ liệu do app mobile tạo.
- Hoàn thiện repo Python AI phục vụ train, evaluate, export model và AI service.
- Docker hóa toàn bộ các dịch vụ server.
- Kết nối MySQL thật.
- Viết Flyway migration.
- Xây dựng hệ thống dẫn đường và tránh ngập trong phạm vi Hà Nội.
- Chạy test tự động.
- Chạy integration test với MySQL thật.
- Kiểm tra dữ liệu thật trong database.
- Sửa lỗi và tự lặp lại cho đến khi toàn bộ Definition of Done đạt PASS.
- Không được dừng ở việc tạo giao diện, tạo file mẫu hoặc viết TODO.

## 1. VỊ TRÍ REPOSITORY DỰ KIẾN

Repository gốc:

`D:\DEV\Project\DATN\DATN-he_thon_canh_bao_ho_tro_tai_xe`

Cấu trúc dự kiến:

```text
DATN-he_thon_canh_bao_ho_tro_tai_xe/
├── web_quan_ly/
│   ├── backend/                    # Spring Boot
│   └── frontend/                   # Next.js
├── safe_fleet_driver_ui/           # Flutter app
├── safefleet_ai/                   # Python AI
├── docker/
├── docs/
├── docker-compose.yml
├── docker-compose.dev.yml
├── .env.example
└── README.md
```

Nếu cấu trúc thực tế khác:

- Tự khảo sát.
- Không tự ý xóa hoặc đổi tên module đang hoạt động.
- Điều chỉnh đường dẫn trong tài liệu.
- Giữ lịch sử Git sạch và dễ review.

## 2. KIẾN TRÚC CUỐI CÙNG PHẢI ĐẠT

```text
Flutter Driver App
        │
        │ REST / WebSocket / FCM
        ▼
Spring Boot Backend
        │
        ├── MySQL
        ├── Redis nếu thực sự cần cho cache/idempotency/queue
        ├── MinIO hoặc local object storage cho ảnh bằng chứng
        ├── Python AI Service
        └── Photon / OSRM / OpenAI / Firebase

Next.js Web Command Center
        │
        └── dùng chung Spring Boot Backend và MySQL
```

Nguyên tắc:

- Web và mobile không có backend riêng.
- Spring Boot là backend nghiệp vụ duy nhất.
- MySQL là nguồn dữ liệu nghiệp vụ duy nhất.
- SQLite trên điện thoại chỉ là cache và offline queue.
- Python không thay thế Spring Boot trong nghiệp vụ chuyến, tài xế, xe, SOS hoặc GPS.
- AI camera thời gian thực chạy on-device.
- OpenAI chỉ được gọi qua backend.
- Docker chỉ chạy các dịch vụ server.
- Flutter app chạy trên máy host, emulator hoặc điện thoại thật; không cố chạy app mobile trong Docker.

## 3. CÁC DỊCH VỤ DOCKER PHẢI CÓ

Tạo một hệ thống Docker Compose hoàn chỉnh gồm tối thiểu:

- mysql
- backend
- frontend
- ai-service

Khuyến nghị thêm nếu phù hợp với code:

- redis
- minio
- adminer chỉ trong profile dev

### 3.1. MySQL

Yêu cầu:

- MySQL 8.4 hoặc phiên bản tương thích.
- Database: safefleet.
- Charset utf8mb4.
- Timezone Asia/Ho_Chi_Minh.
- Persistent volume.
- Healthcheck.
- Không expose root password trong Git.
- App user riêng, không dùng root.
- Flyway do backend thực hiện.
- Không dùng H2.

### 3.2. Backend

Tạo multi-stage Dockerfile: Maven build stage → JRE/JDK runtime stage.

Yêu cầu:

- Java 21.
- Chạy non-root user.
- Copy jar tối thiểu.
- Có healthcheck.
- Profile Docker riêng.
- Bind 0.0.0.0.
- Không chứa secret trong image.
- Chờ MySQL healthy trước khi start.
- Flyway chạy tự động.
- `ddl-auto=validate`.
- Log ra stdout.
- Có endpoint health.

### 3.3. Frontend

Tạo multi-stage Dockerfile: Node install → build → production runtime.

Yêu cầu:

- Không hard-code localhost.
- Browser gọi backend qua URL truy cập được từ máy người dùng.
- Có biến môi trường public API URL.
- Chạy non-root.
- Healthcheck.
- Build production thành công.
- Web local đọc dữ liệu thật từ backend Docker.

### 3.4. AI Service

Tạo repo hoặc module `safefleet_ai`.

Tạo Dockerfile Python:

- Python 3.11 hoặc phiên bản tương thích.
- FastAPI.
- Uvicorn/Gunicorn.
- Non-root user.
- Healthcheck.
- Requirements khóa version.
- Không đóng gói dataset lớn vào image.
- Model mount bằng volume hoặc artifact folder.
- OpenAI key chỉ qua environment.

AI service chỉ phụ trách:

- Intent classification fallback.
- Model metadata.
- Model version.
- Evaluation endpoint nếu cần.
- Xử lý AI server-side không thời gian thực.
- Không gửi video cabin liên tục vào service.

### 3.5. Redis

Chỉ thêm nếu code thực sự sử dụng cho:

- Idempotency.
- Cache routing.
- Retry notification.
- Pub/Sub.
- Rate limiting.

Nếu thêm:

- Persistent volume nếu cần.
- Healthcheck.
- Password qua environment.
- Không dùng Redis thay MySQL làm nguồn dữ liệu nghiệp vụ.

### 3.6. MinIO

Nên dùng cho:

- Ảnh cảnh báo AI.
- Ảnh điểm ngập.
- Ảnh sự cố.
- Evidence.

Yêu cầu:

- Bucket tự tạo khi startup.
- Credential qua environment.
- URL không public mặc định.
- Backend tạo presigned URL hoặc endpoint được bảo vệ.
- Không để app mobile upload trực tiếp bằng secret key.

## 4. FILE DOCKER BẮT BUỘC

Phải tạo hoặc hoàn thiện:

```text
docker-compose.yml
docker-compose.dev.yml
.env.example
.dockerignore
web_quan_ly/backend/Dockerfile
web_quan_ly/backend/.dockerignore
web_quan_ly/frontend/Dockerfile
web_quan_ly/frontend/.dockerignore
safefleet_ai/Dockerfile
safefleet_ai/.dockerignore
docker/mysql/init/
docker/minio/
docker/scripts/
```

### 4.1. docker-compose.yml

Dùng cho stack hoàn chỉnh. Phải có:

- Named volumes.
- Internal network.
- Healthchecks.
- `depends_on` với `condition: service_healthy` khi được hỗ trợ.
- Restart policy hợp lý.
- Resource limits nếu có thể.
- Port mapping rõ ràng.
- Không ghi secret trực tiếp.
- Tất cả config từ `.env`.

### 4.2. docker-compose.dev.yml

Dùng cho development:

- Mount source nếu hợp lý.
- Adminer tùy chọn.
- Expose port dễ debug.
- Seed demo bật.
- Log level DEBUG.
- Không thay đổi dữ liệu production.

### 4.3. `.env.example`

Bao gồm toàn bộ biến cần thiết nhưng không có secret thật:

```dotenv
MYSQL_DATABASE=safefleet
MYSQL_USER=safefleet
MYSQL_PASSWORD=change_me
MYSQL_ROOT_PASSWORD=change_me

BACKEND_PORT=8080
FRONTEND_PORT=3000
AI_SERVICE_PORT=8000

JWT_SECRET=change_me_long_random
JWT_EXPIRATION_MINUTES=1440

OPENAI_API_KEY=
OPENAI_ENABLED=false

FIREBASE_ENABLED=false
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_PATH=

MINIO_ROOT_USER=change_me
MINIO_ROOT_PASSWORD=change_me
MINIO_BUCKET=safefleet-evidence

REDIS_ENABLED=false
REDIS_PASSWORD=

PHOTON_URL=https://photon.komoot.io/api/
OSRM_URL=https://router.project-osrm.org

MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty

SEED_ENABLED=true
HANOI_DEMO_DATA_ENABLED=true
```

### 4.4. Script vận hành

Tạo script PowerShell và Bash:

```text
docker/scripts/start.ps1
docker/scripts/stop.ps1
docker/scripts/reset-local.ps1
docker/scripts/health-check.ps1
docker/scripts/db-backup.ps1
docker/scripts/db-restore.ps1

docker/scripts/start.sh
docker/scripts/stop.sh
docker/scripts/health-check.sh
```

`reset-local` phải yêu cầu xác nhận trước khi xóa volume.

## 5. QUY TẮC DATABASE THẬT

### 5.1. Cấm

Không được:

- Dùng H2 runtime.
- Dùng fake repository.
- Trả dữ liệu hard-code.
- Lưu nghiệp vụ chỉ trong Flutter.
- Dùng SQLite làm DB server.
- Dùng `ddl-auto=create`.
- Bỏ Flyway.
- Tạo dữ liệu giả trong controller.
- Chạy integration test bằng H2.

### 5.2. Bắt buộc

- MySQL thật.
- Flyway.
- `ddl-auto=validate`.
- Transaction.
- Foreign key.
- Index.
- Unique constraint.
- Audit field.
- Timezone thống nhất.
- Query xác minh sau mỗi flow.

### 5.3. Các bảng hiện có phải được kiểm tra

`users`, `roles`, `permissions`, `drivers`, `vehicles`, `devices`, `trips`, `trip_timelines`, `telemetry_logs`, `safety_events`, `driving_sessions`, `driver_work_logs`, `incidents`, `incident_timelines`, `flood_reports`, `notifications`, `system_settings`, `pre_trip_checklists`, `agent_commands`, `audit_logs`.

### 5.4. Các bảng cần bổ sung nếu chưa có

`mobile_devices`, `idempotency_records`, `sync_batches`, `navigation_sessions`, `navigation_route_candidates`, `navigation_events`, `safety_event_evidence`, `push_tokens`, `pending_push_notifications`.

### 5.5. Quy tắc migration

- Đọc migration hiện có trước.
- Tạo version tiếp theo.
- Không sửa migration đã chạy.
- Không xóa cột đang dùng.
- Có index hợp lý.
- Có dữ liệu seed local riêng.
- Có rollback plan trong tài liệu.

## 6. SEED DỮ LIỆU HÀ NỘI

Chỉ bật local/dev. Tạo tối thiểu:

- 1 admin.
- 1 fleet manager.
- 1 dispatcher.
- 1 safety officer.
- 1 rescue user.
- 2 driver.
- 2 vehicle.
- 2 GPS device.
- 1 cabin camera.
- 4 trip Hà Nội.
- 8 flood report demo.

Tuyến test:

- Hà Đông → Cầu Giấy.
- Mỹ Đình → Kiều Mai.
- Phú Diễn → Nguyễn Trãi.
- Đại lộ Thăng Long → Phạm Văn Đồng.

Tất cả điểm ngập demo phải:

- Có prefix `[DEMO]`.
- Source `MANUAL`.
- Có `expiredAt`.
- Có `confidence`.
- Có `status`.
- Không được trình bày là dữ liệu thực tế.

Dữ liệu seed phải vào MySQL qua Flyway hoặc seeder backend, không hard-code trong Flutter.

## 7. QUY TRÌNH TỰ LOOP

Tạo:

```text
docs/CODEX_FULL_PROGRESS.md
docs/CODEX_DECISIONS.md
docs/DOCKER_RUNBOOK.md
docs/LOCAL_DEVICE_TEST.md
docs/API_MOBILE_CONTRACT.md
docs/DATABASE_VERIFICATION.md
```

Mỗi vòng lặp:

1. Chọn một hạng mục P0.
2. Ghi trạng thái DOING.
3. Viết migration nếu cần.
4. Viết backend.
5. Viết test.
6. Chạy test.
7. Build Docker image.
8. Start stack.
9. Gọi API thật.
10. Query MySQL.
11. Kiểm tra web.
12. Kiểm tra mobile.
13. Sửa lỗi.
14. Chạy regression.
15. Ghi bằng chứng.
16. Đánh dấu DONE.
17. Chuyển hạng mục tiếp theo.

Không được đánh dấu DONE chỉ vì code compile.

Nếu lỗi:

- Đọc log.
- Sửa nguyên nhân gốc.
- Rebuild.
- Restart đúng service.
- Chạy lại test.
- Không bỏ qua test.

Nếu thiếu key:

- Dùng fallback miễn phí.
- Không chặn MVP.
- Ghi rõ trong tài liệu.

## 8. BACKEND MOBILE PHẢI HOÀN THIỆN

### 8.1. Auth

```text
POST /api/v1/auth/login
GET  /api/v1/auth/me
```

Yêu cầu:

- Chỉ DRIVER vào Driver App.
- Token lưu an toàn.
- Không log token.
- Production không dùng secret mặc định.

### 8.2. Bootstrap

```text
GET /api/v1/mobile/me
GET /api/v1/mobile/config
GET /api/v1/mobile/safety-summary
GET /api/v1/mobile/current-assignment
GET /api/v1/mobile/notifications
```

### 8.3. Trip

```text
GET  /api/v1/mobile/trips/today
GET  /api/v1/mobile/trips/{id}
GET  /api/v1/mobile/trips/{id}/summary
POST /api/v1/mobile/trips/{id}/accept
POST /api/v1/mobile/trips/{id}/pre-trip-checklist
```

### 8.4. Workflow thống nhất

Tạo:

```text
POST /api/v1/mobile/trips/{id}/start-workflow
POST /api/v1/mobile/trips/{id}/pause-workflow
POST /api/v1/mobile/trips/{id}/resume-workflow
POST /api/v1/mobile/trips/{id}/complete-workflow
GET  /api/v1/mobile/driving-sessions/current
```

Trong cùng transaction:

- Trip.
- DrivingSession.
- Driver.
- Vehicle.
- TripTimeline.
- NavigationSession.

Start phải bị chặn nếu:

- Checklist chưa có.
- Checklist fail.
- Trip không thuộc driver.
- Vehicle không thuộc trip.
- Driver có active session khác.
- Trip sai trạng thái.

### 8.5. Telemetry

```text
POST /api/v1/mobile/telemetry
POST /api/v1/mobile/telemetry/batch
```

Yêu cầu:

- `clientEventId`.
- `batchId`.
- Idempotency.
- Ownership.
- Không để offline record cũ ghi đè current position mới.
- Ghi MySQL.
- Push WebSocket.

### 8.6. Safety

```text
POST /api/v1/mobile/safety-events
GET  /api/v1/mobile/safety-events/today
POST /api/v1/mobile/evidence
```

Yêu cầu:

- Không spam event.
- Cooldown.
- Evidence qua MinIO/local storage.
- URL được bảo vệ.
- Driver/vehicle/trip từ context.

### 8.7. SOS

```text
POST /api/v1/mobile/incidents/sos
GET  /api/v1/mobile/incidents
GET  /api/v1/mobile/incidents/{id}
GET  /api/v1/mobile/incidents/{id}/timeline
```

Yêu cầu:

- Idempotency.
- Priority cao.
- Timeline.
- Web nhìn thấy.
- App nhìn thấy trạng thái sau khi web accept.

### 8.8. Flood

```text
GET  /api/v1/mobile/flood-points/nearby
POST /api/v1/mobile/flood-reports/quick
POST /api/v1/mobile/route-check
```

Yêu cầu:

- Backend tự gắn driver/source.
- Report hết hạn không dùng.
- Scheduler expire.
- Tất cả dữ liệu từ MySQL.

### 8.9. Notifications

```text
GET    /api/v1/mobile/notifications
PATCH  /api/v1/mobile/notifications/{id}/read
PATCH  /api/v1/mobile/notifications/read-all
POST   /api/v1/mobile/push-tokens
DELETE /api/v1/mobile/push-tokens/{deviceUuid}
```

## 9. HỆ THỐNG DẪN ĐƯỜNG HÀ NỘI

### 9.1. Mục tiêu

Phải test được ngay:

- Map Hà Nội.
- Search địa điểm.
- Route.
- Alternative routes.
- Turn steps cơ bản.
- Flood scoring.
- Route tránh ngập.
- Off-route detection.
- Reroute.
- Route cache offline.
- Lưu navigation session vào MySQL.

### 9.2. Công nghệ

- Flutter MapLibre.
- OpenFreeMap.
- Photon.
- OSRM.
- MySQL flood reports.

Không bắt buộc Google Maps. Không gọi Photon/OSRM trực tiếp từ app; gọi qua backend.

### 9.3. API

```text
GET  /api/v1/mobile/locations/autocomplete
POST /api/v1/mobile/navigation/routes
POST /api/v1/mobile/navigation/reroute
POST /api/v1/mobile/navigation/events
GET  /api/v1/mobile/navigation/current
```

### 9.4. OSRM

Gọi:

```text
/route/v1/driving/{coordinates}
?alternatives=3
&steps=true
&geometries=geojson
&overview=full
```

Tạo interface:

- `RoutingProvider`.
- `OsrmRoutingProvider`.

Không đặt logic HTTP ngoài controller/service.

### 9.5. Chấm điểm ngập

Chỉ lấy flood report:

- `status IN (UNVERIFIED, VERIFIED)`.
- `expiredAt > now`.
- `severity >= MEDIUM`.

Tính point-to-polyline.

Ngưỡng:

- 0–100 m: hệ số 1.0.
- 100–200 m: hệ số 0.7.
- 200–300 m: hệ số 0.4.
- >300 m: bỏ qua.

Severity:

- `NONE=0`.
- `LOW=5`.
- `MEDIUM=30`.
- `HIGH=100`.
- `BLOCKED=reject route`.

Freshness:

- <=30 phút: 1.0.
- 30–90 phút: 0.8.
- 90–180 phút: 0.5.
- hết hạn: 0.

Score:

```text
totalScore =
durationMinutes
+ distanceKm
+ floodPenalty
+ vehicleRestrictionPenalty
+ driverTimePenalty
```

Driver time penalty tăng nếu ETA lớn hơn remaining driving time.

### 9.6. Detour fallback

Nếu mọi OSRM alternative đều bị BLOCKED:

1. Chọn flood point nguy hiểm nhất.
2. Tìm segment gần nhất.
3. Tạo hai waypoint lệch vuông góc 800–1500 m.
4. Gọi OSRM qua waypoint A.
5. Gọi OSRM qua waypoint B.
6. Chấm điểm lại.
7. Chọn tuyến safe tốt nhất.

Nếu không có tuyến safe:

- Trả tuyến ít rủi ro nhất.
- `safe=false`.
- Không tuyên bố tuyến an toàn.

### 9.7. Off-route

- Khoảng cách >75 m.
- Liên tục 15 giây.
- GPS accuracy hợp lệ.
- Gọi reroute.
- Lưu navigation event DB.

### 9.8. Test

- Không ngập.
- Ngập HIGH.
- BLOCKED.
- Report expired.
- Alternative route.
- Detour.
- Offline cache.
- Reroute.
- DB navigation session.

## 10. FLUTTER APP

### 10.1. Màn hình

- Splash.
- Login.
- Permission Setup.
- Home.
- Trips Today.
- Trip Detail.
- Checklist.
- Driving Mode.
- Flood Report.
- SOS Status.
- Notifications.
- Safety Summary.
- Agent Voice Sheet.
- Debug Settings chỉ local.

### 10.2. Driving Mode

Hiển thị:

- Map.
- Route.
- Xe.
- Flood marker.
- Next maneuver.
- Speed.
- Remaining driving time.
- GPS status.
- AI status.
- Network status.
- Sync queue.
- Voice.
- SOS.
- Pause/Resume.

Khi xe đang chạy:

- Không form dài.
- Không popup che bản đồ.
- Voice-first.
- Nút lớn.

### 10.3. Offline queue

Dùng Drift/SQLite.

Priority:

1. SOS.
2. CRITICAL safety.
3. HIGH safety.
4. trip workflow.
5. flood report.
6. telemetry.

Batch telemetry. Không xóa item trước server ACK.

### 10.4. Local device test

Backend Docker expose `0.0.0.0:8080`.

App điện thoại dùng:

`http://<IP-LAN-PC>:8080/api/v1`

Không dùng localhost. Tạo màn debug local để đổi base URL nhưng không bật production.

## 11. AI ON-DEVICE

### 11.1. Drowsiness

```text
Camera
→ Face landmarks
→ EAR/PERCLOS/head pose/yawn
→ temporal rules
→ local warning
→ server event
```

### 11.2. Phone usage

```text
YOLO phone
+ face/hand
+ speed
+ duration
+ fixed device exclusion
→ local warning
→ server event
```

### 11.3. Repo Python

```text
safefleet_ai/
├── training/
├── evaluation/
├── export/
├── models/
├── scripts/
├── service/
└── tests/
```

Tạo:

- requirements.
- README.
- benchmark.
- export TFLite/ONNX.
- model metadata.
- Dockerfile.

Không train model trong Docker startup.

## 12. OPENAI AGENT

OpenAI key chỉ ở backend/AI service. Không đặt trong Flutter.

Luồng:

```text
Speech-to-text
→ local rule
→ nếu không hiểu: OpenAI structured classification
→ normalized intent
→ permission/context check
→ confirmation
→ gọi API thật
→ verify result
→ TTS
```

Intent MVP:

- `START_TRIP`.
- `PAUSE_TRIP`.
- `RESUME_TRIP`.
- `COMPLETE_TRIP`.
- `GET_DRIVING_TIME`.
- `REPORT_FLOOD`.
- `SEND_SOS`.
- `READ_LATEST_WARNING`.

Không cho model:

- Gọi SQL trực tiếp.
- Bỏ authorization.
- Sửa driver khác.
- Tự gửi SOS không xác nhận.
- Tự complete trip không xác nhận.

## 13. WEB INTEGRATION

Web phải đọc đúng dữ liệu từ stack Docker:

- GPS.
- Trip status.
- Safety events.
- SOS.
- Flood.
- Navigation session nếu có.
- Notifications.

Nếu frontend hiện poll REST:

- Giữ tương thích.
- Có thể bổ sung WebSocket.
- Không phá các trang hiện có.

Test:

1. App gửi GPS.
2. MySQL có row.
3. Web map cập nhật.
4. App gửi safety event.
5. Web Safety Center thấy.
6. App gửi SOS.
7. Web Incident Room thấy.
8. Web accept.
9. App thấy trạng thái mới.
10. App gửi flood.
11. Web Flood Map thấy.

## 14. SECURITY

Bắt buộc:

- Ownership cho mọi mobile endpoint.
- JWT secret qua env.
- DB secret qua env.
- Notification mark-read kiểm tra user.
- WebSocket auth.
- Rate limit SOS và Agent.
- File upload kiểm tra MIME/size.
- Evidence permission.
- Không log token/key/password.
- Không wildcard CORS production.
- Non-root Docker containers.
- Không commit `.env`.

## 15. TEST

### 15.1. Backend unit test

- State machine.
- Route scoring.
- Flood distance.
- Freshness.
- Idempotency.
- Ownership.
- Duplicate telemetry.
- Safety cooldown.

### 15.2. Integration test

Dùng MySQL thật qua Testcontainers. Không H2.

Test toàn bộ:

- login.
- accept.
- checklist.
- start.
- telemetry.
- batch telemetry.
- route.
- flood scoring.
- safety event.
- SOS.
- pause.
- resume.
- complete.
- notification.

### 15.3. Flutter

- Serialization.
- Auth.
- Offline queue.
- Coordinate conversion.
- Trip next action.
- SOS.
- Safety cooldown.
- Navigation state.
- Widget tests.

### 15.4. Docker

Bắt buộc chạy:

```text
docker compose config
docker compose build --no-cache
docker compose up -d
docker compose ps
docker compose logs backend
docker compose logs frontend
docker compose logs ai-service
```

Healthcheck tất cả dịch vụ.

### 15.5. End-to-end

- Stack Docker chạy.
- App host chạy.
- Điện thoại gọi backend Docker.
- Dữ liệu vào MySQL Docker.
- Web Docker hiển thị dữ liệu.
- AI service health.
- Route Hà Nội trả kết quả.
- Route bị ngập chọn alternative.

## 16. QUERY DATABASE LÀM BẰNG CHỨNG

Sau mỗi flow chạy query thật:

```sql
SELECT id, status, driver_id, vehicle_id
FROM trips
ORDER BY id DESC;

SELECT id, status, trip_id, driver_id
FROM driving_sessions
ORDER BY id DESC;

SELECT id, trip_id, lat, lng, speed, created_at
FROM telemetry_logs
ORDER BY created_at DESC
LIMIT 20;

SELECT id, event_type, severity, trip_id, created_at
FROM safety_events
ORDER BY created_at DESC
LIMIT 20;

SELECT id, incident_code, status, trip_id, created_at
FROM incidents
ORDER BY created_at DESC
LIMIT 20;

SELECT id, severity, status, lat, lng, address
FROM flood_reports
ORDER BY created_at DESC
LIMIT 20;

SELECT id, trip_id, status, route_risk_score
FROM navigation_sessions
ORDER BY id DESC;

SELECT id, navigation_session_id, total_score, safe
FROM navigation_route_candidates
ORDER BY id DESC;
```

Ghi kết quả đã ẩn dữ liệu nhạy cảm vào `docs/DATABASE_VERIFICATION.md`.

## 17. LỆNH CHẠY CUỐI CÙNG PHẢI HOẠT ĐỘNG

### 17.1. Tạo env

```powershell
Copy-Item .env.example .env
```

### 17.2. Build và start

```text
docker compose build --no-cache
docker compose up -d
docker compose ps
```

### 17.3. Health

```powershell
Invoke-WebRequest http://localhost:8080/actuator/health
Invoke-WebRequest http://localhost:3000
Invoke-WebRequest http://localhost:8000/health
```

### 17.4. Flutter

```text
cd safe_fleet_driver_ui
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-PC>:8080/api/v1
```

### 17.5. Stop

```text
docker compose down
```

### 17.6. Không xóa dữ liệu

`docker compose down`, không dùng `-v`.

### 17.7. Reset local có xác nhận

```powershell
.\docker\scripts\reset-local.ps1
```

## 18. DEFINITION OF DONE

Chỉ được kết luận hoàn thành khi toàn bộ đạt PASS.

### Docker

- Compose config hợp lệ.
- Tất cả image build.
- Tất cả container healthy.
- Volume tồn tại.
- Restart không mất DB.
- Không secret trong image.
- Non-root service.
- Healthcheck đúng.
- Backup/restore test được.

### Database

- MySQL thật.
- Flyway pass.
- Không H2.
- Schema validate.
- Seed local.
- Query chứng minh.
- Không duplicate.
- Transaction nhất quán.

### Backend

- Compile.
- Unit test.
- Integration test.
- Swagger.
- Ownership.
- Idempotency.
- Mobile workflow.
- Route scoring.
- SOS.
- Flood.
- Evidence.
- Notification.

### Frontend

- Production build.
- Chạy Docker.
- Đọc backend Docker.
- Hiển thị dữ liệu app tạo.

### Mobile

- Analyze pass.
- Test pass.
- Build Android pass.
- Login thật.
- Trip thật.
- GPS thật.
- Offline queue.
- AI local.
- Safety event DB.
- SOS DB.
- Flood DB.
- Route Hà Nội.
- Reroute.
- Không lộ key.

### AI

- Repo Python.
- Requirements.
- Tests.
- Export scripts.
- Metadata.
- AI service Docker healthy.
- Không dùng AI service thay on-device realtime.

### Documentation

- README.
- Docker runbook.
- Env guide.
- Device LAN guide.
- DB verification.
- API contract.
- Known limitations.
- Test results.

## 19. CÁCH XỬ LÝ BLOCKER

Không dừng toàn bộ dự án vì:

- Google Maps billing.
- OpenAI key chưa có.
- Firebase chưa cấu hình.
- Dịch vụ ngoài lỗi.

Fallback:

- Google Maps → MapLibre + OpenFreeMap.
- Google Routes → OSRM.
- Google Places → Photon.
- OpenAI chưa có → local intent rules.
- FCM chưa có → REST polling.
- MinIO lỗi → protected local storage trong dev.

Nếu blocker bên ngoài không thể giải quyết:

- Hoàn thiện fallback.
- Test fallback.
- Ghi rõ limitation.
- Tiếp tục hạng mục khác.
- Không để TODO P0 chưa xử lý.

## 20. BÁO CÁO CUỐI CÙNG

Khi hoàn thành, cung cấp:

- Kiến trúc cuối.
- Docker services.
- Port.
- Volumes.
- File đã tạo/sửa.
- Migration.
- API mới.
- Mobile screens.
- AI modules.
- Navigation Hà Nội.
- Test đã chạy.
- Kết quả healthcheck.
- Query DB.
- Lệnh chạy.
- Base URL điện thoại.
- Key cần cấu hình.
- Hạn chế còn lại.

Không tuyên bố DONE nếu còn một tiêu chí P0 chưa PASS.

## 21. CHỈ DẪN CUỐI CÙNG

- Bắt đầu bằng khảo sát repository.
- Không viết lại toàn bộ nếu có thể tái sử dụng.
- Không hỏi xác nhận cho từng bước nhỏ.
- Tự chia việc thành các hạng mục end-to-end.
- Tự chạy lệnh.
- Tự đọc log.
- Tự sửa lỗi.
- Tự rebuild.
- Tự kiểm tra database thật.
- Tự cập nhật progress.
- Tiếp tục lặp cho đến khi Definition of Done đạt PASS.
- Docker hóa đầy đủ backend, frontend, MySQL và AI service.
- Flutter app không chạy trong Docker; app phải chạy trên host và kết nối tới backend Docker qua IP LAN.
- Mọi hành động nghiệp vụ phải ghi vào MySQL thật và được web quản lý đọc lại.

---

## 22. CHECKPOINT LOOP 5 — HARDENING, AI ON-DEVICE, REALTIME VÀ E2E CUỐI

Thời điểm cập nhật: 27/07/2026.

### 22.1. Backend hardening

- Safety event và SOS nhận `clientEventId`, trả cùng ID khi retry và gộp cùng loại trong cooldown 30 giây.
- Mobile facade không còn tin `driverId`, `vehicleId`, `tripId` do client truyền; context lấy từ JWT/assignment.
- Rate limit: SOS 3 request/phút/user, agent 10 request/phút/user; quá giới hạn trả 429.
- Evidence multipart:
  - đúng một trong safety event/incident;
  - JPEG/PNG/WebP, tối đa 8 MB;
  - kiểm magic bytes, SHA-256, filename/path traversal;
  - metadata/content có JWT và ownership;
  - response file `no-store`, `nosniff`.
- Push token theo device/user; không trả raw token. Khi chưa có FCM, worker chuyển item sang `POLLING_FALLBACK`.
- Mobile incident timeline đã có.
- STOMP CONNECT bắt buộc Bearer JWT; anonymous nhận frame `ERROR`; CORS dùng origin cấu hình.
- Evidence dùng MinIO private mặc định trong Docker; local volume giữ làm fallback rõ ràng và backend vẫn chạy non-root.

### 22.2. Backend test

```text
Suites: 2
Tests: 21
Failures: 0
Errors: 0
Skipped: 0
```

Trong đó 8 bài integration dựng MySQL 8.4 sạch, chạy Flyway V1–V6 và gọi HTTP thật.

### 22.3. E2E Docker thật

- 5 dịch vụ `healthy`: MySQL, backend, frontend, AI, MinIO.
- Backend/web/AI/MinIO trả HTTP 200.
- Safety payload cố giả mạo driver vẫn được lưu cho driver từ JWT.
- Safety replay và SOS replay trả cùng stable ID.
- Evidence id 2 trong MinIO:
  - PNG thật 1.443 byte, SHA-256 khớp source/API/download;
  - bucket trả HTTP 403 khi truy cập ẩn danh;
  - `mc stat` xác nhận object thật;
  - tài xế khác nhận 403;
  - restart cả MinIO và backend vẫn tải đúng hash.
- SOS id 7 được admin accept; mobile đọc `ACCEPTED` và timeline.
- MySQL có push item `POLLING_FALLBACK`.
- WebSocket smoke:

```json
{
  "authenticated": {"result": "CONNECTED"},
  "anonymous": {"result": "ERROR"}
}
```

### 22.4. Flutter AI on-device

- Bổ sung camera trước và ML Kit face detection/image labeling.
- Temporal engine dùng eye-open, PERCLOS, head pose, yawn, phone confidence, speed, duration và cooldown.
- Camera frame xử lý cục bộ; không upload video liên tục.
- Offline queue ưu tiên `SOS → safety CRITICAL/HIGH → workflow → flood → telemetry`, chỉ mark synced sau ACK server.
- Canonical model metadata phía AI và Flutter asset có cùng SHA-256:

```text
574D5E578C5664DCE5AD2964B89FCEBDE87B61C55D6BE2653E03A1DA8724F96D
```

Kết quả:

```text
flutter analyze: No issues found
flutter test: 8/8 PASS
flutter build apk --debug: PASS
```

APK:

```text
safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk
```

Không có Android phone/emulator kết nối trong phiên; chỉ có Windows/Chrome/Edge. Test camera/GPS vật lý là release gate bên ngoài repository.

### 22.5. AI repo

- 7/7 pytest PASS.
- Training sample tạo calibration threshold.
- Evaluation sample: TP=2, FP=0, FN=0, precision/recall/F1=1,0.
- Benchmark 10.000 vòng: mean khoảng 0,0043 ms, p95 khoảng 0,0058 ms.
- Export mobile metadata hoạt động.
- ONNX/TFLite exporter có code thật nhưng framework nặng chỉ cài trên training workstation.

### 22.6. Frontend/realtime/security dependency

- Native STOMP client có JWT, reconnect exponential và custom event cho Command Center.
- Command Center refresh theo realtime và REST polling fallback 30 giây.
- Header hiển thị trạng thái realtime.
- Nâng Next.js/eslint-config-next từ 16.2.10 lên 16.2.12.
- Override PostCSS 8.5.23 và Sharp 0.35.3.
- `npm audit --omit=dev`: 0 vulnerability.
- Full audit còn advisory trong ESLint/minimatch dev-only; không ép major/plugin không tương thích.
- Lint PASS; production build đủ 17 page PASS; Docker image mới PASS.

### 22.7. Báo cáo và công cụ

- Tạo `docker/scripts/websocket-smoke.mjs`.
- Tạo `docker/scripts/export-api-report.mjs`.
- Sinh `BAO_CAO_HE_THONG_VA_API_SAFEFLEET_2026.md` ngay cạnh `web_quan_ly`:
  - 132 OpenAPI path;
  - 151 operation;
  - 166 input/output schema;
  - kiến trúc, tính năng, test, runbook, limitation và luồng tích hợp app.
- Cập nhật API contract, DB verification, traceability, Docker runbook, device test và README AI/Flutter.

### 22.8. Trạng thái cuối theo phạm vi có thể tự động hóa

MVP local/LAN đã chạy end-to-end và các fallback trong master prompt đã được kiểm thử. Những gate cần tài nguyên ngoài repository không được tuyên bố giả là đã xong:

- FCM/Firebase credential;
- điện thoại Android thật/emulator;
- HTTPS/domain/keystore release/secret manager;
- dataset cabin có consent cho custom YOLO/TFLite;
- SLA routing/geocoding production.

Các mục này không chặn việc dùng/demo MVP ngay qua Docker + APK debug, nhưng bắt buộc hoàn tất trước rollout thương mại.

---

## 22.9. CHECKPOINT LOOP 6 — MINIO, IDEMPOTENCY, OFFLINE QUEUE VÀ DISASTER RESTORE

Thời điểm cập nhật: 27/07/2026.

- Thêm storage abstraction `EvidenceStorage`; Docker mặc định `EVIDENCE_STORAGE_PROVIDER=minio`, bucket private, local volume là fallback.
- E2E `driver01` tạo safety event `id=18`, upload evidence `id=2`, đối chiếu SHA-256:

```text
3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180
```

- Truy cập object MinIO ẩn danh trả `403`; tải qua API có JWT đúng 1.443 byte và giữ nguyên hash sau restart MinIO/backend.
- Flyway V6 thêm receipt idempotency workflow. Docker E2E trip `id=11`: replay start/complete giữ nguyên trip, driving session, navigation session; DB có đúng một receipt và một timeline/action.
- Flood quick-report retry cùng `clientEventId` trả cùng `id=11`; DB chỉ có một hàng và `receivedAt` không còn null.
- Flutter SQLite queue có test thật cho đủ SOS/safety/workflow/flood/telemetry, priority, ACK và retry; tổng 8/8 test.
- Android release không dùng debug signing; build chủ động thất bại nếu thiếu bốn biến keystore. Cleartext chỉ được bật qua manifest debug/profile.
- Web mặc định dùng backend thật; demo credential chỉ hiện khi bật biến môi trường riêng.
- AI có Docker `test` stage Python 3.11 tự chứa service, tests, training fixture và canonical model metadata; 7/7 PASS, không phụ thuộc Python host.
- Sửa backup để dùng `--no-tablespaces`, kiểm exit code/kích thước và không giữ dump lỗi.
- Thêm `docker/scripts/db-verify-backup-restore.ps1`, tương thích Windows PowerShell 5 qua command Base64.
- Diễn tập thật:

```text
backup bytes: 116313
backup sha256: 1940eb3241e954a7ffd56767e11bdd05ba63a44ae6a2637490a64b9ec2bfb0e0
source signature:   20|15|20|11|18|7|11|2|2|6|11|2
restored signature: 20|15|20|11|18|7|11|2|2|6|11|2
temporary database/file remaining: 0
```

Gate ngoài repository còn lại đã được kiểm tra read-only: chỉ có Windows/Chrome/Edge, không có Android emulator; bốn biến release signing đều chưa cấu hình; `FCM_ENABLED=false`; không có TLS certificate hoặc custom dataset. Cần thiết bị Android vật lý, credential FCM, domain/TLS/keystore thật, dataset cabin có consent và SLA provider routing/geocoding.

---

## 23. BẢN MASTER PROMPT NGUYÊN VĂN TỪ ATTACHMENT

MASTER PROMPT DUY NHẤT CHO CODEX

HOÀN THIỆN TOÀN BỘ SAFE FLEET MVP + DOCKER + DATABASE THẬT + MOBILE + AI + DẪN ĐƯỜNG HÀ NỘI

0. MỤC TIÊU

Bạn là Codex Agent chịu trách nhiệm hoàn thiện toàn bộ dự án SafeFleet theo hướng production-ready MVP.

Bạn phải tự:

Khảo sát repository hiện tại.

Xác định phần nào đã có, phần nào lỗi, phần nào chỉ là mock/UI.

Hoàn thiện backend Spring Boot dùng chung cho web và app mobile.

Hoàn thiện Flutter Driver App.

Hoàn thiện web quản lý để đọc đúng dữ liệu do app mobile tạo.

Hoàn thiện repo Python AI phục vụ train, evaluate, export model và AI service.

Docker hóa toàn bộ các dịch vụ server.

Kết nối MySQL thật.

Viết Flyway migration.

Xây dựng hệ thống dẫn đường và tránh ngập trong phạm vi Hà Nội.

Chạy test tự động.

Chạy integration test với MySQL thật.

Kiểm tra dữ liệu thật trong database.

Sửa lỗi và tự lặp lại cho đến khi toàn bộ Definition of Done đạt PASS.

Không được dừng ở việc tạo giao diện, tạo file mẫu hoặc viết TODO.

1. VỊ TRÍ REPOSITORY DỰ KIẾN

Repository gốc:

D:\DEV\Project\DATN\DATN-he_thon_canh_bao_ho_tro_tai_xe

Cấu trúc dự kiến:

DATN-he_thon_canh_bao_ho_tro_tai_xe/
├── web_quan_ly/
│   ├── backend/                    # Spring Boot
│   └── frontend/                   # Next.js
├── safe_fleet_driver_ui/           # Flutter app
├── safefleet_ai/                   # Python AI
├── docker/
├── docs/
├── docker-compose.yml
├── docker-compose.dev.yml
├── .env.example
└── README.md

Nếu cấu trúc thực tế khác:

Tự khảo sát.

Không tự ý xóa hoặc đổi tên module đang hoạt động.

Điều chỉnh đường dẫn trong tài liệu.

Giữ lịch sử Git sạch và dễ review.

2. KIẾN TRÚC CUỐI CÙNG PHẢI ĐẠT

Flutter Driver App
        │
        │ REST / WebSocket / FCM
        ▼
Spring Boot Backend
        │
        ├── MySQL
        ├── Redis nếu thực sự cần cho cache/idempotency/queue
        ├── MinIO hoặc local object storage cho ảnh bằng chứng
        ├── Python AI Service
        └── Photon / OSRM / OpenAI / Firebase

Next.js Web Command Center
        │
        └── dùng chung Spring Boot Backend và MySQL

Nguyên tắc:

Web và mobile không có backend riêng.

Spring Boot là backend nghiệp vụ duy nhất.

MySQL là nguồn dữ liệu nghiệp vụ duy nhất.

SQLite trên điện thoại chỉ là cache và offline queue.

Python không thay thế Spring Boot trong nghiệp vụ chuyến, tài xế, xe, SOS hoặc GPS.

AI camera thời gian thực chạy on-device.

OpenAI chỉ được gọi qua backend.

Docker chỉ chạy các dịch vụ server.

Flutter app chạy trên máy host, emulator hoặc điện thoại thật; không cố chạy app mobile trong Docker.

3. CÁC DỊCH VỤ DOCKER PHẢI CÓ

Tạo một hệ thống Docker Compose hoàn chỉnh gồm tối thiểu:

mysql
backend
frontend
ai-service

Khuyến nghị thêm nếu phù hợp với code:

redis
minio
adminer chỉ trong profile dev

3.1. MySQL

Yêu cầu:

MySQL 8.4 hoặc phiên bản tương thích.

Database: safefleet.

Charset utf8mb4.

Timezone Asia/Ho_Chi_Minh.

Persistent volume.

Healthcheck.

Không expose root password trong Git.

App user riêng, không dùng root.

Flyway do backend thực hiện.

Không dùng H2.

3.2. Backend

Tạo multi-stage Dockerfile:

Maven build stage
→ JRE/JDK runtime stage

Yêu cầu:

Java 21.

Chạy non-root user.

Copy jar tối thiểu.

Có healthcheck.

Profile Docker riêng.

Bind 0.0.0.0.

Không chứa secret trong image.

Chờ MySQL healthy trước khi start.

Flyway chạy tự động.

ddl-auto=validate.

Log ra stdout.

Có endpoint health.

3.3. Frontend

Tạo multi-stage Dockerfile:

Node install
→ build
→ production runtime

Yêu cầu:

Không hard-code localhost.

Browser gọi backend qua URL truy cập được từ máy người dùng.

Có biến môi trường public API URL.

Chạy non-root.

Healthcheck.

Build production thành công.

Web local đọc dữ liệu thật từ backend Docker.

3.4. AI Service

Tạo repo hoặc module safefleet_ai.

Tạo Dockerfile Python:

Python 3.11 hoặc phiên bản tương thích.

FastAPI.

Uvicorn/Gunicorn.

Non-root user.

Healthcheck.

Requirements khóa version.

Không đóng gói dataset lớn vào image.

Model mount bằng volume hoặc artifact folder.

OpenAI key chỉ qua environment.

AI service chỉ phụ trách:

Intent classification fallback.

Model metadata.

Model version.

Evaluation endpoint nếu cần.

Xử lý AI server-side không thời gian thực.

Không gửi video cabin liên tục vào service.

3.5. Redis

Chỉ thêm nếu code thực sự sử dụng cho:

Idempotency.

Cache routing.

Retry notification.

Pub/Sub.

Rate limiting.

Nếu thêm:

Persistent volume nếu cần.

Healthcheck.

Password qua environment.

Không dùng Redis thay MySQL làm nguồn dữ liệu nghiệp vụ.

3.6. MinIO

Nên dùng cho:

Ảnh cảnh báo AI.

Ảnh điểm ngập.

Ảnh sự cố.

Evidence.

Yêu cầu:

Bucket tự tạo khi startup.

Credential qua environment.

URL không public mặc định.

Backend tạo presigned URL hoặc endpoint được bảo vệ.

Không để app mobile upload trực tiếp bằng secret key.

4. FILE DOCKER BẮT BUỘC

Phải tạo hoặc hoàn thiện:

docker-compose.yml
docker-compose.dev.yml
.env.example
.dockerignore
web_quan_ly/backend/Dockerfile
web_quan_ly/backend/.dockerignore
web_quan_ly/frontend/Dockerfile
web_quan_ly/frontend/.dockerignore
safefleet_ai/Dockerfile
safefleet_ai/.dockerignore
docker/mysql/init/
docker/minio/
docker/scripts/

4.1. docker-compose.yml

Dùng cho stack hoàn chỉnh.

Phải có:

Named volumes.

Internal network.

Healthchecks.

depends_on với condition: service_healthy khi được hỗ trợ.

Restart policy hợp lý.

Resource limits nếu có thể.

Port mapping rõ ràng.

Không ghi secret trực tiếp.

Tất cả config từ .env.

4.2. docker-compose.dev.yml

Dùng cho development:

Mount source nếu hợp lý.

Adminer tùy chọn.

Expose port dễ debug.

Seed demo bật.

Log level DEBUG.

Không thay đổi dữ liệu production.

4.3. .env.example

Bao gồm toàn bộ biến cần thiết nhưng không có secret thật:

MYSQL_DATABASE=safefleet
MYSQL_USER=safefleet
MYSQL_PASSWORD=change_me
MYSQL_ROOT_PASSWORD=change_me

BACKEND_PORT=8080
FRONTEND_PORT=3000
AI_SERVICE_PORT=8000

JWT_SECRET=change_me_long_random
JWT_EXPIRATION_MINUTES=1440

OPENAI_API_KEY=
OPENAI_ENABLED=false

FIREBASE_ENABLED=false
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_PATH=

MINIO_ROOT_USER=change_me
MINIO_ROOT_PASSWORD=change_me
MINIO_BUCKET=safefleet-evidence

REDIS_ENABLED=false
REDIS_PASSWORD=

PHOTON_URL=https://photon.komoot.io/api/
OSRM_URL=https://router.project-osrm.org

MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty

SEED_ENABLED=true
HANOI_DEMO_DATA_ENABLED=true

4.4. Script vận hành

Tạo script PowerShell và Bash:

docker/scripts/start.ps1
docker/scripts/stop.ps1
docker/scripts/reset-local.ps1
docker/scripts/health-check.ps1
docker/scripts/db-backup.ps1
docker/scripts/db-restore.ps1

docker/scripts/start.sh
docker/scripts/stop.sh
docker/scripts/health-check.sh

reset-local phải yêu cầu xác nhận trước khi xóa volume.

5. QUY TẮC DATABASE THẬT

5.1. Cấm

Không được:

Dùng H2 runtime.

Dùng fake repository.

Trả dữ liệu hard-code.

Lưu nghiệp vụ chỉ trong Flutter.

Dùng SQLite làm DB server.

Dùng ddl-auto=create.

Bỏ Flyway.

Tạo dữ liệu giả trong controller.

Chạy integration test bằng H2.

5.2. Bắt buộc

MySQL thật.

Flyway.

ddl-auto=validate.

Transaction.

Foreign key.

Index.

Unique constraint.

Audit field.

Timezone thống nhất.

Query xác minh sau mỗi flow.

5.3. Các bảng hiện có phải được kiểm tra

users
roles
permissions
drivers
vehicles
devices
trips
trip_timelines
telemetry_logs
safety_events
driving_sessions
driver_work_logs
incidents
incident_timelines
flood_reports
notifications
system_settings
pre_trip_checklists
agent_commands
audit_logs

5.4. Các bảng cần bổ sung nếu chưa có

mobile_devices
idempotency_records
sync_batches
navigation_sessions
navigation_route_candidates
navigation_events
safety_event_evidence
push_tokens
pending_push_notifications

5.5. Quy tắc migration

Đọc migration hiện có trước.

Tạo version tiếp theo.

Không sửa migration đã chạy.

Không xóa cột đang dùng.

Có index hợp lý.

Có dữ liệu seed local riêng.

Có rollback plan trong tài liệu.

6. SEED DỮ LIỆU HÀ NỘI

Chỉ bật local/dev.

Tạo tối thiểu:

1 admin.

1 fleet manager.

1 dispatcher.

1 safety officer.

1 rescue user.

2 driver.

2 vehicle.

2 GPS device.

1 cabin camera.

4 trip Hà Nội.

8 flood report demo.

Tuyến test:

Hà Đông → Cầu Giấy
Mỹ Đình → Kiều Mai
Phú Diễn → Nguyễn Trãi
Đại lộ Thăng Long → Phạm Văn Đồng

Tất cả điểm ngập demo phải:

Có prefix [DEMO].

Source MANUAL.

Có expiredAt.

Có confidence.

Có status.

Không được trình bày là dữ liệu thực tế.

Dữ liệu seed phải vào MySQL qua Flyway hoặc seeder backend, không hard-code trong Flutter.

7. QUY TRÌNH TỰ LOOP

Tạo:

docs/CODEX_FULL_PROGRESS.md
docs/CODEX_DECISIONS.md
docs/DOCKER_RUNBOOK.md
docs/LOCAL_DEVICE_TEST.md
docs/API_MOBILE_CONTRACT.md
docs/DATABASE_VERIFICATION.md

Mỗi vòng lặp:

1. Chọn một hạng mục P0.
2. Ghi trạng thái DOING.
3. Viết migration nếu cần.
4. Viết backend.
5. Viết test.
6. Chạy test.
7. Build Docker image.
8. Start stack.
9. Gọi API thật.
10. Query MySQL.
11. Kiểm tra web.
12. Kiểm tra mobile.
13. Sửa lỗi.
14. Chạy regression.
15. Ghi bằng chứng.
16. Đánh dấu DONE.
17. Chuyển hạng mục tiếp theo.

Không được đánh dấu DONE chỉ vì code compile.

Nếu lỗi:

Đọc log.

Sửa nguyên nhân gốc.

Rebuild.

Restart đúng service.

Chạy lại test.

Không bỏ qua test.

Nếu thiếu key:

Dùng fallback miễn phí.

Không chặn MVP.

Ghi rõ trong tài liệu.

8. BACKEND MOBILE PHẢI HOÀN THIỆN

8.1. Auth

POST /api/v1/auth/login
GET  /api/v1/auth/me

Yêu cầu:

Chỉ DRIVER vào Driver App.

Token lưu an toàn.

Không log token.

Production không dùng secret mặc định.

8.2. Bootstrap

GET /api/v1/mobile/me
GET /api/v1/mobile/config
GET /api/v1/mobile/safety-summary
GET /api/v1/mobile/current-assignment
GET /api/v1/mobile/notifications

8.3. Trip

GET  /api/v1/mobile/trips/today
GET  /api/v1/mobile/trips/{id}
GET  /api/v1/mobile/trips/{id}/summary
POST /api/v1/mobile/trips/{id}/accept
POST /api/v1/mobile/trips/{id}/pre-trip-checklist

8.4. Workflow thống nhất

Tạo:

POST /api/v1/mobile/trips/{id}/start-workflow
POST /api/v1/mobile/trips/{id}/pause-workflow
POST /api/v1/mobile/trips/{id}/resume-workflow
POST /api/v1/mobile/trips/{id}/complete-workflow
GET  /api/v1/mobile/driving-sessions/current

Trong cùng transaction:

Trip
DrivingSession
Driver
Vehicle
TripTimeline
NavigationSession

Start phải bị chặn nếu:

Checklist chưa có.

Checklist fail.

Trip không thuộc driver.

Vehicle không thuộc trip.

Driver có active session khác.

Trip sai trạng thái.

8.5. Telemetry

POST /api/v1/mobile/telemetry
POST /api/v1/mobile/telemetry/batch

Yêu cầu:

clientEventId.

batchId.

Idempotency.

Ownership.

Không để offline record cũ ghi đè current position mới.

Ghi MySQL.

Push WebSocket.

8.6. Safety

POST /api/v1/mobile/safety-events
GET  /api/v1/mobile/safety-events/today
POST /api/v1/mobile/evidence

Yêu cầu:

Không spam event.

Cooldown.

Evidence qua MinIO/local storage.

URL được bảo vệ.

Driver/vehicle/trip từ context.

8.7. SOS

POST /api/v1/mobile/incidents/sos
GET  /api/v1/mobile/incidents
GET  /api/v1/mobile/incidents/{id}
GET  /api/v1/mobile/incidents/{id}/timeline

Yêu cầu:

Idempotency.

Priority cao.

Timeline.

Web nhìn thấy.

App nhìn thấy trạng thái sau khi web accept.

8.8. Flood

GET  /api/v1/mobile/flood-points/nearby
POST /api/v1/mobile/flood-reports/quick
POST /api/v1/mobile/route-check

Yêu cầu:

Backend tự gắn driver/source.

Report hết hạn không dùng.

Scheduler expire.

Tất cả dữ liệu từ MySQL.

8.9. Notifications

GET    /api/v1/mobile/notifications
PATCH  /api/v1/mobile/notifications/{id}/read
PATCH  /api/v1/mobile/notifications/read-all
POST   /api/v1/mobile/push-tokens
DELETE /api/v1/mobile/push-tokens/{deviceUuid}

9. HỆ THỐNG DẪN ĐƯỜNG HÀ NỘI

9.1. Mục tiêu

Phải test được ngay:

Map Hà Nội.

Search địa điểm.

Route.

Alternative routes.

Turn steps cơ bản.

Flood scoring.

Route tránh ngập.

Off-route detection.

Reroute.

Route cache offline.

Lưu navigation session vào MySQL.

9.2. Công nghệ

Flutter MapLibre
OpenFreeMap
Photon
OSRM
MySQL flood reports

Không bắt buộc Google Maps.

Không gọi Photon/OSRM trực tiếp từ app; gọi qua backend.

9.3. API

GET  /api/v1/mobile/locations/autocomplete
POST /api/v1/mobile/navigation/routes
POST /api/v1/mobile/navigation/reroute
POST /api/v1/mobile/navigation/events
GET  /api/v1/mobile/navigation/current

9.4. OSRM

Gọi:

/route/v1/driving/{coordinates}
?alternatives=3
&steps=true
&geometries=geojson
&overview=full

Tạo interface:

RoutingProvider
OsrmRoutingProvider

Không đặt logic HTTP ngoài controller/service.

9.5. Chấm điểm ngập

Chỉ lấy flood report:

status IN (UNVERIFIED, VERIFIED)
expiredAt > now
severity >= MEDIUM

Tính point-to-polyline.

Ngưỡng:

0–100 m: hệ số 1.0
100–200 m: hệ số 0.7
200–300 m: hệ số 0.4
>300 m: bỏ qua

Severity:

NONE=0
LOW=5
MEDIUM=30
HIGH=100
BLOCKED=reject route

Freshness:

<=30 phút: 1.0
30–90 phút: 0.8
90–180 phút: 0.5
hết hạn: 0

Score:

totalScore =
durationMinutes
+ distanceKm
+ floodPenalty
+ vehicleRestrictionPenalty
+ driverTimePenalty

Driver time penalty tăng nếu ETA lớn hơn remaining driving time.

9.6. Detour fallback

Nếu mọi OSRM alternative đều bị BLOCKED:

Chọn flood point nguy hiểm nhất.

Tìm segment gần nhất.

Tạo hai waypoint lệch vuông góc 800–1500 m.

Gọi OSRM qua waypoint A.

Gọi OSRM qua waypoint B.

Chấm điểm lại.

Chọn tuyến safe tốt nhất.

Nếu không có tuyến safe:

Trả tuyến ít rủi ro nhất.

safe=false.

Không tuyên bố tuyến an toàn.

9.7. Off-route

Khoảng cách >75 m.

Liên tục 15 giây.

GPS accuracy hợp lệ.

Gọi reroute.

Lưu navigation event DB.

9.8. Test

Không ngập.

Ngập HIGH.

BLOCKED.

Report expired.

Alternative route.

Detour.

Offline cache.

Reroute.

DB navigation session.

10. FLUTTER APP

10.1. Màn hình

Splash
Login
Permission Setup
Home
Trips Today
Trip Detail
Checklist
Driving Mode
Flood Report
SOS Status
Notifications
Safety Summary
Agent Voice Sheet
Debug Settings chỉ local

10.2. Driving Mode

Hiển thị:

Map.

Route.

Xe.

Flood marker.

Next maneuver.

Speed.

Remaining driving time.

GPS status.

AI status.

Network status.

Sync queue.

Voice.

SOS.

Pause/Resume.

Khi xe đang chạy:

Không form dài.

Không popup che bản đồ.

Voice-first.

Nút lớn.

10.3. Offline queue

Dùng Drift/SQLite.

Priority:

SOS
CRITICAL safety
HIGH safety
trip workflow
flood report
telemetry

Batch telemetry.

Không xóa item trước server ACK.

10.4. Local device test

Backend Docker expose:

0.0.0.0:8080

App điện thoại dùng:

http://<IP-LAN-PC>:8080/api/v1

Không dùng localhost.

Tạo màn debug local để đổi base URL nhưng không bật production.

11. AI ON-DEVICE

11.1. Drowsiness

Pipeline:

Camera
→ Face landmarks
→ EAR/PERCLOS/head pose/yawn
→ temporal rules
→ local warning
→ server event

11.2. Phone usage

Pipeline:

YOLO phone
+ face/hand
+ speed
+ duration
+ fixed device exclusion
→ local warning
→ server event

11.3. Repo Python

safefleet_ai/
├── training/
├── evaluation/
├── export/
├── models/
├── scripts/
├── service/
└── tests/

Tạo:

requirements.

README.

benchmark.

export TFLite/ONNX.

model metadata.

Dockerfile.

Không train model trong Docker startup.

12. OPENAI AGENT

OpenAI key chỉ ở backend/AI service.

Không đặt trong Flutter.

Luồng:

Speech-to-text
→ local rule
→ nếu không hiểu: OpenAI structured classification
→ normalized intent
→ permission/context check
→ confirmation
→ gọi API thật
→ verify result
→ TTS

Intent MVP:

START_TRIP
PAUSE_TRIP
RESUME_TRIP
COMPLETE_TRIP
GET_DRIVING_TIME
REPORT_FLOOD
SEND_SOS
READ_LATEST_WARNING

Không cho model:

Gọi SQL trực tiếp.

Bỏ authorization.

Sửa driver khác.

Tự gửi SOS không xác nhận.

Tự complete trip không xác nhận.

13. WEB INTEGRATION

Web phải đọc đúng dữ liệu từ stack Docker:

GPS.

Trip status.

Safety events.

SOS.

Flood.

Navigation session nếu có.

Notifications.

Nếu frontend hiện poll REST:

Giữ tương thích.

Có thể bổ sung WebSocket.

Không phá các trang hiện có.

Test:

App gửi GPS.

MySQL có row.

Web map cập nhật.

App gửi safety event.

Web Safety Center thấy.

App gửi SOS.

Web Incident Room thấy.

Web accept.

App thấy trạng thái mới.

App gửi flood.

Web Flood Map thấy.

14. SECURITY

Bắt buộc:

Ownership cho mọi mobile endpoint.

JWT secret qua env.

DB secret qua env.

Notification mark-read kiểm tra user.

WebSocket auth.

Rate limit SOS và Agent.

File upload kiểm tra MIME/size.

Evidence permission.

Không log token/key/password.

Không wildcard CORS production.

Non-root Docker containers.

Không commit .env.

15. TEST

15.1. Backend unit test

State machine.

Route scoring.

Flood distance.

Freshness.

Idempotency.

Ownership.

Duplicate telemetry.

Safety cooldown.

15.2. Integration test

Dùng MySQL thật qua Testcontainers.

Không H2.

Test toàn bộ:

login
accept
checklist
start
telemetry
batch telemetry
route
flood scoring
safety event
SOS
pause
resume
complete
notification

15.3. Flutter

Serialization.

Auth.

Offline queue.

Coordinate conversion.

Trip next action.

SOS.

Safety cooldown.

Navigation state.

Widget tests.

15.4. Docker

Bắt buộc chạy:

docker compose config
docker compose build --no-cache
docker compose up -d
docker compose ps
docker compose logs backend
docker compose logs frontend
docker compose logs ai-service

Healthcheck tất cả dịch vụ.

15.5. End-to-end

Stack Docker chạy.

App host chạy.

Điện thoại gọi backend Docker.

Dữ liệu vào MySQL Docker.

Web Docker hiển thị dữ liệu.

AI service health.

Route Hà Nội trả kết quả.

Route bị ngập chọn alternative.

16. QUERY DATABASE LÀM BẰNG CHỨNG

Sau mỗi flow chạy query thật:

SELECT id, status, driver_id, vehicle_id
FROM trips
ORDER BY id DESC;

SELECT id, status, trip_id, driver_id
FROM driving_sessions
ORDER BY id DESC;

SELECT id, trip_id, lat, lng, speed, created_at
FROM telemetry_logs
ORDER BY created_at DESC
LIMIT 20;

SELECT id, event_type, severity, trip_id, created_at
FROM safety_events
ORDER BY created_at DESC
LIMIT 20;

SELECT id, incident_code, status, trip_id, created_at
FROM incidents
ORDER BY created_at DESC
LIMIT 20;

SELECT id, severity, status, lat, lng, address
FROM flood_reports
ORDER BY created_at DESC
LIMIT 20;

SELECT id, trip_id, status, route_risk_score
FROM navigation_sessions
ORDER BY id DESC;

SELECT id, navigation_session_id, total_score, safe
FROM navigation_route_candidates
ORDER BY id DESC;

Ghi kết quả đã ẩn dữ liệu nhạy cảm vào:

docs/DATABASE_VERIFICATION.md

17. LỆNH CHẠY CUỐI CÙNG PHẢI HOẠT ĐỘNG

17.1. Tạo env

Copy-Item .env.example .env

17.2. Build và start

docker compose build --no-cache
docker compose up -d
docker compose ps

17.3. Health

Invoke-WebRequest http://localhost:8080/actuator/health
Invoke-WebRequest http://localhost:3000
Invoke-WebRequest http://localhost:8000/health

17.4. Flutter

cd safe_fleet_driver_ui
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-PC>:8080/api/v1

17.5. Stop

docker compose down

17.6. Không xóa dữ liệu

docker compose down

Không dùng -v.

17.7. Reset local có xác nhận

.\docker\scripts\reset-local.ps1

18. DEFINITION OF DONE

Chỉ được kết luận hoàn thành khi toàn bộ đạt PASS.

Docker

Compose config hợp lệ.

Tất cả image build.

Tất cả container healthy.

Volume tồn tại.

Restart không mất DB.

Không secret trong image.

Non-root service.

Healthcheck đúng.

Backup/restore test được.

Database

MySQL thật.

Flyway pass.

Không H2.

Schema validate.

Seed local.

Query chứng minh.

Không duplicate.

Transaction nhất quán.

Backend

Compile.

Unit test.

Integration test.

Swagger.

Ownership.

Idempotency.

Mobile workflow.

Route scoring.

SOS.

Flood.

Evidence.

Notification.

Frontend

Production build.

Chạy Docker.

Đọc backend Docker.

Hiển thị dữ liệu app tạo.

Mobile

Analyze pass.

Test pass.

Build Android pass.

Login thật.

Trip thật.

GPS thật.

Offline queue.

AI local.

Safety event DB.

SOS DB.

Flood DB.

Route Hà Nội.

Reroute.

Không lộ key.

AI

Repo Python.

Requirements.

Tests.

Export scripts.

Metadata.

AI service Docker healthy.

Không dùng AI service thay on-device realtime.

Documentation

README.

Docker runbook.

Env guide.

Device LAN guide.

DB verification.

API contract.

Known limitations.

Test results.

19. CÁCH XỬ LÝ BLOCKER

Không dừng toàn bộ dự án vì:

Google Maps billing.

OpenAI key chưa có.

Firebase chưa cấu hình.

Dịch vụ ngoài lỗi.

Fallback:

Google Maps → MapLibre + OpenFreeMap
Google Routes → OSRM
Google Places → Photon
OpenAI chưa có → local intent rules
FCM chưa có → REST polling
MinIO lỗi → protected local storage trong dev

Nếu blocker bên ngoài không thể giải quyết:

Hoàn thiện fallback.

Test fallback.

Ghi rõ limitation.

Tiếp tục hạng mục khác.

Không để TODO P0 chưa xử lý.

20. BÁO CÁO CUỐI CÙNG

Khi hoàn thành, cung cấp:

Kiến trúc cuối.

Docker services.

Port.

Volumes.

File đã tạo/sửa.

Migration.

API mới.

Mobile screens.

AI modules.

Navigation Hà Nội.

Test đã chạy.

Kết quả healthcheck.

Query DB.

Lệnh chạy.

Base URL điện thoại.

Key cần cấu hình.

Hạn chế còn lại.

Không tuyên bố DONE nếu còn một tiêu chí P0 chưa PASS.

21. CHỈ DẪN CUỐI CÙNG

Bắt đầu bằng khảo sát repository.

Không viết lại toàn bộ nếu có thể tái sử dụng.

Không hỏi xác nhận cho từng bước nhỏ.

Tự chia việc thành các hạng mục end-to-end.

Tự chạy lệnh.

Tự đọc log.

Tự sửa lỗi.

Tự rebuild.

Tự kiểm tra database thật.

Tự cập nhật progress.

Tiếp tục lặp cho đến khi Definition of Done đạt PASS.

Docker hóa đầy đủ backend, frontend, MySQL và AI service.

Flutter app không chạy trong Docker; app phải chạy trên host và kết nối tới backend Docker qua IP LAN.

Mọi hành động nghiệp vụ phải ghi vào MySQL thật và được web quản lý đọc lại.

# 24. CHECKPOINT MOBILE V2 — 2026-07-28 23:58 (Asia/Ho_Chi_Minh)

Checkpoint này là điểm khôi phục mới nhất nếu task bị ngắt do quota. Toàn bộ master
prompt nguyên văn vẫn nằm ở các mục 7 và 23 của file này; yêu cầu bổ sung hiện hành là
bản đồ độc lập tránh ngập, camera buồn ngủ xuyên trang, hồ sơ, hoạt động tháng, Agent
giọng nói/câu đánh thức và giao diện trắng chuyên nghiệp.

## Đã triển khai và xác minh

- Flutter có shell năm khu vực với dock nổi: Nhà, Bản đồ, Agent, Tháng, Hồ sơ.
- Shell tải lười các tab native nặng; MapLibre không còn khởi tạo/ngốn quyền vị trí khi
  app mới vào trang chủ. Tab đã mở vẫn được giữ state bằng `IndexedStack`.
- Màn Bản đồ chọn vị trí hiện tại/địa điểm đầu-cuối, autocomplete qua backend, gọi route
  OSRM đã chấm rủi ro và vẽ điểm ngập lấy chung từ MySQL với web quản lý.
- `CabinSafetyController` sở hữu camera/model ở cấp ứng dụng. Đổi trang không dispose;
  có trang preview, công tắc bật/tắt, đổi ST-GT/Temporal và chỉ báo `AI ON` toàn cục.
- Driving Mode đã chuyển sang controller cabin toàn cục và cập nhật tốc độ cho model.
- Hồ sơ đọc `/api/v1/mobile/me`: liên hệ, địa chỉ, GPLX/hạng/hết hạn, xe, điểm an toàn,
  tổng chuyến/cảnh báo; avatar dùng initials khi server chưa có ảnh.
- API thật `GET /api/v1/mobile/activity/monthly?month=YYYY-MM` tổng hợp trips,
  work logs và safety events theo tài xế đăng nhập. Test live tháng 2026-07 trả 31 ngày,
  safetyScore 80, totalTrips 2, alertCount 3.
- AI service có `POST /chat/respond`; backend bảo vệ bằng JWT tại
  `POST /api/v1/mobile/agent/chat`. Mặc định model `gpt-4o-mini`, key chỉ phía server,
  `store=false`; thiếu key trả local safe fallback.
- Agent giữ lịch sử hội thoại trong provider, STT/TTS trên thiết bị, wake phrase
  `Hi Siri`/`Hey Siri`/`Hi SafeFleet`/`Hey SafeFleet`, overlay tối + waveform ngoài tab
  Agent. Lệnh SOS/báo ngập/thay đổi chuyến vẫn dùng sheet xác nhận cũ.
- `flutter analyze`: PASS, không issue. `flutter test`: 12/12 PASS.
- Python AI: 11/11 PASS trong image runtime + requirements dev.
- Backend unit/controller smoke: 16/16 PASS. Lần chạy Testcontainers từ bên trong
  container Maven bị chặn bởi network callback Docker Desktop (Ryuk rồi MySQL mapped
  port), không phải assertion; API live trên MySQL Docker chính đã được test trực tiếp.
- `flutter build apk --debug`: PASS. APK đã cài thành công trên `emulator-5554`.
- Docker build backend + AI service: PASS. Endpoint monthly/chat đã test qua tài khoản
  driver thật; toàn bộ stack đang chạy.
- Bản đồ Android E2E: autocomplete Mỹ Đình PASS; Hồ Hoàn Kiếm → Mỹ Đình trả 3 route,
  tuyến đề xuất 8,0 km/15 phút; flood thật id 12 làm UI đổi từ 0 sang 1 điểm.
- Camera Android E2E trên AVD: trang/công tắc/model fallback khởi động, thoát trang vẫn
  còn pill `AI ON` toàn app. Camera ảo AVD không cấp frame preview ổn định; phải chạy
  thêm trên máy Android thật trước release.
- OpenAPI report đã tái sinh: 136 paths, 155 operations, 174 schemas; có monthly/chat.

## File chính vừa thêm/sửa

- `safe_fleet_driver_ui/lib/features/shell/driver_shell.dart`
- `safe_fleet_driver_ui/lib/features/navigation/route_planner_screen.dart`
- `safe_fleet_driver_ui/lib/features/camera/cabin_camera_screen.dart`
- `safe_fleet_driver_ui/lib/core/ai/cabin_safety_provider.dart`
- `safe_fleet_driver_ui/lib/core/agent/agent_conversation_provider.dart`
- `safe_fleet_driver_ui/lib/features/agent/agent_chat_screen.dart`
- `safe_fleet_driver_ui/lib/features/profile/profile_screen.dart`
- `safe_fleet_driver_ui/lib/features/insights/monthly_insights_screen.dart`
- `web_quan_ly/backend/.../MobileMonthlyActivityResponse.java`
- `web_quan_ly/backend/.../AgentConversationService.java`
- `safefleet_ai/service/main.py`

## Công việc đang chạy / bước kế tiếp bắt buộc

1. Build/cài APK cuối sau khi chuyển pill AI lên tầng `MaterialApp`.
2. Test camera preview/detection bằng điện thoại Android có camera thật.
3. Cấu hình OpenAI key rồi chạy smoke call thật với `gpt-4o-mini`.
4. Chạy lại Testcontainers từ host Maven hoặc CI Linux có Docker network callback.
5. Kiểm tra trực quan web Command Center/Safety Center sau event mobile.

## Giới hạn trung thực

- `.env` hiện không có `OPENAI_API_KEY`, nên local fallback đã được test nhưng cuộc gọi
  OpenAI thật chưa thể PASS cho tới khi chủ dự án cung cấp key. Không nhúng key vào app.
- Wake phrase và camera xuyên trang chỉ được cam kết khi app ở foreground; Android/iOS
  có giới hạn khi app background/killed.
- Avatar hiện là fallback initials vì schema chưa có `avatarUrl`/upload ảnh tài xế.

# 25. CHECKPOINT FACE MESH / CẢNH BÁO NGỦ GẬT — 2026-08-02 23:30

## Thiết kế đã chọn

- Xử lý ảnh trực tiếp trên điện thoại để cảnh báo không phụ thuộc mạng, giảm độ trễ
  và không truyền video cabin lên server. Server chỉ nhận sự kiện cùng EAR, MAR, góc
  đầu, iris, điểm hiện tại và điểm dự báo qua hàng đợi đồng bộ hiện có.
- Luồng Flutter foreground dùng ML Kit Face Mesh 468 điểm kết hợp model TFLite STGT.
  Luồng Android background dùng Camera2 + ML Kit Face Mesh và luật EAR/MAR/PERCLOS.
- Không dùng chung camera ở hai runtime: khi app vào nền Flutter nhả camera, native
  service tiếp quản; khi app trở lại foreground native nhả camera cho Flutter.

## Tương thích pipeline Python do người dùng cung cấp

- Tần số mục tiêu 25 FPS; throttle xử lý khoảng 35 ms tùy hiệu năng thiết bị.
- EAR đúng công thức và landmark mắt trái `[362,385,387,263,373,380]`, mắt phải
  `[33,160,158,133,153,144]`.
- MAR đúng công thức và landmark môi `[78,308,13,14]`.
- Pitch/yaw/roll cùng đơn vị độ nhưng lấy từ ML Kit Face Detection, không hoàn toàn
  đồng nhất với `solvePnP` OpenCV trong pipeline huấn luyện.
- ML Kit Face Mesh chỉ trả 468 điểm, không có iris refine 468..477. Đặc trưng iris được
  giữ 0/trung tính thay vì tạo proxy nhiễu. Muốn tương thích tuyệt đối cần tích hợp
  MediaPipe Face Landmarker 478 điểm và OpenCV solvePnP native trong vòng tiếp theo.
- Cửa sổ 75 khung × 12 đặc trưng, nội suy tối đa 10 frame, Savitzky–Golay 11/poly2,
  chuẩn hóa cá nhân và delta vẫn do `StgtDrowsinessEngine` thực hiện.
- Hiệu chuẩn tăng từ 75 lên 1.500 khung hợp lệ, chỉ nhận mặt nhìn tương đối thẳng,
  mắt mở tự nhiên; mean/std lưu bằng secure storage và tái sử dụng ở lần mở sau.

## Khả năng chạy nền

- Camera nền tăng từ 320×240 lên 640×480 để giảm nhiễu hình học quanh mắt/môi.
- Foreground service chuyển sang `START_STICKY`, ghi nhớ foreground/background và tự
  phục hồi camera native nếu Android/MIUI tái tạo process.
- `stopWithTask=false`; vuốt task không chủ động tắt service. Nút Dừng trên notification
  và đăng xuất vẫn dừng camera rõ ràng. Android force-stop trong Settings vẫn không thể
  tự khởi động lại do chính sách hệ điều hành.

## Kết quả kiểm tra

- `flutter analyze`: PASS, 0 issue.
- `flutter test`: PASS 15/15.
- `flutter build apk --debug`: PASS sau khi biên dịch cả Kotlin Face Mesh native.
- APK cài thành công lên Xiaomi `22011211C`, Android 14, id `JVKNYLBALV4LZDI7`.
- Runtime máy thật: camera khóa đúng khuôn mặt và hiển thị số đo trực tiếp EAR `0.301`,
  MAR `0.003`, pitch/yaw `-5°/2°`; không có `FATAL EXCEPTION` trong logcat.
- Chưa tuyên bố đạt độ chính xác production: cần phiên test có nhắm mắt/ngáp thực tế,
  ánh sáng yếu, đeo kính, rung xe và đối chiếu nhãn để hiệu chỉnh threshold/model.
