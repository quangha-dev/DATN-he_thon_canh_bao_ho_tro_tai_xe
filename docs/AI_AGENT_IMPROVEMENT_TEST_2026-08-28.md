# Kết quả cải tiến và kiểm thử AI Agent SafeFleet — 28/08/2026

## Phạm vi cải tiến

- Bổ sung workflow tất định cho các tác vụ nhiều nguồn và quyết định an toàn trọng yếu.
- Khóa ID phụ thuộc theo dữ liệu trả về từ tool, không dùng ID do mô hình suy đoán.
- Chặn prompt injection, yêu cầu tiết lộ khóa và truy cập dữ liệu ngoài quyền.
- Không thực hiện mutation khi thiếu checklist, phiên lái không ACTIVE hoặc ID không khớp.
- Ghi thời gian, số lượt model, input/output token và chi phí ước tính cho từng request.
- Lưu benchmark nguyên tử sau từng test case; hỗ trợ tiếp tục bằng `--resume`.
- Xử lý dữ liệu nghiệp vụ bị thiếu như một kết quả có kiểm soát, không biến thành exception.

## Kết quả kiểm thử

| Hạng mục | Kết quả |
|---|---:|
| Unit/integration test AI service | 77 passed |
| Biên dịch backend | Thành công |
| Dịch vụ AI trên VPS | Healthy |
| Backend trên VPS | Healthy |
| Lô safety regression | 11/11 không lỗi hệ thống |
| Guardrail smoke trên VPS | 5/5 passed, 0 model call |
| Tool F1 của lô safety | 1,000 |
| Mutation trái phép | 0 |
| Task completion trung bình | 0,9788 |

Lượt benchmark hiện trạng 50 ca hoàn tất trong 163,407 giây, thời gian trung bình 3,268 giây/ca. Tool F1 đạt 0,9638 và task completion đạt 0,9516. Tỷ lệ Gold hiển thị 15/50 không phải điểm chất lượng hợp lệ vì dữ liệu VPS đã thay đổi so với snapshot Gold: hiện có 10 chuyến, phân công là chuyến 7, điểm an toàn 66 và không có thông báo chưa đọc; Gold cũ kỳ vọng 11 chuyến, phân công chuyến 6, điểm 57 và 14 thông báo.

## Eval Cost

Ca kiểm tra điều kiện COMPLETE trước tối ưu cần 9 lượt model, 17.193 token và 25,42 giây. Sau tối ưu, ca này gọi đúng ba nguồn `get_current_driving_session`, `get_current_assignment`, `get_safety_summary`, dùng 0 lượt model, 0 token và xử lý phía AI service trong 427 ms. Hệ thống dừng thao tác vì không có phiên ACTIVE khớp phân công.

Chi phí tiền chỉ được tính khi cấu hình:

```text
OPENAI_INPUT_COST_PER_MILLION_USD
OPENAI_OUTPUT_COST_PER_MILLION_USD
```

Nếu chưa cấu hình đơn giá, báo cáo vẫn lưu đầy đủ token nhưng để `estimatedCostUsd` là `null`, tránh đưa ra chi phí giả định.

## Checkpoint và tiếp tục khi hết quota

Mỗi test case hoàn thành sẽ được ghi ngay vào tệp output bằng cơ chế thay thế nguyên tử. Báo cáo gồm `status`, `completedCases`, `remainingCases`, `remainingCaseIds` và toàn bộ kết quả đã hoàn thành.

Chạy theo từng lô 10 ca:

```powershell
$env:SAFEFLEET_EVAL_USERNAME='<tài khoản kiểm thử>'
$env:SAFEFLEET_EVAL_PASSWORD='<mật khẩu kiểm thử>'
python evaluation/run_eval_v4.py `
  --base-url https://safeflee.duckdns.org/api/v1 `
  --output evaluation/eval_v4_results.json `
  --max-new-cases 10
```

Tiếp tục ở phiên sau:

```powershell
python evaluation/run_eval_v4.py `
  --base-url https://safeflee.duckdns.org/api/v1 `
  --output evaluation/eval_v4_results.json `
  --resume `
  --max-new-cases 10
```

Các ca lỗi tạm thời do quota, HTTP 429, mất kết nối evaluator hoặc cấu hình model sẽ được chạy lại. Các ca đã đánh giá hợp lệ được giữ nguyên. Với history mode `actual`, nếu một lượt trước phải chạy lại thì các lượt sau cùng workflow cũng được chạy lại để không dùng lịch sử hội thoại sai.

## Tệp bằng chứng

- `safefleet_ai/evaluation/eval_v4_results_improved_drift_2026-08-28.json`: benchmark hiện trạng 50 ca.
- `safefleet_ai/evaluation/eval_v4_safety_regression_2026-08-28.json`: lô safety/guardrail 11 ca.
- `safefleet_ai/evaluation/eval_v4_checkpoint_resume_2026-08-28.json`: bằng chứng chạy ngắt quãng và resume.
- `safefleet_ai/evaluation/eval_v4_cost_regression_2026-08-28.json`: bằng chứng tối ưu token/độ trễ ca COMPLETE.
- `safefleet_ai/evaluation/guardrail_smoke_results_2026-08-28.json`: prompt injection, secret exfiltration, phân quyền, làm rõ và out-of-scope.
- `safefleet_ai/evaluation/gold_dataset_v4_current_2026-08-28.json`: snapshot dữ liệu VPS hiện tại.

## Lưu ý nghiệm thu

Không sử dụng tỷ lệ 15/50 làm kết quả Gold chính thức. Trước lượt nghiệm thu tiếp theo cần đóng băng dữ liệu kiểm thử mới, lập expected answer và expected tool arguments từ snapshot đó, kiểm duyệt thủ công rồi chạy lại toàn bộ 50 ca ít nhất ba lần để báo cáo trung bình và độ lệch chuẩn.
