# SafeFleet — Kiểm thử app trên thiết bị

## Endpoint

- Android emulator: `http://10.0.2.2:8080/api/v1`.
- Điện thoại thật cùng LAN: `http://<IP-LAN-PC>:8080/api/v1`.
- Không dùng `localhost` từ điện thoại.

Cho phép inbound TCP 8080 trên máy phát triển và kiểm tra điện thoại/PC cùng mạng.

## Chạy

```powershell
cd safe_fleet_driver_ui
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-PC>:8080/api/v1
```

APK debug đã build:

```text
safe_fleet_driver_ui/build/app/outputs/flutter-apk/app-debug.apk
```

## Checklist pilot bắt buộc

- Login/refresh/logout và secure storage.
- Quyền camera, location while-in-use/background và notification.
- Camera trước hoạt động đúng khi xoay máy; không upload video liên tục.
- Nhắm mắt/ngáp/phone usage tạo cảnh báo sau đúng thời lượng và cooldown.
- GPS cập nhật khi màn hình khóa theo chính sách hệ điều hành.
- Mất mạng 10–30 phút: SOS/safety/workflow/flood/telemetry giữ đúng priority và chỉ xóa sau ACK.
- Cùng `clientEventId` retry không tạo bản ghi trùng.
- Dẫn đường ba alternative, vùng ngập, off-route 75 m/15 giây và reroute.
- SOS xuất hiện trên web; admin accept; app thấy timeline/status mới.
- Evidence tải được bởi chủ sở hữu và bị 403 với tài xế khác.
- Đo pin, nhiệt, bộ nhớ và FPS camera trên thiết bị mục tiêu.

## Trạng thái phiên 28/07/2026

Đã cài Android 15 Google APIs x86_64 và tạo AVD `SafeFleet_API_35`. APK debug cài và mở thành công trên `emulator-5554`; tài khoản hiện hành là `driver001` / `123456`, liên kết tài xế mã `001` và xe `001`. Đăng nhập qua backend Docker `10.0.2.2:8080` PASS, dashboard và Lịch trình hôm nay nhận đúng chuyến được giao từ web, không có lỗi fatal/network. Camera webcam, GPS nền, pin/nhiệt và độ chính xác STGT ngoài thực địa vẫn là gate cần thiết bị thật.
