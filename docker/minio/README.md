# Khởi tạo MinIO

`init-bucket.sh` chạy trong container `minio-init`, tạo bucket evidence nếu chưa có,
đặt quyền anonymous là `none` và kiểm tra lại bucket trước khi backend được phép
khởi động. Script có tính lặp lại an toàn và dừng ngay nếu thiếu biến môi trường.
