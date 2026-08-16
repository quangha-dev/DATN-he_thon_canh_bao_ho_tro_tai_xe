# SafeFleet Agent MCP

## Phạm vi hiện tại

Chat trong ứng dụng tài xế gọi `POST /api/v1/mobile/agent/chat`. Backend chỉ chuyển tiếp JWT; toàn bộ lập kế hoạch, gọi model, registry tool và MCP nằm trong `safefleet_ai`.

Trong triển khai Docker, Agent ưu tiên `OPENAI_API_KEY`, `OPENAI_ENABLED` và `AGENT_MAX_STEPS` từ `.env`. Khi có `OPENAI_API_KEY`, cấu hình đã lưu từ web không được phép ghi đè biến môi trường.

MCP server dùng JSON-RPC 2.0 qua HTTP tại `POST /mcp` và hỗ trợ `initialize`, `tools/list`, `tools/call`. Mỗi request bắt buộc có `X-SafeFleet-Service-Token` và JWT người dùng trong `X-User-Authorization`.

MCP gọi `/api/v1/auth/me`, lấy vai trò thật từ backend, sau đó mới lọc `tools/list` và kiểm tra lại quyền tại `tools/call`. Model không được tự khai báo vai trò, `driverId` hoặc mở rộng quyền.

## Tool dành cho DRIVER

| Tool | Mục đích | Tác động |
|---|---|---|
| `list_completed_trips` | Chuyến đã hoàn thành, lọc ngày | Chỉ đọc |
| `list_upcoming_trips` | Chuyến chưa đi/trì hoãn | Chỉ đọc |
| `list_active_trips` | Chuyến đang chạy/nghỉ/sự cố | Chỉ đọc |
| `rank_upcoming_trips` | Xếp chuyến theo lịch sớm nhất | Chỉ đọc, phân tích xác định |
| `get_current_assignment` | Phân công hiện tại | Chỉ đọc |
| `get_trip_detail` | Chi tiết chuyến thuộc tài xế | Chỉ đọc |
| `get_trip_summary` | Tổng kết chuyến | Chỉ đọc |
| `get_warehouse_issue` | Phiếu xuất kho gắn chuyến | Chỉ đọc |
| `get_monthly_report` | Báo cáo hoạt động tháng | Chỉ đọc |
| `get_safety_summary` | Tổng quan an toàn | Chỉ đọc |
| `get_current_driving_session` | Phiên lái hiện tại | Chỉ đọc |
| `list_notifications` | Thông báo tài khoản | Chỉ đọc |
| `open_mobile_screen` | Mở màn hình app theo allowlist | Tác động phía client |
| `prepare_trip_action` | Chuẩn bị nhận/bắt đầu/tạm dừng/tiếp tục/kết thúc chuyến | Bắt buộc xác nhận |

`open_mobile_screen` chỉ chấp nhận `HOME`, `DOCUMENT_SCAN`, `TRIPS`, `TRIP_DETAIL`, `ROUTE`, `MONTHLY_REPORT`, `SAFETY`, `NOTIFICATIONS`.

`prepare_trip_action` không thay đổi dữ liệu. MCP kiểm tra chuyến qua backend, trả `confirmationRequest`; ứng dụng chỉ gọi workflow sau khi người dùng bấm **Xác nhận**. Backend tiếp tục kiểm tra JWT, quyền sở hữu chuyến và trạng thái hợp lệ. Khi mất mạng, workflow mobile dùng hàng đợi đồng bộ hiện có.

## Agent loop

1. Lấy danh sách tool từ MCP theo JWT.
2. Lập kế hoạch chỉ với tên tool được cấp.
3. Model có thể yêu cầu nhiều tool trong một lượt.
4. Sau từng tool, model bắt buộc trả `CONTINUE`, `COMPLETE`, `REPLAN` hoặc `ERROR`.
5. Nếu `REPLAN`, kế hoạch mới vẫn bị lọc theo danh sách tool MCP ban đầu.
6. Nếu có `clientAction`, app thực thi điều hướng theo allowlist.
7. Nếu có `confirmationRequest`, vòng lặp dừng ở `AWAITING_CONFIRMATION`.

## RAG dự phòng

Contract `search_internal_documents(query, limit)` đã nằm trong registry nhưng `enabled=false`, vì vậy không xuất hiện trong `tools/list` và model không thể gọi. Khi làm RAG, handler mới phải áp dụng ACL theo tài liệu/phòng ban trước khi bật tool.

## Golden evaluation

Dataset mặc định: `safefleet_ai/evaluation/agent_gold_dataset.jsonl`.

Mỗi dòng có `question`, `role`, `expected_tools`, `forbidden_tools`, `expected_answer`. Bộ chấm gồm F1 cho tool và cosine similarity offline cho câu trả lời. Có thể thay scorer bằng embeddings sau mà không đổi định dạng dataset.

```powershell
python safefleet_ai/evaluation/evaluate_agent_gold.py `
  safefleet_ai/evaluation/agent_gold_dataset.jsonl `
  path/to/agent_results.jsonl
```
