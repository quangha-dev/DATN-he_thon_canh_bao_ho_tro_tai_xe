from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import time
from collections import defaultdict
from pathlib import Path

import cv2
import pytesseract
from pytesseract import Output

try:
    from .common import OcrLine, enhance_for_ocr, fold, rotate_right_angle, warp_document
except ImportError:
    from common import OcrLine, enhance_for_ocr, fold, rotate_right_angle, warp_document


AI_ROOT = Path(__file__).resolve().parents[3]
ROOT = AI_ROOT
MODEL_ROOT = Path(os.getenv("OCR_MODEL_DIR", str(AI_ROOT / "models" / "ocr")))
DEFAULT_TESSERACT = Path(
    os.getenv(
        "TESSERACT_CMD",
        shutil.which("tesseract") or r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    )
)
DEFAULT_TESSDATA = MODEL_ROOT / "tessdata_best"


def similarity(first: str, second: str) -> float:
    first, second = fold(first), fold(second)
    if second in first:
        return 1.0
    previous = list(range(len(second) + 1))
    for row, left in enumerate(first, start=1):
        current = [row]
        for column, right in enumerate(second, start=1):
            current.append(
                min(current[-1] + 1, previous[column] + 1, previous[column - 1] + (left != right))
            )
        previous = current
    return 1 - previous[-1] / max(1, len(first), len(second))


def tesseract_config(tessdata: Path, psm: int) -> str:
    os.environ["TESSDATA_PREFIX"] = str(tessdata.resolve())
    return f'--oem 1 --psm {psm} -c preserve_interword_spaces=1'


def lines_from_data(image, tessdata: Path, psm: int = 11) -> list[OcrLine]:
    data = pytesseract.image_to_data(
        image,
        lang="vie+eng",
        config=tesseract_config(tessdata, psm),
        output_type=Output.DICT,
    )
    groups: dict[tuple[int, int, int], list[int]] = defaultdict(list)
    for index, text in enumerate(data["text"]):
        if text.strip():
            groups[(data["block_num"][index], data["par_num"][index], data["line_num"][index])].append(index)
    lines: list[OcrLine] = []
    for indexes in groups.values():
        indexes.sort(key=lambda index: data["left"][index])
        text = " ".join(data["text"][index].strip() for index in indexes)
        left = min(data["left"][index] for index in indexes)
        top = min(data["top"][index] for index in indexes)
        right = max(data["left"][index] + data["width"][index] for index in indexes)
        bottom = max(data["top"][index] + data["height"][index] for index in indexes)
        confidences = [float(data["conf"][index]) for index in indexes if float(data["conf"][index]) >= 0]
        lines.append(OcrLine(text, left, top, right, bottom, sum(confidences) / max(1, len(confidences))))
    return sorted(lines, key=lambda line: (line.top, line.left))


def orientation_score(lines: list[OcrLine]) -> float:
    text = " ".join(line.text for line in lines)
    anchors = ["phieu xuat kho", "ten cong trinh", "ngay", "so luong", "nguoi nhan hang"]
    anchor_score = sum(max(similarity(line.text, anchor) for line in lines) for anchor in anchors)
    confidence = sum(line.confidence for line in lines) / max(1, len(lines))
    return anchor_score * 150 + confidence + min(len(text), 1000) * 0.03


def choose_orientation(image, tessdata: Path):
    scored = []
    for angle in (0, 90, 180, 270):
        candidate = rotate_right_angle(image, angle)
        preview = enhance_for_ocr(candidate, upscale=1.25)
        lines = lines_from_data(preview, tessdata, psm=11)
        scored.append((orientation_score(lines), angle, candidate, lines))
    return max(scored, key=lambda item: item[0])


def strip_project_label(text: str) -> str:
    colon = text.find(":")
    folded = fold(text)
    if colon >= 0 and (
        similarity(text[:colon], "ten cong trinh") >= 0.55 or "xuat hang cho" in folded
    ):
        return text[colon + 1 :].strip(" -:;,.")
    match = re.search(r"(?i)\b(?:xu[aấ]t|nu[aấ]t)\s+h[aà]ng\s+cho\b", text)
    return text[match.start() :].strip(" -:;,.") if match else text.strip(" -:;,.")


def project_anchor_score(line: OcrLine) -> float:
    return max(
        similarity(line.text, "ten cong trinh"),
        similarity(line.text, "xuat hang cho"),
        similarity(line.text, "cong trinh xuat hang cho"),
    )


def extract_project(lines: list[OcrLine]) -> str:
    if not lines:
        return ""
    anchor_index = max(range(len(lines)), key=lambda index: project_anchor_score(lines[index]))
    anchor = lines[anchor_index]
    if project_anchor_score(anchor) < 0.5:
        return ""
    selected = [anchor]
    address_terms = (" pho ", " phuong ", " tinh ", " xa ", " huyen ", " quan ", " thanh pho ")
    for index, line in enumerate(lines):
        if index == anchor_index:
            continue
        vertical_gap = min(abs(line.top - anchor.bottom), abs(anchor.top - line.bottom))
        near = vertical_gap <= max(anchor.height, line.height) * 2.2
        looks_like_address = any(term in f" {fold(line.text)} " for term in address_terms)
        if near and looks_like_address:
            selected.append(line)
    selected.sort(key=lambda line: (line.top, line.left))
    # Anchor always starts the value; OCR engines occasionally emit a wrapped
    # continuation just above it, so append address-only lines after the anchor value.
    anchor_value = strip_project_label(anchor.text)
    continuations = [line.text.strip(" -:;,.") for line in selected if line is not anchor]
    value = " ".join([anchor_value, *continuations])
    value = re.sub(r"\s+", " ", value).strip()
    return value[:260]


def run(image_path: Path, output_path: Path, debug_dir: Path, tessdata: Path) -> dict:
    started = time.perf_counter()
    source = cv2.imread(str(image_path))
    if source is None:
        raise FileNotFoundError(image_path)
    page = warp_document(source)
    _, angle, oriented, orientation_lines = choose_orientation(page, tessdata)
    enhanced = enhance_for_ocr(oriented, upscale=2.0)
    lines = lines_from_data(enhanced, tessdata, psm=11)
    project = extract_project(lines)
    elapsed_ms = round((time.perf_counter() - started) * 1000)
    debug_dir.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(debug_dir / "server_page.jpg"), oriented)
    cv2.imwrite(str(debug_dir / "server_enhanced.png"), enhanced)
    payload = {
        "engine": "server_tesseract_best_vie_eng",
        "elapsed_ms": elapsed_ms,
        "orientation_degrees": angle,
        "fields": {"project_address": project},
        "raw_lines": [line.__dict__ for line in lines],
        "orientation_preview_lines": [line.__dict__ for line in orientation_lines],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "results" / "server_tesseract.json")
    parser.add_argument("--debug-dir", type=Path, default=ROOT / "results" / "debug")
    parser.add_argument("--tesseract", type=Path, default=DEFAULT_TESSERACT)
    parser.add_argument("--tessdata", type=Path, default=DEFAULT_TESSDATA)
    args = parser.parse_args()
    pytesseract.pytesseract.tesseract_cmd = str(args.tesseract)
    payload = run(args.image, args.output, args.debug_dir, args.tessdata)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
