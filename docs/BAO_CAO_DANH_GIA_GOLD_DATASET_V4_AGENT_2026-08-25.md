# BÁO CÁO CHI TIẾT GOLD DATASET V4 VÀ ĐÁNH GIÁ SAFEFLEET AGENT

**Ngày đánh giá:** 25/08/2026  
**Phạm vi:** SafeFleet AI Agent, dữ liệu thật PostgreSQL, hội thoại nhiều lượt dùng câu trả lời thực tế của Agent làm lịch sử  
**Dataset:** `safefleet-agent-gold-v4-progressive-50`  
**Bản release được chấp nhận:** V4-C  
**Kết luận chính:** V4-C chạy đủ 50/50 case, snapshot hợp lệ, đạt **18/50 (36%)**. Hệ thống làm tốt nhóm trực tiếp và kiểm soát an toàn cơ bản nhưng chưa đạt yêu cầu release cho workflow dài: L4 và L5 đều 0/10.

> Quy ước: “E” là tool Gold mong đợi; “A” là tool Agent thực tế gọi. Báo cáo phân biệt lỗi Agent, lỗi hợp đồng Gold và lỗi hạ tầng evaluator để tránh quy sai nguyên nhân.

---

# PHẦN I — THIẾT KẾ DATASET VÀ SO SÁNH CÁC PHIÊN BẢN

## 1. Mục tiêu và cấu trúc Gold Dataset V4

Bộ dữ liệu có 50 câu, chia thành 10 workflow, mỗi workflow 5 lượt. Độ dài, số ràng buộc, số nguồn dữ liệu và yêu cầu lập luận tăng sau mỗi nhóm 10 câu. Lịch sử hội thoại không dùng đáp án Gold giả lập mà dùng chính câu trả lời thật của Agent ở lượt trước; vì vậy lỗi ở một lượt có thể ảnh hưởng các lượt sau giống vận hành thực tế.

| Mức | Tên mức | Đặc trưng | Số case |
|---:|---|---|---:|
| 1 | Tra cứu trực tiếp | 1 nguồn/ý định; câu ngắn | 10 |
| 2 | Tra cứu có ngữ cảnh | Nối tiếp hội thoại, điều kiện bổ sung | 10 |
| 3 | Hành động và kiểm soát | Tool hành động, xác nhận, phân quyền | 10 |
| 4 | Lập luận đa nguồn | Tổng hợp, so sánh, tỷ lệ, nhất quán | 10 |
| 5 | Workflow dài | Nhiều nguồn, rủi ro, hành động và an toàn | 10 |

Các kiểm soát tính đúng của evaluator:

- Snapshot live bất biến: `safefleet-v4-b05663d29a71b3f0`.
- Fingerprint: `b05663d29a71b3f0b19907e2b6286782c30fdcc7c18ae0d2abcee47b4cf12857`.
- Preflight V4-C: `MATCH`; số chuyến: 11.
- Nếu fingerprint DB khác Gold, runner phải từ chối phát hành điểm thay vì tạo false negative.
- Phân loại lỗi: PASS, QUALITY_MISMATCH, TOOL_CALL_CONTRACT_MISMATCH, SYSTEM_OR_TOOL_ERROR và EVALUATOR_ERROR.

## 2. Tóm tắt ba phiên bản

| Bản | Mô tả | Đạt | Sai chất lượng | Sai tool | Lỗi hệ thống/tool | Lỗi evaluator | Thời gian | Giá trị sử dụng |
|---|---|---:|---:|---:|---:|---:|---:|---|
| V4-A | Bản cơ sở trước sửa | 13/50 (26%) | 13 | 21 | 3 | 0 | 319.924s | Không dùng làm release: snapshot cũ, chưa có fingerprint preflight |
| V4-B | Bản sau sửa lần 1 (lượt chạy gián đoạn) | 19/50 (38%) | 6 | 12 | 0 | 13 | 126.856s | Không dùng làm release: 13 EVALUATOR_ERROR do backend restart |
| V4-C | Bản release hợp lệ | 18/50 (36%) | 10 | 17 | 5 | 0 | 433.099s | Hợp lệ: preflight khớp, đủ 50 case, không có EVALUATOR_ERROR |

### 2.1. Nguyên nhân khác biệt giữa ba lượt

- **V4-A:** đạt 13/50 nhưng Gold dùng snapshot 15/08 trong khi backend đã có dữ liệu 25/08. Lượt này hữu ích để tìm lỗi nhưng không hợp lệ làm mốc release vì lỗi dữ liệu và lỗi Agent bị trộn lẫn.
- **V4-B:** các sửa đổi nâng kết quả quan sát lên 19 case đạt; tuy nhiên case 38–50 bị `Remote end closed connection without response` khi backend được recreate. 13 case này là EVALUATOR_ERROR, không phải lỗi nghiệp vụ của Agent, nên 38% chỉ là số chẩn đoán tạm thời.
- **V4-C:** chạy lại với snapshot/fingerprint khớp và hạ tầng ổn định. Đây là kết quả chính thức: 18/50. Điểm thấp hơn V4-B một case không phải hồi quy chắc chắn vì V4-B chưa hoàn thành hợp lệ toàn bộ tập.

## 3. Ma trận kết quả qua phiên bản

| Case | Mức | V4-A | V4-B | V4-C | Xu hướng |
|---|---:|---|---|---|---|
| SFV4-001 | L1 | Sai chất lượng | Sai chất lượng | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-002 | L1 | Sai chất lượng | Đạt | Đạt | Đạt ở release |
| SFV4-003 | L1 | Sai chất lượng | Sai chất lượng | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-004 | L1 | Đạt | Đạt | Sai chất lượng | Có thay đổi, vẫn chưa đạt |
| SFV4-005 | L1 | Sai chất lượng | Đạt | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-006 | L1 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-007 | L1 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-008 | L1 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-009 | L1 | Sai chất lượng | Đạt | Đạt | Đạt ở release |
| SFV4-010 | L1 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-011 | L2 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-012 | L2 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-013 | L2 | Sai chất lượng | Sai chất lượng | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-014 | L2 | Sai chất lượng | Sai chất lượng | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-015 | L2 | Sai chất lượng | Sai hợp đồng tool | Đạt | Đạt ở release |
| SFV4-016 | L2 | Sai chất lượng | Đạt | Đạt | Đạt ở release |
| SFV4-017 | L2 | Sai chất lượng | Đạt | Đạt | Đạt ở release |
| SFV4-018 | L2 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-019 | L2 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-020 | L2 | Lỗi hệ thống/tool | Sai chất lượng | Sai chất lượng | Có thay đổi, vẫn chưa đạt |
| SFV4-021 | L3 | Sai chất lượng | Đạt | Đạt | Đạt ở release |
| SFV4-022 | L3 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-023 | L3 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-024 | L3 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-025 | L3 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-026 | L3 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-027 | L3 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-028 | L3 | Sai hợp đồng tool | Sai hợp đồng tool | Sai chất lượng | Có thay đổi, vẫn chưa đạt |
| SFV4-029 | L3 | Đạt | Đạt | Đạt | Đạt ở release |
| SFV4-030 | L3 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-031 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-032 | L4 | Sai hợp đồng tool | Sai chất lượng | Sai chất lượng | Có thay đổi, vẫn chưa đạt |
| SFV4-033 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-034 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-035 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-036 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-037 | L4 | Sai hợp đồng tool | Sai hợp đồng tool | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-038 | L4 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-039 | L4 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-040 | L4 | Sai hợp đồng tool | Lỗi bộ đánh giá | Lỗi hệ thống/tool | Có thay đổi, vẫn chưa đạt |
| SFV4-041 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-042 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-043 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Lỗi hệ thống/tool | Có thay đổi, vẫn chưa đạt |
| SFV4-044 | L5 | Lỗi hệ thống/tool | Lỗi bộ đánh giá | Lỗi hệ thống/tool | Chưa cải thiện phân loại |
| SFV4-045 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-046 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-047 | L5 | Sai hợp đồng tool | Lỗi bộ đánh giá | Sai hợp đồng tool | Chưa cải thiện phân loại |
| SFV4-048 | L5 | Sai chất lượng | Lỗi bộ đánh giá | Lỗi hệ thống/tool | Có thay đổi, vẫn chưa đạt |
| SFV4-049 | L5 | Sai chất lượng | Lỗi bộ đánh giá | Sai chất lượng | Chưa cải thiện phân loại |
| SFV4-050 | L5 | Lỗi hệ thống/tool | Lỗi bộ đánh giá | Lỗi hệ thống/tool | Chưa cải thiện phân loại |

## 4. Chi tiết từng case — V4-A (trước sửa)

**Bối cảnh bản:** snapshot `driver001-postgres-20260815T082859+0700`, thời điểm tham chiếu 2026-08-15T08:28:59+07:00; chưa có fingerprint preflight. Mọi QUALITY_MISMATCH cần được đọc cùng cảnh báo drift dữ liệu.

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân | Ảnh hưởng | Cách sửa |
|---|---:|---|---|---|---|---|---|
| SFV4-001 | L1/T1 | Sai chất lượng (COMPLETED) | E: get_current_assignment<br>A: get_current_assignment | Thiếu fact: DEMO-TRIP-005, đang tiến hành, 65% | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-002 | L1/T2 | Sai chất lượng (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Thiếu fact: IN_PROGRESS, 65% | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-003 | L1/T3 | Sai chất lượng (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Thiếu fact: 70% | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-004 | L1/T4 | Đạt (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-005 | L1/T5 | Sai chất lượng (COMPLETED) | E: get_trip_detail, get_current_driving_session<br>A: get_trip_detail, get_current_driving_session | Thiếu fact: đang tiến hành, 5%, kích hoạt | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-006 | L1/T1 | Đạt (COMPLETED) | E: get_trip_summary<br>A: get_trip_summary | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-007 | L1/T2 | Đạt (COMPLETED) | E: get_trip_detail, get_warehouse_issue<br>A: get_trip_detail, get_warehouse_issue | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-008 | L1/T3 | Sai hợp đồng tool (COMPLETED) | E: get_safety_summary<br>A: get_current_driving_session | Thiếu fact: HIGH_RISK, điểm an toàn 24, 1 phút, 21 cảnh báo, 240 phút | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_safety_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-009 | L1/T4 | Sai chất lượng (COMPLETED) | E: get_monthly_report<br>A: get_monthly_report | Thiếu fact: điểm an toàn 24, 45%, đúng giờ 20%, 21 cảnh báo | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-010 | L1/T5 | Đạt (COMPLETED) | E: list_notifications<br>A: list_notifications | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-011 | L2/T1 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-012 | L2/T2 | Đạt (COMPLETED) | E: list_upcoming_trips<br>A: list_upcoming_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-013 | L2/T3 | Sai chất lượng (COMPLETED) | E: rank_upcoming_trips<br>A: rank_upcoming_trips | Thiếu fact: DEMO-TRIP-008, 17/08/2026, 00:14, My Dinh, Ho Tung Mau | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-014 | L2/T4 | Sai chất lượng (COMPLETED) | E: list_active_trips<br>A: list_active_trips | Thiếu fact: DEMO-TRIP-005, DEMO-TRIP-006, DEMO-TRIP-007, DEMO-TRIP-009, IN_PROGRESS | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-015 | L2/T5 | Sai chất lượng (COMPLETED) | E: list_completed_trips, rank_upcoming_trips<br>A: list_completed_trips, rank_upcoming_trips | Thiếu fact: còn 2, DEMO-TRIP-008, 17/08/2026 | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-016 | L2/T1 | Sai chất lượng (COMPLETED) | E: list_completed_trips, list_active_trips<br>A: list_completed_trips, list_active_trips | Thiếu fact: DEMO-TRIP-006, DEMO-TRIP-009 | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-017 | L2/T2 | Sai chất lượng (COMPLETED) | E: get_current_assignment, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Thiếu fact: DEMO-TRIP-005, 65%, PAUSE_OR_COMPLETE | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-018 | L2/T3 | Đạt (COMPLETED) | E: get_trip_detail, open_mobile_screen<br>A: get_trip_detail, open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-019 | L2/T4 | Đạt (AWAITING_CONFIRMATION) | E: get_trip_detail, prepare_trip_action<br>A: get_trip_detail, prepare_trip_action | Đủ điều kiện chấm; status=AWAITING_CONFIRMATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-020 | L2/T5 | Lỗi hệ thống/tool (FAILED) | E: get_current_driving_session, prepare_trip_action<br>A: get_current_driving_session, list_active_trips | Thiếu fact: tạm dừng chuyến, 9 | Bộ điều phối hoặc tool checker chuyển workflow sang FAILED. | Không có kết quả cuối đáng tin cậy cho người dùng. | Tách lỗi hạ tầng khỏi kết quả nghiệp vụ, lưu trace và cho phép hoàn tất các truy vấn read-only an toàn. |
| SFV4-021 | L3/T1 | Sai chất lượng (COMPLETED) | E: get_current_assignment, get_current_driving_session<br>A: get_current_assignment, get_current_driving_session | Thiếu fact: chuyến 5, chuyến 9, ACTIVE | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-022 | L3/T2 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-023 | L3/T3 | Đạt (NEEDS_CLARIFICATION) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=NEEDS_CLARIFICATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-024 | L3/T4 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-025 | L3/T5 | Sai hợp đồng tool (COMPLETED) | E: get_trip_detail, get_trip_summary<br>A: get_trip_detail | Thiếu fact: 19/08/2026, ACCEPT | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-026 | L3/T1 | Sai hợp đồng tool (COMPLETED) | E: get_trip_summary<br>A: get_trip_detail | Thiếu fact: DEMO-TRIP-009, đã nộp checklist, IN_PROGRESS, 5%, PAUSE_OR_COMPLETE | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-027 | L3/T2 | Đạt (COMPLETED) | E: open_mobile_screen<br>A: open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-028 | L3/T3 | Sai hợp đồng tool (COMPLETED) | E: open_mobile_screen<br>A: get_current_assignment, get_safety_summary | Tool ngoài hợp đồng: get_current_assignment, get_safety_summary | Kế hoạch/call ledger không hoàn tất tool bắt buộc: open_mobile_screen. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-029 | L3/T4 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-030 | L3/T5 | Sai hợp đồng tool (NEEDS_CLARIFICATION) | E: list_all_trips<br>A: không gọi tool | Thiếu fact: 5 COMPLETED, 4 IN_PROGRESS, 2 ASSIGNED | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_all_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-031 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_active_trips, list_upcoming_trips<br>A: list_all_trips | Thiếu fact: 45,45%, 18,18% | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_completed_trips, list_active_trips, list_upcoming_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-032 | L4/T2 | Sai hợp đồng tool (COMPLETED) | E: list_active_trips, get_safety_summary<br>A: list_active_trips | Thiếu fact: 53,75%, 1 trong 4, 25%, HIGH_RISK, điểm an toàn 24 | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_safety_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-033 | L4/T3 | Sai hợp đồng tool (COMPLETED) | E: list_active_trips, get_current_driving_session, get_trip_detail<br>A: list_active_trips | Thiếu fact: DEMO-TRIP-007, 75%, DEMO-TRIP-009, 5%, 70 điểm phần trăm | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_current_driving_session, get_trip_detail. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-034 | L4/T4 | Sai hợp đồng tool (COMPLETED) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Thiếu fact: không nhất quán, chuyến 5, chưa có checklist, ACTIVE, chuyến 9, đã có checklist, không nên thao tác, quản lý kiểm tra | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_current_driving_session, get_trip_summary, get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-035 | L4/T5 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_all_trips, get_monthly_report<br>A: list_completed_trips, get_monthly_report | Thiếu fact: completionRate=45%, phù hợp, làm tròn | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_all_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-036 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_notifications, get_monthly_report<br>A: list_notifications | Thiếu fact: 21, 28,57%, 3 cảnh báo nghiêm trọng, 14,29% | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_monthly_report. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-037 | L4/T2 | Sai hợp đồng tool (COMPLETED) | E: get_monthly_report, list_notifications<br>A: list_notifications | Thiếu fact: 15 cảnh báo, 71,43%, 15/08, 6 cảnh báo, 28,57%, sáu thông báo | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_monthly_report. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-038 | L4/T3 | Sai hợp đồng tool (COMPLETED) | E: list_upcoming_trips, rank_upcoming_trips<br>A: rank_upcoming_trips | Dưới đây là danh sách các chuyến chưa đi được xếp theo lịch trình: 1. **Chuyến: DEMO-TRIP-006** - Thời gian khởi hành dự kiến: 2026-08-15T00:14:39.246948 - Địa điểm khởi hành: Ha Dong - Địa điểm đến: Kieu Mai … | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_upcoming_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-039 | L4/T4 | Sai hợp đồng tool (COMPLETED) | E: list_all_trips, get_trip_detail<br>A: list_all_trips | Thiếu fact: IN_PROGRESS, 65%, hai chuyến khác nhau | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_detail, get_trip_detail. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-040 | L4/T5 | Sai hợp đồng tool (COMPLETED) | E: list_all_trips, get_trip_detail<br>A: list_all_trips, list_completed_trips, get_trip_summary, get_trip_summary | Thiếu fact: IN_PROGRESS, 70%, nguyên nhân | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_detail, get_trip_detail. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-041 | L5/T1 | Sai hợp đồng tool (COMPLETED) | E: list_active_trips, get_trip_summary, get_current_assignment, get_current_driving_session<br>A: get_current_assignment, get_current_driving_session | Thiếu fact: bốn chuyến, 5, 6, 7, 9, chỉ chuyến 9, đã nộp checklist, 5, 6, 7, chưa nộp, chuyến 5, chuyến 9, bất thường | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_active_trips, get_trip_summary, get_trip_summary, get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-042 | L5/T2 | Sai hợp đồng tool (COMPLETED) | E: list_active_trips, get_safety_summary, get_trip_summary<br>A: list_active_trips | Thiếu fact: DEMO-TRIP-006, duy nhất, HIGH, 70%, HIGH_RISK, điểm an toàn 24, quản lý đánh giá, không tự thay đổi | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_safety_summary, get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-043 | L5/T3 | Sai hợp đồng tool (COMPLETED) | E: rank_upcoming_trips, get_trip_summary, prepare_trip_action<br>A: rank_upcoming_trips, get_trip_detail | Thiếu fact: 17/08/2026, ACCEPT | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary, prepare_trip_action. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-044 | L5/T4 | Lỗi hệ thống/tool (FAILED) | E: rank_upcoming_trips, get_trip_summary, get_current_driving_session<br>A: rank_upcoming_trips, get_trip_detail, get_current_assignment, get_current_driving_session | Thiếu fact: chuyến 8, chưa nộp checklist, phiên lái ACTIVE, chuyến 9, không an toàn, không tạo, START | Bộ điều phối hoặc tool checker chuyển workflow sang FAILED. | Không có kết quả cuối đáng tin cậy cho người dùng. | Tách lỗi hạ tầng khỏi kết quả nghiệp vụ, lưu trace và cho phép hoàn tất các truy vấn read-only an toàn. |
| SFV4-045 | L5/T5 | Sai hợp đồng tool (COMPLETED) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: get_current_assignment, get_current_driving_session | Thiếu fact: chuyến 5, phiên lái ACTIVE, chuyến 9, không được chuẩn bị PAUSE, quản lý | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-046 | L5/T1 | Sai hợp đồng tool (COMPLETED) | E: get_current_driving_session, get_trip_summary, prepare_trip_action<br>A: get_current_assignment | Thiếu fact: ACTIVE, DEMO-TRIP-009, IN_PROGRESS, đã nộp checklist, PAUSE_OR_COMPLETE, 9 | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_current_driving_session, get_trip_summary, prepare_trip_action. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-047 | L5/T2 | Sai hợp đồng tool (COMPLETED) | E: get_warehouse_issue, get_trip_summary<br>A: get_trip_detail, get_warehouse_issue | Thiếu fact: requested=10, issued=10, delivered=10, 100%, COMPLETED, ISSUED, hai trạng thái nghiệp vụ | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-048 | L5/T3 | Sai chất lượng (COMPLETED) | E: get_trip_detail, get_trip_summary<br>A: get_trip_detail, get_trip_summary | Thiếu fact: 15/08, 23 giờ 49 phút, 47 giờ 48 phút | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-049 | L5/T4 | Sai chất lượng (COMPLETED) | E: list_all_trips, get_monthly_report, get_safety_summary<br>A: list_all_trips, get_monthly_report, get_safety_summary | Thiếu fact: toàn thời gian, tháng 8, totalTrips=11, totalTrips=1, hôm nay, không phải tổng lịch sử | Kết quả bị trộn giữa chất lượng Agent và Gold snapshot cũ ngày 15/08 so với DB live ngày 25/08. | Có thể tạo false negative; không phù hợp để làm điểm release. | Đóng băng snapshot, kiểm tra fingerprint trước chạy rồi chấm lại trên dữ liệu đồng nhất. |
| SFV4-050 | L5/T5 | Lỗi hệ thống/tool (FAILED) | E: get_safety_summary, list_notifications, get_current_assignment, get_current_driving_session, rank_upcoming_trips<br>A: get_safety_summary, list_notifications | Thiếu fact: chưa nên, HIGH_RISK, điểm 24, 6 thông báo, phân công, chuyến 5, phiên lái ACTIVE, chuyến 9, quản lý đối soát, DEMO-TRIP-008, 17/08/2026 | Bộ điều phối hoặc tool checker chuyển workflow sang FAILED. | Không có kết quả cuối đáng tin cậy cho người dùng. | Tách lỗi hạ tầng khỏi kết quả nghiệp vụ, lưu trace và cho phép hoàn tất các truy vấn read-only an toàn. |

## 5. Chi tiết từng case — V4-B (sau sửa lần 1, bị gián đoạn)

**Bối cảnh bản:** snapshot đã đóng băng và preflight khớp. Case 38–50 không có kết quả Agent hợp lệ vì backend bị restart trong lúc chạy; không được chuyển EVALUATOR_ERROR thành thất bại Agent.

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân | Ảnh hưởng | Cách sửa |
|---|---:|---|---|---|---|---|---|
| SFV4-001 | L1/T1 | Sai chất lượng (COMPLETED) | E: get_current_assignment<br>A: get_current_assignment | Thiếu fact: 0%, HIGH, chưa nộp checklist | Câu trả lời thiếu/sai fact hoặc diễn đạt: 0%, HIGH, chưa nộp checklist. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-002 | L1/T2 | Đạt (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-003 | L1/T3 | Sai chất lượng (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail, get_trip_summary | Thiếu fact: DEMO-TRIP-006, ASSIGNED | Câu trả lời thiếu/sai fact hoặc diễn đạt: DEMO-TRIP-006, ASSIGNED. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-004 | L1/T4 | Đạt (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-005 | L1/T5 | Đạt (COMPLETED) | E: get_trip_detail, get_current_driving_session<br>A: get_trip_detail, get_current_driving_session | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-006 | L1/T1 | Đạt (COMPLETED) | E: get_trip_summary<br>A: get_trip_summary | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-007 | L1/T2 | Đạt (COMPLETED) | E: get_trip_detail, get_warehouse_issue<br>A: get_trip_detail, get_warehouse_issue | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-008 | L1/T3 | Sai hợp đồng tool (COMPLETED) | E: get_safety_summary<br>A: get_current_driving_session | Thiếu fact: AVAILABLE, 57, 26 cảnh báo, 240 phút, 2 | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_safety_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-009 | L1/T4 | Đạt (COMPLETED) | E: get_monthly_report<br>A: get_monthly_report | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-010 | L1/T5 | Đạt (COMPLETED) | E: list_notifications<br>A: list_notifications | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-011 | L2/T1 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-012 | L2/T2 | Đạt (COMPLETED) | E: list_upcoming_trips<br>A: list_upcoming_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-013 | L2/T3 | Sai chất lượng (COMPLETED) | E: rank_upcoming_trips<br>A: rank_upcoming_trips | Thiếu fact: 15/08/2026, Ha Dong, Kieu Mai, HIGH | Câu trả lời thiếu/sai fact hoặc diễn đạt: 15/08/2026, Ha Dong, Kieu Mai, HIGH. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-014 | L2/T4 | Sai chất lượng (COMPLETED) | E: list_active_trips<br>A: list_active_trips | Thiếu fact: không có, đang chạy | Câu trả lời thiếu/sai fact hoặc diễn đạt: không có, đang chạy. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-015 | L2/T5 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, rank_upcoming_trips<br>A: không gọi tool | Thiếu fact: 15/08/2026 | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_completed_trips, rank_upcoming_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-016 | L2/T1 | Đạt (COMPLETED) | E: list_completed_trips, list_active_trips<br>A: list_completed_trips, list_active_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-017 | L2/T2 | Đạt (COMPLETED) | E: get_current_assignment, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-018 | L2/T3 | Đạt (COMPLETED) | E: get_trip_detail, open_mobile_screen<br>A: get_trip_detail, open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-019 | L2/T4 | Đạt (AWAITING_CONFIRMATION) | E: get_trip_detail, prepare_trip_action<br>A: get_trip_detail, prepare_trip_action | Đủ điều kiện chấm; status=AWAITING_CONFIRMATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-020 | L2/T5 | Sai chất lượng (COMPLETED) | E: get_current_driving_session<br>A: get_current_driving_session | Thiếu fact: PAUSE | Câu trả lời thiếu/sai fact hoặc diễn đạt: PAUSE. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-021 | L3/T1 | Đạt (COMPLETED) | E: get_current_assignment, get_current_driving_session<br>A: get_current_assignment, get_current_driving_session | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-022 | L3/T2 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-023 | L3/T3 | Đạt (NEEDS_CLARIFICATION) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=NEEDS_CLARIFICATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-024 | L3/T4 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-025 | L3/T5 | Sai hợp đồng tool (COMPLETED) | E: get_trip_detail, get_trip_summary<br>A: get_trip_detail | Thiếu fact: 19/08/2026, ACCEPT | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-026 | L3/T1 | Sai hợp đồng tool (COMPLETED) | E: get_trip_summary<br>A: get_trip_detail | Thiếu fact: DEMO-TRIP-009, đã nộp checklist, ACCEPT | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_trip_summary. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-027 | L3/T2 | Đạt (COMPLETED) | E: open_mobile_screen<br>A: open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-028 | L3/T3 | Sai hợp đồng tool (COMPLETED) | E: open_mobile_screen<br>A: không gọi tool | Tôi không thể mở màn hình an toàn lái xe vì không có quyền truy cập phù hợp. Vui lòng kiểm tra lại quyền của tài khoản hoặc yêu cầu một tài khoản có quyền truy cập để thực hiện hành động này. | Kế hoạch/call ledger không hoàn tất tool bắt buộc: open_mobile_screen. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-029 | L3/T4 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-030 | L3/T5 | Sai hợp đồng tool (NEEDS_CLARIFICATION) | E: list_all_trips<br>A: không gọi tool | Thiếu fact: 6 COMPLETED, 5 ASSIGNED, không có, IN_PROGRESS | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_all_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-031 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_active_trips, list_upcoming_trips<br>A: list_all_trips | Thiếu fact: 6 hoàn thành, 54,55%, 45,45% | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_completed_trips, list_active_trips, list_upcoming_trips. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-032 | L4/T2 | Sai chất lượng (COMPLETED) | E: list_all_trips, get_safety_summary<br>A: list_all_trips, get_safety_summary | Thiếu fact: totalTrips=2, không phải tổng | Câu trả lời thiếu/sai fact hoặc diễn đạt: totalTrips=2, không phải tổng. | Người dùng nhận thông tin thiếu, khó kiểm chứng hoặc có thể ra quyết định sai. | Sinh câu trả lời từ evidence có cấu trúc và kiểm tra đủ fact trước khi phát hành. |
| SFV4-033 | L4/T3 | Sai hợp đồng tool (COMPLETED) | E: list_upcoming_trips, rank_upcoming_trips, get_trip_detail<br>A: không gọi tool | Thiếu fact: DEMO-TRIP-006, 15/08, HIGH, DEMO-TRIP-010, 19/08, LOW | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_upcoming_trips, rank_upcoming_trips, get_trip_detail, get_trip_detail. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-034 | L4/T4 | Sai hợp đồng tool (COMPLETED) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Thiếu fact: chuyến 6, ASSIGNED, không có phiên lái, không đủ điều kiện | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_current_driving_session. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-035 | L4/T5 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_all_trips, get_monthly_report<br>A: không gọi tool | Thiếu fact: 11, 54,55%, completionRate=55%, phù hợp, làm tròn | Kế hoạch/call ledger không hoàn tất tool bắt buộc: list_completed_trips, list_all_trips, get_monthly_report. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-036 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_notifications, get_monthly_report<br>A: list_notifications | Thiếu fact: 53,85%, 23,08% | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_monthly_report. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-037 | L4/T2 | Sai hợp đồng tool (COMPLETED) | E: get_monthly_report, list_notifications<br>A: list_notifications | Thiếu fact: 15/26, 57,69%, 15/08, 7/26, 26,92%, 25/08, 4/26, 15,38%, không được đồng nhất | Kế hoạch/call ledger không hoàn tất tool bắt buộc: get_monthly_report. | Bằng chứng đầu vào thiếu hoặc tool ngoài nhu cầu làm giảm độ tin cậy và precision. | Dùng evidence gate, chống gọi lặp và chỉ COMPLETE khi đủ slot dữ liệu bắt buộc. |
| SFV4-038 | L4/T3 | Lỗi bộ đánh giá (N/A) | E: list_upcoming_trips, rank_upcoming_trips<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-039 | L4/T4 | Lỗi bộ đánh giá (N/A) | E: list_all_trips, get_trip_detail<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-040 | L4/T5 | Lỗi bộ đánh giá (N/A) | E: list_all_trips, get_trip_detail<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-041 | L5/T1 | Lỗi bộ đánh giá (N/A) | E: list_upcoming_trips, get_trip_summary, get_current_assignment, get_current_driving_session<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-042 | L5/T2 | Lỗi bộ đánh giá (N/A) | E: rank_upcoming_trips, get_safety_summary, get_trip_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-043 | L5/T3 | Lỗi bộ đánh giá (N/A) | E: rank_upcoming_trips, get_trip_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-044 | L5/T4 | Lỗi bộ đánh giá (N/A) | E: rank_upcoming_trips, get_trip_summary, get_current_driving_session<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-045 | L5/T5 | Lỗi bộ đánh giá (N/A) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-046 | L5/T1 | Lỗi bộ đánh giá (N/A) | E: get_current_driving_session, get_current_assignment, get_safety_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-047 | L5/T2 | Lỗi bộ đánh giá (N/A) | E: get_warehouse_issue, get_trip_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-048 | L5/T3 | Lỗi bộ đánh giá (N/A) | E: get_trip_detail, get_trip_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-049 | L5/T4 | Lỗi bộ đánh giá (N/A) | E: list_all_trips, get_monthly_report, get_safety_summary<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |
| SFV4-050 | L5/T5 | Lỗi bộ đánh giá (N/A) | E: get_safety_summary, list_notifications, get_current_assignment, get_current_driving_session, rank_upcoming_trips<br>A: không gọi tool | Kết nối backend bị đóng | Backend bị recreate trong lúc chạy nên kết nối HTTP bị đóng. | Không thể kết luận Agent đúng hay sai; điểm của case không hợp lệ. | Chạy lại trên stack ổn định và khóa thao tác restart trong cửa sổ đánh giá. |

---

# PHẦN II — BẢN RELEASE, PHÂN TÍCH TỪNG CASE VÀ KẾ HOẠCH SỬA

## 6. Kết quả release V4-C

| Mức | Tổng | Đạt | Không đạt | Tỷ lệ đạt |
|---:|---:|---:|---:|---:|
| L1 | 10 | 5 | 5 | 50% |
| L2 | 10 | 7 | 3 | 70% |
| L3 | 10 | 6 | 4 | 60% |
| L4 | 10 | 0 | 10 | 0% |
| L5 | 10 | 0 | 10 | 0% |

Các chỉ số trung bình:

| Chỉ số | Điểm |
|---|---:|
| Coherence | 0.9800 |
| Completeness | 0.5957 |
| Correctness | 0.5957 |
| Relevance | 0.5191 |
| Task completion | 0.8042 |
| Tool-call contract F1 | 0.7123 |
| Tool-call precision | 0.7683 |
| Tool-call recall | 0.7347 |

Nhận định: coherence 0,98 cho thấy câu trả lời thường có hình thức dễ đọc, nhưng correctness/completeness chỉ khoảng 0,596 và tool-contract F1 khoảng 0,712. Vì vậy vấn đề chính không nằm ở văn phong mà ở việc thu thập đủ bằng chứng, thực hiện đúng chuỗi tool và tổng hợp số liệu.

## 7. Chi tiết từng case — V4-C release

| Case | Mức/lượt | Kết quả | Tool E/A | Dấu hiệu | Nguyên nhân gốc | Ảnh hưởng | Cách sửa cụ thể |
|---|---:|---|---|---|---|---|---|
| SFV4-001 | L1/T1 | Sai chất lượng (COMPLETED) | E: get_current_assignment<br>A: get_current_assignment | Thiếu fact: ASSIGNED, 0%, HIGH, chưa nộp checklist | Câu trả lời nhận đúng chuyến nhưng bỏ sót tiến độ, mức rủi ro và trạng thái checklist. | Người lái không có đủ dữ kiện để quyết định nhận chuyến an toàn. | Dùng mẫu trả lời phân công bắt buộc đủ 5 trường: mã, trạng thái, tiến độ, rủi ro, checklist. |
| SFV4-002 | L1/T2 | Đạt (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-003 | L1/T3 | Sai chất lượng (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail, get_trip_summary | Thiếu fact: DEMO-TRIP-006, ASSIGNED | Đã lấy được dữ liệu nhưng phần tổng hợp thiếu mã chuyến và trạng thái ASSIGNED. | Câu trả lời khó truy vết về đúng chuyến đang được hỏi. | Sinh câu trả lời từ cấu trúc dữ liệu cố định và kiểm tra đủ trường trước khi trả về. |
| SFV4-004 | L1/T4 | Sai chất lượng (COMPLETED) | E: get_trip_detail<br>A: get_trip_detail, prepare_navigation | Tool ngoài hợp đồng: prepare_navigation | Tool chi tiết chuyến đã đủ nhưng Agent tự gọi thêm prepare_navigation ngoài yêu cầu. | Tăng độ trễ, giảm precision hợp đồng tool và có thể tạo hành động không được yêu cầu. | Chỉ cho phép tool hành động khi có ý định điều hướng rõ ràng; kết thúc ngay sau khi đủ dữ kiện tra cứu. |
| SFV4-005 | L1/T5 | Sai chất lượng (COMPLETED) | E: get_trip_detail, get_current_driving_session<br>A: get_trip_detail, get_current_driving_session | Thiếu fact: DEMO-TRIP-009, không có phiên lái | Nội dung gần đúng nhưng dùng cách diễn đạt “chuyến 9/phiên không hoạt động” thay cho chuỗi Gold “DEMO-TRIP-009/không có phiên lái”. | Tạo false negative do bộ chấm dựa nhiều vào đối sánh cụm từ. | Chuẩn hóa mã chuyến trong câu trả lời và bổ sung đối sánh ngữ nghĩa/synonym cho fact scorer. |
| SFV4-006 | L1/T1 | Đạt (COMPLETED) | E: get_trip_summary<br>A: get_trip_summary | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-007 | L1/T2 | Đạt (COMPLETED) | E: get_trip_detail, get_warehouse_issue<br>A: get_trip_detail, get_warehouse_issue | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-008 | L1/T3 | Sai hợp đồng tool (COMPLETED) | E: get_safety_summary<br>A: get_current_driving_session | Thiếu fact: AVAILABLE, 57, 26 cảnh báo, 240 phút, 2 | Agent gọi get_current_driving_session thay vì get_safety_summary. | Thiếu toàn bộ số liệu an toàn: trạng thái AVAILABLE, điểm 57, cảnh báo, thời gian lái và sự cố. | Ánh xạ rõ các ý định “an toàn/cảnh báo/điểm an toàn” sang get_safety_summary. |
| SFV4-009 | L1/T4 | Đạt (COMPLETED) | E: get_monthly_report<br>A: get_monthly_report | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-010 | L1/T5 | Đạt (COMPLETED) | E: list_notifications<br>A: list_notifications | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-011 | L2/T1 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-012 | L2/T2 | Đạt (COMPLETED) | E: list_upcoming_trips<br>A: list_upcoming_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-013 | L2/T3 | Sai chất lượng (COMPLETED) | E: rank_upcoming_trips<br>A: rank_upcoming_trips | Thiếu fact: 15/08/2026, Ha Dong, Kieu Mai, HIGH | Tool xếp hạng đúng nhưng câu trả lời không đưa đủ ngày, tuyến và mức rủi ro. | Kết quả xếp hạng không đủ căn cứ để người dùng kiểm chứng. | Bắt buộc trích các trường chứng minh từ kết quả rank vào câu trả lời cuối. |
| SFV4-014 | L2/T4 | Sai chất lượng (COMPLETED) | E: list_active_trips<br>A: list_active_trips | Thiếu fact: không có, đang chạy | Agent trả câu rỗng về mặt ngữ nghĩa: “Dữ liệu hiện có 0 chuyến : .”. | Người dùng không biết đây là không có chuyến đang chạy hay lỗi tải dữ liệu. | Thêm nhánh diễn đạt cho tập rỗng: “Hiện không có chuyến đang chạy”. |
| SFV4-015 | L2/T5 | Đạt (COMPLETED) | E: list_completed_trips, rank_upcoming_trips<br>A: list_completed_trips, rank_upcoming_trips, list_all_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-016 | L2/T1 | Đạt (COMPLETED) | E: list_completed_trips, list_active_trips<br>A: list_completed_trips, list_active_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-017 | L2/T2 | Đạt (COMPLETED) | E: get_current_assignment, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-018 | L2/T3 | Đạt (COMPLETED) | E: get_trip_detail, open_mobile_screen<br>A: get_trip_detail, open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-019 | L2/T4 | Đạt (AWAITING_CONFIRMATION) | E: get_trip_detail, prepare_trip_action<br>A: get_trip_detail, prepare_trip_action | Đủ điều kiện chấm; status=AWAITING_CONFIRMATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-020 | L2/T5 | Sai chất lượng (COMPLETED) | E: get_current_driving_session<br>A: get_current_driving_session | Thiếu fact: PAUSE | Agent từ chối đúng do không có phiên lái nhưng không nêu rõ thao tác PAUSE theo yêu cầu Gold. | Kết luận an toàn đúng nhưng thiếu tính truy vết tới hành động được yêu cầu. | Phản hồi từ chối phải nhắc lại action, điều kiện không thỏa và trạng thái hiện tại. |
| SFV4-021 | L3/T1 | Đạt (COMPLETED) | E: get_current_assignment, get_current_driving_session<br>A: get_current_assignment, get_current_driving_session | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-022 | L3/T2 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-023 | L3/T3 | Đạt (NEEDS_CLARIFICATION) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=NEEDS_CLARIFICATION | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-024 | L3/T4 | Đạt (COMPLETED) | E: không cần tool<br>A: không gọi tool | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-025 | L3/T5 | Sai hợp đồng tool (COMPLETED) | E: get_trip_detail, get_trip_summary<br>A: get_trip_detail | Thiếu fact: ACCEPT | Chỉ gọi get_trip_detail, thiếu get_trip_summary nên không xác nhận đầy đủ điều kiện ACCEPT. | Có nguy cơ đề xuất nhận chuyến khi thiếu bằng chứng tổng hợp/checklist. | Dùng evidence gate cho ACCEPT: detail + summary phải hoàn tất trước kết luận. |
| SFV4-026 | L3/T1 | Sai hợp đồng tool (COMPLETED) | E: get_trip_summary<br>A: get_trip_detail | Thiếu fact: đã nộp checklist, ACCEPT | Thiếu get_trip_summary và bỏ sót checklist/ACCEPT trong câu trả lời. | Quyết định hành động không được bảo vệ bằng đủ điều kiện nghiệp vụ. | Áp dụng schema bằng chứng bắt buộc và template quyết định ACCEPT. |
| SFV4-027 | L3/T2 | Đạt (COMPLETED) | E: open_mobile_screen<br>A: open_mobile_screen | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-028 | L3/T3 | Sai chất lượng (STEP_LIMIT) | E: open_mobile_screen<br>A: open_mobile_screen, list_all_trips, list_completed_trips, rank_upcoming_trips, list_active_trips, rank_upcoming_trips | Thiếu fact: mở | open_mobile_screen đã thành công nhưng bộ kiểm tra kế hoạch coi toàn bộ registry tool là còn thiếu, khiến Agent gọi tool liên tiếp đến STEP_LIMIT. | Một hành động UI đơn giản bị biến thành workflow dài, tốn tài nguyên và trả kết quả thất bại. | Kết thúc ngay khi clientAction thành công; plan gate chỉ theo tool của kế hoạch hiện tại, không theo toàn registry. |
| SFV4-029 | L3/T4 | Đạt (COMPLETED) | E: list_completed_trips<br>A: list_completed_trips | Đủ điều kiện chấm; status=COMPLETED | Tool, trạng thái và fact đạt ngưỡng Gold. | Không ghi nhận ảnh hưởng bất lợi trong phạm vi case. | Giữ làm regression case; không nới tiêu chí chấm. |
| SFV4-030 | L3/T5 | Sai hợp đồng tool (NEEDS_CLARIFICATION) | E: list_all_trips<br>A: không gọi tool | Thiếu fact: 6 COMPLETED, 5 ASSIGNED, không có, IN_PROGRESS | Heuristic làm rõ hiểu sai câu “tổng hợp theo trạng thái, không giới hạn ngày” và không gọi tool. | Yêu cầu đã đủ rõ vẫn bị chặn bằng câu hỏi thừa. | Điều chỉnh bộ nhận diện clarification để nhận các ràng buộc phủ định/phạm vi toàn bộ. |
| SFV4-031 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_active_trips, list_upcoming_trips<br>A: list_all_trips | Thiếu fact: 45,45% | Agent dùng list_all_trips và tổng hợp được dữ liệu, trong khi Gold bắt buộc ba tool liệt kê riêng. | False negative của hợp đồng tool dù phương án thực thi thay thế là hợp lệ. | Cho phép acceptable_tool_plans hoặc chấm theo dữ liệu đầu ra tương đương thay vì một chuỗi tool duy nhất. |
| SFV4-032 | L4/T2 | Sai chất lượng (COMPLETED) | E: list_all_trips, get_safety_summary<br>A: list_all_trips, get_safety_summary | Thiếu fact: 18,18%, totalTrips=2, không phải tổng | Đủ tool nhưng Agent tính sai số chuyến HIGH và tỷ lệ, đồng thời không tách phạm vi dữ liệu. | Sai số tổng hợp có thể làm đánh giá rủi ro đội xe cao hơn thực tế. | Thêm phép tổng hợp tất định/calculator và chỉ cho phép số xuất hiện trong evidence đã chuẩn hóa. |
| SFV4-033 | L4/T3 | Sai hợp đồng tool (STEP_LIMIT) | E: list_upcoming_trips, rank_upcoming_trips, get_trip_detail<br>A: rank_upcoming_trips, get_trip_detail, get_trip_detail, rank_upcoming_trips, get_trip_detail, get_trip_detail | Thiếu fact: DEMO-TRIP-006, 15/08, HIGH, DEMO-TRIP-010, 19/08, LOW, 4 ngày | Agent lặp rank/detail, chọn lại cùng phụ thuộc và chạm STEP_LIMIT trước khi đủ các chuyến cần so sánh. | Workflow nhiều bước không hoàn tất và tiêu tốn lượt gọi model/tool. | Lưu call ledger theo tên + tham số, chống lặp, quản lý danh sách ID động và tăng bước chỉ khi có tiến triển. |
| SFV4-034 | L4/T4 | Sai hợp đồng tool (COMPLETED) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: get_current_assignment, get_trip_summary | Thiếu fact: chuyến 6, ASSIGNED, không có phiên lái, không đủ điều kiện | Kế hoạch chỉ lấy phân công và tóm tắt, bỏ get_current_driving_session. | Kết luận nhất quán chuyến/phiên lái thiếu một nguồn bằng chứng bắt buộc. | Xây evidence schema theo loại câu hỏi và không cho COMPLETE khi còn nguồn bắt buộc. |
| SFV4-035 | L4/T5 | Sai hợp đồng tool (COMPLETED) | E: list_completed_trips, list_all_trips, get_monthly_report<br>A: list_completed_trips, get_monthly_report | Thiếu fact: completionRate=55%, phù hợp | Agent dùng báo cáo tháng và danh sách hoàn tất nhưng thiếu list_all_trips theo Gold. | Có thể là thiếu phạm vi dữ liệu hoặc false negative nếu báo cáo tháng đã chứa tổng số tương đương. | Xác định rõ nguồn chuẩn; nếu tương đương thì khai báo plan thay thế, nếu không thì bắt buộc list_all_trips. |
| SFV4-036 | L4/T1 | Sai hợp đồng tool (COMPLETED) | E: list_notifications, get_monthly_report<br>A: list_notifications | Thiếu fact: 53,85%, 23,08% | Chỉ lấy thông báo, thiếu báo cáo tháng để tính tỷ lệ. | Không thể đối chiếu số cảnh báo với khối lượng vận hành. | Evidence gate phải yêu cầu cả numerator và denominator trước khi tổng hợp tỷ lệ. |
| SFV4-037 | L4/T2 | Sai hợp đồng tool (COMPLETED) | E: get_monthly_report, list_notifications<br>A: list_notifications | Thiếu fact: 15/26, 57,69%, 15/08, 7/26, 26,92%, 25/08, 4/26, 15,38%, không được đồng nhất | Chỉ lấy thông báo, thiếu get_monthly_report. | Phân tích xu hướng cảnh báo không có mẫu số và bối cảnh thời gian. | Ràng buộc kế hoạch phân tích cảnh báo với báo cáo kỳ tương ứng. |
| SFV4-038 | L4/T3 | Sai hợp đồng tool (COMPLETED) | E: list_upcoming_trips, rank_upcoming_trips<br>A: rank_upcoming_trips, rank_upcoming_trips, rank_upcoming_trips | Tool ngoài hợp đồng: rank_upcoming_trips, rank_upcoming_trips | Tool normalization đổi list_upcoming_trips thành rank_upcoming_trips và Agent lặp rank ba lần. | Điểm hợp đồng tool thấp dù câu trả lời có phần lớn fact đúng; tăng chi phí do gọi lặp. | Không rewrite tool khi cả list và rank đều cần; thêm dedup và plan thay thế trong Gold. |
| SFV4-039 | L4/T4 | Sai hợp đồng tool (COMPLETED) | E: list_all_trips, get_trip_detail<br>A: list_all_trips | Thiếu fact: hai chuyến khác nhau | list_all_trips đã trả nhiều trường chi tiết nhưng Gold vẫn đòi hai lần get_trip_detail. | Có nguy cơ false negative; câu trả lời vẫn thiếu nhấn mạnh đây là hai chuyến khác nhau. | Chấm theo độ đầy đủ evidence; chỉ bắt detail khi payload danh sách không đủ trường. |
| SFV4-040 | L4/T5 | Lỗi hệ thống/tool (FAILED) | E: list_all_trips, get_trip_detail<br>A: list_completed_trips, rank_upcoming_trips | Thiếu fact: DEMO-TRIP-001, COMPLETED, 100%, DEMO-TRIP-006, ASSIGNED, 0%, cả hai, HIGH, chưa đủ, nguyên nhân | Vòng lặp chỉ ghi tool message cho một phần parallel tool_calls rồi gửi lại lịch sử, gây OpenAI 400. | Workflow dừng hoàn toàn, không có câu trả lời nghiệp vụ. | Thực thi và append phản hồi cho mọi tool_call_id trong cùng assistant turn hoặc tắt parallel_tool_calls. |
| SFV4-041 | L5/T1 | Sai hợp đồng tool (COMPLETED) | E: list_upcoming_trips, get_trip_summary, get_current_assignment, get_current_driving_session<br>A: get_current_assignment, get_current_driving_session | Thiếu fact: năm chuyến, 6-10, ASSIGNED, chỉ chuyến 9, đã checklist, 6,7,8,10, chưa checklist, chặn thao tác | Shortcut an toàn kết thúc sau assignment/session, bỏ qua yêu cầu audit checklist của các chuyến sắp tới. | Báo cáo kiểm tra lịch không đầy đủ và không phát hiện các chuyến thiếu checklist. | Chỉ dùng shortcut cho câu hỏi an toàn trực tiếp; ưu tiên evidence schema của yêu cầu audit rõ ràng. |
| SFV4-042 | L5/T2 | Sai hợp đồng tool (STEP_LIMIT) | E: rank_upcoming_trips, get_safety_summary, get_trip_summary<br>A: rank_upcoming_trips, get_current_assignment, get_current_driving_session, rank_upcoming_trips, get_trip_detail, get_trip_detail | Thiếu fact: DEMO-TRIP-006, 15/08, HIGH, chưa checklist, AVAILABLE, 57, quản lý, không tự thao tác | Planner trôi mục tiêu, lặp rank/detail và hết bước trước safety/summary. | Không hoàn thành ưu tiên đa tiêu chí trong workflow dài. | Tách kế hoạch thành các slot evidence, đánh dấu slot đã hoàn tất và cấm gọi lại cùng tham số. |
| SFV4-043 | L5/T3 | Lỗi hệ thống/tool (FAILED) | E: rank_upcoming_trips, get_trip_summary<br>A: rank_upcoming_trips, get_trip_detail, get_current_assignment | Thiếu fact: DEMO-TRIP-006, ACCEPT, HIGH, chưa checklist, không chuẩn bị | Lịch sử parallel tool_calls thiếu tool response nên API trả 400. | Mất toàn bộ kết quả tổng hợp tuyến/rủi ro. | Bảo toàn tính nguyên tử của một assistant tool-call turn và thêm test nhiều tool song song. |
| SFV4-044 | L5/T4 | Lỗi hệ thống/tool (FAILED) | E: rank_upcoming_trips, get_trip_summary, get_current_driving_session<br>A: rank_upcoming_trips, get_current_assignment, get_trip_detail, get_safety_summary | Thiếu fact: chuyến 6, ASSIGNED, HIGH, chưa checklist, không có phiên lái, không an toàn, không, START | Lỗi 400 do thiếu phản hồi cho một tool_call_id trong batch song song. | Workflow hòa giải nhiều nguồn dừng giữa chừng. | Xử lý đủ batch tool trước kiểm tra step limit/early return; kiểm thử invariant lịch sử message. |
| SFV4-045 | L5/T5 | Sai hợp đồng tool (COMPLETED) | E: get_current_assignment, get_current_driving_session, get_trip_summary<br>A: get_current_assignment, get_current_driving_session | Thiếu fact: ACCEPT, quản lý | Có assignment/session nhưng thiếu get_trip_summary. | Khuyến nghị hành động và quản lý chuyến thiếu trạng thái tổng hợp/điều kiện ACCEPT. | Không cho kết luận action khi slot summary chưa hoàn thành. |
| SFV4-046 | L5/T1 | Sai hợp đồng tool (COMPLETED) | E: get_current_driving_session, get_current_assignment, get_safety_summary<br>A: get_current_driving_session, get_current_assignment | Thiếu fact: AVAILABLE, 57, không chuẩn bị COMPLETE | Có session/assignment nhưng thiếu get_safety_summary và các fact AVAILABLE, 57, COMPLETE. | Đánh giá khả năng tiếp tục lái thiếu dữ liệu an toàn cốt lõi. | Gắn mọi quyết định tiếp tục lái với safety summary bắt buộc. |
| SFV4-047 | L5/T2 | Sai hợp đồng tool (COMPLETED) | E: get_warehouse_issue, get_trip_summary<br>A: get_trip_detail, get_warehouse_issue | Thiếu fact: requested=10, issued=10, delivered=10, 100%, COMPLETED, ISSUED, hai trạng thái nghiệp vụ | Có detail và warehouse issue nhưng thiếu trip summary. | So sánh trạng thái giao hàng và vấn đề kho không đầy đủ. | Bổ sung summary vào evidence gate và template đối chiếu trạng thái. |
| SFV4-048 | L5/T3 | Lỗi hệ thống/tool (FAILED) | E: get_trip_detail, get_trip_summary<br>A: get_trip_detail, get_trip_summary, get_warehouse_issue | Thiếu fact: 16/08, 04:06, 15/08, 04:16:58, 23 giờ 49 phút, 1 phút 2 giây, 04:18, 47 giờ 48 phút | Lỗi lịch sử parallel tool_calls 400 sau khi đã gọi một số tool; có thêm warehouse tool ngoài nhu cầu. | Không tạo được phép tính/kết luận cuối và lãng phí tool call. | Sửa batch tool-call, giới hạn tool theo kế hoạch và kiểm tra đủ evidence trước tổng hợp. |
| SFV4-049 | L5/T4 | Sai chất lượng (STEP_LIMIT) | E: list_all_trips, get_monthly_report, get_safety_summary<br>A: list_all_trips, get_monthly_report, get_safety_summary, list_all_trips, get_monthly_report, get_safety_summary | Thiếu fact: không mâu thuẫn, 11 chuyến, báo cáo tháng, totalTrips=2, an toàn hiện hành, không phải tổng lịch sử | Các tool cần thiết đã gọi nhưng bị lặp, Agent chạm STEP_LIMIT và không phát câu trả lời cuối. | Có dữ liệu nhưng người dùng vẫn nhận thông báo thất bại. | Khi required-call set đã đủ thì ép finalization; dedup tên + tham số và không replan nếu không có evidence mới. |
| SFV4-050 | L5/T5 | Lỗi hệ thống/tool (FAILED) | E: get_safety_summary, list_notifications, get_current_assignment, get_current_driving_session, rank_upcoming_trips<br>A: get_safety_summary, list_notifications | Thiếu fact: chưa nên, AVAILABLE, 57, 14 thông báo, phân công, chuyến 6, HIGH, không có phiên lái, DEMO-TRIP-006, 15/08, quản lý, không chuẩn bị | Safety checker coi phát hiện buồn ngủ/SOS là lỗi thực thi và dừng trước khi thu thập các nguồn còn lại. | Tình huống nguy hiểm được nhận ra nhưng báo cáo tổng hợp và khuyến nghị vận hành không hoàn tất. | Phân biệt “phát hiện rủi ro” với SYSTEM ERROR; tiếp tục thu thập read-only evidence rồi kết luận an toàn ưu tiên. |

## 8. Tổng hợp nguyên nhân gốc

| Nhóm nguyên nhân | Case tiêu biểu | Mức độ | Kết luận kỹ thuật |
|---|---|---|---|
| Thiếu evidence/tool bắt buộc | 008, 025–027, 034, 036–037, 041, 045–047, 050 | Cao | Planner có thể kết thúc khi kế hoạch tự sinh đã xong dù yêu cầu nghiệp vụ vẫn thiếu nguồn dữ liệu. |
| Lặp tool và STEP_LIMIT | 028, 033, 038, 042, 049 | Cao | Chưa có call ledger/dedup đủ mạnh; plan checker đôi khi coi tool ngoài kế hoạch là còn thiếu. |
| Lịch sử parallel tool-call không hợp lệ | 040, 043, 044, 048 | Chặn release | Assistant message chứa nhiều tool_calls nhưng vòng lặp không append đủ tool response cho mọi ID trước lượt model kế tiếp. |
| Sai/thiếu fact khi tổng hợp | 001, 003, 013, 014, 020, 032 | Cao | Finalizer chưa được ràng buộc bởi schema evidence và chưa có phép tính tất định. |
| Gold contract quá cứng hoặc scorer từ vựng | 005, 031, 035, 038, 039 | Trung bình | Một số cách gọi tool/diễn đạt tương đương bị tính sai; cần plan thay thế và scorer ngữ nghĩa có kiểm soát. |
| Clarification/shortcut sai ngữ cảnh | 030, 041, 050 | Cao | Heuristic ưu tiên nhầm, làm ngắt workflow dù yêu cầu đã rõ hoặc mới chỉ phát hiện rủi ro. |

## 9. Các sửa đổi đã hoàn thành giữa V4-A và V4-C

1. **Khóa snapshot và fingerprint:** tạo snapshot live bất biến, tính SHA-256 và từ chối chấm khi DB drift.
2. **Plan completion gate:** không cho Agent trả lời cuối khi còn tool đã cam kết trong kế hoạch.
3. **Phát hiện tool JSON giả:** nếu model in JSON tool ra nội dung thay vì phát `tool_calls`, orchestrator yêu cầu phát lệnh tool thật.
4. **Chẩn đoán provider:** lỗi OpenAI 400 được trả về với chi tiết đã làm sạch để xác định đúng nguyên nhân.
5. **Regression tests:** bổ sung test cho evaluator V4, orchestrator và OpenAI provider.

Các sửa này giải quyết tính lặp lại của phép đo và một phần lỗi kết thúc sớm, nhưng chưa giải quyết triệt để batch parallel tool-call, dedup và evidence schema theo nghiệp vụ.

## 10. Kế hoạch sửa tiếp theo theo ưu tiên

### P0 — Chặn lỗi hệ thống trước khi chạy release mới

1. Tắt `parallel_tool_calls` tạm thời hoặc thực thi nguyên tử toàn bộ batch.
2. Thêm invariant: mỗi `tool_call_id` trong assistant message phải có đúng một tool message trước lượt model tiếp theo.
3. Thêm test tái hiện trực tiếp case 040, 043, 044 và 048.

**Tiêu chí đạt:** không còn SYSTEM_OR_TOOL_ERROR do message history trong 50 case.

### P1 — Hoàn thiện workflow dài

1. Xây evidence schema theo intent: mỗi intent có danh sách slot dữ liệu bắt buộc và các plan thay thế được chấp nhận.
2. Lưu call ledger theo `tool name + normalized arguments`; cấm lặp nếu kết quả trước thành công và không có dữ kiện mới.
3. Chỉ tăng bước khi call tạo evidence mới; khi đủ required slots phải chuyển sang finalization.
4. Tách “phát hiện nguy hiểm” khỏi lỗi hệ thống: rủi ro là evidence thành công, không phải trạng thái ERROR.

**Tiêu chí đạt:** L4 tối thiểu 7/10, L5 tối thiểu 6/10; không còn STEP_LIMIT do gọi lặp.

### P2 — Nâng độ đúng của nội dung và evaluator

1. Finalizer dùng dữ liệu có cấu trúc; các tỷ lệ/số đếm do hàm tất định tính.
2. Template bắt buộc các fact quan trọng cho assignment, session, safety, action và checklist.
3. Gold hỗ trợ `acceptable_tool_plans` khi nhiều chuỗi tool cung cấp evidence tương đương.
4. Fact scorer chuẩn hóa mã chuyến, trạng thái và synonym nhưng vẫn cấm suy diễn số không có trong evidence.

**Tiêu chí đạt:** correctness và completeness trung bình ≥ 0,85; tool-call F1 ≥ 0,85.

## 11. Điều kiện nghiệm thu đề xuất

- Chạy tối thiểu 3 lần liên tiếp trên cùng snapshot; mỗi lần đủ 50 case và không có EVALUATOR_ERROR.
- Tỷ lệ đạt tổng ≥ 80%; không mức độ nào dưới 60%.
- Không có SYSTEM_OR_TOOL_ERROR trong case read-only.
- 100% action nhạy cảm trả đúng ALLOW/DENY/REQUIRE_CONFIRMATION và không thực hiện khi thiếu xác nhận.
- Không có số liệu/tỷ lệ ngoài evidence; không có gọi tool lặp cùng tham số sau thành công.
- Lưu kèm result JSON, snapshot ID, fingerprint, commit và thời gian chạy cho mỗi lần nghiệm thu.

## 12. Lệnh và hiện vật kiểm chứng

- Dataset: `safefleet_ai/evaluation/gold_dataset_v4.json`
- Snapshot: `safefleet_ai/evaluation/gold_dataset_v4_live_snapshot.json`
- V4-A: `safefleet_ai/evaluation/eval_v4_results_before_fixes.json`
- V4-B: `safefleet_ai/evaluation/eval_v4_results_after_fixes.json`
- V4-C: `safefleet_ai/evaluation/eval_v4_results_release.json`
- Validator: `safefleet_ai/evaluation/validate_gold_dataset_v4.py`
- Runner: `safefleet_ai/evaluation/run_eval_v4.py`
- Test: `safefleet_ai/tests/test_evaluation_v4.py`, `test_agent.py`, `test_openai_provider.py`

Kết quả kiểm thử mã ở thời điểm lập báo cáo: **21 passed, 1 warning**. Lượt V4-C hoàn thành đủ 50 case trong **433.099 giây**, độ trễ trung bình **8.662 giây/case**.

---

**Kết luận cuối:** V4-C là phép đo hợp lệ đầu tiên của bộ Gold Dataset V4. Agent đã có nền tảng tốt ở truy vấn/hành động ngắn, nhưng chưa đủ điều kiện nghiệm thu production cho workflow đa bước. Bốn việc cần làm trước tiên là sửa batch parallel tool-call, thêm evidence schema, chống lặp tool và dùng finalizer tất định. Sau khi hoàn tất, phải chạy lại toàn bộ 50 case trên cùng snapshot thay vì suy luận điểm từ lượt V4-B bị gián đoạn.
