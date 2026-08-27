# BÁO CÁO ĐỐI CHIẾU USE CASE VỚI HỆ THỐNG SAFEFLEET HIỆN TẠI

## 1. Mục đích và phương pháp đánh giá

Tài liệu này kiểm tra từng sơ đồ use case so với mã nguồn đang có của SafeFleet. Mỗi use case được đánh giá theo hai nhóm tiêu chí độc lập:

1. **Độ phủ chức năng:** Chức năng trong sơ đồ có được triển khai trên giao diện, API, xử lý nghiệp vụ và dữ liệu hay không.
2. **Độ chính xác mô hình UML:** Actor, phạm vi hệ thống, tên use case, hướng mũi tên và quan hệ `include`/`extend` có phản ánh đúng hành vi thực tế hay không.

Thang đánh giá:

| Mức | Ý nghĩa |
|---|---|
| Đúng | Mô tả khớp với hệ thống hiện tại và có bằng chứng mã nguồn. |
| Đúng một phần | Có chức năng nhưng phạm vi, actor, điều kiện hoặc quan hệ UML chưa hoàn toàn chính xác. |
| Chưa đúng | Sơ đồ mô tả khác với hành vi thực tế hoặc dùng sai quan hệ UML. |
| Chưa triển khai | Không tìm thấy luồng xử lý tương ứng trong hệ thống hiện tại. |

Mốc đối chiếu ngày 27/08/2026: nhánh `redesign/web-quan-ly-ui`, commit gần nhất `7210082`, đồng thời workspace còn có các thay đổi chưa commit. Vì vậy, kết luận trong tài liệu phản ánh **mã nguồn thực tế trong workspace tại thời điểm kiểm tra**, không chỉ riêng commit `7210082`.

---

## 2. Use case 01 — Xác thực và quản lý phiên

### 2.1. Nội dung sơ đồ được kiểm tra

- Actor: Lái xe.
- Use case trung tâm: Xác thực và quản lý phiên.
- Các use case liên quan: Đăng nhập, Đăng xuất, Khôi phục phiên, Làm mới access token và Cấp quyền thiết bị.
- Quan hệ đang thể hiện: Đăng nhập, Đăng xuất và Khôi phục phiên dùng `include`; Làm mới access token và Cấp quyền thiết bị dùng `extend` với use case trung tâm.

### 2.2. Kết quả đối chiếu chức năng

| Thành phần trong sơ đồ | Bằng chứng trong hệ thống hiện tại | Kết quả |
|---|---|---|
| Xác thực và quản lý phiên | Backend dùng Spring Security ở chế độ stateless, xác thực JWT cho các API được bảo vệ. Ứng dụng tài xế có `SessionController` quản lý ba trạng thái `checking`, `signedOut`, `signedIn`. | Đúng |
| Đăng nhập | App tài xế gửi tài khoản/email và mật khẩu tới `POST /api/v1/auth/login`. Backend xác thực bằng `AuthenticationManager`, sau đó phát access token và refresh token. | Đúng |
| Đăng xuất | App gọi `POST /api/v1/auth/logout`, backend thu hồi refresh token; app luôn xóa access token và refresh token cục bộ rồi chuyển về trạng thái chưa đăng nhập. | Đúng |
| Khôi phục phiên | Khi app khởi động, hệ thống đọc token trong secure storage, gọi `/auth/me` để kiểm tra và khôi phục giao diện đã đăng nhập. Nếu mất mạng tạm thời, app vẫn giữ phiên để dùng dữ liệu offline; nếu server trả 401, app xóa phiên. Web quản lý cũng kiểm tra token và gọi `/auth/me` khi khởi tạo. | Đúng |
| Làm mới access token | Khi API trả 401, interceptor của app/web gọi `POST /api/v1/auth/refresh`, lưu cặp token mới rồi gửi lại request cũ. Backend xoay vòng refresh token: token cũ bị thu hồi và không thể tái sử dụng. | Đúng |
| Cấp quyền thiết bị | App có màn hình “Quyền & riêng tư”, cho phép kiểm tra/yêu cầu quyền vị trí, camera, microphone và thông báo. | Có chức năng nhưng không thuộc luồng xác thực |

**Độ phủ chức năng: 6/6 thành phần, tương đương 100%.** Con số này chỉ khẳng định các chức năng có tồn tại, không có nghĩa sơ đồ UML đã chính xác hoàn toàn.

### 2.3. Đánh giá actor và quan hệ UML

| Nội dung sơ đồ | Đối chiếu hành vi thực tế | Đánh giá | Đề xuất sửa |
|---|---|---|---|
| Actor duy nhất là Lái xe | Lái xe đúng là actor của luồng trên app. Tuy nhiên API xác thực được dùng chung cho `ADMIN`, `FLEET_MANAGER`, `DISPATCHER`, `SAFETY_OFFICER`, `RESCUE_TEAM` và `DRIVER`. Nếu khung hệ thống mang tên toàn bộ “Hệ thống SafeFleet”, một actor Lái xe là chưa đủ. | Đúng một phần | Nếu sơ đồ chỉ mô tả app, đổi tên biên thành “Ứng dụng SafeFleet Driver”. Nếu mô tả toàn hệ thống, dùng actor tổng quát “Người dùng” rồi chuyên biệt hóa thành các vai trò. |
| “Xác thực và quản lý phiên” `include` “Đăng nhập” | Đăng nhập là mục tiêu độc lập do người dùng khởi tạo khi chưa có phiên; nó không phải bước bắt buộc mỗi lần quản lý một phiên đang tồn tại. | Chưa đúng | Cho actor liên kết trực tiếp với “Đăng nhập”. Có thể để “Đăng nhập” `include` “Xác thực thông tin đăng nhập” và “Phát hành cặp token”. |
| “Xác thực và quản lý phiên” `include` “Đăng xuất” | Đăng xuất là hành vi tùy chọn do người dùng chủ động, không xảy ra bắt buộc trong mọi phiên xác thực. | Chưa đúng | Tách “Đăng xuất” thành use case độc lập, liên kết trực tiếp với actor. |
| “Xác thực và quản lý phiên” `include` “Khôi phục phiên” | Khôi phục phiên chỉ chạy khi khởi động app và đã có token lưu cục bộ. Đây là hành vi có điều kiện, không phải bước luôn xảy ra. | Đúng một phần | Thêm use case “Khởi động ứng dụng”; use case này `include` “Kiểm tra phiên đã lưu”. “Khôi phục phiên” là kết quả khi token hợp lệ. |
| “Làm mới access token” `extend` “Xác thực và quản lý phiên” | Làm mới token chỉ xảy ra khi request nhận 401 và có refresh token. Đây là hành vi mở rộng có điều kiện. | Đúng | Giữ `extend`, ghi extension point: “Access token hết hạn/không hợp lệ và refresh token còn hiệu lực”. |
| “Cấp quyền thiết bị” `extend` “Xác thực và quản lý phiên” | Cấp quyền hệ điều hành không tham gia xác minh danh tính hoặc duy trì JWT. Trong app hiện tại, người dùng mở màn hình này từ Hồ sơ → Quyền & riêng tư sau khi đã đăng nhập; một số tính năng cũng yêu cầu quyền ngay lúc sử dụng. | Chưa đúng | Tách thành use case “Quản lý quyền ứng dụng”, liên kết trực tiếp với Lái xe; các chức năng GPS, camera, trợ lý giọng nói và thông báo có thể `include` hoặc phụ thuộc use case này. |

Theo sáu tiêu chí về actor/quan hệ ở bảng trên: 1 tiêu chí đúng, 2 tiêu chí đúng một phần và 3 tiêu chí chưa đúng. Nếu quy đổi `Đúng = 1`, `Đúng một phần = 0,5`, `Chưa đúng = 0`, độ chính xác mô hình là:

\[
\frac{1 + 2 \times 0,5}{6} \times 100\% = 33,3\%
\]

Khi kết hợp sáu điểm về sự tồn tại chức năng và sáu điểm về mô hình UML, sơ đồ đạt:

\[
\frac{6 + 2}{12} \times 100\% = 66,7\%
\]

**Kết luận:** Sơ đồ có **độ phủ chức năng cao (100%)**, nhưng **độ chính xác UML còn thấp (33,3%)**. Mức phù hợp tổng hợp theo thang đo nêu trên là **66,7% — đúng một phần, cần chỉnh quan hệ và phạm vi actor**.

### 2.4. Use case đặc tả đề xuất sau khi hiệu chỉnh

#### UC-AUTH-01 — Đăng nhập

| Thuộc tính | Nội dung |
|---|---|
| Actor chính | Người dùng; trong phạm vi app tài xế là Lái xe |
| Tiền điều kiện | Người dùng có tài khoản đang hoạt động và chưa bị khóa; thiết bị kết nối được backend. |
| Kích hoạt | Người dùng nhập tài khoản/email, mật khẩu và chọn Đăng nhập. |
| Luồng chính | (1) App kiểm tra hai trường bắt buộc. (2) App gửi thông tin tới `/auth/login`. (3) Backend tìm tài khoản theo username hoặc email, không phân biệt hoa thường. (4) Backend kiểm tra mật khẩu, trạng thái hoạt động và khóa tài khoản. (5) Backend tạo JWT access token và refresh token. (6) App lưu token. (7) App khởi động đồng bộ OCR, theo dõi chuyến được giao và đăng ký push token. (8) App hiển thị màn hình chính. |
| Luồng thay thế | Thiếu dữ liệu: hiển thị lỗi tại form. Sai tài khoản/mật khẩu: backend trả 401. Tài khoản khóa/không hoạt động: từ chối xác thực. Lỗi mạng: giữ ở màn hình đăng nhập và hiển thị lỗi. |
| Hậu điều kiện thành công | Người dùng ở trạng thái `signedIn`, có cặp token hợp lệ và truy cập được chức năng đúng vai trò. |
| Hậu điều kiện thất bại | Không tạo phiên mới và không chuyển vào màn hình nghiệp vụ. |

#### UC-AUTH-02 — Khôi phục phiên

| Thuộc tính | Nội dung |
|---|---|
| Actor kích hoạt | Hệ thống khi ứng dụng khởi động; Lái xe là bên hưởng lợi. |
| Tiền điều kiện | Thiết bị đã lưu access token từ lần đăng nhập trước. |
| Luồng chính | (1) App đọc token trong secure storage. (2) App gọi `/auth/me`. (3) Nếu access token hết hạn, interceptor thử làm mới token. (4) Nếu xác thực thành công, app chuyển sang `signedIn` và khởi động các dịch vụ nền. |
| Ngoại lệ | Không có token: chuyển tới đăng nhập. Server trả 401 và refresh thất bại: xóa token, chuyển tới đăng nhập. Mất mạng tạm thời: app giữ phiên để hỗ trợ dữ liệu offline. |

#### UC-AUTH-03 — Làm mới token

| Thuộc tính | Nội dung |
|---|---|
| Kích hoạt | API nghiệp vụ trả 401, request chưa retry và không phải API login/refresh. |
| Luồng chính | Client gửi refresh token; backend kiểm tra token chưa hết hạn/chưa thu hồi; backend thu hồi token cũ, phát cặp token mới; client lưu cặp mới và gửi lại request ban đầu. |
| Ngoại lệ | Refresh token thiếu, hết hạn, đã thu hồi hoặc tài khoản không còn khả dụng: xóa phiên cục bộ và yêu cầu đăng nhập lại. |

#### UC-AUTH-04 — Đăng xuất

| Thuộc tính | Nội dung |
|---|---|
| Actor chính | Người dùng/Lái xe |
| Tiền điều kiện | Đang có phiên cục bộ. |
| Luồng chính | Dừng giám sát cabin và các dịch vụ nền; hủy đăng ký push của thiết bị; gửi refresh token tới `/auth/logout`; backend thu hồi refresh token; client xóa hai token và chuyển về màn hình đăng nhập. |
| Ngoại lệ | Nếu gọi backend thất bại, app vẫn xóa token cục bộ để hoàn tất đăng xuất trên thiết bị. |

### 2.5. Điểm chưa hoàn thiện phát hiện trong hệ thống

1. Access token mặc định có thời hạn 1.440 phút (24 giờ). Backend chỉ thu hồi refresh token khi đăng xuất, nên access token đã phát hành vẫn có thể dùng tới khi hết hạn nếu bị sao chép khỏi thiết bị.
2. Khi refresh token thất bại trong lúc app đang hoạt động, `ApiClient` xóa token nhưng chưa thông báo trực tiếp cho `SessionController` đổi ngay sang `signedOut`. Trạng thái giao diện có thể vẫn là đã đăng nhập cho tới khi một luồng khác xử lý 401 hoặc app khởi động lại.
3. App chỉ bắt đầu khôi phục khi tìm thấy access token. Trường hợp hiếm khi refresh token còn nhưng access token bị mất riêng lẻ sẽ bị coi là không có phiên.
4. Web lưu token trong `localStorage`, trong khi app di động dùng secure storage. Đây là khác biệt bảo mật cần nêu rõ nếu báo cáo mô tả chung cả hai client.
5. Kiểm thử tích hợp backend đã bao phủ đăng nhập sai, bảo vệ API 401, xoay vòng refresh token, chống tái sử dụng refresh token cũ và thu hồi token khi đăng xuất. Chưa tìm thấy kiểm thử tự động chuyên biệt cho khôi phục phiên và chuyển trạng thái phiên của app Flutter.

**Trạng thái xác minh khi chạy ngày 27/08/2026:** đã thử chạy riêng test `refreshTokenRotationLogoutAndNotificationReadStateAreIsolatedPerUser`. Maven tải và biên dịch được test, nhưng Testcontainers dừng trước khi thực thi các assertion vì không tìm thấy Docker environment hợp lệ. Do đó, báo cáo chỉ kết luận **có test tích hợp trong mã nguồn**, chưa ghi nhận test này đạt trong lần kiểm tra hiện tại. Muốn xác minh runtime cần khởi động Docker rồi chạy lại test.

### 2.6. Bằng chứng mã nguồn chính

- `web_quan_ly/backend/src/main/java/com/safefleet/auth/controller/AuthController.java`: các API login, refresh, logout, me và change-password.
- `web_quan_ly/backend/src/main/java/com/safefleet/auth/service/AuthService.java`: xác thực, cấp cặp token, xoay vòng và thu hồi refresh token.
- `web_quan_ly/backend/src/main/java/com/safefleet/infrastructure/security/JwtService.java`: phát và kiểm tra JWT access token.
- `web_quan_ly/backend/src/main/java/com/safefleet/config/SecurityConfig.java`: cấu hình stateless và bảo vệ API.
- `safe_fleet_driver_ui/lib/core/network/api_client.dart`: lưu token bằng secure storage, tự refresh và retry request.
- `safe_fleet_driver_ui/lib/app.dart`: đăng nhập, khôi phục, đăng xuất và trạng thái phiên của app tài xế.
- `safe_fleet_driver_ui/lib/features/permissions/permission_setup_screen.dart`: quản lý quyền hệ điều hành của thiết bị.
- `web_quan_ly/frontend/context/AuthContext.tsx` và `web_quan_ly/frontend/lib/apiClient.ts`: quản lý phiên và tự refresh trên web.
- `web_quan_ly/backend/src/test/java/com/safefleet/RealPostgreSqlApiIntegrationTest.java`: kiểm thử lỗi xác thực, xoay vòng và thu hồi refresh token.

### 2.7. Cấu trúc sơ đồ nên vẽ lại

Nếu chỉ mô tả ứng dụng tài xế, nên đổi tên system boundary thành **“Ứng dụng SafeFleet Driver”** và bố trí:

- Lái xe — Đăng nhập.
- Lái xe — Đăng xuất.
- Lái xe — Quản lý quyền ứng dụng.
- Khởi động ứng dụng `include` Kiểm tra phiên đã lưu.
- Làm mới access token `extend` Kiểm tra/duy trì phiên, với điều kiện access token hết hạn.
- GPS, camera, microphone và thông báo liên kết với Quản lý quyền ứng dụng; không nối use case này vào Xác thực.

Nếu mô tả toàn bộ SafeFleet, dùng actor tổng quát **Người dùng** cho Đăng nhập/Đăng xuất, sau đó chuyên biệt hóa thành Quản trị viên, Quản lý đội xe, Điều phối viên, Cán bộ an toàn, Đội cứu hộ và Lái xe.

---

## 3. Nhận xét tổng quan 12 sơ đồ

### 3.1. Lưu ý về loại sơ đồ

Mười hai hình được cung cấp là **sơ đồ use case**, không phải sơ đồ hoạt động. Sơ đồ use case nên tập trung vào mục tiêu mà actor muốn đạt được. Các chi tiết như JWT, WebSocket, TFLite, ML Kit, polling, hàng đợi offline và thuật toán OCR phù hợp hơn với sơ đồ hoạt động, tuần tự hoặc thành phần.

### 3.2. Kết quả kiểm tra từng sơ đồ

| STT | Nhóm chức năng | Đánh giá tổng quan | Nhận xét ngắn |
|---:|---|---|---|
| 1 | Xác thực và quản lý phiên | **Đúng một phần** | Đăng nhập, đăng xuất, khôi phục và refresh token đều có. Sai chính là dùng `include` cho đăng nhập/đăng xuất và gắn cấp quyền thiết bị vào xác thực. |
| 2 | Quản lý và thực hiện chuyến | **Đúng phần lớn** | Hệ thống có chuyến hôm nay, chi tiết chuyến, đúng 7 mục kiểm tra, bắt đầu/hoàn thành, tạm nghỉ/tiếp tục, phiếu xuất kho và hàng đợi lệnh offline. Tuy nhiên xem danh sách, xem chi tiết, bắt đầu và hoàn thành là các mục tiêu/thao tác riêng, không phải tất cả đều luôn được `include`. |
| 3 | Dẫn đường và chia sẻ vị trí | **Đúng phần lớn** | Có tìm địa điểm, so sánh tuyến tránh ngập, gửi GPS/telemetry, chế độ lái, phát hiện lệch tuyến, định tuyến lại và theo dõi nền. Sơ đồ khớp chức năng nhưng đang trộn thao tác người dùng với xử lý nền của hệ thống. |
| 4 | Giám sát an toàn bằng AI cabin | **Đúng phần lớn** | Có bật/tắt camera, hiệu chuẩn khuôn mặt, suy luận STGT TFLite, ML Kit + luật dự phòng, cảnh báo nhiều mức và xếp hàng đồng bộ sự kiện an toàn. Các bước suy luận/model là cơ chế nội bộ, nên đưa sang sơ đồ hoạt động hoặc tuần tự. |
| 5 | Báo cáo nguy hiểm và khẩn cấp | **Đúng một phần** | Có lấy GPS, báo ngập/kẹt xe, chọn mức độ, gửi SOS và ưu tiên SOS khi offline. Backend có API biên nhận/timeline sự cố, nhưng màn SOS hiện tại chưa hiển thị timeline đầy đủ cho tài xế; báo ngập và SOS cũng là hai use case độc lập chứ không phải bước bắt buộc chung. |
| 6 | Quản lý phiếu nhật trình OCR | **Đúng phần lớn** | Có chụp/chọn ảnh, tìm/crop tài liệu, OCR đa hướng/đa vùng, chấm đỏ-vàng-xanh, tách trường, đối chiếu, lưu cục bộ, bổ sung trường thiếu, VietOCR và xuất/chia sẻ Excel. Sơ đồ đúng chức năng nhưng quá nhiều bước xử lý kỹ thuật được biểu diễn như use case. |
| 7 | Trợ lý và thông tin cá nhân | **Đúng phần lớn** | Có chat, giọng nói, wake phrase, xác nhận/hủy lệnh, thông báo, báo cáo tháng, hồ sơ và quyền thiết bị. Hàng đợi offline chỉ áp dụng cho một số lệnh nghiệp vụ như chuyến/SOS/ngập, không có nghĩa toàn bộ chat trợ lý hoạt động offline. |
| 8 | Giám sát vận hành thời gian thực | **Đúng phần lớn** | Có trung tâm chỉ huy, bản đồ, GPS/tốc độ/trạng thái xe, tìm kiếm, lọc SOS/ngập/offline, WebSocket và polling dự phòng. WebSocket/polling là giải pháp kỹ thuật, không nên là use case trực tiếp của Quản lý. |
| 9 | Điều phối và quản lý chuyến | **Đúng phần lớn** | Có chuyến nháp, tìm điểm đi/đến, gợi ý tài xế-xe, ETA/rủi ro ngập, chọn cặp, phát hành chuyến, phiếu xuất kho, cập nhật/hủy và theo dõi chuyến. Đây là một trong các sơ đồ khớp hệ thống nhất, nhưng các thao tác tùy chọn không nên đều dùng `include`. |
| 10 | Xử lý cảnh báo, sự cố và ngập | **Đúng phần lớn** | Có xem/lọc, xác nhận, giải quyết/bỏ qua cảnh báo, chuyển cảnh báo thành sự cố, phân công sự cố, timeline, xem/xác minh/giải quyết điểm ngập. Chức năng khớp tốt; cần tách thành ba nhóm use case: cảnh báo, sự cố và điểm ngập. |
| 11 | Quản lý nguồn lực và cấu hình | **Đúng phần lớn** | Có quản lý phương tiện, tài xế, thiết bị, bảo trì, tài khoản, ngưỡng giờ lái và bật/tắt loại cảnh báo AI. Các nhóm này là chức năng ngang hàng; nên liên kết actor trực tiếp thay vì coi tất cả là bước `include` của một use case rất lớn. |
| 12 | Xem và xuất báo cáo | **Đúng một phần** | Backend có báo cáo trạng thái xe, cảnh báo theo loại, chuyến theo ngày, tài xế rủi ro, ngập và sự cố; frontend có xuất CSV. Tuy nhiên trang Báo cáo hiện chỉ hiển thị trực tiếp cảnh báo theo loại và chuyến theo ngày; các nội dung còn lại nằm ở API hoặc các trang nghiệp vụ khác. |

### 3.3. Kết luận chung

- **Không có sơ đồ nào sai hoàn toàn về phạm vi chức năng.** Phần lớn chức năng mô tả đã có trong app, web hoặc backend.
- Các sơ đồ **3, 4, 6, 9, 10 và 11** gần với hệ thống hiện tại nhất.
- Các sơ đồ **1, 5 và 12** cần sửa trước vì có quan hệ chưa đúng hoặc giao diện hiện tại chưa thể hiện đầy đủ nội dung đã vẽ.
- Các sơ đồ **2, 7 và 8** đúng về chức năng nhưng cần tách các mục tiêu độc lập và bỏ bớt chi tiết kỹ thuật khỏi sơ đồ use case.
- Lỗi chung của cả bộ sơ đồ là dùng `include` như quan hệ “gồm các chức năng con”. Trong UML, `include` chỉ phù hợp khi use case nguồn **luôn bắt buộc thực hiện** use case đích. Chức năng do actor tự chọn nên liên kết trực tiếp với actor; hành vi chỉ xảy ra theo điều kiện mới cân nhắc `extend`.
- Tên actor **Quản lí** còn quá chung. Nên dùng đúng vai trò hiện có: `ADMIN`, `FLEET_MANAGER`, `DISPATCHER`, `SAFETY_OFFICER` và `RESCUE_TEAM`, hoặc tạo actor tổng quát “Nhân viên quản lý” rồi chuyên biệt hóa.
- Nếu vẫn giữ màu sắc để phân biệt nhóm chức năng, cần thêm chú giải vì màu xanh/nâu/xanh lá không mang ý nghĩa chuẩn trong UML.
