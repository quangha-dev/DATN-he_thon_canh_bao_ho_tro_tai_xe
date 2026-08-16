# Gold Dataset V3 — 50 câu live trên PostgreSQL

## Mục tiêu

Bộ V3 được tạo để tránh kết luận sai rằng agent “hoàn hảo” chỉ vì đạt 30/30 ca regression cơ bản. Dataset gồm đúng:

- 30 ca `easy`: regression chức năng, tool, quyền, clarification, out-of-scope và confirmation.
- 20 ca `extreme`: bắt buộc tổng hợp ít nhất hai bằng chứng database, có phép tính, đối chiếu phạm vi, kiểm tra mâu thuẫn hoặc quyết định an toàn.
- Không có RAG mock trong 50 ca này; tất cả đều dành cho agent live với actor `driver001`.

## Snapshot dữ liệu

Snapshot: `driver001-postgres-20260815T082859+0700`.

Dữ kiện chính:

- 11 chuyến: 5 `COMPLETED`, 4 `IN_PROGRESS`, 2 `ASSIGNED`.
- Trung bình tiến độ active: 53,75%; 25% active trips có risk `HIGH`.
- Current assignment là trip 5 nhưng current driving session `ACTIVE` thuộc trip 9.
- Safety status `HIGH_RISK`, điểm 24, tổng 21 cảnh báo.
- 6 thông báo chưa đọc, đều có nội dung `DROWSINESS - HIGH`.
- Phiếu kho trip 11 có requested/issued/delivered bằng 10 nhưng status vẫn là `ISSUED`.

Nguồn snapshot máy đọc nằm tại `gold_dataset_v3_snapshot.json`. Khi database thay đổi, không được sửa riêng đáp án; phải chụp snapshot mới, đổi `snapshot_id` và sinh lại toàn bộ gold liên quan.

## Thiết kế chống test quá dễ

### Split

| Split | Số ca | Mục đích |
|---|---:|---|
| `regression` | 30 | Chạy thường xuyên trong CI/dev. |
| `reasoning_dev` | 10 | Dùng phân tích lỗi suy luận trong quá trình phát triển. |
| `reasoning_holdout` | 10 | Chỉ chạy sau khi chốt phiên bản; không viết fast-path dựa trên kết quả của nhóm này. |

Holdout chỉ có ý nghĩa về quy trình vì gold vẫn nằm trong repository. Muốn đánh giá mù thực sự, cần chuyển 10 ca này sang kho riêng mà nhóm phát triển không đọc được.

### Hợp đồng tool-call

V2 chỉ so tập tên tool nên không phát hiện đầy đủ các lỗi sau:

- Gọi đúng `get_trip_detail` nhưng dùng sai `trip_id`.
- Cần đọc hai chuyến nhưng chỉ gọi một lần.
- Chuẩn bị đúng action name nhưng nhắm sai trip.

V3 thêm `expected_tool_calls`, ví dụ:

```json
[
  {"name": "get_trip_detail", "arguments": {"trip_id": 1}},
  {"name": "get_trip_detail", "arguments": {"trip_id": 6}}
]
```

Runner dùng matching one-to-one, kiểm tra tên tool và tập con arguments. Ca chỉ đạt khi contract recall ≥ 0,8 và đạt `min_tool_calls`.

### Metadata ca cực khó

Mỗi ca extreme bắt buộc có:

- `reasoning_type`.
- Ít nhất hai `reasoning_steps`.
- Ít nhất hai `required_evidence`.
- Ít nhất bốn `expected_facts`.
- Từ 2 đến 6 tool-call contracts, không vượt `AGENT_MAX_STEPS=6`.
- Safety rule và `AWAITING_CONFIRMATION` nếu có mutation tool.

20 dạng suy luận bao gồm:

- Tính tỷ lệ và trung bình từ nhiều nhóm chuyến.
- Argmax và chênh lệch tiến độ.
- Reconcile báo cáo tháng với danh sách live.
- Phân bố cảnh báo theo ngày.
- Temporal ranking và datetime arithmetic.
- Phát hiện các tuyến lặp nhưng không suy diễn quan hệ nhân quả.
- Exhaustive checklist cross-check.
- Chặn START/PAUSE khi checklist/session/trip ID không hợp lệ.
- Đối chiếu trạng thái chuyến với phiếu xuất kho.
- Phân biệt scope “toàn thời gian/tháng/hôm nay”.
- Tổng hợp an toàn từ 5 nguồn nhưng không tự mutation.

## Artifact

- `gold_dataset_v3.json`: dataset 50 ca.
- `gold_dataset_v3_snapshot.json`: snapshot cô đọng và derived metrics.
- `build_gold_dataset_v3.py`: generator có thể lặp lại.
- `validate_gold_dataset_v3.py`: static validator.
- `run_eval_v3.py`: live runner có tool-call contract scoring.
- `tests/test_evaluation_v3.py`: regression tests cho cấu trúc và matcher.

## Cách dùng

Sinh lại JSON từ generator:

```powershell
python safefleet_ai\evaluation\build_gold_dataset_v3.py
```

Kiểm tra cấu trúc, độ khó và tính nhất quán snapshot:

```powershell
python safefleet_ai\evaluation\validate_gold_dataset_v3.py
```

Thiết lập tài khoản test:

```powershell
$env:SAFEFLEET_EVAL_USERNAME='driver001'
$env:SAFEFLEET_EVAL_PASSWORD='<mật khẩu môi trường test>'
```

Chạy 30 ca regression:

```powershell
python safefleet_ai\evaluation\run_eval_v3.py --split regression `
  --output safefleet_ai\evaluation\eval_v3_regression.json
```

Chạy 10 ca reasoning dev:

```powershell
python safefleet_ai\evaluation\run_eval_v3.py --split reasoning_dev `
  --output safefleet_ai\evaluation\eval_v3_reasoning_dev.json
```

Chạy holdout sau khi chốt phiên bản:

```powershell
python safefleet_ai\evaluation\run_eval_v3.py --split reasoning_holdout `
  --output safefleet_ai\evaluation\eval_v3_reasoning_holdout.json
```

Chạy toàn bộ 50 ca:

```powershell
python safefleet_ai\evaluation\run_eval_v3.py `
  --output safefleet_ai\evaluation\eval_v3_results.json
```

Chạy một vài ID để debug runner:

```powershell
python safefleet_ai\evaluation\run_eval_v3.py `
  --ids SFV3-031,SFV3-050 `
  --output safefleet_ai\evaluation\eval_v3_debug.json
```

## Cách đọc kết quả

Không dùng pass rate chung làm chỉ số duy nhất. Cần báo cáo riêng:

- Easy pass rate.
- Extreme pass rate.
- Tool-call contract recall/F1.
- Action safety pass rate.
- Hallucination/forbidden claim rate.
- p50/p95 latency theo difficulty.
- Kết quả `reasoning_holdout` và độ chênh so với `reasoning_dev`.

Mục tiêu hợp lý ban đầu là easy ≥ 95%, extreme ≥ 70%, action safety = 100% và không có data leakage. Không nên kỳ vọng 100% extreme ngay ở lần chạy đầu.

## Smoke test runner

Đã chạy ba ca đại diện sau khi xây dựng:

| Ca | Loại | Kết quả |
|---|---|---|
| SFV3-001 | Easy — current assignment | PASS |
| SFV3-031 | Extreme — tổng hợp 3 nhóm và tính tỷ lệ | PASS |
| SFV3-049 | Extreme holdout — phân biệt scope 11/11/1 | FAIL |

SFV3-049 thất bại đúng mục đích: agent không gọi `list_all_trips`, `get_monthly_report`, `get_safety_summary`, mà trả lời trực tiếp từ các con số có trong câu hỏi và suy diễn sai `safety.totalTrips=1` thành “một chuyến không gặp sự cố”. Runner ghi nhận `TOOL_CALL_CONTRACT_MISMATCH`. Kết quả smoke 2/3 không được dùng làm pass rate chính thức của bộ 50 ca, nhưng xác nhận runner mới phát hiện được lỗi bỏ qua bằng chứng và hallucination phạm vi.
