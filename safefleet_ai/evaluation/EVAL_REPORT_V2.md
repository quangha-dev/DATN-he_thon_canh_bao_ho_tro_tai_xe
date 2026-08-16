# Báo cáo đánh giá Chatbot Agent SafeFleet — Gold Dataset v2

Ngày đánh giá: 15/08/2026
Actor: `DRIVER` (`driver001`)
Hệ thống: `backend → AI service → OpenAI agent → MCP → PostgreSQL 17`

## 0. Kết luận điều hành

Sau khi sửa các lỗi được phát hiện ở baseline, lượt release đạt:

- **30/30 ca đạt (100%)**.
- Live agent: **24/24 đạt (100%)**.
- RAG mock: **6/6 đạt (100%)**.
- Task Completion live: **1,0000**.
- Tool F1 live: **1,0000**.
- Không còn `SYSTEM_OR_TOOL_ERROR`, `POSSIBLE_HALLUCINATION`, `OUT_OF_SCOPE_TOOL_USE` hoặc action nhầm trip trong lượt release.
- Độ trễ live trung bình **4,834 giây**; p95 **13,778 giây**; lớn nhất **44,992 giây**.

So với baseline, pass rate tăng từ **63,33% lên 100%**, live pass rate tăng từ **54,17% lên 100%**, độ trễ trung bình chung giảm từ **5,298 giây xuống 3,868 giây**.

Kết luận: các lỗi chức năng P0/P1 trong bộ gold v2 đã được khắc phục. Hệ thống đủ điều kiện làm release candidate về correctness và safety trên phạm vi 30 ca này. Chưa nên coi là đã đạt toàn bộ SLO production vì p95 vẫn cao hơn mục tiêu 10 giây và đã quan sát một khoảng gián đoạn kết nối OpenAI trong quá trình chạy trung gian.

## 1. Fundamentals — Nền tảng đánh giá

Evaluation được thực hiện theo quy trình có thể lặp lại và so sánh:

1. Cố định snapshot PostgreSQL và tài khoản kiểm thử.
2. Cố định câu hỏi, đáp án, expected facts, expected/forbidden tools và trạng thái mong muốn.
3. Lưu response, trace tool, arguments, status, classification và latency.
4. Dùng cùng công thức chấm cho baseline và release.
5. Giữ riêng các file kết quả từng lượt, không ghi đè baseline.

Bốn chiều chất lượng output:

| Chiều | Cách chấm |
|---|---|
| Correctness | Tỷ lệ `expected_facts` đúng, có trừ điểm `forbidden_claims`. |
| Relevance | Semantic proxy giữa câu trả lời và gold answer. |
| Completeness | Tỷ lệ dữ kiện bắt buộc xuất hiện hoặc được diễn đạt tương đương. |
| Coherence | Câu trả lời không rỗng, không lộ JSON/HTML/trace, cấu trúc hợp lý. |

Semantic proxy hiện tại gồm 62% cosine token tiếng Việt đã chuẩn hóa và 38% cosine character trigram. Ngưỡng là `0,35`; đây là proxy offline, chưa thay thế embedding hoặc LLM-as-judge đã hiệu chuẩn.

Ba loại eval:

- **Offline:** batch 30 ca, gold facts/tools/status, replay/rescore.
- **Online:** cần tiếp tục theo dõi error rate, latency, confirmation mismatch, câu hỏi lại và CSAT.
- **Human:** cần review định kỳ về đúng dữ liệu, dễ hiểu, an toàn, đúng quyền và hallucination.

## 2. Benchmark design

### 2.1. Phân bổ 30 ca

| Nhóm | Số ca | Kết quả release |
|---|---:|---:|
| Agent data | 17 | 17/17 |
| Agent action | 3 | 3/3 |
| Hallucination guard | 1 | 1/1 |
| Access control | 1 | 1/1 |
| Clarification | 1 | 1/1 |
| Out of scope | 1 | 1/1 |
| RAG mock | 6 | 6/6 |

### 2.2. Snapshot gold

- Chuyến hoàn thành: ID `1, 2, 3, 4, 11`.
- Chuyến đang chạy: ID `5, 6, 7, 9`.
- Chuyến chưa đi: ID `8, 10`.
- Current assignment: trip `5`.
- Current driving session: trip `9`, trạng thái `ACTIVE`.
- 6 thông báo chưa đọc, nội dung `AI_ALERT / DROWSINESS / HIGH`.
- Báo cáo tháng 8: điểm an toàn 24, 11 chuyến, 5 chuyến hoàn thành, 21 cảnh báo, 3 cảnh báo nghiêm trọng.

Sự không nhất quán giữa assignment trip 5 và driving session trip 9 được giữ để kiểm tra grounding và chống action sai đối tượng.

### 2.3. Điều kiện đạt

Một ca live chỉ đạt khi đồng thời:

- Status thuộc `expected_statuses`.
- Tool F1 ≥ 0,8 và không gọi forbidden tool.
- Mọi tool chạy thành công.
- Semantic similarity ≥ 0,35.
- Fact coverage ≥ 0,75.
- Coherence = 1.
- Không có forbidden claim.

RAG mock yêu cầu thêm Faithfulness ≥ 0,70, Context Recall = 1 và Context Precision ≥ 0,34.

## 3. Metrics release

### 3.1. Agent live

| Metric | Baseline | Release |
|---|---:|---:|
| Pass rate | 54,17% (13/24) | **100% (24/24)** |
| Task Completion | 0,6991 | **1,0000** |
| Correctness | 0,5572 | **0,9500** |
| Relevance | 0,4856 | **0,8569** |
| Completeness | 0,5989 | **0,9500** |
| Coherence | 1,0000 | **1,0000** |
| Tool F1 | 0,8472 | **1,0000** |
| System/tool errors | 9 | **0** |
| Possible hallucination/action sai ID | 2 | **0** |

`Task Completion = trung bình(status đúng, tool F1, toàn bộ tool thành công)`.

### 3.2. Latency

| Chỉ số | Kết quả release |
|---|---:|
| Trung bình 24 ca live | 4,834 giây |
| p95 live | 13,778 giây |
| Lớn nhất | 44,992 giây |
| Trung bình toàn bộ 30 ca | 3,868 giây |

Ca chậm nhất là SFV2-005 (44,992 giây); SFV2-015 mất 13,778 giây. Correctness đạt nhưng latency chưa đạt SLO đề xuất p95 < 10 giây.

### 3.3. RAG mock

RAG chưa tích hợp vào chatbot live. Hai văn bản mock được chia 12 chunk theo `Mã văn bản → Điều → Khoản → nội dung nguyên tử`.

| RAGAS metric | Kết quả |
|---|---:|
| Faithfulness | 1,0000 |
| Answer Relevancy | 0,4632 |
| Context Recall | 1,0000 |
| Context Precision | 0,7500 |

6/6 ca đạt, gồm cả ca không có căn cứ về nghỉ phép: hệ thống phải trả “chưa đủ căn cứ” thay vì bịa.

## 4. Lỗi đã sửa

### 4.1. PostgreSQL nullable parameter — P0

Baseline lỗi `could not determine data type of parameter $5` khi `from/to` là null.

Đã tách repository thành bốn truy vấn có kiểu rõ ràng:

- Không có ngày.
- Chỉ có `from`.
- Chỉ có `to`.
- Có cả `from` và `to`.

Integration test PostgreSQL 17 và smoke test live đều trả đúng 5 chuyến hoàn thành ở cả bốn biến thể.

### 4.2. Action nhầm chuyến — P0

Đã bổ sung ba lớp bảo vệ:

1. Orchestrator khóa trip ID theo bằng chứng tool trước: assignment, driving session, detail hoặc ranking.
2. MCP kiểm tra ma trận trạng thái cho `ACCEPT/START/PAUSE/RESUME/COMPLETE`, checklist khi START và session-trip/status khi PAUSE/RESUME/COMPLETE.
3. Backend kiểm tra current driving session thuộc đúng trip trước mọi mutation pause/resume/complete.

Kết quả release: 3/3 ca action đạt; không có confirmation sai trip ID.

### 4.3. Routing và grounding — P1

Đã thêm deterministic guard/fast-path cho:

- Từ chối dữ liệu tài xế khác mà không gọi tool.
- Từ chối thời tiết khi không có weather tool.
- Làm rõ câu hỏi chuyến không có phạm vi.
- Mở chi tiết chuyến theo đúng hai bước `get_trip_detail → open_mobile_screen`.
- Phiếu xuất kho, thông báo chưa đọc, danh sách hoàn thành/chưa đi/đang chạy.
- Tổng kết đúng current assignment.
- Đối chiếu assignment với driving session.
- Chi tiết/tóm tắt chuyến giữ nguyên enum và dữ kiện quan trọng.
- Khóa ngày được nêu trong câu hỏi trên mọi list tool của cùng flow.

Fast-path vẫn lấy dữ liệu qua MCP/backend theo token người dùng; không hard-code dữ liệu gold.

### 4.4. Resilience OpenAI — P1

Client OpenAI đã retry tối đa 3 lần với backoff ngắn cho lỗi mạng, HTTP 429 và 5xx; không retry lỗi 401/403.

Trong một lượt trung gian, 13 ca phụ thuộc model cùng lỗi do kết nối OpenAI trong khoảng ngắn; endpoint cấu hình sau đó xác nhận kết nối phục hồi. Lượt release kế tiếp đạt 30/30. Sự cố này cho thấy vẫn cần circuit breaker/monitor/fallback production dù functional eval đã đạt.

## 5. Kiểm thử kỹ thuật

| Hạng mục | Kết quả |
|---|---|
| AI unit/integration tests | **41/41 pass** |
| Backend compile JDK 21 | **BUILD SUCCESS** |
| PostgreSQL 17 integration mobile flow | **1/1 pass** |
| API list trips 4 biến thể ngày | **4/4 HTTP OK** |
| Gold release | **30/30 pass** |
| Docker health | frontend/backend/ai-service/postgres/minio đều healthy |

Cảnh báo không chặn: test AI có một `StarletteDeprecationWarning` về TestClient/httpx; Flyway cảnh báo phiên bản hiện tại chưa tuyên bố hỗ trợ PostgreSQL 17 dù migrations và integration test đều thành công.

## 6. Đánh giá production

Đã đạt trong phạm vi benchmark:

- Functional pass rate ≥ 90%.
- Tool error = 0 trong lượt release.
- Hallucination/action sai ID = 0.
- Confirmation trước mutation = 100%.
- Access control, clarification và out-of-scope = 100%.
- RAG mock Faithfulness/Recall đạt ngưỡng.

Còn cần trước production chính thức:

1. Chạy mỗi ca live 3–5 lần để đo variance/pass@k; một lượt 30/30 chưa chứng minh độ ổn định dài hạn.
2. Đưa OpenAI error rate, p50/p95/p99, tool error và confirmation mismatch lên dashboard/alert.
3. Giảm p95 xuống dưới 10 giây; ưu tiên SFV2-005 và các flow có nhiều vòng plan-check.
4. Thêm circuit breaker và thông báo fallback rõ khi OpenAI gián đoạn.
5. Tạo database seed riêng cho CI để gold không trôi.
6. Khi bật RAG thật, bắt buộc citation `document/chunk/điều/khoản` và chạy lại RAGAS trên pipeline live.
7. Mở rộng lên tối thiểu 100 ca action và kiểm thử concurrent/replay/idempotency trước phát hành.

## 7. Hạn chế

- 30 ca là bộ cơ bản, chưa bao phủ prompt injection nâng cao, lỗi chính tả nặng, hội thoại dài, tải đồng thời và dữ liệu lớn.
- Database dev có thể thay đổi; gold phụ thuộc snapshot.
- OpenAI có tính không xác định và phụ thuộc mạng bên ngoài.
- Semantic proxy còn lexical/character; có thể phạt câu đúng nhưng diễn đạt khác.
- RAG hiện là mock, chưa phải RAG live của chatbot.

## 8. Artifact và cách chạy lại

Artifact chính:

- Dataset: `gold_dataset_v2.json`.
- Baseline: `eval_v2_results.json` — 19/30.
- Lượt release: `eval_v2_results_release.json` — 30/30.
- Hai tài liệu mock: `rag_documents/01_quy_dinh_an_ca_lam_them.md`, `rag_documents/02_quy_dinh_su_co_lop.md`.
- Chunks: `rag_chunks_v2.jsonl`.

Chạy toàn bộ:

```powershell
$env:SAFEFLEET_EVAL_USERNAME='driver001'
$env:SAFEFLEET_EVAL_PASSWORD='<mật khẩu môi trường test>'
python safefleet_ai\evaluation\run_eval_v2.py --only all `
  --output safefleet_ai\evaluation\eval_v2_results_release.json
```

Chỉ chạy RAG mock:

```powershell
python safefleet_ai\evaluation\run_eval_v2.py --only rag
```

Chấm lại response đã lưu mà không gọi model:

```powershell
python safefleet_ai\evaluation\rescore_eval_v2.py
```
