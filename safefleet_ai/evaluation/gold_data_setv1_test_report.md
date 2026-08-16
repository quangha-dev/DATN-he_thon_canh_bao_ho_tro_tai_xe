# Báo cáo chạy live `gold_data_setv1`

## 1. Phạm vi chạy

- Thời điểm: 14/08/2026, múi giờ `Asia/Ho_Chi_Minh`.
- Dataset: `safefleet-driver-agent-gold-v1`.
- Chế độ: gọi thật `POST /api/v1/mobile/agent/chat` qua backend, AI service, OpenAI và MCP.
- Tài khoản: tài xế kiểm thử `driver001`.
- Tổng số ca: 20.
- Tổng thời gian: 204,208 giây.
- Lỗi HTTP/kết nối: 0.

## 2. Kết quả thô

| Chỉ số | Kết quả |
|---|---:|
| Đạt toàn bộ tiêu chí | 0/20 |
| Sai/chênh tool selection | 16/20 |
| Sai/chênh arguments | 16/20 |
| Sai/chênh thứ tự tool | 15/20 |
| Có tool thực thi lỗi | 3/20 |
| Agent trả `FAILED` | 1/20 |
| Agent hỏi làm rõ ngoài mong đợi | 1/20 |
| Không đạt ngưỡng answer similarity | 20/20 |
| Thiếu expected facts | 20/20 |

Không được hiểu kết quả `0/20` là Agent hỏng hoàn toàn. Dataset chứa fixture giả lập nhưng runner đang dùng dữ liệu thật. Vì vậy phần answer/fact của cả 20 ca không có điều kiện để khớp.

## 3. Dữ liệu live khác fixture

Dataset giả định:

- Có chuyến trong ngày 14/08/2026.
- Chuyến hiện tại là `DEMO-A24`, ID 24, trạng thái `IN_PROGRESS`.
- Chuyến chờ là `DEMO-U21`, ID 21, lúc 16:00.
- Điểm an toàn tháng là 94, hiện tại là 96.
- Có 2 thông báo chưa đọc.

Database thật tại thời điểm chạy:

- Có 11 chuyến, lịch nằm trong ngày 01–03/08/2026; không có chuyến ngày 14/08.
- ID 21 là chuyến `COMPLETED`, không phải chuyến chờ.
- Phân công hiện tại là ID 25, `DEMO-001-M09`, trạng thái `ASSIGNED`.
- Không có driving session hiện tại.
- Báo cáo tháng: 11 chuyến, hoàn thành 8, điểm an toàn 87, 496,5 km và 6 cảnh báo.
- Có 29 thông báo chưa đọc.

Đây là nguyên nhân trực tiếp khiến 20/20 câu trả lời không khớp expected facts và expected answer. Muốn chấm semantic/fact chính xác phải seed database theo fixture hoặc chạy MCP giả lập trả `fixture_catalog`.

## 4. Lỗi Agent thực tế

### P0 — Chuẩn bị hành động không kiểm tra trạng thái chuyến

Các ca `SFV1-007`, `SFV1-008`, `SFV1-014` lần lượt tạo yêu cầu:

- `PAUSE` chuyến 25.
- `COMPLETE` chuyến 25.
- `RESUME` chuyến 25.

Trong database, chuyến 25 đang là `ASSIGNED`, chưa chạy. Cả ba hành động trên đều không hợp lệ nhưng MCP vẫn trả `AWAITING_CONFIRMATION`.

Nguyên nhân: `prepare_trip_action` chỉ kiểm tra action có nằm trong enum và `trip_id > 0`; sau khi lấy chuyến, nó không xác thực ma trận chuyển trạng thái, checklist hay driving session.

Rủi ro: nếu bước confirm phía backend không chặn lần nữa, người dùng có thể thực hiện chuyển trạng thái sai. Ngay cả khi backend có chặn, Agent vẫn đưa ra xác nhận sai và gây hiểu nhầm.

### P1 — Mất phạm vi ngày giữa các bước

- `SFV1-001`: `list_completed_trips` dùng đúng 14/08 nhưng `rank_upcoming_trips` lại truyền hai ngày `null`, dẫn tới trả chuyến ngày 03/08.
- `SFV1-009` và `SFV1-016`: câu hỏi “hôm nay” nhưng chỉ truyền `start_date=2026-08-14`, còn `end_date=null`.
- `SFV1-011`: bước đầu dùng tuần 10–16/08, hai bước sau bỏ ngày và truy vấn toàn bộ thời gian.
- `SFV1-017`: bỏ toàn bộ phạm vi ngày khi chọn chuyến tiếp theo.

Nguyên nhân: ngày tương đối được model tự sinh cho từng tool. Hàm normalize chỉ buộc ngày về `null` cho yêu cầu upcoming không có ngày rõ ràng; nó không cưỡng chế cùng một date scope cho mọi tool khi câu hỏi có “hôm nay/tuần này”.

Hậu quả: câu trả lời trộn dữ liệu hôm nay với toàn bộ lịch sử.

### P1 — Nhầm nhóm trạng thái “đang chờ”

- `SFV1-001`: gọi thêm `list_active_trips` để đếm chuyến đang chờ.
- `SFV1-011`: dùng `list_all_trips` để đếm chuyến đang chờ và kết luận 11 chuyến đều đang chờ.

Nguyên nhân: planner/checker không áp đặt mapping bất biến:

- Chờ/chưa đi → `list_upcoming_trips` hoặc `rank_upcoming_trips`.
- Đang chạy/nghỉ/sự cố → `list_active_trips`.
- Tất cả → `list_all_trips`.

Tool description đã đúng, nhưng model vẫn được tự quyết lại ở execution và plan-check.

### P1 — Có dấu hiệu trả lời ngoài bằng chứng tool

- `SFV1-002` chỉ gọi `get_current_assignment` nhưng trả cả loại hàng và số lượng. Contract của assignment không chứa phiếu xuất kho.
- `SFV1-015` chỉ gọi `get_trip_detail` và `get_trip_summary`, không gọi `get_warehouse_issue`, nhưng vẫn trả tên hàng và số lượng.

Nguyên nhân: bước tổng hợp cuối chưa kiểm tra field-level grounding. Prompt “không bịa” chưa đủ để ngăn model suy diễn dữ liệu hàng hóa ngoài payload tool.

### P1 — Clarification guard bắt nhầm yêu cầu rõ ràng

`SFV1-012` hỏi phiếu xuất kho của chuyến hiện tại rồi yêu cầu mở quét phiếu. Agent không gọi tool mà hỏi “xem tất cả chuyến hay chuyến tiếp theo”.

Nguyên nhân: bộ nhận diện scope thấy từ “chuyến” nhưng danh sách tín hiệu không có các cụm `chuyến hiện tại`, `phiếu xuất kho`, `quét phiếu`, nên coi câu hỏi là mơ hồ.

### P1 — Replan sang tool không liên quan và làm hỏng toàn bộ câu trả lời

`SFV1-004` đã lấy đúng `get_safety_summary` và `get_monthly_report`, sau đó gọi thêm `get_trip_summary(trip_id=1)`. Tool này thất bại và Agent trả `FAILED` dù hai kết quả cần thiết đã có đủ.

Nguyên nhân: plan-check do model quyết định thêm bước nhưng không có ràng buộc rằng báo cáo tháng không cần một trip ID tùy ý. Không có validator đối chiếu tool mới với mục tiêu và dữ liệu đã có.

### P2 — Không hoàn thành action/navigation sau khi đã chọn chuyến

- `SFV1-009`, `SFV1-016`, `SFV1-019`: khi không có chuyến đúng ngày live, Agent dừng sớm. Đây là hành vi hợp lý với dữ liệu thật nhưng khác fixture.
- `SFV1-010`: thông báo tham chiếu trip 27 không truy cập được; Agent fallback sang trip 25 nhưng không gọi `open_mobile_screen`.

Với `SFV1-009/016/019`, nguyên nhân chính là fixture/live mismatch, không phải lỗi Agent. Với `SFV1-010`, dữ liệu notification có reference stale và luồng recovery chưa hoàn tất hành động điều hướng.

## 5. Vấn đề của bộ chấm hiện tại

### Fixture chưa được đưa vào runtime

`fixture_catalog` mới chỉ nằm trong JSON. MCP live không đọc các fixture này. Vì thế expected answer không thể dùng để chấm live backend.

### Arguments đang bị so sánh quá cứng

Các khác biệt sau có thể vẫn hợp lệ nhưng bị đánh trượt:

- `limit=1` thay cho `limit=50` khi chỉ cần chuyến đầu tiên.
- `limit=100` thay cho `limit=20` khi lấy thông báo.
- `open_mobile_screen(destination=ROUTE, trip_id=25)` thay cho `trip_id=null`; handler hiện chấp nhận cả hai.
- Dùng `get_current_driving_session` thay `get_current_assignment` để xác định có chuyến đang chạy.

Evaluator nên hỗ trợ argument matcher theo rule và `acceptable_tool_plans`, không chỉ equality tuyệt đối.

### Semantic similarity chưa phải semantic thật

Hàm hiện tại chỉ cosine trên token sau khi bỏ dấu tiếng Việt. Nó không nhận biết tốt các cách diễn đạt đồng nghĩa. Con số similarity trong báo cáo chỉ là lexical baseline, chưa phải embedding similarity.

## 6. Phân loại 20 ca

| Case | Trạng thái live | Nhận định chính |
|---|---|---|
| SFV1-001 | COMPLETED | Sai tool đếm chờ và mất date scope |
| SFV1-002 | COMPLETED | Thiếu warehouse tool, có dấu hiệu trả hàng hóa ngoài evidence |
| SFV1-003 | COMPLETED | Live không có session/chuyến chạy; dataset không khớp |
| SFV1-004 | FAILED | Gọi thừa trip summary ID 1 làm hỏng kết quả đã đủ |
| SFV1-005 | COMPLETED | Agent từ chối START trip 21 đã hoàn thành; đúng với live, sai fixture |
| SFV1-006 | COMPLETED | Warehouse tool lỗi; fixture không khớp live |
| SFV1-007 | AWAITING_CONFIRMATION | Lỗi nghiêm trọng: cho PAUSE chuyến ASSIGNED |
| SFV1-008 | AWAITING_CONFIRMATION | Lỗi nghiêm trọng: cho COMPLETE chuyến ASSIGNED |
| SFV1-009 | COMPLETED | Không có upcoming hôm nay; đúng với live |
| SFV1-010 | COMPLETED | Notification reference stale, recovery không mở màn hình |
| SFV1-011 | COMPLETED | Dùng all trips để đếm waiting và mất phạm vi tuần |
| SFV1-012 | NEEDS_CLARIFICATION | Clarification false positive |
| SFV1-013 | COMPLETED | Tool/arguments đúng; answer lệch vì fixture không khớp live |
| SFV1-014 | AWAITING_CONFIRMATION | Lỗi nghiêm trọng: cho RESUME chuyến ASSIGNED |
| SFV1-015 | COMPLETED | Thiếu warehouse tool nhưng vẫn trả hàng hóa |
| SFV1-016 | COMPLETED | Không có upcoming hôm nay; đúng với live |
| SFV1-017 | COMPLETED | Đúng chuỗi 3 tool; khác argument fixture nhưng hợp lệ một phần |
| SFV1-018 | COMPLETED | Tool thay thế có thể hợp lý; fixture notification lệch lớn |
| SFV1-019 | COMPLETED | Không có chuyến chờ hôm nay nên không tạo ACCEPT; đúng với live |
| SFV1-020 | COMPLETED | Tool/arguments/order đúng; không có chuyến trong tuần live |

## 7. Thứ tự sửa đề xuất

1. Thêm validator chuyển trạng thái trong `prepare_trip_action` và kiểm tra lại tại confirm backend.
2. Chuẩn hóa date scope một lần từ câu hỏi, sau đó inject cố định vào mọi list/rank tool.
3. Thêm deterministic routing cho các khái niệm `waiting`, `active`, `all`.
4. Sửa clarification guard cho `chuyến hiện tại`, phiếu và quét phiếu.
5. Chặn final answer sử dụng field không tồn tại trong evidence; riêng hàng hóa bắt buộc có `get_warehouse_issue` thành công.
6. Dựng chế độ fixture MCP để replay `fixture_catalog` rồi mới chấm expected answer/facts.
7. Thay lexical cosine bằng multilingual embedding và hỗ trợ acceptable tool/argument plans.
