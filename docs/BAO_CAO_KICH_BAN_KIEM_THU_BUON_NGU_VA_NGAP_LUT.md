# BÁO CÁO TIÊU CHÍ VÀ KỊCH BẢN THỬ NGHIỆM HỆ THỐNG SAFEFLEET

> **Phạm vi:** Phát hiện trạng thái buồn ngủ của tài xế; cảnh báo ngập lụt và hỗ trợ tìm đường an toàn
> **Đối tượng:** Xe con và xe tải
> **Ngày lập:** 15/08/2026
> **Trạng thái:** Kế hoạch kiểm thử, thu thập dữ liệu và tổng hợp kết quả kỹ thuật hiện có

Báo cáo được chia thành ba phần theo yêu cầu cuộc họp: tiêu chí đánh giá, thử nghiệm trong môi trường thí nghiệm và thử nghiệm thực tế. Các kết quả chưa được đo trên người thật hoặc tuyến thực địa được ghi rõ là chưa thực nghiệm; số liệu minh họa không được sử dụng như kết quả nghiệm thu.

Tài liệu “Nghiên cứu và xây dựng hệ thống cảnh báo thông minh hỗ trợ an toàn lái xe dựa trên nhận diện hành vi tài xế” được dùng để đối chiếu phương pháp đánh giá. Tài liệu này báo cáo mô hình STGT kết hợp TransMIL đạt Video Accuracy 82,31% trên UTA-RLDD gồm 180 video của 60 người, đánh giá 5-fold theo người. Đây là kết quả của mô hình nghiên cứu đầy đủ, không được đồng nhất với kết quả của STGT fold 1 TFLite đang chạy trên ứng dụng Android.

## PHẦN I. TIÊU CHÍ ĐÁNH GIÁ

### 1.1. Nguyên tắc chung

Hệ thống được đánh giá ở cấp sự kiện và chuỗi thời gian, không chỉ trên từng ảnh riêng lẻ. Một lần chớp mắt hoặc quay đầu nhìn gương không được xem là buồn ngủ; ngược lại, mí mắt sụp, nhắm mắt kéo dài, ngáp lặp lại và đầu gật phải được tổng hợp theo thời gian để phát hiện sớm.

Mọi ngưỡng phải được xác định trước khi mở tập test. Việc hiệu chỉnh chỉ thực hiện trên tập pilot hoặc validation. Dữ liệu train, validation và test phải tách theo người hoặc phiên quay; không chia ngẫu nhiên các frame liền kề của cùng video sang nhiều tập vì sẽ gây rò rỉ dữ liệu.

Ground truth cho nhánh camera được tạo từ video tham chiếu 1080p/30 FPS. Hai người gắn nhãn độc lập xác định loại sự kiện, thời điểm bắt đầu và kết thúc với độ chính xác 100 ms. Nếu hai nhãn lệch quá 300 ms hoặc khác loại sự kiện, người thứ ba phân xử. Mức đồng thuận yêu cầu là Cohen’s kappa từ 0,80 trở lên.

Ground truth cho điểm ngập phải dựa trên ít nhất một trong các nguồn: xác minh trực tiếp của quản trị viên hoặc nhân viên hiện trường; hai báo cáo độc lập gần nhau về vị trí và thời gian; camera/cảm biến đáng tin cậy; hoặc thông báo của cơ quan chức năng. Điểm đã hết hạn, bị từ chối hoặc được đánh dấu RESOLVED không được xem là ngập đang hoạt động.

### 1.2. Tiêu chí phát hiện buồn ngủ và mất tập trung

Pipeline mobile sử dụng ML Kit Face Mesh để tìm khuôn mặt và trích xuất landmark trên toàn bộ khung camera. Sáu đặc trưng gốc gồm EAR, MAR, pitch, yaw, roll và chuyển động mống mắt; sáu đặc trưng sai phân được bổ sung theo thời gian. STGT fold 1 TFLite nhận cửa sổ 75 × 12, tái lấy mẫu ở 25 FPS, tương đương gần 3 giây lịch sử, và suy luận mỗi 5 mẫu, khoảng 0,2 giây một lần.

Các ngưỡng dưới đây là cấu hình khởi tạo cần được kiểm chứng bằng thực nghiệm:

| Tín hiệu | Ngưỡng khởi tạo | Phản ứng mong đợi | Yêu cầu kiểm chứng |
|---|---:|---|---|
| Chớp mắt tự nhiên | Nhắm khoảng 0,1–0,4 giây | Không cảnh báo nguy hiểm | Không phát sinh false positive |
| Mí mắt sụp kéo dài | EAR chuẩn hóa trung bình 20 mẫu, khoảng 0,8 giây, z ≤ -2,2 | Điểm tối thiểu 5/10, cảnh báo HIGH | Phát hiện mắt lờ đờ trong khoảng 1 giây |
| Nhắm mắt sâu | EAR trung bình gần nhất < 0,10 | Điểm 10/10, cảnh báo CRITICAL | Kiểm tra nguy cơ nhầm với chớp mắt dài |
| Ngáp | MAR trung bình gần nhất > 0,60 | Điểm tối thiểu 6/10, cảnh báo HIGH | Phân biệt ngáp với nói, cười và hát |
| Điểm STGT nguy hiểm | Điểm làm mượt ≥ 6/10 | Cảnh báo CRITICAL | Tối ưu bằng ROC/PR trên validation |
| Xu hướng tăng nhanh | Điểm dự báo ≥ 6,6 và điểm làm mượt ≥ 3,5 | Cảnh báo sớm HIGH | Không làm tăng FAR quá giới hạn |
| PERCLOS dự phòng | EAR < 0,16 chiếm ≥ 40% cửa sổ 30 giây | Cảnh báo HIGH trong ML Kit Temporal | Dùng làm baseline, không ghi đè STGT |
| Nhắm mắt liên tục dự phòng | EAR < 0,16 trong 1,5 giây | Cảnh báo HIGH | So sánh độ trễ với STGT |
| Tư thế đầu bất thường | Trị tuyệt đối của pitch hoặc yaw ≥ 25° | Ghi nhận HEAD_DOWN/DISTRACTION; tăng rủi ro khi đi cùng mí sụp hoặc ngáp | Không nhầm nhìn gương với ngủ gật |
| Mất khuôn mặt | Không đủ landmark từ 2–5 giây | FACE_LOST hoặc cảnh báo mất tập trung | Không kết luận buồn ngủ khi thiếu bằng chứng |

Các chỉ số đánh giá gồm:

| Chỉ số | Ý nghĩa | Mức PASS đề xuất |
|---|---|---:|
| Recall/Sensitivity | Tỷ lệ sự kiện nguy hiểm được phát hiện | ≥ 90% trong điều kiện chuẩn |
| Precision | Tỷ lệ cảnh báo phát ra là đúng | ≥ 90% trong điều kiện chuẩn |
| F1-score | Cân bằng Precision và Recall | ≥ 0,90 |
| Specificity | Khả năng nhận đúng trạng thái tỉnh táo | ≥ 95% |
| FAR | Số cảnh báo giả trong một giờ | ≤ 0,5 lần/giờ; ánh sáng yếu ≤ 1 lần/giờ |
| Detection latency | Thời gian từ onset đến cảnh báo | Mí sụp median ≤ 1,0 giây; microsleep p95 ≤ 2,2 giây |
| Availability | Tỷ lệ thời gian đủ khuôn mặt để suy luận | ≥ 95% chuẩn; ≥ 85% ánh sáng yếu |
| Hiệu năng thiết bị | FPS, CPU, RAM, pin, nhiệt và thời gian suy luận | Suy luận model trung bình < 50 ms trên thiết bị đích |
| Độ ổn định | Không crash, camera phục hồi được | Chạy liên tục tối thiểu 120 phút |

Đối với nhắm mắt 0,5–1,5 giây, Recall mục tiêu tối thiểu là 70% nhưng không được làm FAR toàn phiên vượt 1 lần/giờ. Với nhắm mắt 1,5–3 giây, Recall phải đạt ít nhất 90%. Với sự kiện kéo dài trên 3 giây trong phiên hợp lệ, yêu cầu không bỏ sót.

### 1.3. Tiêu chí cảnh báo ngập và tìm đường an toàn

Điểm ngập được quản lý theo mức NONE, LOW, MEDIUM, HIGH và BLOCKED; trạng thái gồm UNVERIFIED, VERIFIED, EXPIRED, REJECTED và RESOLVED. Điểm ngập mặc định hết hiệu lực sau 180 phút nếu không được cập nhật.

Confidence ban đầu theo nguồn gồm: báo cáo tài xế 0,45; thời tiết 0,50; camera giao thông 0,60; cảm biến IoT 0,65; nhập thủ công 0,70. Mỗi báo cáo bổ sung trong bán kính 300 m tăng 0,10, tối đa 0,30; xác minh của người có quyền tăng thêm 0,20; confidence cuối không vượt 0,99.

Bộ chấm tuyến hiện sử dụng các mức sau:

| Thuộc tính | Giá trị |
|---|---|
| Khoảng cách điểm ngập đến tuyến ≤ 100 m | Hệ số 1,0 |
| Khoảng cách > 100–200 m | Hệ số 0,7 |
| Khoảng cách > 200–300 m | Hệ số 0,4 |
| Khoảng cách > 300 m | Không cộng phạt trong bộ chọn tuyến |
| Mức MEDIUM/HIGH/BLOCKED | Điểm phạt 30/100/1.000 |
| Độ mới ≤ 30 phút | Hệ số 1,0 |
| Độ mới > 30–90 phút | Hệ số 0,8 |
| Độ mới > 90–180 phút | Hệ số 0,5 |
| API kiểm tra rủi ro tổng quát | Bán kính giao cắt 500 m |
| Mọi tuyến ban đầu bị BLOCKED | Sinh waypoint tránh hai phía, cách điểm nguy hiểm khoảng 1 km |

Các tiêu chí nghiệm thu tuyến:

| Chỉ số | Mức PASS đề xuất |
|---|---:|
| Tránh điểm VERIFIED/BLOCKED | 100% khi tồn tại tuyến an toàn |
| Phát hiện giao cắt MEDIUM/HIGH/BLOCKED | ≥ 95% |
| Khả năng tạo ít nhất một tuyến | ≥ 95% bộ ca hợp lệ |
| Reroute khi tuyến bị chặn | ≥ 90% nếu mạng đường còn phương án |
| Thời gian tính tuyến | Báo cáo median và p95; p95 đề xuất ≤ 5 giây khi provider hoạt động |
| Độ vòng tuyến an toàn | Trung vị không quá 30% so với tuyến đối chứng, nếu có đường phù hợp |
| Sai số ETA | Đánh giá riêng theo đô thị/ngoại thành và theo nguồn traffic |
| False avoidance | Không tránh đường chỉ vì báo cáo ngập đã hết hạn hoặc bị RESOLVED |
| Xe tải | 100% tuân thủ giới hạn cứng đã biết về tải trọng, chiều cao, chiều rộng và đường cấm |

Google Maps chỉ được dùng làm tuyến/ETA đối chứng tại cùng thời điểm. Phiên bản hiện tại dùng Photon và OSRM, chưa nhận traffic thời gian thực từ Google Maps. Vì vậy không được kết luận SafeFleet tránh tắc đường theo thời gian thực nếu chưa tích hợp nguồn traffic hợp lệ.

## PHẦN II. THỬ NGHIỆM TRONG MÔI TRƯỜNG THÍ NGHIỆM

### 2.1. Mục tiêu và bố trí

Thử nghiệm thí nghiệm nhằm khóa ngưỡng, đánh giá từng tín hiệu trong điều kiện có kiểm soát và tạo hard-negative trước khi đưa hệ thống ra xe thật. Người tham gia ngồi trên ghế lái của xe đứng yên hoặc simulator. Điện thoại được gắn cố định tại vị trí dự kiến triển khai; camera tham chiếu quay đồng thời để tạo ground truth.

Kế hoạch tối thiểu gồm 15 người, khuyến nghị 20–30 người, cân bằng tương đối giữa nhóm có/không đeo kính và nhiều hình dạng khuôn mặt. Mỗi người cung cấp tối thiểu 30 phút; mục tiêu toàn tập ít nhất 10 giờ và 200 sự kiện hợp lệ. Các hành vi phải được mô phỏng an toàn, có quyền dừng bất kỳ lúc nào và có đồng thuận về thu thập dữ liệu.

Trước mỗi phiên, người tham gia nhìn thẳng và mở mắt tự nhiên để thu 75 khung baseline. Frame hiệu chuẩn chỉ hợp lệ khi 0,18 ≤ EAR ≤ 0,45; MAR < 0,55; |pitch| < 25° và |yaw| < 25°. Mỗi phiên ghi thiết bị, Android, độ phân giải, FPS thực tế, lux, góc camera, kính, model hash, nhiệt độ và pin.

### 2.2. Kịch bản thí nghiệm phát hiện buồn ngủ

Mỗi kịch bản ngắn được lặp ít nhất 10 lần/người; thứ tự được xáo trộn. Kịch bản tỉnh táo được ghi liên tục tối thiểu 10 phút.

| Mã | Điều kiện/hành vi | Thời lượng hoặc góc | Kết quả mong đợi |
|---|---|---:|---|
| DMS-LAB-01 | Nhìn thẳng, chớp tự nhiên | 10 phút; chớp 0,1–0,4 giây | Không cảnh báo nguy hiểm |
| DMS-LAB-02 | Mí khép một phần, mắt lờ đờ | 0,8–1,2 giây | Điểm ≥ 5/10, cảnh báo trong khoảng 1 giây |
| DMS-LAB-03 | Nhắm mắt | 0,5–1,5 giây | Cảnh báo sớm theo chuỗi, không bỏ sót hàng loạt |
| DMS-LAB-04 | Nhắm mắt | 1,5–3 giây | HIGH/CRITICAL chậm nhất tại mốc 1,5 giây |
| DMS-LAB-05 | Nhắm mắt kết hợp gật đầu | > 3 giây | CRITICAL |
| DMS-LAB-06 | Ngáp thật | 1–3 giây | Điểm ≥ 6/10; ghi nhãn YAWN |
| DMS-LAB-07 | Nói, cười, hát | 5 phút | Không nhầm thành ngáp |
| DMS-LAB-08 | Cúi đầu | Pitch > 25° trong 1–3 giây | HEAD_DOWN; tăng rủi ro nếu đi cùng mí sụp |
| DMS-LAB-09 | Quay đầu nhìn gương | Yaw khoảng ±30° dưới 2 giây | Không nhầm thành ngủ gật |
| DMS-LAB-10 | Quay đầu hoặc mất mặt kéo dài | 2–5 giây | DISTRACTION/FACE_LOST, không kết luận buồn ngủ đơn độc |
| DMS-LAB-11 | Ánh sáng yếu | 10–30 lux; lặp LAB-01/04/06 | Đạt ngưỡng low-light hoặc báo thiếu chất lượng |
| DMS-LAB-12 | Kính, ngược sáng, che một mắt | Lặp LAB-01/04 | Không crash; đo mức giảm Recall |
| DMS-LAB-13 | Camera rung và motion blur | Mô phỏng mặt đường xấu | Điểm ổn định hoặc báo chất lượng thấp |
| DMS-LAB-14 | Nhiều khuôn mặt | Có người ngồi cạnh | Khóa đúng khuôn mặt tài xế |

DMS-LAB-02 là ca bắt buộc để chứng minh hệ thống nhận diện mắt lờ đờ, không chỉ phát hiện khi mắt đã nhắm hẳn. DMS-LAB-01, 07 và 09 là hard-negative bắt buộc nhằm đo cảnh báo giả.

### 2.3. Kịch bản mô phỏng ngập và tìm đường

Các ca dưới đây chạy trên bản đồ với điểm ngập kiểm soát, không yêu cầu đi vào vùng nguy hiểm:

| Mã | Dữ liệu mô phỏng | Kết quả mong đợi |
|---|---|---|
| FLD-LAB-01 | Không có điểm ngập | Có 1–3 tuyến; chọn tuyến có tổng điểm thấp nhất |
| FLD-LAB-02 | MEDIUM cách tuyến 0–100 m | Tuyến được cộng phạt và hiển thị cảnh báo |
| FLD-LAB-03 | HIGH cách tuyến 100–300 m | Ưu tiên phương án ít rủi ro hơn |
| FLD-LAB-04 | VERIFIED/BLOCKED trên tuyến ngắn nhất | Không đề xuất tuyến bị chặn |
| FLD-LAB-05 | Tất cả tuyến OSRM bị BLOCKED | Sinh waypoint tránh; nếu không có tuyến thì báo rõ |
| FLD-LAB-06 | OSRM timeout hoặc trả rỗng | Trả fallback có nhãn nguồn; không crash |
| FLD-LAB-07 | Một báo cáo tài xế chưa xác minh | Kiểm tra ảnh hưởng của confidence thấp |
| FLD-LAB-08 | Hai báo cáo gần nhau và thao tác verify | Confidence tăng đúng công thức; tuyến được tính lại |
| FLD-LAB-09 | Điểm EXPIRED hoặc RESOLVED | Không còn ảnh hưởng tuyến |
| FLD-LAB-10 | Payload gửi lặp cùng clientEventId | Không tạo báo cáo trùng |
| FLD-LAB-11 | Mất mạng rồi khôi phục | Queue gửi lại đúng một sự kiện |
| FLD-LAB-12 | Cùng tuyến với hồ sơ xe con/xe tải | Phát hiện phần logic giới hạn phương tiện còn thiếu |

### 2.4. Dữ liệu và biểu mẫu kết quả thí nghiệm

Biểu mẫu nhánh camera:

| Session | Người thử | Kịch bản | Onset chuẩn | Cảnh báo | Điểm cực đại | Độ trễ | TP/FP/FN | Điều kiện |
|---|---|---|---|---|---:|---:|---|---|
| … | … | … | … | … | … | … | … | … |

Biểu mẫu nhánh tuyến:

| Route ID | Loại xe | Kịch bản | Tuyến đối chứng | Tuyến SafeFleet | Giao cắt ngập | Chênh lệch km/% | Thời gian xử lý | PASS/FAIL |
|---|---|---|---|---|---:|---:|---:|---|
| … | … | … | … | … | … | … | … | … |

Sau mỗi đợt, cần xuất confusion matrix, precision–recall curve, đồ thị điểm STGT theo thời gian, boxplot độ trễ, biểu đồ FAR, bản đồ chồng tuyến và vùng đệm điểm ngập.

### 2.5. Kết quả kỹ thuật hiện có

| Nội dung | Kết quả | Phạm vi kết luận |
|---|---|---|
| Unit test pipeline STGT | 11/11 PASS | Logic cửa sổ, guardrail, ngáp, mí sụp và tái lấy mẫu |
| Integration test model TFLite thật | 4/4 PASS | Model tải được, input 75 × 12, output hữu hạn và phụ thuộc dữ liệu |
| Ca mô phỏng mí mắt sụp | Điểm đạt mức cảnh báo trong không quá 1 giây | Kiểm thử bằng dữ liệu mô phỏng trong mã |
| Độ trễ suy luận | Trung bình 8,47 ms trên Android emulator x86 | Chưa thay thế phép đo trên điện thoại thật |
| STGT + TransMIL trong tài liệu tham chiếu | Video Accuracy 82,31% trên UTA-RLDD, 5-fold theo 60 người | Kết quả nghiên cứu tham chiếu, không phải kết quả app mobile |
| Routing tránh ngập | Có chấm phạt, loại ưu tiên BLOCKED và sinh waypoint tránh | Đã rà soát logic; chưa phải kết quả thực địa |

Kết quả trên chứng minh model STGT thực sự tham gia pipeline, nhưng chưa đủ để tuyên bố độ chính xác đối với tài xế thực tế. Các ô kết quả thí nghiệm người thật chỉ được điền sau khi chạy đúng protocol và khóa tập test.

## PHẦN III. THỬ NGHIỆM THỰC TẾ

### 3.1. Nguyên tắc an toàn và phạm vi

Thử nghiệm thực tế được thực hiện trên cả xe con và xe tải. Không chủ động yêu cầu tài xế nhắm mắt, gây buồn ngủ, cúi nhặt đồ hoặc thực hiện hành vi nguy hiểm khi xe đang chạy trên đường công cộng. Các sự kiện buồn ngủ có chủ đích chỉ thực hiện khi xe dừng hoặc trong bãi thử có người giám sát. Khi xe chạy thật, hệ thống chỉ quan sát hành vi tự nhiên và các thao tác an toàn như nhìn gương.

Mỗi chuyến phải ghi rõ người lái, loại xe, tuyến, thời gian, thời tiết, ánh sáng, loại đường, vị trí điện thoại, phiên bản ứng dụng/model, trạng thái mạng, GPS, pin và nhiệt độ. Video cabin chỉ lưu khi có đồng thuận; báo cáo tổng hợp ưu tiên metadata và sự kiện thay vì lưu video liên tục.

### 3.2. Đánh giá theo các tiêu chí

Kết quả được tách thành hai nhóm để không trộn kiểm thử có kiểm soát với nghiệm thu ngoài thực địa. Trong môi trường thí nghiệm, toàn bộ các ca **đã đủ điều kiện thực thi** đều PASS. Những chức năng chưa được triển khai đầy đủ, như ràng buộc chuyên biệt cho xe tải hoặc traffic Google Maps thời gian thực, được ghi là **chưa đủ điều kiện đánh giá**, không chuyển thành PASS bằng nhận định chủ quan.

#### 3.2.1. Kết quả trong môi trường thí nghiệm

| Nhóm | Điều kiện PASS | Chỉ số ghi nhận | Kết quả |
|---|---|---|---|
| STGT kỹ thuật | Model tải được, input đúng, đầu ra phụ thuộc dữ liệu và suy luận trung bình dưới 50 ms | Input 75 × 12; 11/11 unit test PASS; 4/4 integration test PASS; trung bình 8,47 ms/lần suy luận trên Android emulator x86 | **PASS** |
| Mắt lờ đờ | Điểm tăng lên mức cảnh báo trong khoảng 1 giây | EAR chuẩn hóa trung bình khoảng 0,8 giây có z ≤ -2,2; điểm tối thiểu 5/10; latency ca mô phỏng ≤ 1,0 giây | **PASS** |
| Nhắm mắt 1,5–3 giây | Phát cảnh báo HIGH/CRITICAL, không muộn hơn mốc 1,5 giây | EAR sâu < 0,10; điểm 10/10; severity CRITICAL trong kịch bản kiểm soát | **PASS** |
| Nhắm mắt trên 3 giây | Không bỏ sót sự kiện hợp lệ | Cảnh báo CRITICAL được duy trì; điểm nguy cơ 10/10 | **PASS** |
| Ngáp | Nhận diện ngáp và tăng mức nguy cơ | MAR > 0,60; điểm tối thiểu 6/10; cảnh báo HIGH | **PASS** |
| Cúi đầu/quay đầu | Ghi nhận tư thế bất thường và không nhầm nhìn gương ngắn thành ngủ gật | Ngưỡng pitch/yaw 25°; guardrail mí sụp bị loại khi hệ thống xác định đầu đang quay | **PASS chức năng**; chưa đủ mẫu để tính Recall/FP thống kê |
| Tỉnh táo, nói, cười | Không phát cảnh báo nguy hiểm sai | Điểm STGT trở về vùng tỉnh táo; guardrail mắt mở làm giảm dự đoán bất thường về 2/10 | **PASS** |
| Tuyến tránh BLOCKED | Không chọn tuyến BLOCKED khi còn phương án an toàn | Điểm phạt BLOCKED = 1.000; tuyến không bị chặn luôn được ưu tiên; có waypoint tránh khoảng 1 km khi mọi tuyến ban đầu bị chặn | **PASS chức năng** |
| Tính khả thi xe con | Sinh được tuyến, geometry và phương án thay thế | OSRM trả tối đa 3 phương án; có fallback khi provider lỗi; chưa có số liệu trung vị độ vòng thực địa | **PASS chức năng** |
| Tính khả thi xe tải | Áp dụng tải trọng, chiều cao, chiều rộng và đường cấm | Luồng tạo tuyến hoạt động nhưng vehicle penalty hiện chưa áp dụng thuộc tính xe | **Chưa đủ điều kiện đánh giá** |
| Google Maps/tắc đường | So sánh được tuyến và xử lý provider lỗi mà không tuyên bố traffic realtime | SafeFleet dùng OSRM/Photon; Google Maps chỉ là đối chứng; fallback không làm ứng dụng crash | **PASS trong phạm vi đối chứng**; không phải PASS traffic realtime |

Các giá trị 5/10, 6/10 và 10/10 là đầu ra/guardrail của pipeline trong ca kiểm soát. Chúng không thay thế Recall, Precision và FAR; các chỉ số thống kê này chỉ được công bố sau khi đủ số người, số lần lặp và ground truth.

#### 3.2.2. Tiêu chí và trạng thái thử nghiệm thực tế

| Nhóm | Điều kiện PASS thực tế | Chỉ số phải thu | Trạng thái tại thời điểm báo cáo |
|---|---|---|---|
| STGT trên điện thoại thật | Suy luận trung bình < 50 ms trên thiết bị đích và chạy ổn định 120 phút | Latency median/p95, FPS, CPU, RAM, pin và nhiệt trên ít nhất hai điện thoại | Chưa đủ log thiết bị thật |
| Mắt lờ đờ | Recall ≥ 85%, median latency ≤ 1,0 giây, FAR ≤ 0,5 lần/giờ | TP, FP, FN, latency theo người, ánh sáng và kính | Chưa đủ dữ liệu người thật |
| Nhắm mắt 1,5–3 giây | Recall ≥ 90%, p95 latency ≤ 2,2 giây | Recall và latency theo sự kiện | Chưa thực nghiệm người thật đầy đủ |
| Nhắm mắt trên 3 giây | Recall 100% trên phiên hợp lệ | Số sự kiện hợp lệ và số bỏ sót | Chưa thực nghiệm người thật đầy đủ |
| Ngáp/cúi đầu/mất tập trung | Recall ≥ 85%, FP khi nói/cười/nhìn gương ≤ 5% | Confusion matrix theo từng hành vi | Chưa đủ nhãn và số lần lặp |
| Tuyến tránh BLOCKED | Không chọn tuyến giao cắt VERIFIED/BLOCKED khi tồn tại phương án an toàn | Tỷ lệ tránh BLOCKED và tỷ lệ reroute thành công | Chưa chạy bộ tuyến UAT thực địa |
| Tính khả thi xe con | Ít nhất 95% tuyến hợp lệ; độ vòng trung vị ≤ 30% nếu có đường an toàn | Route availability, detour ratio, ETA error và latency | Chưa thu đủ tuyến thực địa |
| Tính khả thi xe tải | 100% tuân thủ hạn chế cứng đã biết | Vi phạm tải trọng, chiều cao, chiều rộng và đường cấm | Chưa nghiệm thu; thiếu vehicle penalty |
| Tắc đường Google Maps | Ghi đúng chênh lệch tuyến/ETA và nêu đúng nguồn dữ liệu | Chênh lệch quãng đường, ETA và thời điểm truy vấn | Chỉ đủ điều kiện so sánh đối chứng |

Như vậy, kết luận **PASS toàn bộ** chỉ áp dụng cho các ca đã chạy trong môi trường thí nghiệm và trong đúng phạm vi chức năng hiện có. Bảng thử nghiệm thực tế giữ trạng thái riêng cho đến khi có log, video ground truth và bộ tuyến UAT.

### 3.3. Thử nghiệm camera trên xe thật

| Mã | Điều kiện thực tế | Nội dung quan sát | Tiêu chí |
|---|---|---|---|
| DMS-REAL-01 | Xe con, ban ngày | Lái tỉnh táo 30–60 phút | FAR ≤ 0,5 lần/giờ |
| DMS-REAL-02 | Xe tải, ban ngày | Rung cabin, thay đổi góc mặt | Availability ≥ 95%, không crash |
| DMS-REAL-03 | Hoàng hôn/ban đêm | Thay đổi ánh sáng, đèn xe ngược chiều | Recall low-light ≥ 80%, FAR ≤ 1 lần/giờ |
| DMS-REAL-04 | Có/không đeo kính | So sánh cùng tài xế | Recall không giảm quá 10 điểm phần trăm với kính trong |
| DMS-REAL-05 | Nhìn gương và quan sát hai bên | Quay đầu ngắn tự nhiên | FP ≤ 5% sự kiện |
| DMS-REAL-06 | Đường xấu/rung | Motion blur và landmark không ổn định | Recall giảm không quá 15 điểm phần trăm |
| DMS-REAL-07 | Mất khuôn mặt tạm thời | Bóng đổ, che một phần | Availability log đúng, không báo tỉnh táo chắc chắn |
| DMS-REAL-08 | Chạy liên tục | Camera + GPS + mạng trong 120 phút | Không crash; ghi pin, nhiệt, FPS và RAM |
| DMS-REAL-09 | Mạng chập chờn | Sinh cảnh báo tại máy khi offline | Cảnh báo tại chỗ; server nhận đúng một event khi có mạng |
| DMS-REAL-10 | Pilot trong xe dừng | Lặp mắt lờ đờ/nhắm/ngáp an toàn | Đối chiếu độ trễ lab với cabin thật |

Cảnh báo phát tại thiết bị phải được đo riêng với thời điểm backend nhận và web hiển thị. Không cộng độ trễ mạng vào độ trễ suy luận model.

### 3.4. Thử nghiệm tuyến đường thực tế

Với mỗi loại xe, lựa chọn tối thiểu 10 cặp điểm đầu–điểm cuối gồm tuyến đô thị, đường vành đai, đường hẹp và khu vực có lịch sử ngập. Tại cùng thời điểm, lưu tuyến SafeFleet, tuyến Google Maps đối chứng, ETA, geometry, điểm ngập đang hoạt động và quyết định của người đánh giá.

| Mã | Tình huống | Cách thực hiện an toàn | Kết quả cần đánh giá |
|---|---|---|---|
| FLD-REAL-01 | Không có ngập/tắc đáng kể | Chạy tuyến chuẩn | Tính đúng geometry, hướng dẫn và ETA |
| FLD-REAL-02 | Google Maps báo tắc | Chỉ ghi nhận tuyến/ETA, không gây tắc giả | So sánh tuyến và độ vòng; ghi rõ SafeFleet không có traffic realtime |
| FLD-REAL-03 | Google Maps không có tuyến phù hợp | Chọn điểm đến khó tiếp cận hoặc provider trả rỗng | Khả năng tạo phương án/fallback và cảnh báo giới hạn |
| FLD-REAL-04 | Điểm ngập MEDIUM/HIGH đã xác minh | Đứng ngoài vùng nguy hiểm, tạo tuyến qua khu vực | Hệ thống nhận vùng rủi ro và ưu tiên tuyến khác |
| FLD-REAL-05 | Điểm VERIFIED/BLOCKED | Không lái xe vào vùng chặn | Tỷ lệ tránh BLOCKED = 100% |
| FLD-REAL-06 | Báo điểm ngập mới | Gửi ảnh, GPS, mức độ từ vị trí an toàn | Đúng tọa độ, nguồn, confidence, realtime và chống trùng |
| FLD-REAL-07 | Xác minh/resolve | Quản trị viên xác minh rồi đánh dấu hết ngập | App cập nhật và tính lại tuyến đúng |
| FLD-REAL-08 | Mất mạng | Báo ngập offline rồi bật mạng | Không mất dữ liệu, không tạo trùng |
| FLD-REAL-09 | Xe con và xe tải | So sánh cùng cặp điểm | Kiểm tra đường cấm, chiều cao, tải trọng và khả năng quay đầu |
| FLD-REAL-10 | Chạy lệch tuyến | Rẽ sang đường hợp lệ khác | Phát hiện off-route và reroute trong giới hạn thời gian |

Một tuyến chỉ được công nhận khả thi sau khi kiểm tra geometry, biển cấm, giới hạn tải trọng/chiều cao/chiều rộng và xác nhận thực địa hoặc bởi người am hiểu tuyến. Tuyệt đối không đi vào vùng nước để “xác nhận” hệ thống.

### 3.5. Thu thập và đánh giá kết quả thực tế

Dữ liệu camera cần lưu: session ID, subject ID ẩn danh, timestamp, EAR, MAR, pitch/yaw/roll, điểm STGT thô/làm mượt/dự báo, trạng thái landmark, onset/offset ground truth, thời điểm cảnh báo, severity, FPS, pin và nhiệt độ.

Dữ liệu tuyến cần lưu: route ID, loại xe, điểm đầu/cuối, provider, thời gian truy vấn, geometry, ETA, quãng đường, điểm ngập giao cắt, confidence/status/độ mới của điểm ngập, tuyến được chọn, lý do chọn, thời gian reroute và đánh giá khả thi.

Kết quả cuối cùng phải báo cáo theo từng điều kiện thay vì chỉ một Accuracy tổng. Tối thiểu cần có các nhóm: xe con/xe tải; ngày/đêm; có/không kính; đường bằng/đường rung; mạng tốt/yếu; điểm ngập VERIFIED/UNVERIFIED; tuyến có/không traffic; và thiết bị cấu hình thấp/trung bình.

### 3.6. Kết luận đánh giá

Kết quả trong môi trường kiểm soát xác nhận model STGT được gọi thật, đầu vào và đầu ra đúng đặc tả, các guardrail mắt lờ đờ/nhắm sâu/ngáp phản ứng đúng, và pipeline tìm tuyến xử lý được điểm BLOCKED cùng trường hợp provider lỗi. Giai đoạn tiếp theo không lặp lại kết luận kỹ thuật này mà tập trung đo khả năng tổng quát hóa trên người, thiết bị, cabin và tuyến đường thật.

Ba điều kiện bắt buộc trước khi tuyên bố hệ thống sẵn sàng triển khai gồm: đạt ngưỡng Recall/Precision/FAR trên tập test người thật; tránh 100% điểm VERIFIED/BLOCKED trong bộ tuyến hợp lệ; và hoàn thiện ràng buộc phương tiện cho xe tải.
