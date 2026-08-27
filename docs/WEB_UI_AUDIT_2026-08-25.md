# Báo cáo kiểm tra giao diện web SafeFleet

Ngày kiểm tra: 25/08/2026  
Môi trường: Docker local, frontend `http://localhost:3001`, backend `http://localhost:8080`  
Kích thước kiểm tra: desktop 1440×900 và mobile 390×844

## Kết quả tổng quan

- Đã mở và kiểm tra 17 màn hình: đăng nhập và 16 trang trong khu vực quản trị.
- Không còn trang nào làm tràn ngang toàn bộ viewport ở hai kích thước đã kiểm tra.
- Không ghi nhận lỗi JavaScript trên console trong lượt kiểm tra sau triển khai.
- Frontend lint và production build thành công; backend/frontend Docker build thành công.
- Tất cả 5 service đang chạy healthy: PostgreSQL, MinIO, AI service, backend và frontend.

## Lỗi đã sửa

| Mức | Trang/khu vực | Lỗi xác nhận trước sửa | Cách sửa và kết quả |
|---|---|---|---|
| P1 | `/flood-map`, `/realtime-map` | Tile OpenStreetMap không tải làm sự kiện `load` không phát; nền bản đồ và toàn bộ marker cùng biến mất | Khởi tạo lớp dữ liệu từ `style.load`, giữ map instance ngay khi tạo, thêm nền dự phòng và cảnh báo ngoại tuyến. Sau sửa vẫn render 2 marker điểm ngập khi tile ngoài không truy cập được |
| P1 | `/settings` | Trang tự hiện toast “Lỗi hệ thống” | Phát hiện DB lưu `value_type=TEXT` trong khi enum chỉ nhận `STRING`; thêm migration V18 chuẩn hóa dữ liệu. Sau sửa tải thành công 9 khóa cấu hình |
| P1 | `/incidents`, `/alerts` | Badge dài chồng sang cột tài xế ở desktop/mobile | Giới hạn badge theo ô, ẩn phần dư và truncate nội dung. Kiểm tra lại không còn overflow offender |
| P2 | `/command-center` | Hero dashboard bị kéo cao bằng danh sách ưu tiên, tạo khoảng trống lớn | Đổi grid sang căn đầu; hai cột giữ chiều cao nội dung riêng |
| P2 | `/accounts` | “Hoạt động cuối” hiển thị chuỗi ISO thô và bị cắt | Định dạng ngày giờ theo locale `vi-VN` |
| P2 | `/settings` mobile | Range input vượt khung 4 px, padding chật | Bỏ margin mặc định của range, dùng padding responsive |
| P2 | Header | Khi socket ngắt, nhãn nhìn thấy là “Đang kết nối” nhưng tooltip nói mất kết nối | Tách đủ ba trạng thái: Realtime / Đang kết nối / Mất kết nối |
| P3 | Marker bản đồ | Marker chỉ click bằng chuột, không có tên truy cập | Thêm role, aria-label, tabIndex và Enter/Space; 2 marker điểm ngập đã được xác nhận có thể focus/click |
| Build | Mock data | Production build lỗi vì `FloodPoint` thiếu `hazardType` | Bổ sung `hazardType: flood` cho dữ liệu mock; production build qua 21 route |

## Kiểm tra từng trang

| Trang | Nội dung đã kiểm tra | Kết quả |
|---|---|---|
| `/login` | Bố cục, form đăng nhập, trạng thái đăng nhập | Đạt |
| `/command-center` | KPI, biểu đồ, danh sách ưu tiên, nút mở bản đồ | Đạt sau sửa chiều cao |
| `/realtime-map` | Danh sách xe, zoom in/out, reset, lớp fallback | Đạt; nền đường thật còn phụ thuộc tile ngoài |
| `/drivers` | Bộ lọc, mở drawer dòng đầu, mở/đóng modal thêm tài xế | Đạt |
| `/accounts` | Bộ lọc vai trò/trạng thái, drawer, modal tạo, ngày hoạt động | Đạt sau sửa |
| `/vehicles` | Bộ lọc, drawer, modal thêm xe | Đạt |
| `/dispatch` | Form điều phối, trường tuyến và phiếu xuất, nút gợi ý ghép cặp | Hiển thị đạt |
| `/trips` | Bộ lọc, mở drawer, modal hủy | Đạt |
| `/document-reviews` | Empty state và bộ lọc | Đạt; hiện không có dữ liệu để kiểm tra ảnh/duyệt thực tế |
| `/alerts` | Bộ lọc Ngủ gật, mở drawer, badge dài | Đạt sau sửa |
| `/incidents` | Bộ lọc, mở drawer, timeline, badge dài | Đạt sau sửa |
| `/flood-map` | Filter, fallback, 2 marker, click marker mở vùng chi tiết | Đạt sau sửa |
| `/devices` | Danh sách, lọc, nút Gắn thiết bị | Danh sách đạt; luồng gắn thiết bị chưa có giao diện thật |
| `/maintenance` | Bộ lọc, mở chi tiết, modal tạo phiếu | Đạt |
| `/reports` | Biểu đồ/tổng hợp, nút xuất CSV | Hiển thị đạt |
| `/settings` | 9 khóa cấu hình, AI toggle, kết nối hệ thống, mobile layout | Đạt sau migration và sửa responsive |
| `/profile` | Thông tin cá nhân, bật/tắt hiển thị mật khẩu | Đạt |

Kiểm tra toàn cục:

- Tìm nhanh mở được, truy vấn `001` trả về xe, tài xế, chuyến, cảnh báo và sự cố thật.
- Menu mobile mở được và hiển thị đúng các route được phân quyền.
- Không thực hiện thao tác ghi/xóa dữ liệu production trong lượt audit; các modal tạo/hủy chỉ được mở rồi đóng.

## Tính năng backend đã có nhưng giao diện web còn thiếu

### P1 — nên làm trước

1. Quản lý thiết bị đầy đủ: backend đã có chi tiết, tạo/sửa/xóa, gắn xe, đổi trạng thái và connection logs. Web hiện chỉ gọi API danh sách; nút “Gắn thiết bị” chỉ báo sang Quản lý phương tiện nhưng modal phương tiện không có trường chọn thiết bị.
2. Lịch sử và phát lại hành trình: backend có `/telemetry/trips/{tripId}/history` và `/replay`, nhưng drawer chuyến chưa có bản đồ replay/timeline GPS.
3. Điều phối sự cố nâng cao: backend có assign điều phối viên và thêm timeline; web chỉ tiếp nhận, xem timeline và đóng sự cố.
4. Xử lý cảnh báo an toàn: backend có dismiss và create-incident; web chỉ tiếp nhận/resolve, chưa có hai hành động này.

### P2 — hoàn thiện vận hành

1. Chi tiết tài xế/xe: backend có lịch sử chuyến, safety events, realtime status và tính lại safety score; drawer web chủ yếu dùng dữ liệu từ danh sách.
2. Bảo trì: backend có xóa, due alerts và document-expiry alerts; web chưa có trung tâm cảnh báo hạn bảo trì/giấy tờ.
3. Phiếu xuất kho: luồng điều phối tạo/cập nhật/phát hành đã có, nhưng chưa có trang danh sách/chi tiết và hành động xác nhận nhận hàng (`confirm`).
4. Báo cáo: backend có báo cáo chi tiết theo tài xế/xe, ngập và sự cố; web mới hiển thị các tổng hợp cơ bản.
5. Timeline chuyến: backend có endpoint timeline; web chưa hiển thị lịch sử chuyển trạng thái của chuyến.

### P3 — cải thiện trải nghiệm

- Đổi nhãn kỹ thuật kiểu “Nguồn: /reports/...” thành tên dữ liệu dễ hiểu.
- Thêm role `dialog` cho Drawer và command palette để trình đọc màn hình nhận đúng cấu trúc.
- Thêm test dữ liệu cho trang duyệt lệch biển để kiểm tra đầy đủ tải ảnh, duyệt và từ chối.

## Lệnh xác minh

```text
npm run lint                      PASS
npm run build                     PASS (21 route)
docker compose build backend      PASS
docker compose build frontend     PASS
Flyway validate                   PASS (18 migration)
docker compose ps                 5/5 service healthy
```

## Giới hạn đã biết

Máy kiểm tra không truy cập được `tile.openstreetmap.org:443`, vì vậy lớp đường phố thật không tải trong phiên này. Bản sửa đảm bảo dữ liệu theo dõi, marker và thao tác điều hành vẫn hoạt động trên nền dự phòng, đồng thời hiển thị trạng thái ngoại tuyến. Để production có nền đường ổn định cần cấu hình tile provider có SLA hoặc tile proxy/cache do hệ thống quản lý.
