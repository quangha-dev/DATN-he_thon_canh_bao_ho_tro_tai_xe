# 4.4. Giao diện hệ thống

Phần này trình bày các giao diện đã được triển khai trong hệ thống SafeFleet, bao gồm website quản lý dành cho quản trị viên, điều phối viên và cán bộ an toàn; đồng thời bao gồm ứng dụng mobile dành cho tài xế. Mỗi giao diện được thiết kế theo đúng vai trò sử dụng, hỗ trợ theo dõi đội xe, điều phối chuyến, xử lý cảnh báo và bảo đảm an toàn trong quá trình vận hành.

## 4.4.1. Giao diện website quản lý

### 4.4.1.1. Giao diện đăng nhập

Giao diện đăng nhập như Hình 4.4 cho phép người dùng truy cập website quản lý bằng tài khoản được cấp. Sau khi xác thực thành công, hệ thống điều hướng người dùng đến trang phù hợp với vai trò và chỉ hiển thị các chức năng được phân quyền.

Hình 4.4. Giao diện đăng nhập website quản lý

### 4.4.1.2. Giao diện trung tâm điều hành

Giao diện trung tâm điều hành như Hình 4.5 tổng hợp trạng thái vận hành của đội xe, số cảnh báo, sự cố SOS, điểm ngập và các công việc cần xử lý theo mức ưu tiên. Điều phối viên có thể theo dõi nhanh tình hình chung và chuyển đến màn hình nghiệp vụ liên quan.

Hình 4.5. Giao diện trung tâm điều hành

### 4.4.1.3. Giao diện Agent quản lý

Giao diện Agent quản lý như Hình 4.6 hỗ trợ người quản lý truy vấn dữ liệu đội xe bằng ngôn ngữ tự nhiên. Agent có thể tổng hợp chuyến đi, cảnh báo, tài xế và quy định nội bộ theo quyền của tài khoản, đồng thời hiển thị nguồn để người dùng đối chiếu trước khi ra quyết định.

Hình 4.6. Giao diện Agent quản lý

### 4.4.1.4. Giao diện bản đồ thời gian thực

Giao diện bản đồ thời gian thực như Hình 4.7 hiển thị vị trí và trạng thái của phương tiện trên bản đồ số. Người dùng có thể lọc xe đang chạy, xe có cảnh báo, xe phát SOS, xe mất GPS và quan sát các điểm ngập ảnh hưởng đến hành trình.

Hình 4.7. Giao diện bản đồ thời gian thực

### 4.4.1.5. Giao diện quản lý tài xế

Giao diện quản lý tài xế như Hình 4.8 cho phép theo dõi hồ sơ, giấy phép lái xe, phương tiện phụ trách, thời gian lái và điểm an toàn của từng tài xế. Hệ thống hỗ trợ tìm kiếm, lọc theo trạng thái và nhận diện nhanh các trường hợp có mức rủi ro cao.

Hình 4.8. Giao diện quản lý tài xế

### 4.4.1.6. Giao diện quản lý tài khoản

Giao diện quản lý tài khoản như Hình 4.9 cho phép quản trị viên tạo tài khoản, phân vai trò, khóa hoặc kích hoạt người dùng và theo dõi lần hoạt động gần nhất. Danh sách có thể được lọc theo vai trò và trạng thái để thuận tiện cho công tác quản trị.

Hình 4.9. Giao diện quản lý tài khoản

### 4.4.1.7. Giao diện quản lý phương tiện

Giao diện quản lý phương tiện như Hình 4.10 tập trung thông tin biển số, loại xe, tải trọng, tài xế phụ trách, giấy tờ và trạng thái kết nối GPS. Người quản lý có thể thêm phương tiện và phát hiện nhanh xe mất kết nối hoặc có giấy tờ sắp hết hạn.

Hình 4.10. Giao diện quản lý phương tiện

### 4.4.1.8. Giao diện điều phối chuyến

Giao diện điều phối chuyến như Hình 4.11 cho phép tạo chuyến mới, nhập điểm đi, điểm đến, thời gian dự kiến, hàng hóa và phiếu xuất kho. Hệ thống hỗ trợ gợi ý cặp tài xế – phương tiện phù hợp trước khi giao chuyến đến ứng dụng tài xế.

Hình 4.11. Giao diện điều phối chuyến

### 4.4.1.9. Giao diện chuyến đi và chứng từ

Giao diện chuyến đi và chứng từ như Hình 4.12 hiển thị danh sách chuyến, tiến độ thực hiện và các chứng từ liên quan. Người dùng có thể tìm kiếm, lọc trạng thái, xem chi tiết hành trình và đối chiếu dữ liệu phiếu được gửi từ ứng dụng tài xế.

Hình 4.12. Giao diện chuyến đi và chứng từ

### 4.4.1.10. Giao diện duyệt phiếu lệch biển số

Giao diện duyệt phiếu lệch biển số như Hình 4.13 hỗ trợ xử lý các chứng từ có biển số nhận dạng từ OCR không trùng với xe được giao. Cán bộ phụ trách có thể đối chiếu ảnh gốc, thông tin chuyến và quyết định duyệt hoặc yêu cầu tài xế bổ sung.

Hình 4.13. Giao diện duyệt phiếu lệch biển số

### 4.4.1.11. Giao diện cảnh báo AI

Giao diện cảnh báo AI như Hình 4.14 tập hợp các sự kiện buồn ngủ, mất tập trung, dùng điện thoại, quá giờ lái, vượt tốc độ và lệch tuyến. Mỗi cảnh báo hiển thị tài xế, phương tiện, mức độ, dữ liệu kỹ thuật và trạng thái xử lý để cán bộ an toàn tiếp nhận kịp thời.

Hình 4.14. Giao diện cảnh báo AI

### 4.4.1.12. Giao diện SOS và sự cố

Giao diện SOS và sự cố như Hình 4.15 cho phép điều phối viên theo dõi các yêu cầu cứu hộ, va chạm, hỏng xe và sự cố khác. Hệ thống hiển thị vị trí, mức ưu tiên, người tiếp nhận và nhật ký xử lý nhằm bảo đảm quá trình phản ứng được ghi nhận đầy đủ.

Hình 4.15. Giao diện SOS và sự cố

### 4.4.1.13. Giao diện điểm ngập và rủi ro

Giao diện điểm ngập và rủi ro như Hình 4.16 thể hiện các vùng ngập, tắc nghẽn và đoạn đường cần né trên bản đồ. Người quản lý có thể xác minh báo cáo từ tài xế, theo dõi xe ở gần và gửi cảnh báo đến các phương tiện bị ảnh hưởng.

Hình 4.16. Giao diện điểm ngập và rủi ro

### 4.4.1.14. Giao diện quản lý thiết bị

Giao diện quản lý thiết bị như Hình 4.17 hỗ trợ theo dõi thiết bị GPS, camera cabin, số serial, phương tiện đã gắn và thời điểm kết nối cuối. Chức năng này giúp phát hiện thiết bị mất kết nối và quản lý các thiết bị chưa được phân bổ.

Hình 4.17. Giao diện quản lý thiết bị

### 4.4.1.15. Giao diện quản lý bảo trì

Giao diện quản lý bảo trì như Hình 4.18 cho phép lập phiếu bảo trì, theo dõi lịch sửa chữa, mức ưu tiên, nội dung công việc và chi phí dự kiến. Các xe sắp đến hạn hoặc phiếu quá hạn được làm nổi bật để người quản lý xử lý sớm.

Hình 4.18. Giao diện quản lý bảo trì

### 4.4.1.16. Giao diện báo cáo

Giao diện báo cáo như Hình 4.19 tổng hợp số chuyến, cảnh báo và xu hướng an toàn theo khoảng thời gian. Dữ liệu được trực quan hóa bằng biểu đồ và có thể xuất ra tệp để phục vụ đánh giá hoạt động đội xe.

Hình 4.19. Giao diện báo cáo

### 4.4.1.17. Giao diện cấu hình hệ thống

Giao diện cấu hình như Hình 4.20 cho phép thiết lập giới hạn thời gian lái liên tục, các ngưỡng cảnh báo, loại sự kiện AI cần theo dõi và kết nối dịch vụ. Thay đổi chỉ được áp dụng sau khi người có quyền lưu cấu hình.

Hình 4.20. Giao diện cấu hình hệ thống

### 4.4.1.18. Giao diện hồ sơ cá nhân

Giao diện hồ sơ cá nhân như Hình 4.21 hiển thị thông tin tài khoản, vai trò và trạng thái hoạt động của người dùng. Tại đây, người dùng có thể đổi mật khẩu và kiểm soát an toàn phiên đăng nhập của mình.

Hình 4.21. Giao diện hồ sơ cá nhân trên website

## 4.4.2. Giao diện ứng dụng mobile dành cho tài xế

### 4.4.2.1. Giao diện đăng nhập

Giao diện đăng nhập mobile như Hình 4.22 cho phép tài xế xác thực bằng tài khoản được cấp và hiển thị địa chỉ máy chủ đang kết nối. Ứng dụng hỗ trợ tiếp tục sử dụng dữ liệu chuyến đã tải khi mất mạng và tự đồng bộ khi kết nối được khôi phục.

Hình 4.22. Giao diện đăng nhập ứng dụng mobile

### 4.4.2.2. Giao diện trang chủ tài xế

Giao diện trang chủ như Hình 4.23 cung cấp thông tin chuyến được giao, tuyến đang dẫn đường, thời gian lái liên tục và điểm an toàn trong ngày. Các thao tác thường dùng được bố trí tập trung để tài xế truy cập nhanh khi làm việc.

Hình 4.23. Giao diện trang chủ tài xế

### 4.4.2.3. Giao diện bản đồ an toàn

Giao diện bản đồ an toàn như Hình 4.24 cho phép tài xế nhập điểm đến, xem tuyến đường và các điểm ngập hoặc rủi ro xung quanh. Hệ thống có thể đề xuất tuyến thay thế và tiếp tục hỗ trợ khi chất lượng kết nối suy giảm.

Hình 4.24. Giao diện bản đồ an toàn

### 4.4.2.4. Giao diện trợ lý SafeFleet

Giao diện trợ lý SafeFleet như Hình 4.25 hỗ trợ tài xế tra cứu chuyến, báo cáo tình trạng đường, yêu cầu nghỉ hoặc gọi điều hành bằng giọng nói. Trợ lý chỉ mở khi người dùng chủ động gọi hoặc nhấn nút micro, tránh che khuất thông tin lái xe.

Hình 4.25. Giao diện trợ lý SafeFleet

### 4.4.2.5. Giao diện thống kê theo tháng

Giao diện thống kê theo tháng như Hình 4.26 tổng hợp số chuyến, thời gian lái, cảnh báo và điểm an toàn của tài xế. Các chỉ số giúp tài xế theo dõi xu hướng cá nhân và chủ động điều chỉnh hành vi lái xe.

Hình 4.26. Giao diện thống kê theo tháng

### 4.4.2.6. Giao diện hồ sơ tài xế

Giao diện hồ sơ như Hình 4.27 hiển thị giấy phép lái xe, phương tiện được phân công, thông tin liên hệ và trạng thái kết nối máy chủ. Tài xế cũng có thể truy cập cài đặt quyền, thông báo, giám sát tỉnh táo và nhật trình phiếu từ màn hình này.

Hình 4.27. Giao diện hồ sơ tài xế

### 4.4.2.7. Giao diện thông báo

Giao diện thông báo như Hình 4.28 hiển thị chuyến mới được giao, cảnh báo ngập, phản hồi SOS và các cập nhật liên quan đến tài xế. Người dùng có thể mở thông báo để xem chi tiết và quyết định nhận hoặc từ chối chuyến được giao.

Hình 4.28. Giao diện thông báo trên ứng dụng mobile

### 4.4.2.8. Giao diện nhật trình phiếu

Giao diện nhật trình phiếu như Hình 4.29 quản lý các chứng từ đã quét theo tháng, trạng thái hoàn chỉnh và các mục cần bổ sung. Tài xế có thể mở lại phiếu, tiếp tục quét và xuất dữ liệu phục vụ đối soát.

Hình 4.29. Giao diện nhật trình phiếu

### 4.4.2.9. Giao diện tổng quan an toàn

Giao diện tổng quan an toàn như Hình 4.30 trình bày điểm an toàn, thời gian lái và các nhóm cảnh báo của tài xế. Thông tin được tổng hợp trực quan để tài xế nhận biết nguyên nhân làm giảm điểm và cải thiện hành vi lái xe.

Hình 4.30. Giao diện tổng quan an toàn

### 4.4.2.10. Giao diện giám sát tỉnh táo

Giao diện giám sát tỉnh táo như Hình 4.31 sử dụng camera trước và mô hình AI chạy trực tiếp trên điện thoại để phát hiện dấu hiệu buồn ngủ hoặc mất tập trung. Video không được gửi lên máy chủ; hệ thống chỉ đồng bộ sự kiện và các chỉ số cần thiết khi vượt ngưỡng cảnh báo.

Hình 4.31. Giao diện giám sát tỉnh táo

### 4.4.2.11. Giao diện chuyến hôm nay

Giao diện chuyến hôm nay như Hình 4.32 hiển thị toàn bộ lịch trình được giao và cho phép lọc theo trạng thái đang chạy, chờ đi hoặc đã hoàn thành. Mỗi thẻ chuyến thể hiện tuyến đường, thời gian dự kiến và yêu cầu kiểm tra trước chuyến.

Hình 4.32. Giao diện danh sách chuyến hôm nay

### 4.4.2.12. Giao diện chi tiết chuyến

Giao diện chi tiết chuyến như Hình 4.33 cung cấp lộ trình, thời gian, phương tiện, hàng hóa và số chứng từ liên quan. Đối với chuyến mới được giao, tài xế có thể xem đầy đủ thông tin trước khi lựa chọn nhận hoặc từ chối chuyến.

Hình 4.33. Giao diện chi tiết chuyến

### 4.4.2.13. Giao diện báo tình trạng đường

Giao diện báo tình trạng đường như Hình 4.34 cho phép tài xế gửi vị trí ngập nước hoặc kẹt xe, chọn mức độ và bổ sung ghi chú nhanh. Khi mất mạng, báo cáo được lưu trong hàng đợi và tự động đồng bộ khi có kết nối.

Hình 4.34. Giao diện báo tình trạng đường

### 4.4.2.14. Giao diện cứu hộ khẩn cấp

Giao diện cứu hộ khẩn cấp như Hình 4.35 cho phép tài xế giữ nút SOS trong hai giây để gửi tín hiệu ưu tiên cao đến trung tâm điều hành. Yêu cầu được gửi kèm vị trí, phương tiện, chuyến đang chạy và thông tin liên hệ để rút ngắn thời gian phản ứng.

Hình 4.35. Giao diện cứu hộ khẩn cấp

### 4.4.2.15. Giao diện chế độ lái

Giao diện chế độ lái như Hình 4.36 ưu tiên hiển thị chỉ dẫn rẽ, quãng đường còn lại, thời gian dự kiến và trạng thái tuyến. Các nút báo ngập, mở trợ lý giọng nói và kết thúc hành trình được bố trí ở vùng thao tác nhanh nhưng không che khuất thông tin dẫn đường.

Hình 4.36. Giao diện chế độ lái

### 4.4.2.16. Giao diện quyền và riêng tư

Giao diện quyền và riêng tư như Hình 4.37 giải thích rõ mục đích sử dụng vị trí, camera, micro và thông báo của ứng dụng. Người dùng có thể kiểm tra trạng thái từng quyền và mở cài đặt hệ thống để cấp quyền còn thiếu.

Hình 4.37. Giao diện quyền và riêng tư

### 4.4.2.17. Giao diện chọn nguồn quét phiếu

Giao diện chọn nguồn quét phiếu như Hình 4.38 cho phép tài xế chụp chứng từ mới bằng camera hoặc chọn nhiều ảnh có sẵn. Ảnh sau đó được xử lý OCR, đối chiếu với chuyến và lưu vào nhật trình phiếu.

Hình 4.38. Giao diện chọn nguồn quét phiếu
