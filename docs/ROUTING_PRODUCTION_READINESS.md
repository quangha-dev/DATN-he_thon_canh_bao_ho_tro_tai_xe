# SafeFleet routing — production readiness

## Kiến trúc đang dùng

- Dữ liệu đường: OpenStreetMap Việt Nam.
- Routing graph: Valhalla tự host, costing theo đúng loại xe.
- Bản đồ trên web/app: MapLibre; tile nền phải chuyển sang tile server tự host trước khi tải lớn hoặc hỗ trợ offline toàn vùng.
- Vùng nguy hiểm động: điểm, đoạn và đa giác do tài xế báo được gửi vào `exclude_locations`/`exclude_polygons`; backend vẫn kiểm tra lại hình học tuyến trả về và không công bố tuyến cắt vùng chặn cứng.
- Mất Valhalla: OSRM chỉ là chế độ suy giảm. Candidate có `providerFallback=true` để giao diện/cảnh báo vận hành không coi đây là tuyến chất lượng đầy đủ.

## Các lớp an toàn đã có

1. Hồ sơ xe gồm chiều cao, rộng, dài, tổng tải, tải trục, số trục, tốc độ tối đa và hàng nguy hiểm.
2. Nếu hồ sơ còn thiếu, backend dùng cấu hình bảo thủ theo loại xe; quản trị viên nên nhập số đo thật để tránh vòng đường không cần thiết.
3. Xe tải, xe khách, xe máy hoặc bất kỳ xe nào có giới hạn riêng đều đi qua Valhalla; Google Routes không được dùng vì không bảo đảm các giới hạn này.
4. Báo `BLOCKED` chưa xác minh chặn ngay trong 30 phút. Sau đó cần trạng thái `VERIFIED` hoặc confidence >= 0,65 mới tiếp tục chặn cứng; báo cáo vẫn được giữ làm điểm phạt rủi ro.
5. Telemetry luôn được lưu để điều tra, nhưng chỉ vị trí không quá 2 phút, accuracy <= 50 m và trạng thái GPS không LOST/OFFLINE mới cập nhật vị trí thời gian thực.
6. Tốc độ GPS ngoài 0–250 km/h bị từ chối ở biên API.

## Điều kiện bắt buộc trước pilot ngoài đường

- Nhập và kiểm tra hồ sơ vật lý của toàn bộ xe pilot.
- Chọn 30–50 tuyến chuẩn ở khu vực hoạt động; có ca cầu thấp, đường cấm tải, đường một chiều, ngõ hẹp, đường ngập và mất mạng.
- Chạy mỗi tuyến ít nhất hai chiều, ban ngày và giờ cao điểm; lưu GPS 1–5 giây/lần để tính độ lệch tuyến, sai số ETA và thời gian reroute.
- Mục tiêu ban đầu: không vi phạm closure/giới hạn xe; P95 tạo tuyến < 3 giây; P95 reroute < 5 giây; tuyến GPS hợp lệ nằm trong 30 m ít nhất 95%; không cập nhật realtime từ GPS stale/yếu.
- Có người trực xác minh hazard, quy trình gỡ báo sai và số điện thoại vận hành. Không để crowd report là nguồn duy nhất cho quyết định an toàn dài hạn.
- Hiển thị rõ “tuyến suy giảm” khi `providerFallback=true`; tài xế không được mặc định coi tuyến fallback là đã xét ngập.

## Dữ liệu và vận hành

- Kiểm tra `GET /status` của Valhalla và `tileset_last_modified` mỗi ngày.
- Cập nhật graph OSM định kỳ hàng tuần trong pilot, sau đó hàng ngày hoặc dùng replication diff khi triển khai rộng. Luôn dựng graph mới ở volume/staging riêng, chạy bộ tuyến chuẩn rồi mới chuyển traffic.
- Không dùng tile server công cộng của openstreetmap.org cho production/offline. Tự dựng vector tile bằng Planetiler và phục vụ bằng Martin (hoặc một stack tương đương), kèm attribution OSM/ODbL.
- Photon/Nominatim công cộng chỉ phù hợp thử nghiệm. Khi lưu lượng tăng, tự host geocoder và giới hạn/rate-limit truy vấn.
- ETA giao thông chính xác cần thêm live/predicted traffic. Valhalla hỗ trợ traffic tile nhưng dữ liệu phải được SafeFleet thu từ telemetry đủ lớn hoặc mua từ nhà cung cấp; báo kẹt xe thủ công chỉ là lớp tránh sự cố, không thay thế speed feed.

## Chu kỳ phát hành an toàn

1. Dựng graph mới và chạy route benchmark ngoại tuyến.
2. Chạy unit/integration test backend, `flutter analyze`, `flutter test`, web lint/build.
3. Chạy E2E: giao chuyến → nhận chuyến → tạo tuyến → báo đoạn ngập → reroute → xác nhận tuyến mới không cắt hazard.
4. Canary 1–3 xe, theo dõi fallback rate, route latency, GPS rejected rate và phản hồi tài xế.
5. Chỉ mở rộng khi không còn lỗi an toàn mức nghiêm trọng; có kế hoạch rollback image và graph.

## Giới hạn cần nói rõ

Hệ thống hiện có thể pilot có kiểm soát, chưa nên quảng bá là “chính xác như Google Maps” trên toàn quốc. Chất lượng cuối cùng phụ thuộc độ đầy đủ của tag OSM (cấm tải, chiều cao cầu, tải cầu), độ mới graph, chất lượng GPS và nguồn traffic. Nếu tag an toàn không tồn tại trong dữ liệu đường thì không thuật toán routing nào có thể tự suy ra chắc chắn; cần khảo sát tuyến vận tải trọng yếu và bổ sung dữ liệu có kiểm duyệt.
