# 4.5.2. Thử nghiệm hiệu năng

## Mục tiêu và phạm vi

Thử nghiệm hiệu năng được thực hiện nhằm đánh giá thời gian phản hồi, thông lượng,
tỷ lệ lỗi và mức độ ổn định của SafeFleet khi nhiều người dùng truy cập đồng thời.
Hai nhóm thao tác được lựa chọn gồm:

1. Đăng nhập vào hệ thống.
2. Đọc hỗn hợp các dữ liệu thường dùng: tổng quan, chuyến đi, phương tiện và bản đồ
   cảnh báo ngập lụt.

Các API thay đổi dữ liệu không được đưa vào thử nghiệm tải để tránh tạo dữ liệu rác
hoặc ảnh hưởng đến hệ thống đang triển khai. Ngưỡng chấp nhận được xác định là tỷ lệ
lỗi nhỏ hơn 5% và thời gian phản hồi P95 nhỏ hơn 3 giây.

## Môi trường thử nghiệm

- Thời gian thực hiện: ngày 27/08/2026.
- Địa chỉ: `https://safeflee.duckdns.org` qua HTTPS.
- VPS: 6 CPU logic, 11,68 GiB RAM và 2 GiB swap.
- SafeFleet được triển khai bằng Docker, gồm Backend, Frontend, PostgreSQL, AI
  Service, MinIO và Valhalla.
- VPS đang đồng thời vận hành SafeFleet và VelaPath; các container chưa được đặt
  giới hạn CPU hoặc bộ nhớ riêng.
- Máy tạo tải kết nối từ bên ngoài VPS, vì vậy số liệu bao gồm độ trễ Internet, TLS,
  reverse proxy, Backend và cơ sở dữ liệu.
- Các request đăng nhập sử dụng cùng một tài khoản kiểm thử; kịch bản đọc tái sử dụng
  một access token. Vì vậy kết quả đo khả năng xử lý request đồng thời, chưa mô phỏng
  đầy đủ 100 tài khoản có dữ liệu và phiên đăng nhập độc lập.
- Mỗi người dùng ảo trong kịch bản đọc gửi lần lượt 5 hoặc 10 request tới bốn API
  nghiệp vụ. Tải được tăng dần và tự dừng khi P95 vượt 3 giây hoặc tỷ lệ lỗi vượt 5%.

## Kết quả thử nghiệm đăng nhập

| Người dùng đồng thời | Tổng request | Thời gian trung bình (ms) | P95 (ms) | P99 (ms) | Thông lượng (request/giây) | Tỷ lệ lỗi |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 468,21 | 468,21 | 468,21 | 2,14 | 0% |
| 5 | 5 | 925,73 | 1.082,90 | 1.083,30 | 4,61 | 0% |
| 10 | 10 | 895,67 | 1.303,27 | 1.306,51 | 7,63 | 0% |
| 20 | 20 | 931,37 | 1.295,30 | 1.309,59 | 15,12 | 0% |
| 50 | 50 | 1.141,12 | 1.566,58 | 1.654,40 | 29,17 | 0% |
| 100 | 100 | 2.679,94 | 3.556,03 | 3.589,30 | 27,25 | 0% |

Hệ thống xử lý thành công toàn bộ request đăng nhập và không phát sinh lỗi HTTP.
Ở mức 50 người dùng đồng thời, P95 đạt 1,57 giây và đáp ứng yêu cầu nhỏ hơn 3 giây.
Khi tăng lên 100 người dùng đồng thời, P95 tăng lên 3,56 giây và thông lượng giảm từ
29,17 xuống 27,25 request/giây. Do đó, kịch bản đăng nhập 100 người đồng thời chưa
đạt yêu cầu về thời gian phản hồi dù tỷ lệ lỗi vẫn bằng 0%.

## Kết quả thử nghiệm tải dữ liệu hỗn hợp

| Người dùng đồng thời | Tổng request | Thời gian trung bình (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Thông lượng (request/giây) | Tỷ lệ lỗi |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 50 | 368,82 | 360,77 | 504,38 | 559,39 | 25,33 | 0% |
| 25 | 125 | 443,53 | 426,92 | 678,03 | 770,00 | 47,22 | 0% |
| 50 | 250 | 683,80 | 452,39 | 1.818,01 | 2.766,88 | 55,46 | 0% |
| 50, chạy duy trì | 500 | 542,06 | 376,59 | 1.781,50 | 1.903,58 | 85,16 | 0% |
| 75, chạy duy trì | 750 | 483,12 | 403,60 | 925,33 | 1.749,26 | 125,53 | 0% |
| 100 | 500 | 1.733,80 | 658,45 | 6.711,51 | 9.076,82 | 42,51 | 0% |
| 100, chạy lặp lại | 1.000 | 1.741,19 | 714,97 | 6.876,82 | 10.362,23 | 45,86 | 0% |

Kết quả chạy lặp lại cho thấy mốc 100 người dùng đồng thời có độ trễ P95 khoảng
6,7–6,9 giây. Đây không phải kết quả bất thường của một lần đo đơn lẻ. Toàn bộ
request vẫn trả HTTP 200 nhưng hệ thống đã xuất hiện hàng đợi và không còn đáp ứng
ngưỡng thời gian 3 giây. Sau thử nghiệm, đăng nhập trả HTTP 200 trong 956 ms và API
tổng quan trả HTTP 200 trong 761 ms, cho thấy hệ thống phục hồi bình thường và không
bị gián đoạn dịch vụ.

## Đánh giá

- Kịch bản đăng nhập đáp ứng yêu cầu ở mức tối đa 50 người dùng đồng thời trong lần
  thử nghiệm này.
- Kịch bản đọc dữ liệu hỗn hợp đáp ứng yêu cầu đến mức 75 người dùng đồng thời.
- Tại 100 người dùng đồng thời, tỷ lệ lỗi vẫn bằng 0% nhưng P95 vượt 3 giây rõ rệt;
  hệ thống không đạt yêu cầu phi chức năng về độ trễ.
- Không tiếp tục thử nghiệm 200, 500 hoặc 1.000 người dùng đồng thời vì ngưỡng dừng
  an toàn đã bị vượt tại 100 người dùng. Vì vậy chưa có cơ sở để tuyên bố hệ thống
  hỗ trợ 500–1.000 người dùng đồng thời.
- VPS vẫn còn bộ nhớ khả dụng sau thử nghiệm và log Backend không ghi nhận exception,
  timeout hoặc lỗi từ chối request. Điểm nghẽn cần được đo thêm tại connection pool,
  truy vấn cơ sở dữ liệu, số luồng xử lý HTTP và reverse proxy.
- SafeFleet đang dùng chung VPS với VelaPath và các container chưa có giới hạn tài
  nguyên, vì vậy tải nền của dự án còn lại có thể làm kết quả biến động.

## Hướng cải tiến

1. Bổ sung Prometheus và Grafana để thu thập CPU, bộ nhớ, số luồng HTTP, HikariCP,
   thời gian truy vấn PostgreSQL và P95 của từng API trong suốt quá trình tạo tải.
2. Phân tích câu lệnh SQL của các API tổng quan, chuyến đi, phương tiện và bản đồ
   ngập; bổ sung chỉ mục và loại bỏ truy vấn lặp nếu có.
3. Cấu hình và đo lại connection pool của Backend thay vì sử dụng cấu hình mặc định.
4. Áp dụng bộ nhớ đệm cho dữ liệu tổng hợp hoặc dữ liệu bản đồ ít thay đổi.
5. Đặt giới hạn và phần tài nguyên dự phòng cho SafeFleet, hoặc tách SafeFleet và
   VelaPath sang các VPS khác nhau trước khi thử tải lớn.
6. Sau khi tối ưu, thử nghiệm tăng dần 100, 150, 250 và 500 người dùng; chỉ tăng lên
   1.000 khi mức trước đó đạt P95 dưới 3 giây và tỷ lệ lỗi dưới 5%.
7. Thực hiện thêm một lần kiểm thử từ máy tạo tải cùng khu vực với VPS để tách độ trễ
   Internet khỏi thời gian xử lý của ứng dụng.

Kịch bản kiểm thử có thể chạy lại tại `tools/performance/vps_load_test.py`. Mật khẩu
được truyền qua biến môi trường và không được lưu trong mã nguồn hoặc báo cáo.

## Ước lượng khi SafeFleet và VelaPath dùng chung VPS

VPS có tổng năng lực CPU tương đương 600% theo cách hiển thị của Docker. Khi chạy
lại tải 75–100 người dùng đồng thời và giám sát hai dự án, tài nguyên ghi nhận xấp xỉ:

| Thành phần | CPU trung bình khi tạo tải | CPU cực đại quan sát | Bộ nhớ sử dụng |
|---|---:|---:|---:|
| SafeFleet | 224% (khoảng 2,24 lõi) | 276% (khoảng 2,76 lõi) | khoảng 1,35 GiB |
| VelaPath | 58% (khoảng 0,58 lõi) | 86% (khoảng 0,86 lõi) | khoảng 1,00 GiB |
| Hai dự án | 282% (khoảng 2,82 lõi) | 362% (khoảng 3,62 lõi) | khoảng 2,35 GiB |

Ở thời điểm sau thử nghiệm, máy còn khoảng 8,3 GiB RAM khả dụng. Ngay tại mẫu CPU
cực đại, VPS vẫn còn khoảng 2,4 lõi chưa sử dụng. Do đó không phù hợp nếu lấy năng
lực VPS chia đều 50% cho mỗi dự án. Trong lần đo này, VelaPath sử dụng khoảng 0,6
lõi nền và làm giảm năng lực CPU khả dụng của SafeFleet khoảng 10% tổng CPU VPS,
không phải 50%.

Tuy vậy, cả hai dự án hiện chưa được cấu hình giới hạn CPU/RAM riêng. Khi VelaPath
có đợt xử lý nền hoặc truy cập tăng cao, VelaPath có thể sử dụng thêm tài nguyên và
làm độ trễ SafeFleet biến động. Backend SafeFleet cũng chưa cấu hình rõ kích thước
HikariCP và số luồng Tomcat qua biến môi trường. Việc P95 tăng mạnh ở 100 người dùng
trong khi CPU/RAM chưa cạn cho thấy giới hạn hiện tại có khả năng nằm ở hàng đợi bên
trong Backend, connection pool hoặc truy vấn, thay vì thiếu tổng tài nguyên VPS.

### Quy đổi thông lượng thành số người dùng

Mức 75 người dùng ảo đạt 94,67 request/giây với P95 là 1,48 giây. Để dự phòng cho
VelaPath, dao động Internet, tác vụ AI/OCR và tải đột biến, chỉ sử dụng khoảng 65%
thông lượng này làm ngân sách vận hành:

`Thông lượng an toàn = 94,67 × 65% ≈ 61,5 request/giây`

Làm tròn xuống, SafeFleet nên được vận hành với ngân sách khoảng 60 request/giây
trên VPS hiện tại.

Ứng dụng tài xế gửi vị trí khoảng 10 giây một lần và kiểm tra thông báo phân công
khoảng 15 giây một lần. Chỉ riêng hai tác vụ nền tương đương khoảng 0,167
request/giây cho mỗi tài xế. Khi cộng thêm thao tác xem chuyến đi, bản đồ và cảnh báo,
có thể ước lượng 0,25 request/giây cho một tài xế đang hoạt động.

| Kịch bản sử dụng | Tải ước lượng mỗi người | Số người theo ngân sách 60 request/giây |
|---|---:|---:|
| Người dùng chủ yếu xem, trung bình 1 request/10 giây | 0,10 req/s | khoảng 600 |
| Tài xế chỉ chạy tác vụ nền GPS và thông báo | 0,167 req/s | khoảng 359 |
| Tài xế đang hoạt động, có GPS, thông báo và thao tác ứng dụng | 0,25 req/s | khoảng 240 |
| Người dùng web thao tác liên tục, 1 request/2 giây | 0,50 req/s | khoảng 120 |

Một cấu hình sử dụng thực tế có thể tính như sau:

- 200 tài xế hoạt động: `200 × 0,25 = 50 request/giây`.
- 20 người quản lý thao tác nhiều: `20 × 0,50 = 10 request/giây`.
- Tổng cộng: khoảng `60 request/giây`, nằm trong ngân sách vận hành đề xuất.

Nếu có 300 tài xế và 30 người quản lý cùng hoạt động, tải ước lượng là 90
request/giây, gần ngưỡng đã xuất hiện suy giảm. Với 500 tài xế và 50 người quản lý,
tải có thể đạt 150 request/giây, vượt rõ rệt năng lực an toàn đã đo.

### Khuyến nghị vận hành

- Ngưỡng đề xuất hiện tại: khoảng 200 tài xế đang hoạt động và 20 người dùng web
  thao tác đồng thời.
- Có thể chấp nhận khoảng 250 tài xế trong thời gian ngắn nếu ít thao tác AI/OCR và
  VelaPath không có tải cao, nhưng cần giám sát P95.
- Không nên cam kết 500–1.000 người dùng hoạt động đồng thời trên cấu hình hiện tại.
- Nên dành mục tiêu tài nguyên khoảng 3,5 CPU và 5 GiB RAM cho SafeFleet; khoảng
  1,5 CPU và 3,5 GiB RAM cho VelaPath; giữ phần còn lại cho hệ điều hành và tải đột
  biến. Đây là ngân sách vận hành đề xuất, cần được xác nhận lại sau khi áp dụng giới
  hạn container.
- Sau khi cấu hình connection pool, tối ưu truy vấn và cô lập tài nguyên hai dự án,
  cần chạy lại các mốc 100, 150, 250 và 500 người dùng.
