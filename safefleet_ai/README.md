# SafeFleet AI

Repo AI cung cấp hai phần:

1. FastAPI server cho intent fallback và model metadata.
2. Temporal safety engine/toolchain để hiệu chuẩn, đánh giá, benchmark và export classifier.

Camera cabin realtime luôn xử lý on-device trong Flutter; AI service không nhận video liên tục.

## Cấu trúc

- `service/main.py`: `/health`, `/models/metadata`, `/intent/classify`.
- `service/temporal.py`: drowsiness/phone temporal rules dùng trong test/evaluation.
- `models/safefleet_temporal_rules.json`: metadata canonical.
- `models/best_model_fold_1.pth`: checkpoint STGT fold 1 gốc.
- `models/drowsiness_model.onnx`: bản export trung gian của checkpoint STGT.
- `training/train_temporal_rules.py`: hiệu chuẩn threshold từ JSONL.
- `evaluation/evaluate_temporal_rules.py`: precision/recall/F1 theo sequence.
- `export/export_model.py`: export mobile metadata, ONNX hoặc TFLite.
- `scripts/benchmark.py`: latency benchmark.
- `tests`: 10 unit/API tests, gồm temporal rules, API, OpenAI structured fallback và fail-safe.

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

## Bằng chứng hiện tại

- 10/10 pytest PASS.
- Benchmark 10.000 vòng: p95 khoảng 0,006 ms trên máy phát triển.
- Sample evaluation: precision/recall/F1 = 1,0.
- Flutter đã đóng gói bản TFLite của checkpoint STGT và giữ ML Kit temporal làm fallback có thể chuyển đổi trên giao diện.

Kết quả sample chứng minh pipeline chạy, không đại diện độ chính xác ngoài thực địa. STGT vẫn cần dataset cabin có consent, chia train/validation/test và pilot trên thiết bị mục tiêu; adapter Flutter hiện chưa có iris landmark tương thích MediaPipe gốc.
