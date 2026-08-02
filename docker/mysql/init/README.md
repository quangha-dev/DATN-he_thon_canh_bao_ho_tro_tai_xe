# MySQL init

Thư mục này được giữ có chủ đích nhưng không chứa SQL khởi tạo. Toàn bộ schema và
reference data do Flyway trong backend quản lý (`V1` đến migration mới nhất), nhờ
đó cùng một lịch sử migration được dùng ở local, test và production. Không đặt
schema SQL thủ công ở đây vì sẽ làm sai checksum hoặc thứ tự Flyway.
