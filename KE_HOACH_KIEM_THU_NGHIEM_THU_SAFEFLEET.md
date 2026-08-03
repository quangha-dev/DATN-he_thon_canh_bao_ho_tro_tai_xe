# KẾ HOẠCH KIỂM THỬ VÀ NGHIỆM THU HỆ THỐNG SAFEFLEET

> **Phạm vi:** Web quản lý, ứng dụng tài xế Android và hệ thống phát hiện buồn ngủ theo chuỗi thời gian
> **Phiên bản tài liệu:** 1.0 — 03/08/2026
> **Đối tượng sử dụng:** Khách hàng, đội vận hành, QA, đội phát triển và hội đồng nghiệm thu
> **Môi trường chuẩn:** 01 tài xế `001`, 01 xe `001`, backend và web dùng cùng cơ sở dữ liệu

---

## 1. Mục tiêu nghiệm thu

Kế hoạch này chứng minh bốn nhóm năng lực:

1. Web quản lý vận hành đúng các quy trình điều phối, theo dõi GPS, cảnh báo, chứng từ,
   bảo trì và báo cáo.
2. App Android nhận đúng chuyến của tài xế, gửi GPS thật, hoạt động foreground service,
   hiển thị điều hướng, camera cabin và cảnh báo an toàn.
3. Hệ thống phát hiện buồn ngủ được đánh giá theo **sự kiện và chuỗi thời gian**, không
   chỉ chấm một ảnh riêng lẻ.
4. So sánh công bằng giữa người quan sát và máy về độ chính xác, độ trễ, khả năng hoạt
   động liên tục và độ ổn định trong điều kiện khó.

## 2. Trạng thái kỹ thuật cần công bố trước khi thử nghiệm

| Thành phần | Trạng thái hiện tại | Quyết định nghiệm thu |
|---|---|---|
| ST-GT fold 1 | Đã tích hợp TFLite trên Android; đầu vào 75 khung × 12 đặc trưng | Được phép kiểm thử thực địa |
| Luật ML Kit Temporal | Đã tích hợp; dùng EAR, PERCLOS, tư thế đầu, ngáp và thời lượng | Được phép làm baseline/fallback |
| TranMIL/TransMIL | **Chưa tìm thấy checkpoint, runtime hoặc mã suy luận trong repository** | `K-PASS/BLOCKED` cho đến khi bên cung cấp bàn giao model và đặc tả đầu vào |
| Camera nền Android | Foreground service + thông báo thường trực | Kiểm thử trên máy thật |
| Web/backend/mobile | Đã liên thông bằng JWT và MySQL | Kiểm thử end-to-end |

> **Lưu ý bắt buộc:** Trong tài liệu này, “TranMIL” là tên model theo yêu cầu khách
> hàng. Không được đổi tên ML Kit Temporal thành TranMIL để báo cáo kết quả. Khi model
> TranMIL thật được bàn giao, chạy lại cùng bộ dữ liệu và cùng giao thức dưới đây.

## 3. Định nghĩa “giấc ngủ trắng” và nhãn chuẩn

Trong phạm vi nghiệm thu, “giấc ngủ trắng” được chuẩn hóa thành **microsleep**: mất
tỉnh táo ngắn, có thể gồm nhắm mắt kéo dài, đầu gật, phản ứng chậm hoặc nhìn trống rỗng.
Không sử dụng cảm nhận chủ quan làm nhãn duy nhất.

Các nhãn sự kiện:

| Mã | Định nghĩa vận hành |
|---|---|
| `ALERT` | Tỉnh táo, chớp mắt sinh lý, nói chuyện hoặc quan sát đường bình thường |
| `DROWSY_EARLY` | Ngáp lặp lại, mí mắt cụp, PERCLOS tăng hoặc đầu bắt đầu gật |
| `MICROSLEEP_0_5_1_5` | Mất tỉnh táo/nhắm mắt liên tục từ 0,5 đến dưới 1,5 giây |
| `MICROSLEEP_1_5_3` | Mất tỉnh táo/nhắm mắt liên tục từ 1,5 đến 3 giây |
| `MICROSLEEP_GT_3` | Nhắm mắt hoặc mất phản ứng trên 3 giây — mức nguy hiểm |
| `BLANK_STARE` | Mắt có thể còn mở nhưng mất phản ứng; chỉ xác nhận khi có video hành vi và bài kiểm tra phản ứng đồng bộ |
| `YAWN` | Miệng mở theo mẫu ngáp, không đồng nhất với đang nói/cười |
| `FACE_LOST` | Không đủ dữ liệu khuôn mặt để suy luận |

`BLANK_STARE` không được tuyên bố phát hiện chính xác chỉ từ EAR/MAR. Muốn nghiệm thu
nhãn này cần thêm tác vụ phản ứng, dữ liệu gaze/iris đáng tin cậy hoặc tín hiệu sinh lý.

## 4. Thiết kế thực nghiệm người – máy

### 4.1 Mô hình thử nghiệm

- Thiết kế within-subject: cùng một đoạn video/sự kiện được đánh giá bởi người và tất
  cả model, dùng cùng mốc thời gian.
- Tối thiểu 15 người tham gia; khuyến nghị 20–30 người, cân bằng có/không đeo kính.
- Mỗi người tối thiểu 30 phút; tổng dữ liệu mục tiêu tối thiểu 10 giờ và 200 sự kiện.
- Không chủ động gây buồn ngủ khi xe chạy ngoài đường. Các tình huống buồn ngủ phải
  thực hiện trên simulator, xe đứng yên hoặc bãi thử có kiểm soát và nhân viên an toàn.

### 4.2 Ground truth

1. Camera tham chiếu quay 1080p/30 fps, nhìn rõ mắt và đầu.
2. Hai chuyên gia độc lập gắn nhãn onset/offset đến độ chính xác 100 ms.
3. Nếu lệch nhãn trên 300 ms hoặc khác loại sự kiện, chuyên gia thứ ba phân xử.
4. Tính Cohen’s kappa; yêu cầu `κ ≥ 0,80`. Thấp hơn phải huấn luyện lại người gắn nhãn.
5. Thời điểm người quan sát bấm nút chỉ dùng để tính **độ trễ con người**, không thay thế
   ground truth từ video hậu kiểm.

### 4.3 Đồng bộ thời gian

- Đồng bộ điện thoại, máy ghi hình và máy ghi nhận nút bấm bằng NTP trước mỗi phiên.
- Đầu phiên dùng đèn flash/tiếng vỗ tay nhìn thấy trên cả video và log.
- Ghi các mốc: `event_onset`, `human_alert_at`, `model_alert_at`, `server_received_at`,
  `web_rendered_at` theo UTC ISO-8601 có millisecond.

### 4.4 Chỉ số so sánh

| Chỉ số | Công thức/ý nghĩa |
|---|---|
| Recall/Sensitivity | TP / (TP + FN), khả năng bắt đúng sự kiện buồn ngủ |
| Precision | TP / (TP + FP), độ tin cậy của cảnh báo |
| F1 | Trung bình điều hòa precision và recall |
| Specificity | TN / (TN + FP) trên các cửa sổ tỉnh táo |
| FAR | Số cảnh báo giả trên một giờ vận hành |
| Detection latency | `alert_at - event_onset`; báo cáo median, p90 và p95 |
| Event IoU | Mức giao nhau giữa khoảng cảnh báo và khoảng ground truth |
| Availability | Tỷ lệ thời gian có khuôn mặt/đủ dữ liệu để suy luận |
| FPS, CPU, RAM, pin, nhiệt | Hiệu năng và khả năng chạy liên tục trên thiết bị đích |

So sánh tốc độ phải có ba cột riêng: độ trễ người, độ trễ suy luận on-device và độ trễ
end-to-end lên web. Không cộng độ trễ mạng vào thời gian suy luận model.

## 5. Ngưỡng PASS/K-PASS đề xuất

| Nhóm | PASS | K-PASS |
|---|---|---|
| Điều kiện chuẩn | Recall ≥ 90%, Precision ≥ 90%, F1 ≥ 0,90, FAR ≤ 0,5/giờ | Một chỉ số dưới ngưỡng |
| Ánh sáng yếu 10–30 lux | Recall ≥ 80%, Precision ≥ 85%, FAR ≤ 1/giờ | Không đạt hoặc availability < 85% |
| Microsleep 1,5–3 giây | Recall ≥ 90%, p95 latency ≤ 2,2 giây | Bỏ sót > 10% hoặc trễ hơn ngưỡng |
| Microsleep 0,5–1,5 giây | Recall ≥ 70%; không làm FAR toàn phiên vượt 1/giờ | Recall < 70% |
| Nhắm mắt > 3 giây | Recall = 100% với các phiên hợp lệ | Bỏ sót bất kỳ sự kiện hợp lệ nào |
| Tỉnh táo liên tục | FAR ≤ 0,5/giờ | FAR cao hơn ngưỡng |
| Chạy nền Android | Camera/service sống ≥ 120 phút; notification luôn hiện; không crash | Service chết, camera không phục hồi hoặc không có thông báo |
| GPS end-to-end | 95% điểm lên web trong ≤ 10 giây, sai số theo GPS thiết bị | Không đạt tỷ lệ/độ trễ |

Ngưỡng có thể điều chỉnh bằng biên bản trước khi chạy, nhưng không được thay đổi sau
khi đã xem kết quả.

## 6. Ma trận kiểm thử Web quản lý

| ID | Ca kiểm thử | Thao tác chính | Kết quả mong đợi | Trạng thái hiện tại |
|---|---|---|---|---|
| WEB-01 | Đăng nhập đúng/sai | Đăng nhập `admin`, thử sai mật khẩu | Đúng vào dashboard; sai báo lỗi, không lộ token | PASS tự động/API |
| WEB-02 | Phân quyền | Mở URL ngoài quyền bằng tài khoản tài xế | Hiện trang không có quyền/HTTP 403 | PASS smoke; cần UAT vai trò |
| WEB-03 | Theme sáng/tối | Chuyển theme, reload, mở 5 trang | Theme giữ nguyên, không nháy sai màu, tương phản rõ | PASS trình duyệt local |
| WEB-04 | Responsive | 390×844, 768×1024, 1440×900 | Menu mobile mở/đóng; không tràn ngang | PASS 390×844 và desktop 1280×720; 768/1440 dành cho UAT |
| WEB-05 | Điều phối nháp | Lưu nháp, mở app tài xế | Nháp không xuất hiện trên mobile | PASS API live |
| WEB-06 | Phát hành chuyến | Phát hành cặp driver 001 + xe 001 | Cùng trip chuyển ASSIGNED, không tạo trùng | PASS API live |
| WEB-07 | Phiếu xuất kho | 2 dòng hàng, phát hành, tài xế xác nhận | Dữ liệu giữ nguyên; audit log đầy đủ | PASS API live |
| WEB-08 | GPS realtime | Bật GPS điện thoại, di chuyển mô phỏng 100 m | Marker xe 001 cập nhật đúng thời gian/vị trí | CHƯA CHẠY thực địa |
| WEB-09 | Cảnh báo buồn ngủ | Tạo cảnh báo từ app | Web nhận đúng tài xế, thời gian, nguồn model, severity | PASS API; CHƯA CHẠY camera thực địa |
| WEB-10 | Điểm ngập | Tạo/xác minh điểm ngập và mở mobile | Hai phía hiển thị cùng điểm; route đánh giá rủi ro | PASS E2E trước đó |
| WEB-11 | Bảo trì | Tìm/lọc phiếu xe 001 | Đúng lịch, chi phí, trạng thái; dark mode rõ | PASS đọc/lọc; CRUD UI CHƯA CÓ |
| WEB-12 | Báo cáo | Mở biểu đồ và xuất CSV | Số liệu lấy backend; CSV UTF-8; không có dữ liệu giả | PASS build/browser |
| WEB-13 | Mất backend | Ngắt backend 30 giây | UI báo mất realtime, không treo; phục hồi sau khi backend lên | CHƯA CHẠY |
| WEB-14 | Bảo mật đầu vào | Script/chuỗi dài ở ghi chú/chứng từ | Không XSS, validation đúng, log không chứa mật khẩu | CHƯA CHẠY security suite |

## 7. Ma trận kiểm thử App mobile

| ID | Ca kiểm thử | Kết quả mong đợi | Trạng thái hiện tại |
|---|---|---|---|
| MOB-01 | Đăng nhập `driver001` | Nhận đúng hồ sơ tài xế 001/xe 001 | PASS máy thật trước đó |
| MOB-02 | Chuyến hôm nay | Đã đi/chưa đi phân nhóm đúng; không thấy chuyến người khác | PASS API/Flutter test |
| MOB-03 | Nhận chuyến mới | Web phát hành → app nhận đúng một chuyến | PASS API live |
| MOB-04 | Vòng đời chuyến | Nhận → bắt đầu → nghỉ → tiếp tục → hoàn thành | PASS API; cần UAT UI toàn luồng |
| MOB-05 | Phiếu xuất kho | Hiển thị đúng Unicode và mọi dòng hàng | PASS Flutter/API |
| MOB-06 | GPS foreground | Gửi vị trí thật, tốc độ, heading và timestamp | PASS chức năng; cần đo sai số thực địa |
| MOB-07 | GPS background | Chuyển app/khóa màn hình 30 phút | Tiếp tục gửi theo chính sách Android | CHƯA CHẠY phiên nghiệm thu |
| MOB-08 | Camera foreground | Preview, EAR/MAR/head pose/FPS thay đổi trực tiếp | PASS máy Xiaomi trước đó |
| MOB-09 | Camera background | Chuyển ứng dụng khác 120 phút | Foreground service + notification; không tranh chấp camera | CHƯA CHẠY 120 phút |
| MOB-10 | Mạng chập chờn | Tắt mạng 5 phút rồi bật | Queue không mất sự kiện; đồng bộ không trùng | CHƯA CHẠY |
| MOB-11 | Bản đồ tránh ngập | Route không đi qua vùng cấm/ngập không thể qua | PASS chức năng; cần bộ tuyến UAT |
| MOB-12 | Agent giọng nói | Wake phrase, STT/TTS, xác nhận lệnh nguy hiểm | PASS fallback; OpenAI thật BLOCKED nếu thiếu API key |
| MOB-13 | Pin/nhiệt | Camera + GPS + mạng 2 giờ | Không crash; nhiệt/pin trong ngưỡng khách hàng chấp thuận | CHƯA CHẠY |
| MOB-14 | Quyền bị từ chối | Từ chối camera/GPS/thông báo | Hướng dẫn cấp quyền, không crash | CHƯA CHẠY |

## 8. Ca kiểm thử chuyên sâu phát hiện buồn ngủ

Mỗi ca chạy tối thiểu 10 lần/người; thứ tự được random để giảm sai lệch học trước.

| ID | Điều kiện | Hành vi/kịch bản | ST-GT mong đợi | TranMIL mong đợi | Người quan sát | Tiêu chí |
|---|---|---|---|---|---|---|
| DMS-01 | 300–500 lux | Nhìn đường, chớp mắt tự nhiên 10 phút | Không cảnh báo | Không cảnh báo | Không bấm | FAR đạt ngưỡng |
| DMS-02 | 300–500 lux | Nhắm mắt 0,2–0,4 giây | Không cảnh báo nguy hiểm | Tương tự | Có thể không bấm | Không FP |
| DMS-03 | 300–500 lux | Nhắm mắt 0,5–1,5 giây | Có thể cảnh báo sớm theo chuỗi | Phát hiện theo sequence | Bấm khi nhận thấy | Recall ≥ 70% |
| DMS-04 | 300–500 lux | Nhắm mắt 1,5–3 giây | Cảnh báo HIGH/CRITICAL | Cảnh báo | Bấm | Recall ≥ 90% |
| DMS-05 | 300–500 lux | Nhắm mắt > 3 giây + đầu gật | Cảnh báo CRITICAL | Cảnh báo CRITICAL | Bấm | Recall 100% |
| DMS-06 | 300–500 lux | Ngáp thật, không buồn ngủ | Tăng risk nhưng hạn chế cảnh báo giả | Phân biệt theo chuỗi | Đánh dấu YAWN | FAR không vượt ngưỡng |
| DMS-07 | 300–500 lux | Ngáp + đầu gật + mí cụp lặp lại | Cảnh báo sớm trước microsleep | Cảnh báo sớm | Bấm khi thấy nguy cơ | So sánh latency |
| DMS-08 | 10–30 lux | Lặp DMS-01/04/05 | Availability và recall đạt ngưỡng low-light | Tương tự | Quan sát qua camera IR/tham chiếu | PASS theo mục 5 |
| DMS-09 | Ngược sáng | Mặt tối, nền sáng | Không suy luận quá tự tin; báo mặt không rõ nếu cần | Tương tự | Gắn nhãn visibility | FAR ≤ 1/giờ |
| DMS-10 | Kính trong | DMS-04 và tỉnh táo | Không suy giảm recall quá 10 điểm % | Tương tự | Bấm | So với không kính |
| DMS-11 | Kính râm | Nhắm mắt mô phỏng | Báo không đủ dữ liệu hoặc fallback an toàn | Tương tự | Bấm | Không được báo “tỉnh táo” chắc chắn |
| DMS-12 | Che một mắt | Chớp/nhắm mắt | Duy trì hoặc báo giảm chất lượng | Tương tự | Gắn nhãn | Không crash, FAR đạt ngưỡng |
| DMS-13 | Quay đầu ±30° | Nhìn gương, không buồn ngủ | Không nhầm thành ngủ gật | Tương tự | Không bấm | FP ≤ 5% sự kiện |
| DMS-14 | Đường rung | Video rung và motion blur | Giữ ổn định hoặc báo chất lượng thấp | Tương tự | Gắn nhãn | Recall giảm ≤ 15 điểm % |
| DMS-15 | Nói/cười | Miệng mở lớn | Không nhầm ngáp kéo dài thành ngủ gật | Tương tự | Không bấm | FP ≤ 5% |
| DMS-16 | Mắt mở, mất phản ứng | Bài PVT có timeout | Chỉ cảnh báo nếu có bằng chứng chuỗi đủ mạnh | TranMIL theo đặc tả | Bấm theo PVT | Báo riêng, không gộp kết luận EAR |
| DMS-17 | Mất khuôn mặt 5–15 giây | Cúi lấy đồ/ra khỏi ghế | Báo FACE_LOST, không nội suy quá 10 frame | Tương tự | Gắn nhãn | Availability log đúng |
| DMS-18 | Nhiều khuôn mặt | Người khác xuất hiện cạnh tài xế | Khóa đúng khuôn mặt tài xế | Tương tự | Gắn ID | Không đổi subject |
| DMS-19 | Camera nền | Chuyển sang app khác khi đang giám sát | Native service tiếp tục, notification hiện | Cùng runtime nếu hỗ trợ | Quan sát notification | 120 phút không crash |
| DMS-20 | Mạng mất | Sinh cảnh báo khi offline | Cảnh báo tại máy ngay; server nhận sau khi có mạng | Tương tự | Bấm | Không phụ thuộc mạng, không trùng event |

## 9. Nhấn mạnh đánh giá chuỗi thời gian

### ST-GT

- Cửa sổ 75 khung; mục tiêu lấy mẫu khoảng 25 fps, tương đương gần 3 giây lịch sử.
- 6 đặc trưng gốc: EAR, MAR, pitch, yaw, roll, iris; cộng 6 delta theo thời gian.
- Có hiệu chuẩn cá nhân 1.500 khung hợp lệ, Savitzky–Golay, chuẩn hóa và dự báo xu thế.
- Kết quả phải đánh giá ở cấp **event/window**, không trộn ngẫu nhiên frame của cùng
  một người vào train và test.

### TranMIL/TransMIL

- Khi được bàn giao phải công bố: checkpoint hash, input shape, sequence length, FPS,
  feature extractor, preprocessing, threshold và thời điểm phát hành cảnh báo.
- Chia dữ liệu theo subject/session, không chia frame ngẫu nhiên gây rò rỉ dữ liệu.
- Chạy cùng video, cùng timestamp và cùng hardware với ST-GT.
- Nếu TranMIL dùng multiple-instance learning, phải báo cả score theo instance và score
  tổng hợp theo bag/sequence để giải thích onset cảnh báo.

## 10. Biểu mẫu ghi kết quả người – máy

| Session | Subject | Scenario | Ground truth onset | Human alert | ST-GT alert | TranMIL alert | Human latency | ST-GT latency | TranMIL latency | Kết quả |
|---|---|---|---|---|---|---|---:|---:|---:|---|
| S001 | P001 | DMS-04 | 00:03:15.200 | 00:03:16.650 | 00:03:16.100 | — | 1.450 s | 0.900 s | BLOCKED | Chưa chạy thật |

Dòng trên chỉ minh họa định dạng, không phải số liệu nghiệm thu.

## 11. Quy trình chạy một phiên

1. Kiểm tra consent, sức khỏe người tham gia và phương án dừng khẩn cấp.
2. Ghi model/version/commit SHA, điện thoại, Android, mức pin, nhiệt độ, lux và mạng.
3. Đồng bộ thời gian và tạo marker đầu phiên.
4. Hiệu chuẩn ST-GT ở trạng thái tỉnh táo; ghi thời gian/khung hợp lệ.
5. Chạy danh sách tình huống đã random; nghỉ tối thiểu 2 phút giữa nhóm.
6. Thu log app, log backend, video tham chiếu và nút bấm người quan sát.
7. Hai chuyên gia gắn nhãn độc lập; phân xử bất đồng.
8. Chạy script tính metrics cố định, xuất CSV/JSON và biểu đồ latency.
9. QA đối chiếu event app → backend → web và đánh PASS/K-PASS theo ngưỡng đã khóa.
10. Lưu biên bản, hash dữ liệu và danh sách lỗi; không chỉnh threshold trên tập test.

## 12. Điều kiện dừng và an toàn

- Dừng ngay khi người tham gia yêu cầu, có chóng mặt, mất định hướng hoặc camera/thiết
  bị gây nóng bất thường.
- Không cho người thật cố ngủ khi đang điều khiển xe trên đường công cộng.
- Video khuôn mặt là dữ liệu nhạy cảm: mã hóa, phân quyền, thời hạn lưu và consent rõ.
- Không tải video cabin lên dịch vụ bên thứ ba nếu chưa có chấp thuận bằng văn bản.

## 13. Tiêu chí hoàn tất nghiệm thu

Nghiệm thu chỉ được ký khi:

- 100% ca mức Critical đã chạy và không còn lỗi blocker/critical.
- Web/mobile/backend vượt toàn bộ smoke, lifecycle và recovery test bắt buộc.
- ST-GT đạt ngưỡng mục 5 trên tập test khóa độc lập.
- TranMIL chỉ được ghi PASS sau khi model thật được tích hợp và chạy cùng protocol.
- Các giới hạn như kính râm, blank stare, ánh sáng cực thấp được ghi rõ trong hướng dẫn
  vận hành; không che giấu ca K-PASS.
- Báo cáo cuối có confusion matrix, event list, FAR/giờ, latency người–máy, hiệu năng
  thiết bị, commit SHA và chữ ký đại diện khách hàng/nhà phát triển.

## 14. Bảng ký xác nhận

| Vai trò | Họ tên | Ngày | Chữ ký | Ý kiến |
|---|---|---|---|---|
| Đại diện khách hàng |  |  |  |  |
| Quản lý dự án |  |  |  |  |
| QA Lead |  |  |  |  |
| Kỹ sư AI/Mobile |  |  |  |  |
| An toàn thử nghiệm |  |  |  |  |

## 15. Baseline kỹ thuật tại thời điểm phát hành tài liệu

| Hạng mục | Kết quả | Phạm vi kết luận |
|---|---|---|
| Frontend lint + production build | PASS | ESLint sạch; Next.js type-check/build đủ 20 route |
| Backend Maven test | PASS | Unit/controller/integration; MySQL 8.4 Testcontainers; Flyway V1–V8 |
| Flutter test | PASS `15/15` | Widget, sync queue, Temporal, ST-GT engine và chuyến/chứng từ |
| Flutter analyze | PASS `0 issue` | Static analysis trên mã nguồn mobile hiện tại |
| Python AI pytest | PASS `11/11` | API, temporal rules, fallback và toolchain hiện có |
| Temporal rule benchmark | PASS | 10.000 observation; mean `0,00345 ms`, p95 `0,00524 ms`, max `0,20226 ms` |
| TranMIL | `K-PASS/BLOCKED` | Repository chưa có model/runtime để đo |
| Thử nghiệm người–máy thực địa | CHƯA CHẠY | Phải thực hiện theo mục 4–13 trước khi ký nghiệm thu AI |

Benchmark Temporal trên chỉ đo hàm luật xác định bằng CPU container, không gồm camera,
Face Mesh, ST-GT TFLite, render UI, mạng hoặc backend. Không được trích số `0,00524 ms`
để quảng cáo độ trễ phát hiện buồn ngủ end-to-end.
