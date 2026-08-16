# OCR benchmark: phiếu xuất kho

Thư mục này so sánh hai đường chạy độc lập trên cùng một ảnh:

- `mobile_mlkit`: pipeline thật đang chạy trong ứng dụng Android (Google ML Kit, on-device).
- `service/ocr/pipeline`: pipeline OCR dành cho máy tính/server, có hiệu chỉnh phối cảnh, xoay, tăng cường ảnh và OCR tiếng Việt.

## Quy tắc chống “fix cứng”

- Kết quả chuẩn chỉ nằm trong `fixtures/ground_truth.json` và chỉ được `compare.py` đọc để tính CER/WER/pass.
- Mã trong `service/ocr/pipeline/` và mã ứng dụng mobile không được đọc file ground truth, không chứa câu kết quả chuẩn và không thay thế đầu ra bằng từ điển theo phiếu test.
- Pipeline inference phải chạy được khi thay ảnh đầu vào khác mà không cần sửa mã.

## Kết quả acceptance hiện tại

| Pipeline | Thời gian CPU | CER | WER | Exact |
|---|---:|---:|---:|---:|
| Mobile simulation / model fast | 5,4 s | 50,45% | 76% | Không |
| Server Tesseract best đơn | 13,1 s | 26,13% | 40% | Không |
| Server hybrid (lần chốt gần nhất) | 9,7 s | 0% | 0% | **PASS** |

Các lượt cold/warm trên máy phát triển dao động khoảng 9,7–18,2 giây do cache
file/model và tải CPU. Mobile simulation là proxy có thể tái lập, không phải số
đo Google ML Kit trên điện thoại thật.

Pipeline PASS gồm: phát hiện/crop tờ giấy, OSD xoay trang, OCR `vie_best`, ước
lượng độ nghiêng cục bộ, hai biến thể deskew đối xứng, VietOCR cho dòng địa chỉ,
và chọn kết quả riêng cho từng dòng. Việc tách từng dòng giải quyết trường hợp
giấy cong khiến tên công trình và địa chỉ không song song.

## Kiến trúc đã tích hợp

`App mobile → backend /api/v1/mobile/documents/ocr → AI service /ocr/driving-log`

App chạy upload server song song với xử lý local. Local vẫn lưu bản scan, đánh
giá đỏ/vàng/xanh và là fallback offline; khi server thành công, trường công
trình được thay bằng kết quả server và vẫn hiển thị ở màn hình đối chiếu.

## Cài đặt và chạy

Model lớn được tải bằng script setup và không đưa vào Git thường:

Chạy từ thư mục `safefleet_ai`:

```powershell
.\benchmarks\ocr\setup.ps1
.\benchmarks\ocr\run_all.ps1
```

```powershell
python .\benchmarks\ocr\compare.py --results .\artifacts\ocr-benchmark
```

Kết quả `exact_match=true` chỉ có nghĩa là đầu ra OCR thật khớp ground truth sau khi chuẩn hóa khoảng trắng và Unicode; không dùng ground truth để sinh kết quả.
