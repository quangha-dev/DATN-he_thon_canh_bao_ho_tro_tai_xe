# SafeFleet MCP tools

MCP server là ranh giới duy nhất giữa model và nghiệp vụ SafeFleet. Danh sách tool được lọc theo vai trò lấy từ JWT backend; model không được truyền `driverId` để đổi phạm vi dữ liệu.

## Vòng đời một yêu cầu

1. Agent kiểm tra yêu cầu có thuộc phạm vi tài khoản và SafeFleet hay không.
2. Agent lập kế hoạch chỉ với các tool MCP được cấp quyền.
3. Sau mỗi tool, agent so bằng chứng với mục tiêu và chọn `CONTINUE`, `COMPLETE`, `REPLAN` hoặc `ERROR`.
4. Tool thay đổi trạng thái chỉ tạo `confirmationRequest`. Ứng dụng thực thi sau thao tác xác nhận rõ ràng của người dùng.
5. Kết quả RAG chỉ được tổng hợp từ `citations` và phải dẫn `[documentKey – headingPath]`.
6. Runtime tạo fingerprint từ dữ liệu nghiệp vụ của từng kết quả. Khi cùng một tool cho kết quả giống hệt quá 2 lần, lần lặp thứ ba bị gắn `DUPLICATE_RESULT_BLOCKED`; evaluator phải chọn trả lời ngay (`ANSWER`) hoặc lập kế hoạch dùng tool khác (`REPLAN`).

## Tool dành cho web quản lý

Agent quản lý chỉ đọc dữ liệu qua REST business API của backend PostgreSQL; model không được phát SQL và không nhận chuỗi kết nối database. Tool được lọc từ JWT: `ADMIN`/`FLEET_MANAGER` có phạm vi rộng nhất; `DISPATCHER` và `SAFETY_OFFICER` chỉ nhận tool tương ứng quyền backend.

| Tool | Bộ lọc/đầu vào | Nội dung đầu ra để agent lập kế hoạch |
|---|---|---|
| `management_get_fleet_overview` | rỗng | Tổng/phân bố trạng thái xe, tài xế, chuyến; cảnh báo và sự cố đang mở; 10 tài xế rủi ro cao. |
| `management_search_drivers` | từ khóa, trạng thái, hạng bằng, khoảng safety score, trang | ID, liên hệ, bằng/hạn bằng, trạng thái, xe hiện tại, điểm an toàn, phút lái, tổng chuyến/cảnh báo. |
| `management_get_driver_report` | `driver_id` | Hồ sơ, tổng chuyến, tổng cảnh báo, safety score và thời gian lái/nghỉ trong ngày. |
| `management_compare_driver_group` | 1–20 `driver_ids`, ngày đầu/cuối | Mỗi tài xế kèm số chuyến và số cảnh báo đúng trong kỳ; dùng để so sánh/xếp ưu tiên. |
| `management_search_trips` | trạng thái, xe, tài xế, ngày đầu/cuối, trang | Danh sách chuyến toàn đội: tuyến, xe/tài xế, lịch dự kiến/thực tế, tiến độ và rủi ro. |
| `management_get_trip_detail` | `trip_id` | Chi tiết chuyến và timeline trạng thái/người thao tác/thời điểm/ghi chú. |
| `management_list_active_trips` | giới hạn | Mọi chuyến `IN_PROGRESS`, `RESTING`, `INCIDENT`, kèm phân bố trạng thái. |
| `management_get_trip_period_report` | ngày đầu/cuối (tối đa 367 ngày) | Tổng chuyến, hoàn thành, đang hoạt động, tỷ lệ hoàn thành, đủ 10 trạng thái, chuỗi theo ngày và `dataAvailability` công khai chỉ số nguồn chưa có. |
| `management_search_safety_events` | loại, severity, status, xe/tài xế, khoảng datetime, trang | Cảnh báo với GPS, tốc độ, confidence, evidence, người/trạng thái xử lý. |
| `management_search_incidents` | loại, severity, status, xe/tài xế, trang | SOS/sự cố, vị trí, mô tả, người phụ trách và các mốc xử lý. |
| `management_search_vehicles` | biển số, loại, trạng thái, GPS online, trang | Kích thước/tải trọng, thiết bị/tài xế, giấy tờ, vị trí và tốc độ cuối. |
| `management_search_accounts` | từ khóa, trang | Hồ sơ tài khoản, vai trò, trạng thái và lần đăng nhập; không trả password/token. |
| `management_search_maintenance_orders` | xe, trạng thái, khoảng ngày, trang | Lệnh bảo trì, lịch, chi phí, nhà cung cấp và mốc hoàn tất. |
| `management_search_devices` | loại, trạng thái, xe, trang | Serial, firmware, IP, pin, tín hiệu và lần cuối online của GPS/camera/điện thoại/cảm biến. |
| `management_get_operational_risks` | rỗng | Bảo trì đến hạn, giấy tờ sắp hết hạn, tổng hợp điểm ngập và sự cố. |
| `management_get_system_settings` | rỗng | Cấu hình nghiệp vụ key/group/value/type/mô tả; không trả OpenAI key đã mã hóa. |
| `search_internal_documents` | câu hỏi, giới hạn | Citation RAG gồm mã/version/ngày hiệu lực/Điều-Khoản/nội dung/score và chính sách trả lời. |

Trang web gọi `POST /api/v1/management/agent/chat`. Phản hồi gồm `responseText`, `plan`, `steps`, `planCheck`, `reason`, `status` và cờ `replanned` để quản lý kiểm tra agent đã dùng nguồn nào.

## Tool dành cho tài xế

| Tool | Đầu vào chính | Đầu ra | Ghi chú an toàn |
|---|---|---|---|
| `list_*_trips` | khoảng ngày, giới hạn | chuyến thuộc tài khoản | Backend tự ràng buộc tài xế từ JWT. |
| `rank_upcoming_trips` | khoảng ngày, giới hạn | chuyến đề xuất và tiêu chí | Không gọi kết quả “hôm nay” nếu không có phạm vi ngày. |
| `get_current_assignment` | rỗng | phân công hiện tại | Chỉ đọc. |
| `get_trip_detail` | `trip_id` | chi tiết chuyến | Backend kiểm tra quyền sở hữu. |
| `get_trip_summary` | `trip_id` | tổng kết chuyến | Chỉ đọc. |
| `get_warehouse_issue` | `trip_id` | phiếu xuất kho | Chỉ đọc. |
| `get_monthly_report` | năm, tháng | báo cáo hoạt động | Chỉ đọc. |
| `get_safety_summary` | rỗng | tổng quan an toàn | Chỉ đọc. |
| `get_current_driving_session` | rỗng | phiên lái hiện tại | Dùng làm bằng chứng trước pause/resume/complete. |
| `list_notifications` | chưa đọc, giới hạn | thông báo | Chỉ đọc. |
| `open_mobile_screen` | màn hình, `trip_id` tùy chọn | `clientAction` | Chỉ mở các màn hình allowlist. |
| `search_destinations` | truy vấn, giới hạn | địa điểm thật từ backend | Model không được tự sinh tọa độ. |
| `prepare_navigation` | truy vấn, chỉ số kết quả | `START_NAVIGATION` | Backend tìm lại điểm, app lấy GPS rồi lập tuyến tránh ngập. |
| `prepare_flood_report` | mức ngập, mô tả | `confirmationRequest` | Tọa độ chỉ lấy từ GPS thiết bị sau xác nhận. |
| `prepare_trip_action` | hành động, `trip_id`, ghi chú | `confirmationRequest` | Kiểm tra trạng thái chuyến/checklist/phiên lái trước xác nhận. |
| `search_internal_documents` | câu hỏi, giới hạn | chunk và citation pgvector | Hybrid multilingual E5 + full-text, chỉ tài liệu ACTIVE/đã có hiệu lực. |

## Idempotency và kiểm toán

- Báo ngập và thao tác mobile sử dụng `clientEventId`; backend trả lại kết quả cũ khi replay cùng sự kiện.
- UI khóa nút khi đang xác nhận và xóa pending confirmation ngay sau thành công.
- Mọi kết quả MCP có `_audit` gồm tool, user, driver, role và UTC timestamp. Log production không được chứa access token, ảnh chứng từ hoặc toàn bộ nội dung hội thoại nhạy cảm.
