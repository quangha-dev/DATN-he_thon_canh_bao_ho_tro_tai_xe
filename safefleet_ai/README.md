# SafeFleet AI

Thiết kế MCP, ma trận tool, xác nhận thao tác và golden evaluation được mô tả tại
[`../docs/SAFEFLEET_AGENT_MCP.md`](../docs/SAFEFLEET_AGENT_MCP.md).

`safefleet_ai` là ranh giới sở hữu toàn bộ xử lý AI phía server:

1. OCR phiếu và trích xuất trường dữ liệu.
2. Phân loại intent giọng nói, gồm local rule và OpenAI fallback.
3. Agent dữ liệu dùng `gpt-4o-mini`: lập kế hoạch, gọi tool động, kiểm tra sau từng bước và lập lại kế hoạch.
4. Lưu cấu hình OpenAI đã mã hóa trong volume riêng của AI service.
5. Temporal safety engine/toolchain để hiệu chuẩn, đánh giá, benchmark và export classifier.

Backend Java không gọi OpenAI, không giữ prompt/tool definition và không lưu API key. Nó chỉ xác thực người dùng, cung cấp API dữ liệu nghiệp vụ theo quyền và chuyển tiếp request đến AI service qua `SafeFleetAiGateway`.

Camera cabin realtime luôn xử lý on-device trong Flutter; AI service không nhận video liên tục.

## Cấu trúc

- `service/main.py`: app factory FastAPI, không chứa logic nghiệp vụ.
- `service/api/routers/`: HTTP boundary cho health, OCR, intent, chat và agent.
- `service/agent/configuration.py`: mã hóa và lưu cấu hình OpenAI.
- `service/agent/orchestrator.py`: plan → tool → check → replan/final.
- `service/agent/tools.py`: tool definitions và client đọc dữ liệu tài xế từ backend.
- `service/providers/openai.py`: adapter duy nhất kết nối tới OpenAI.
- `service/intent/`: local rules và OpenAI structured fallback.
- `service/chat/`: trợ lý hỏi đáp phía server.
- `service/ocr/service.py`: facade OCR dùng ở runtime.
- `service/ocr/pipeline/`: crop, xoay, tiền xử lý và nhận dạng trường phiếu.
- `benchmarks/ocr/`: fixture, acceptance test và công cụ đo OCR; không được đóng gói vào image runtime.
- `models/ocr/`: model OCR offline dùng chung bởi runtime và benchmark.
- `.local/`: virtualenv/vendor cục bộ, luôn bị loại khỏi Git và Docker context.
- `artifacts/`: kết quả benchmark/debug sinh ra, luôn bị loại khỏi Git và Docker context.
- `service/temporal.py`: drowsiness/phone temporal rules dùng trong test/evaluation.
- `models/safefleet_temporal_rules.json`: metadata canonical.
- `models/best_model_fold_1.pth`: checkpoint STGT fold 1 gốc.
- `models/drowsiness_model.onnx`: bản export trung gian của checkpoint STGT.
- `training/train_temporal_rules.py`: hiệu chuẩn threshold từ JSONL.
- `evaluation/evaluate_temporal_rules.py`: precision/recall/F1 theo sequence.
- `export/export_model.py`: export mobile metadata, ONNX hoặc TFLite.
- `scripts/benchmark.py`: latency benchmark.
- `tests`: unit/API tests cho temporal rules, OCR, intent, mã hóa cấu hình và agent orchestration.

## Chạy

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest
python .\scripts\benchmark.py --iterations 10000
python .\training\train_temporal_rules.py --input .\training\sample_calibration.jsonl --output .\models\calibration.json
python .\evaluation\evaluate_temporal_rules.py --input .\evaluation\sample_sequence.jsonl
python .\export\export_model.py --format mobile --output <path-json>
uvicorn service.main:app --reload
```

Nếu máy host không có đúng Python 3.11, test stage Docker là nguồn tái lập:

```powershell
docker build --target test -t safefleet-ai-test:local .
docker run --rm safefleet-ai-test:local
```

ONNX/TFLite chỉ cần trên máy training:

```powershell
python -m pip install -r requirements-ml.txt
python .\export\export_model.py --format onnx --output .\models\safefleet.onnx
python .\export\export_model.py --format tflite --output .\models\safefleet.tflite
```

Không cài TensorFlow/ONNX vào runtime Docker nhẹ.

## Nguyên tắc vận hành production

- Client mobile chỉ gọi backend; chỉ backend được gọi các endpoint AI bằng `X-SafeFleet-Service-Token`.
- API key được nhập trên web quản lý, mã hóa AES-GCM và lưu trong volume `ai_data`; không nằm trong database nghiệp vụ.
- Tool agent luôn dùng token tài xế được backend chuyển tiếp nên chỉ đọc dữ liệu thuộc tài khoản đang đăng nhập.
- `/health` là endpoint duy nhất công khai trong mạng container; cổng AI chỉ được publish trong compose phát triển.

## Bằng chứng hiện tại

- Chạy `python -m pytest` để kiểm tra API, OCR contract, intent, mã hóa cấu hình và vòng lặp agent.
- Benchmark 10.000 vòng: p95 khoảng 0,006 ms trên máy phát triển.
- Sample evaluation: precision/recall/F1 = 1,0.
- Flutter đóng gói bản TFLite tối ưu mobile của checkpoint STGT. Exact GELU `FlexErf` được thay bằng xấp xỉ `TANH` built-in để chạy bằng LiteRT gọn nhẹ; ML Kit temporal không ghi đè điểm STGT và chỉ dùng cho chế độ temporal/chạy nền.

Kết quả sample chứng minh pipeline chạy, không đại diện độ chính xác ngoài thực địa. STGT vẫn cần dataset cabin có consent, chia train/validation/test và pilot trên thiết bị mục tiêu; adapter Flutter hiện chưa có iris landmark tương thích MediaPipe gốc.
