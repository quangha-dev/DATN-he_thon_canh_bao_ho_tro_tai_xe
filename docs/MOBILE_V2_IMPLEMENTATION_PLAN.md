# Kế hoạch triển khai SafeFleet Driver V2

Ngày lập: 2026-07-28  
Trạng thái: **DOING — Loop 5: Android E2E, sửa ANR tải trang lười và hồi quy**

## 1. Mục tiêu người dùng

Tài xế phải có thể dùng app như một buồng lái số: tìm tuyến trước hoặc trong chuyến,
nhìn rõ tuyến tránh ngập, bật giám sát buồn ngủ một lần và tiếp tục dùng các màn hình
khác, xem hồ sơ/thành tích tháng, và gọi trợ lý bằng giọng nói mà không phải tìm nút.

## 2. Phạm vi tính năng và tiêu chí nghiệm thu

### P0. App shell và điều hướng

- Dock nổi dạng viên thuốc, nền trắng, tối đa năm đích: Trang chủ, Bản đồ, Agent,
  Hoạt động, Hồ sơ.
- Dùng `IndexedStack` để giữ state mỗi tab; route nghiệp vụ chi tiết vẫn dùng Navigator.
- Chỉ báo camera/AI nhỏ luôn nằm trên shell khi đang bật.
- Overlay wake-word làm tối nội dung, hiển thị waveform và có nút hủy rõ ràng.

### P0. Bản đồ tìm đường tránh ngập

- Chọn điểm đầu bằng vị trí hiện tại hoặc Photon search; chọn điểm cuối bằng search.
- Gọi backend `/mobile/locations/autocomplete`, không gọi Photon trực tiếp.
- Gọi `/mobile/navigation/routes`, hiển thị tối đa ba tuyến, tuyến đề xuất và cảnh báo.
- Hiển thị điểm ngập lấy từ MySQL qua `/mobile/flood-points/nearby`.
- Màu tuyến: xanh an toàn, cam còn rủi ro, xám cho alternative; không dùng chữ “an
  toàn” nếu backend trả `safe=false`.
- Navigation session phải xuất hiện trong MySQL và web tiếp tục đọc cùng nguồn ngập.

### P0. Camera và phát hiện buồn ngủ xuyên trang

- Trang camera có preview, trạng thái model, nút bật/tắt và lựa chọn STGT/ML Kit.
- `CabinAiController` thuộc provider toàn app, không thuộc riêng Driving Mode.
- Chuyển tab hoặc mở màn khác không dispose camera; logout/app dispose mới giải phóng.
- Chỉ báo toàn cục cho biết `đang hiệu chuẩn/đang giám sát/đã dừng/lỗi`.
- Detection tiếp tục vào offline queue rồi MySQL; web Safety Center thấy cùng event.

### P1. Hồ sơ và tổng quan tháng

- Hồ sơ: avatar/fallback initials, họ tên, điện thoại, email, địa chỉ, trạng thái, bằng
  lái, hạng bằng, ngày hết hạn, xe hiện tại, điểm an toàn, tổng chuyến/cảnh báo.
- Tổng quan tháng: số chuyến hoàn thành, quãng đường, thời gian lái, điểm an toàn,
  cảnh báo theo loại, số SOS/báo ngập và xu hướng theo tuần.
- Dữ liệu tháng do backend tổng hợp theo driver hiện tại; không cộng giả trong Flutter.

### P1. Agent hội thoại và wake phrase

- Trang riêng lưu transcript hội thoại, mic lớn, trạng thái nghe/suy nghĩ/đọc.
- Khi ở tab Agent: hiển thị bubble hội thoại chi tiết.
- Khi ở tab khác: nghe được wake phrase “Hi Siri” khi app đang foreground, phủ lớp tối
  và waveform. Do giới hạn quyền riêng tư hệ điều hành, không tuyên bố hoạt động khi app
  đã bị đóng hoặc bị OS suspend.
- Luồng: STT local → intent rule → nếu là thao tác thì xác nhận → API thật → verify →
  TTS. Hội thoại thường gửi backend/AI service.
- Model hội thoại theo yêu cầu: `gpt-4o-mini`; key chỉ ở AI service. GPT-4o mini xử lý
  text/Structured Outputs, còn âm thanh dùng STT/TTS trên thiết bị.
- Khi không có key: trả fallback hữu ích và các intent nghiệp vụ vẫn hoạt động.

## 3. Thứ tự loop

1. **Loop 1 — PASS:** shell, dock, global cabin service, camera page, route planner.
2. **Loop 2 — PASS:** API monthly summary + profile UX + API/MySQL proof.
3. **Loop 3 — PASS:** hội thoại giữ state, adapter `gpt-4o-mini`, Agent page; lệnh
   nghiệp vụ tiếp tục dùng confirmation flow riêng.
4. **Loop 4 — PASS có giới hạn OS:** foreground wake controller, waveform overlay,
   privacy controls. Không cam kết wake khi app bị kill/suspend.
5. **Loop 5 — DOING:** tải lười MapLibre để loại ANR lúc khởi động, Android E2E,
   web verification, regression và tài liệu.

## 4. Rủi ro và quyết định

- Camera “xuyên trang” nghĩa là xuyên màn hình trong cùng app foreground. Camera nền khi
  app ra background bị Android/iOS giới hạn và cần foreground service/notification cùng
  đánh giá store policy riêng.
- “Hi Siri” có thể xung đột nhãn hiệu/wake word của hệ điều hành; code sẽ cho phép đổi
  sang “Hey SafeFleet” bằng config mà không đổi luồng UX.
- Không gửi video cabin lên OpenAI. Frame chỉ xử lý on-device; server chỉ nhận event và
  evidence đã chọn.
- Không đưa OpenAI key vào Flutter, kể cả debug.

## 5. Bằng chứng bắt buộc trước DONE

- `flutter analyze`, `flutter test`, APK debug/release-gate build.
- Backend unit + Testcontainers MySQL.
- Docker health toàn stack.
- Android emulator/thiết bị thật: tìm địa điểm, route, flood marker, bật camera, đổi tab,
  chỉ báo vẫn active, event vào queue/MySQL.
- Web: điểm ngập và safety event từ app hiển thị đúng.
