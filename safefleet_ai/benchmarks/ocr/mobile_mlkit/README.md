# Mobile OCR simulation

Runner mô phỏng nằm trong `mobile_simulation/run_mobile_sim.py`. Nó chạy hoàn
toàn trên máy tính nhưng cố ý dùng model `tessdata_fast`, giới hạn độ phân giải
và không dùng VietOCR/dewarp theo từng dòng. Đây là proxy tái lập được cho lớp
OCR nhẹ trên điện thoại; không được trình bày như một phép đo ML Kit thật.
