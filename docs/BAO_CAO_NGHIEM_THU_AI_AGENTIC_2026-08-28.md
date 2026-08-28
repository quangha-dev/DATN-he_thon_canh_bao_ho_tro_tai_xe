### 4.5.3. Thử nghiệm hệ thống AI Agentic

Mục tiêu thử nghiệm là đánh giá khả năng hiểu yêu cầu, duy trì ngữ cảnh, lựa chọn công cụ, thực hiện workflow đa bước và kiểm soát an toàn của AI Agent SafeFleet. Thử nghiệm cuối được thực hiện trực tiếp trên hệ thống đã triển khai tại `https://safeflee.duckdns.org` ngày 28/08/2026.

#### Kịch bản và phương pháp đánh giá

Nhóm xây dựng Gold Dataset V4 gồm 50 ca kiểm thử, chia đều thành năm mức độ. Mỗi ca có câu trả lời chuẩn đã duyệt thủ công, dữ kiện bắt buộc, trạng thái kết thúc, công cụ và tham số mong đợi. Dữ liệu VPS được cố định bằng snapshot `safefleet-v4-faed53b88028645b` và fingerprint để loại trừ sai lệch dữ liệu giữa các lần chạy.

| Mức | Nội dung | Số ca |
|---:|---|---:|
| 1 | Tra cứu trực tiếp một nguồn dữ liệu | 10 |
| 2 | Tra cứu liên kết và duy trì ngữ cảnh | 10 |
| 3 | Hành động, làm rõ yêu cầu và kiểm soát quyền | 10 |
| 4 | Tổng hợp, đối chiếu và lập luận từ nhiều nguồn | 10 |
| 5 | Workflow dài có cổng kiểm soát an toàn | 10 |
| **Tổng cộng** |  | **50** |

Các phương pháp được sử dụng gồm:

- **Gold Dataset và Output Quality:** đánh giá correctness, relevance, completeness và coherence.
- **Agent Trace Evaluation:** kiểm tra công cụ, tham số, thứ tự phụ thuộc, trạng thái workflow và hành động chờ xác nhận.
- **RAGAS-style Evaluation:** đánh giá faithfulness, answer relevancy, context precision và context recall đối với các ca truy hồi tri thức.
- **LLM-as-Judge:** chấm mẫu 10 ca khó theo thang 1–5 với bốn tiêu chí correctness, groundedness, completeness và safety. Gold Dataset vẫn là tiêu chuẩn chính nhằm hạn chế thiên lệch của mô hình chấm.
- **Guardrails/Red Team:** kiểm tra prompt injection, rò rỉ bí mật, truy cập sai quyền, yêu cầu mơ hồ và yêu cầu ngoài phạm vi.
- **Statistical Evaluation:** chạy lặp ba lần trên 10 ca đa bước trọng yếu để đo độ ổn định.
- **Eval Cost:** ghi nhận thời gian, số lần gọi công cụ, số lần gọi mô hình, token và chi phí.

Một ca chỉ được tính là đạt khi câu trả lời có đủ dữ kiện bắt buộc, không chứa thông tin bị cấm, gọi đủ công cụ với tham số phù hợp, các công cụ thực thi thành công và workflow kết thúc đúng trạng thái. Các hành động thay đổi dữ liệu phải dừng ở bước chờ xác nhận nếu chưa được người dùng đồng ý.

#### Kết quả nghiệm thu

| Mức độ | Số ca | Đạt | Không đạt | Tỷ lệ đạt |
|---:|---:|---:|---:|---:|
| Mức 1 | 10 | 10 | 0 | 100% |
| Mức 2 | 10 | 10 | 0 | 100% |
| Mức 3 | 10 | 10 | 0 | 100% |
| Mức 4 | 10 | 10 | 0 | 100% |
| Mức 5 | 10 | 10 | 0 | 100% |
| **Tổng cộng** | **50** | **50** | **0** | **100%** |

Lần nghiệm thu đầu trên cùng snapshot đạt 42/50 ca (84%). Sau khi sửa cơ chế suy luận theo dữ liệu, khóa quan hệ phụ thuộc giữa các công cụ và bổ sung workflow tất định cho các tác vụ an toàn, lần chạy phát hành cuối đạt 50/50 ca. Không ghi nhận lỗi hệ thống, lỗi công cụ, vi phạm quyền hoặc kết luận không có căn cứ.

Các chỉ số trung bình của 50 ca gồm: correctness 98,01%, completeness 98,01%, task completion 99,94%, Tool F1 99,71% và Tool Contract Recall 100%. Hệ thống thực hiện 99 lượt gọi công cụ, trung bình 1,98 lượt/ca.

| Phép đánh giá bổ trợ | Kết quả chính |
|---|---|
| Chạy lặp ca khó | 30/30 lượt đạt; tỷ lệ đạt trung bình 100%; độ lệch chuẩn 0 |
| Guardrails trực tiếp trên VPS | 10/10 ca đạt; không gọi model hoặc công cụ khi yêu cầu phải bị chặn/làm rõ |
| LLM-as-Judge | 10/10 ca đạt; correctness 4,8/5; groundedness 5/5; completeness 4,7/5; safety 4,7/5 |
| RAGAS-style | 6/6 ca đạt; faithfulness 1,00; context recall 1,00; context precision 0,75 |
| Kiểm thử mã nguồn | 82/82 kiểm thử đạt |

Khoảng tin cậy Wilson 95% của tỷ lệ đạt Gold là 92,86%–100%. Với 30 lượt chạy lặp, khoảng tin cậy là 88,65%–100%. Kết quả chạy lặp có độ trễ trung bình 1,332 giây và độ lệch chuẩn 0,160 giây, cho thấy các workflow trọng yếu ổn định giữa các lần thực thi.

Điểm cần lưu ý là Answer Relevancy của tập RAG đạt 0,4632, thấp hơn các chỉ số faithfulness và context recall. Điều này cho thấy nội dung truy hồi đúng và có căn cứ, nhưng cách diễn đạt câu trả lời RAG vẫn có thể được tối ưu để bám sát câu hỏi hơn. Ngoài ra, tập RAG hiện chỉ có sáu ca nên kết quả chưa đại diện cho mọi tài liệu hoặc cách diễn đạt của người dùng.

#### Thời gian và chi phí đánh giá

Lần chạy Gold cuối hoàn thành trong 92,391 giây, trung bình 1,843 giây/ca. P50 đạt 1,082 giây, P95 đạt 6,663 giây và P99 đạt 26,402 giây. P95 và P99 cao hơn trung bình do một số ca cần lập kế hoạch bằng mô hình; các workflow an toàn đã được xử lý tất định nên có độ trễ thấp hơn.

Hệ thống dùng `gpt-4o-mini`, thực hiện 18 lượt gọi mô hình với 40.223 input token và 1.946 output token. Theo đơn giá 0,15 USD/1 triệu input token và 0,60 USD/1 triệu output token, chi phí chạy Gold là khoảng **0,00720 USD**. LLM-as-Judge sử dụng thêm 8.856 token, tương đương **0,00174 USD**. Tổng chi phí Gold và Judge là khoảng **0,00894 USD**, chưa bao gồm chi phí hạ tầng VPS. Đơn giá được đối chiếu từ trang mô hình chính thức của OpenAI tại `https://developers.openai.com/api/docs/models/gpt-4o-mini`.

#### Kết luận

Kết quả cho thấy AI Agent SafeFleet đạt yêu cầu nghiệm thu trên bộ Gold Dataset hiện tại. Agent thực hiện đúng các workflow tra cứu và đa bước, duy trì quan hệ phụ thuộc giữa dữ liệu, không tự suy diễn khi thiếu bằng chứng và chặn đúng các yêu cầu vi phạm an toàn. Tuy nhiên, kết quả 100% chỉ có ý nghĩa trong phạm vi snapshot, 50 ca Gold và 10 ca Guardrails đã thiết kế; hệ thống vẫn cần được đánh giá định kỳ khi dữ liệu, prompt, công cụ hoặc mô hình thay đổi.
