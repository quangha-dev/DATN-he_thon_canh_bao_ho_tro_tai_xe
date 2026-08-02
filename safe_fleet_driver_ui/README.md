# SafeFleet Driver

Ứng dụng Flutter cho tài xế kết nối trực tiếp SafeFleet backend.

## Tính năng

- Login, refresh token, logout và secure storage.
- Bootstrap hồ sơ/assignment/trip; checklist và workflow chuyến.
- GPS telemetry đơn/batch; SQLite offline queue có priority và ACK.
- Safety/SOS/flood report/notification/timeline incident.
- MapLibre navigation, alternative route, flood warning, off-route/reroute.
- Camera AI on-device có hai chế độ chuyển trực tiếp trên màn hình lái xe: STGT fold 1 TFLite (mặc định) và ML Kit temporal dự phòng.
- STGT dùng cửa sổ 75 khung hình × 12 đặc trưng, hiệu chuẩn theo tài xế trước khi chấm điểm; phone label vẫn dùng ML Kit ở cả hai chế độ.
- Cảnh báo haptic/UI cục bộ trước khi đồng bộ metadata; không stream video liên tục.
- Android foreground camera service giữ giám sát khi nhấn Home hoặc chuyển sang
  ứng dụng khác. Notification thường trực hiển thị engine hiệu lực, camera trước,
  số cảnh báo và có thao tác mở SafeFleet/dừng giám sát.

## Chạy

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Điện thoại thật cùng LAN:

```powershell
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-PC>:8080/api/v1
```

## Build Android

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

HTTP cleartext chỉ được phép ở manifest `debug/profile`; manifest `main` bắt buộc HTTPS. Release build không dùng debug signing và sẽ từ chối chạy nếu thiếu:

```powershell
$env:SAFEEFLEET_ANDROID_STORE_FILE="D:\secure\safefleet-release.jks"
$env:SAFEEFLEET_ANDROID_STORE_PASSWORD="<secret>"
$env:SAFEEFLEET_ANDROID_KEY_ALIAS="safefleet"
$env:SAFEEFLEET_ANDROID_KEY_PASSWORD="<secret>"
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://api.example.vn/api/v1
```

Không commit keystore hoặc password. Trước khi phát hành còn cần domain/TLS, Firebase credential và kiểm thử camera/GPS nền, mất mạng dài, pin/nhiệt trên thiết bị Android thật.

## Model buồn ngủ STGT

- Runtime: `assets/models/drowsiness_model.tflite`.
- Nguồn: `best_model_fold_1.pth`, SHA-256 `79CF58033CFD358164F350183839CF2F73D275DAA1BB5271CAABE09DF3F0894C`.
- Nếu model TFLite không nạp được, controller tự động dùng ML Kit temporal và báo trạng thái trên giao diện.
- Adapter Flutter hiện dùng ML Kit Face Mesh 468 điểm. EAR dùng đúng `[362,385,387,263,373,380]` và `[33,160,158,133,153,144]`; MAR dùng đúng `[78,308,13,14]` như pipeline Python. Head pose lấy theo độ từ ML Kit Face Detection. `iris_movement` được giữ trung tính vì ML Kit không có 10 điểm iris refine 468..477 của MediaPipe; không dùng giá trị giả gây nhiễu model.
- Hiệu chuẩn cá nhân dùng 1.500 khung hình hợp lệ (xấp xỉ 60 giây ở 25 FPS) và được lưu an toàn để các lần sau không phải làm lại. Trước pilot production vẫn cần đánh giá lại threshold trên dữ liệu cabin thật, kính, ban đêm và rung xe.

## Giám sát camera nền trên Android

1. Mở màn hình **Giám sát tỉnh táo** và bật giám sát khi SafeFleet đang hiển thị.
2. Cấp quyền camera và thông báo. Từ Android 14, foreground camera service bắt
   buộc phải được khởi động từ một Activity đang hiển thị.
3. Khi người dùng nhấn Home/chuyển app, Flutter trả camera cho native Camera2.
   ML Kit native tiếp tục kiểm tra mắt, PERCLOS và góc đầu trong foreground service.
4. Mở notification để quay lại app hoặc chọn **Dừng giám sát** để đóng camera và
   service. Đăng xuất cũng tự động dừng service.

Android không cho phép ứng dụng tự ý bật lại camera từ nền sau khi người dùng đã
force-stop ứng dụng hoặc chưa chủ động bật giám sát. Đây là ràng buộc riêng tư của
hệ điều hành, không phải lỗi SafeFleet.
