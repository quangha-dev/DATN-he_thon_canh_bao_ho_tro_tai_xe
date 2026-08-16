from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import cv2
import pytesseract


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "server"
sys.path.insert(0, str(SERVER))

from common import enhance_for_ocr, warp_document  # noqa: E402
from run_tesseract import choose_orientation, extract_project, lines_from_data  # noqa: E402


DEFAULT_TESSERACT = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
DEFAULT_TESSDATA = ROOT / "models" / "tessdata_fast"


def run(image_path: Path, output_path: Path, tessdata: Path) -> dict:
    started = time.perf_counter()
    source = cv2.imread(str(image_path))
    if source is None:
        raise FileNotFoundError(image_path)
    height, width = source.shape[:2]
    scale = min(1.0, 1280 / max(height, width))
    if scale < 1:
        source = cv2.resize(source, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)

    # Mô phỏng ngân sách mobile: model fast, ảnh giới hạn 1280 px, chỉ một
    # lượt OCR cuối và tăng cường nhẹ; không dùng VietOCR hoặc ensemble theo dòng.
    page = warp_document(source)
    _, orientation, oriented, _ = choose_orientation(page, tessdata)
    prepared = enhance_for_ocr(oriented, upscale=1.25)
    lines = lines_from_data(prepared, tessdata, psm=11)
    payload = {
        "engine": "mobile_simulation_tesseract_fast_vie_eng",
        "simulation": True,
        "limitations": [
            "Không phải phép đo Google ML Kit thật",
            "Giới hạn cạnh dài 1280 px",
            "Không có VietOCR và dewarp riêng từng dòng",
        ],
        "elapsed_ms": round((time.perf_counter() - started) * 1000),
        "orientation_degrees": orientation,
        "fields": {"project_address": extract_project(lines)},
        "raw_lines": [line.__dict__ for line in lines],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "results" / "mobile_simulation.json")
    parser.add_argument("--tesseract", type=Path, default=DEFAULT_TESSERACT)
    parser.add_argument("--tessdata", type=Path, default=DEFAULT_TESSDATA)
    args = parser.parse_args()
    pytesseract.pytesseract.tesseract_cmd = str(args.tesseract)
    os.environ["TESSDATA_PREFIX"] = str(args.tessdata.resolve())
    print(json.dumps(run(args.image, args.output, args.tessdata), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
