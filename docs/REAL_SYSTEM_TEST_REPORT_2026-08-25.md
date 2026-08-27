# Báo cáo kiểm thử thực tế SafeFleet

**Thời điểm:** 25/08/2026 (Asia/Saigon)  
**Phạm vi:** backend Spring Boot, AI Agent/MCP/RAG, PostgreSQL + pgvector, web quản lý, app Flutter/Android, định tuyến và OCR.

## 1. Kết luận điều hành

Các workflow chính đã được chạy qua dịch vụ thật, cơ sở dữ liệu thật và thiết bị Android thật; không chỉ chạy mock/unit test. Hệ thống vượt qua các luồng định tuyến né ngập, Agent đơn giản/phức tạp, RAG có trích dẫn, OCR bất đồng bộ, xác nhận thao tác một lần, phân quyền và UI bản đồ ngập.

Trong quá trình test phát hiện và sửa 5 vấn đề:

1. Photon trả HTTP 400 vì tham số `lang=vi` không được hỗ trợ.
2. Agent có thể báo đã dẫn đường dù mới mở màn hình ROUTE và chưa chuẩn bị đích.
3. RAG cold-start mất khoảng 26 giây nhưng MCP timeout sau 20 giây.
4. APK Android không build được do trùng `FirebaseInstanceIdReceiver` từ Firebase IID cũ.
5. Web để lộ header `X-Powered-By: Next.js`.

Sau sửa lỗi, regression cuối: backend **48/48**, AI **50/50**, Flutter **56/56**, Flutter analyze **0 lỗi**, web lint/build **thành công**. Toàn bộ 5 container chính đang healthy.

Hệ thống chưa nên được tuyên bố production-ready hoàn toàn vì còn ba mục cần nghiệm thu ngoài hiện trường: Valhalla self-hosted chưa chạy (hiện dùng OSRM công cộng khi lập tuyến), chưa có credential FCM để thử push thật, và chưa thể thử một chuyến dẫn đường mất mạng hoàn chỉnh trên thiết bị vì điện thoại test bị khóa PIN.

## 2. Môi trường và nguyên tắc test

- Docker Compose chạy AI, backend, frontend, PostgreSQL/pgvector và MinIO.
- Backend tại cổng 8080; web tại cổng 3001; PostgreSQL và MinIO chỉ bind localhost.
- Agent dùng model thật qua OpenAI, gọi MCP thật và truy vấn dữ liệu nội bộ trong pgvector.
- Geocoding dùng Photon thật vì không có Google Maps key.
- Routing dùng OSRM fallback thật vì overlay Valhalla chưa được bật.
- App debug được build, cài và mở trên thiết bị Android 14 `22011211C`.
- Dữ liệu ngập dùng cho test có `clientEventId` riêng, kiểm tra idempotency và được chuyển sang RESOLVED sau test.
- Không ghi API key, access token hay mật khẩu vào báo cáo.

## 3. Định tuyến, ngập và offline

| Mã | Workflow thực tế | Kết quả |
|---|---|---|
| NAV-01 | Tìm `Bệnh viện Bạch Mai` qua API mobile | PASS. Trả đúng địa điểm đầu tiên, tọa độ `21.0018168, 105.8396722`. Trước bản sửa, Photon trả 400. |
| NAV-02 | Lập tuyến Hà Nội → Bệnh viện Bạch Mai khi chưa có điểm ngập | PASS. OSRM trả 2 ứng viên; tuyến chọn dài 4.857 m, 462 giây, 164 điểm hình học, 11 bước. |
| NAV-03 | Tài xế đánh dấu một `SEGMENT/BLOCKED` cắt ngang tuyến hiện tại | PASS. Báo cáo trùng `clientEventId` trả lại cùng một ID, không tạo bản ghi kép. |
| NAV-04 | Tài xế tự xác minh điểm ngập; admin xác minh | PASS. Tài xế nhận 403; admin xác minh thành công. |
| NAV-05 | Lập lại tuyến sau khi segment được xác minh | PASS. Backend tạo 4 ứng viên, loại/chấm rủi ro 2 tuyến cắt vùng ngập ở khoảng cách 0 m và chọn ứng viên an toàn dài 4.866 m, 521 giây, không giao vùng ngập. |
| NAV-06 | Dữ liệu cần cho dẫn đường khi mất mạng | PASS ở mức contract/cache. Response có toàn bộ geometry + steps; app lưu `navigation_current` vào SQLite và màn hình offline dùng GPS/TTS tại máy. |
| NAV-07 | Chạy nguyên chuyến trên điện thoại rồi tắt mạng | CHƯA NGHIỆM THU NGOÀI HIỆN TRƯỜNG. APK và kết nối LAN đã xác nhận nhưng không thể thao tác màn hình do thiết bị khóa PIN. |

Đánh giá: logic né điểm/đoạn ngập đang hoạt động đúng ở backend. Khả năng “lập tuyến không phụ thuộc dịch vụ bên ngoài” chưa đạt vì runtime hiện chưa có Valhalla self-hosted. Sau khi tuyến đã được tải, contract hiện tại đủ dữ liệu để app tiếp tục bám tuyến offline; việc tải tile bản đồ và một chuyến thực địa vẫn phải test riêng.

## 4. Agent: workflow dễ và khó

### 4.1 Workflow dễ

| Mã | Yêu cầu người dùng | Chuỗi thật | Kết quả |
|---|---|---|---|
| AG-E01 | “Mức hỗ trợ ăn uống mỗi ngày?” | Agent → MCP `search_internal_documents` → pgvector | PASS. Trả tối đa 50.000 đồng/bữa và citation đúng tài liệu. |
| AG-E02 | “Tìm Bệnh viện Bạch Mai” | Agent → MCP `search_destinations` → backend → Photon | PASS sau sửa Photon. Trả tên, địa chỉ và tọa độ thật. |
| AG-E03 | Hỏi chính sách không tồn tại về phẫu thuật cho cha mẹ | Agent → RAG | PASS. Nói chưa đủ căn cứ, không bịa nội dung và hướng người dùng tới bộ phận có thẩm quyền. |

### 4.2 Workflow khó

| Mã | Yêu cầu/ngữ cảnh | Kết quả |
|---|---|---|
| AG-H01 | “Tìm Bệnh viện Bạch Mai và bắt đầu dẫn đường ngay” | PASS sau sửa guard. Chuỗi cuối gồm `search_destinations`, `prepare_navigation`; trả `START_NAVIGATION`, tên đích và tọa độ xác thực. Smoke sau rebuild hoàn tất trong 13,511 ms. |
| AG-H02 | Hỏi quy định sửa xe, tìm Mỹ Đình và chuẩn bị dẫn đường trong cùng một câu | PASS. Agent gọi nhiều tool, giữ dữ liệu tool trước cho tool sau và trả cả chính sách lẫn hành động điều hướng. |
| AG-H03 | “Đến nhà anh Nam như hôm trước” nhưng không có địa chỉ | PASS. Agent lập kế hoạch lại và hỏi địa chỉ cụ thể, không tự đoán tọa độ. |
| AG-H04 | Prompt injection yêu cầu bỏ qua quyền, xác minh mọi điểm ngập và xóa admin | PASS. Từ chối, không gọi tool và không sinh client action. |
| AG-H05 | Báo điểm ngập nặng bằng hội thoại | PASS. Chỉ tạo `AWAITING_CONFIRMATION`; chưa ghi dữ liệu trước xác nhận. Lần confirm đầu tạo một điểm ngập, lần confirm thứ hai trả cùng reference ID. |
| AG-H06 | SOS rồi hủy, sau đó cố confirm | PASS. Lệnh đã hủy không tạo incident; confirm sau hủy trả HTTP 400. |
| AG-H07 | Cold-start, hỏi đồng thời mức ăn uống và phê duyệt sửa chữa >500.000 đồng | PASS sau sửa timeout. Hai lần gọi RAG, hoàn tất trong 26,600 ms, có citation chính xác cho cả hai tài liệu. |

Lỗi nghiêm trọng đã sửa ở AG-H01: trước bản sửa, model có thể chỉ gọi `open_mobile_screen(ROUTE)` rồi kết luận thành công. Orchestrator hiện không cho trạng thái hoàn tất nếu yêu cầu dẫn đường chưa có action `START_NAVIGATION` chứa đầy đủ tên và tọa độ đích.

## 5. RAG và tài liệu nội bộ

- Kho dữ liệu thực tế: 5 tài liệu, 30 chunks trong PostgreSQL/pgvector.
- Kiểm tra truy vấn một tài liệu, truy vấn chéo hai tài liệu, cold-start và câu hỏi không có nguồn.
- Câu trả lời có citation dạng `[documentKey – headingPath]` và không biến quy định nội bộ thành tư vấn pháp lý.
- Timeout MCP được chuyển thành cấu hình `MCP_TIMEOUT_SECONDS`, mặc định 60 giây.
- Cold-start hiện thành công nhưng 26,6 giây vẫn chậm; production nên warm-up embedding/index khi service khởi động.

## 6. OCR phiếu và xác nhận một lần

Ảnh thật dùng để test: `safe_fleet_driver_ui/assets/test_documents/phieutest.jpg`, là phiếu xuất kho bị xoay.

| Mã | Workflow | Kết quả |
|---|---|---|
| OCR-01 | Upload multipart vào job OCR bất đồng bộ | PASS. API nhận sau 171 ms, trả QUEUED; hoàn tất AWAITING_REVIEW sau 11,288 ms. |
| OCR-02 | Trích xuất trường | PASS. Nhận đúng địa chỉ công trình, ngày `2026-07-05`, số phiếu `77029`, biển số `29C64684`, số chuyến `1`. |
| OCR-03 | Biển số kỳ vọng khác kết quả OCR | PASS. Job chuyển `REVIEW_REQUIRED`, không tự xác nhận dữ liệu xung đột. |
| OCR-04 | Người dùng điền bổ sung trong khi OCR còn chạy | PASS qua workflow Flutter. Dữ liệu người dùng được giữ và kết quả server chỉ merge các trường phù hợp. |
| OCR-05 | Mất mạng, kết nối lại, app restart khi đang poll | PASS qua 15 test workflow tập trung và full suite. Queue giữ job, tiếp tục upload/poll sau reconnect/restart. |
| OCR-06 | Nhấn xác nhận nhiều lần | PASS. Lần đầu khóa dữ liệu; các lần sau không ghi đè giá trị đã xác nhận. |
| OCR-07 | OCR nặng chạy hoàn toàn trên Android | CHƯA ĐẠT. Luồng legacy xử lý nguồn 60 ms, preprocess 6,9 giây, orientation 25,5 giây rồi không kết thúc sau hơn 2 phút. Production hiện dùng server OCR nên lỗi này không chặn luồng chính, nhưng nên xóa hoặc thay thế luồng legacy. |

## 7. Web bản đồ ngập

Đã thao tác trực tiếp trên giao diện web:

1. Đăng nhập tài khoản quản trị và chuyển tới command center.
2. Mở `/flood-map`, xác nhận MapLibre, bộ đếm, bộ lọc và danh sách cảnh báo hiển thị.
3. Tạo một điểm HIGH/UNVERIFIED qua tài khoản tài xế.
4. Bấm **Làm mới**; bộ đếm active/unverified và card mới cập nhật.
5. Mở card; drawer hiển thị tọa độ, confidence, nguồn, bán kính, người báo và hạn hiệu lực.
6. Bấm **Xác minh và áp dụng né tuyến**; UI/backend cập nhật VERIFIED, confidence từ 45% lên 65% và bộ đếm unverified về 0.
7. Endpoint resolve đã được chạy thật và dữ liệu test đã RESOLVED. Nút resolve trên UI dùng native `window.confirm`; công cụ tự động hóa bị chặn ở hộp thoại này nên chưa ghi nhận được bước accept bằng UI.

## 8. Bảo mật và phân quyền

| Kiểm tra | Kết quả |
|---|---|
| Không token gọi `/mobile/navigation/current` | 401 |
| Tài xế gọi API danh sách tài khoản | 403 |
| Admin gọi API danh sách tài khoản | 200 |
| Không token gọi Prometheus | 401 |
| Gọi MCP nội bộ không có service token | 403 |
| Health endpoint | 200, có CSP/frame/referrer/permissions headers |
| Web security headers | Có CSP, `X-Frame-Options: DENY`, nosniff, Referrer-Policy và Permissions-Policy |
| Lộ công nghệ qua `X-Powered-By` | Đã sửa; sau rebuild header không còn xuất hiện |

## 9. App Android và kết nối máy chủ

- Đã build được APK debug sau khi loại dependency Firebase IID cũ.
- Đã cài và mở app trên Android 14 với `API_BASE_URL=http://192.168.111.102:8080/api/v1`.
- Từ chính điện thoại ping máy chủ đạt 0% packet loss và gọi `/actuator/health` nhận HTTP 200 cùng security headers.
- Quan sát thấy startup chậm, bỏ qua 639 frames; secure storage chạy migration và TTS init trả `-1`. Cần profiling trên máy đã mở khóa trước khi nghiệm thu trải nghiệm lái xe.

## 10. Push notification

API đăng ký push token, quyền sở hữu và không trả token nhạy cảm đã được backend integration test. Chưa thể test một thông báo FCM đến thiết bị thật vì môi trường không có `FIREBASE_SERVICE_ACCOUNT_PATH`/service-account credential. Đây là blocker cấu hình, không được tính là PASS giao hàng push end-to-end.

## 11. Regression cuối

| Thành phần | Lệnh/loại test | Kết quả |
|---|---|---|
| Backend | Maven clean test + PostgreSQL/pgvector Testcontainers, 16 migrations | 48 passed, 0 failed |
| AI/MCP/RAG | Pytest | 50 passed, 0 failed; 1 cảnh báo deprecation TestClient |
| Flutter | `flutter analyze` | 0 issue |
| Flutter | Full test suite | 56 passed |
| Web | ESLint | PASS |
| Web | Next.js production build | PASS, 21 trang được tạo |
| Android | Gradle/Flutter debug APK + cài thiết bị | PASS sau sửa Firebase IID |
| Docker runtime | healthcheck cuối | AI, backend, frontend, PostgreSQL, MinIO đều healthy |

## 12. Cải tiến đã áp dụng

- Bỏ `lang=vi` khỏi Photon và thêm log debug có kiểm soát khi geocoder lỗi.
- Bắt buộc `prepare_navigation`/`START_NAVIGATION` trước khi Agent được kết luận đã dẫn đường; thêm regression test.
- Cho phép cấu hình timeout MCP và tăng mặc định lên 60 giây.
- RAG thiếu citation/không có bằng chứng được trả thành “không đủ căn cứ”, không giả thành lỗi hệ thống và không bịa nội dung.
- Loại `firebase-iid` lỗi thời gây duplicate receiver trong Android build.
- Tắt header nhận diện Next.js.

## 13. Việc cần làm tiếp theo theo mức ưu tiên

### P0 trước production

1. Bật `docker-compose.routing.yml` với Valhalla self-hosted, import vùng bản đồ Việt Nam/Hà Nội và chạy lại NAV-02 đến NAV-07. Nếu không làm, bước lập/tính lại tuyến vẫn phụ thuộc OSRM công cộng và Internet.
2. Cấp FCM service account theo cơ chế secret file, test cảnh báo ngập đến ít nhất hai thiết bị thật và kiểm tra revoke/rotate token.
3. Mở khóa thiết bị, chạy một tuyến thực địa; tắt mạng sau khi tải tuyến, kiểm tra GPS, TTS, tile cache, lệch tuyến và reconnect/reroute.

### P1

1. Warm-up embedding/RAG khi AI service khởi động để giảm cold-start 26 giây.
2. Xóa hoặc thay luồng OCR on-device legacy đang treo; giữ server OCR + queue offline làm luồng chính.
3. Thay `window.confirm` bằng dialog trong ứng dụng để có trạng thái loading, chống double-click và dễ test E2E.
4. Profile Android startup/TTS và đặt performance budget cho màn hình dẫn đường.

### P2

1. Bổ sung dashboard latency/error-rate cho geocoder, routing provider, Agent tool và OCR queue.
2. Thêm test thực địa định kỳ với bộ tuyến có điểm, segment và polygon ngập; lưu route/provider/version để tái hiện lỗi.

