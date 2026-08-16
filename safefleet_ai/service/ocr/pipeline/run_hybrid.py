from __future__ import annotations

import argparse
import datetime as dt
import functools
import json
import math
import os
import re
import time
import unicodedata
from collections import defaultdict
from pathlib import Path

import cv2
import numpy as np
import pytesseract
import yaml
from PIL import Image
from pytesseract import Output
from vietocr.tool.config import Cfg
from vietocr.tool.predictor import Predictor

try:
    from .common import OcrLine, enhance_for_ocr, fold, rotate_right_angle, warp_document
    from .run_tesseract import (
        DEFAULT_TESSDATA,
        DEFAULT_TESSERACT,
        MODEL_ROOT,
        choose_orientation,
        lines_from_data,
        project_anchor_score,
        similarity,
        tesseract_config,
    )
except ImportError:
    from common import OcrLine, enhance_for_ocr, fold, rotate_right_angle, warp_document
    from run_tesseract import (
        DEFAULT_TESSDATA,
        DEFAULT_TESSERACT,
        MODEL_ROOT,
        choose_orientation,
        lines_from_data,
        project_anchor_score,
        similarity,
        tesseract_config,
    )


ROOT = Path(__file__).resolve().parents[3]
VIETOCR_MODEL_DIR = MODEL_ROOT / "vietocr"
OSD_MODEL_DIR = MODEL_ROOT / "tessdata_osd"


def _ocr_digits(value: str) -> str:
    return re.sub(
        r"\D",
        "",
        value.lower()
        .replace("o", "0")
        .replace("i", "1")
        .replace("l", "1")
        .replace("s", "5")
        .replace("b", "8"),
    )


def _valid_date(day: str, month: str, year: str) -> str | None:
    try:
        parsed = dt.date(
            int(_ocr_digits(year)),
            int(_ocr_digits(month)),
            int(_ocr_digits(day)),
        )
    except (TypeError, ValueError):
        return None
    if not 2000 <= parsed.year <= 2100:
        return None
    return parsed.isoformat()


def extract_common_fields(lines: list[OcrLine], project_address: str) -> dict:
    """Extract stable header fields from the full-page OCR result.

    The previous server contract intentionally returned only the project field,
    which made a successful job look incomplete on mobile. Keep project OCR's
    specialized ensemble, while deriving the printed header values from the
    same oriented full-page Tesseract pass.
    """
    ordered = sorted(lines, key=lambda line: (line.top, line.left))
    raw_text = "\n".join(line.text.strip() for line in ordered if line.text.strip())
    normalized = fold(raw_text)

    voucher_date = None
    for pattern in (
        r"\bngay\s*([0-9oilsb]{1,2})\s*thang\s*([0-9oilsb]{1,2})\s*nam\s*([0-9oilsb]{4})\b",
        r"\b([0-9oilsb]{1,2})\s*[./-]\s*([0-9oilsb]{1,2})\s*[./-]\s*([0-9oilsb]{4})\b",
    ):
        for match in re.finditer(pattern, normalized, flags=re.IGNORECASE):
            voucher_date = _valid_date(*match.groups())
            if voucher_date:
                break
        if voucher_date:
            break

    voucher_number = ""
    # Avoid labels such as “Mẫu số” and “Mã số xe”; a voucher number normally
    # has at least four consecutive OCR digits and sits in the document header.
    for line in ordered:
        line_text = fold(line.text)
        if "mau so" in line_text or "ma so" in line_text:
            continue
        match = re.search(
            r"(?:^|\s)so\s*[:.]?\s*([0-9oilsb]{4,})\b",
            line_text,
            flags=re.IGNORECASE,
        )
        if match:
            candidate = _ocr_digits(match.group(1))
            if len(candidate) >= 4:
                voucher_number = candidate
                break

    vehicle_plate = ""
    plate_match = re.search(
        r"\b([0-9]{2})\s*([a-z])\s*[-.]?\s*([0-9]{3})\s*[.-]?\s*([0-9]{2})\b",
        normalized,
        flags=re.IGNORECASE,
    )
    if plate_match:
        vehicle_plate = "".join(plate_match.groups()).upper()

    driver_name = ""
    for line in ordered:
        if "ho ten nguoi nhan hang" not in fold(line.text):
            continue
        if line.confidence < 50:
            continue
        # Keep Vietnamese accents from the original OCR line.
        candidate = line.text.split(":", 1)[1] if ":" in line.text else ""
        candidate = re.split(
            r"\s+(?:địa\s*chỉ|xe\s*vận\s*chuyển|xuất\s*hàng\s*cho)\b",
            candidate,
            maxsplit=1,
            flags=re.IGNORECASE,
        )[0].strip(" -:;,.()")
        surname = fold(candidate).split()[0] if fold(candidate).split() else ""
        common_surnames = {
            "nguyen", "tran", "le", "pham", "hoang", "huynh", "phan",
            "vu", "vo", "dang", "bui", "do", "ho", "ngo", "duong", "ly",
        }
        if (
            2 <= len(candidate.split()) <= 7
            and surname in common_surnames
            and re.fullmatch(r"[A-Za-zÀ-ỹĐđ\s]+", candidate)
        ):
            driver_name = candidate
            break

    confidences = {
        "project_address": 0.99,
        "voucher_date": 0.93 if voucher_date else 0.0,
        "voucher_number": 0.90 if voucher_number else 0.0,
        "vehicle_plate": 0.92 if vehicle_plate else 0.0,
        "driver_name": 0.78 if driver_name else 0.0,
    }
    return {
        "project_address": project_address,
        "voucher_date": voucher_date,
        "voucher_number": voucher_number,
        "vehicle_plate": vehicle_plate,
        "driver_name": driver_name,
        "trip_count": 1,
        "raw_text": raw_text,
        "confidences": confidences,
    }


def load_vietocr_config() -> Cfg:
    with (VIETOCR_MODEL_DIR / "base.yml").open(encoding="utf-8") as stream:
        config = yaml.safe_load(stream)
    with (VIETOCR_MODEL_DIR / "vgg-transformer.yml").open(encoding="utf-8") as stream:
        config.update(yaml.safe_load(stream))
    config["device"] = "cpu"
    config["weights"] = str(VIETOCR_MODEL_DIR / "vgg_transformer.pth")
    config["cnn"]["pretrained"] = False
    config["predictor"]["beamsearch"] = False
    return Cfg(config)


@functools.lru_cache(maxsize=1)
def get_predictor() -> Predictor:
    """Giữ model trong RAM giữa các request của OCR service."""
    return Predictor(load_vietocr_config())


def choose_orientation_osd(page, content_tessdata: Path):
    try:
        os.environ["TESSDATA_PREFIX"] = str(OSD_MODEL_DIR.resolve())
        result = pytesseract.image_to_osd(
            page, config="--psm 0", output_type=Output.DICT
        )
        angle = int(result["rotate"])
        if angle not in (0, 90, 180, 270):
            raise ValueError(angle)
        return angle, rotate_right_angle(page, angle)
    except Exception:
        os.environ["TESSDATA_PREFIX"] = str(content_tessdata.resolve())
        _, angle, oriented, _ = choose_orientation(page, content_tessdata)
        return angle, oriented
    finally:
        os.environ["TESSDATA_PREFIX"] = str(content_tessdata.resolve())


def group_tesseract_lines(image, tessdata: Path) -> list[OcrLine]:
    data = pytesseract.image_to_data(
        image,
        lang="vie+eng",
        config=tesseract_config(tessdata, 6),
        output_type=Output.DICT,
    )
    grouped: dict[tuple[int, int, int], list[int]] = defaultdict(list)
    for index, text in enumerate(data["text"]):
        if text.strip():
            grouped[(data["block_num"][index], data["par_num"][index], data["line_num"][index])].append(index)
    result: list[OcrLine] = []
    for indexes in grouped.values():
        indexes.sort(key=lambda index: data["left"][index])
        confidences = [float(data["conf"][index]) for index in indexes if float(data["conf"][index]) >= 0]
        result.append(
            OcrLine(
                text=" ".join(data["text"][index].strip() for index in indexes),
                left=min(data["left"][index] for index in indexes),
                top=min(data["top"][index] for index in indexes),
                right=max(data["left"][index] + data["width"][index] for index in indexes),
                bottom=max(data["top"][index] + data["height"][index] for index in indexes),
                confidence=sum(confidences) / max(1, len(confidences)),
            )
        )
    return sorted(result, key=lambda line: (line.top, line.left))


def find_project_neighborhood(lines: list[OcrLine], width: int, height: int):
    anchor = max(lines, key=project_anchor_score)
    if project_anchor_score(anchor) < 0.5:
        raise RuntimeError("Không tìm thấy nhãn công trình")
    nearby = [anchor]
    for line in lines:
        if line is anchor:
            continue
        center_distance = abs(
            (line.top + line.bottom) / 2 - (anchor.top + anchor.bottom) / 2
        )
        same_zone = center_distance <= max(anchor.height, line.height) * 1.5
        right_continuation = line.left >= anchor.left and line.right > anchor.right
        address_line = any(
            token in f" {fold(line.text)} "
            for token in (" pho ", " phuong ", " duong ", " tinh ", " xa ", " huyen ")
        )
        if same_zone and (right_continuation or address_line):
            nearby.append(line)
    # Padding theo chiều cao chữ để không phụ thuộc độ phân giải ảnh.
    left = max(0, round(min(line.left for line in nearby) - anchor.height * 0.9))
    top = max(0, round(min(line.top for line in nearby) - anchor.height * 0.6))
    right = min(width, round(max(line.right for line in nearby) + anchor.height * 1.2))
    bottom = min(height, round(max(line.bottom for line in nearby) + anchor.height * 0.4))
    return anchor, nearby, (left, top, right, bottom)


def estimate_skew(anchor: OcrLine, nearby: list[OcrLine]) -> float:
    chain = [anchor]
    previous = anchor
    for line in sorted((line for line in nearby if line.left >= anchor.right - 10), key=lambda item: item.left):
        if line.left - previous.right > max(anchor.height, line.height) * 1.8:
            continue
        center_distance = abs(
            (line.top + line.bottom) / 2 - (anchor.top + anchor.bottom) / 2
        )
        if center_distance > max(anchor.height, line.height) * 1.2:
            continue
        chain.append(line)
        previous = line
    if len(chain) < 2:
        return 0.0
    x = np.array([(line.left + line.right) / 2 for line in chain], dtype=float)
    y = np.array([(line.top + line.bottom) / 2 for line in chain], dtype=float)
    slope = float(np.polyfit(x, y, 1)[0])
    return math.degrees(math.atan(slope))


def extract_geometric_project_block(image, lines: list[OcrLine], predictor: Predictor) -> str:
    """Read a wrapped project field by geometry when address words are abbreviated."""
    if not lines:
        return ""
    anchor = max(lines, key=project_anchor_score)
    if project_anchor_score(anchor) < 0.5:
        return ""

    boundary_labels = (
        "xuat tai kho",
        "hang muc",
        "ho ten nguoi nhan hang",
        "xe van chuyen",
        "ten nhan hieu",
        "so luong",
    )
    anchor_center = (anchor.top + anchor.bottom) / 2
    nearby: list[OcrLine] = []
    for line in lines:
        if line is anchor or line.confidence < 60:
            continue
        folded = fold(line.text)
        if any(similarity(folded, label) >= 0.68 for label in boundary_labels):
            continue
        center = (line.top + line.bottom) / 2
        if abs(center - anchor_center) > max(anchor.height, line.height) * 1.7:
            continue
        if line.right < anchor.left - anchor.height:
            continue
        visible = [character for character in line.text if not character.isspace()]
        alphanumeric_ratio = sum(character.isalnum() for character in visible) / max(
            1, len(visible)
        )
        if alphanumeric_ratio < 0.45:
            continue
        nearby.append(line)

    inline = [
        line
        for line in nearby
        if line.left >= anchor.right - anchor.height * 0.5
        and abs((line.top + line.bottom) / 2 - anchor_center)
        <= max(anchor.height, line.height) * 1.1
    ]
    inline.sort(key=lambda line: line.left)
    wrapped = [line for line in nearby if line not in inline]
    wrapped.sort(key=lambda line: (line.top, line.left))

    def recognize_line(line: OcrLine) -> str:
        pad = max(4, round(line.height * 0.12))
        height, width = image.shape[:2]
        crop = image[
            max(0, line.top - pad) : min(height, line.bottom + pad),
            max(0, line.left - pad) : min(width, line.right + pad),
        ]
        recognized, probability = predictor.predict(
            Image.fromarray(crop), return_prob=True
        )
        recognized = re.sub(r"\s+", " ", recognized).strip()
        if probability >= 0.78 and similarity(recognized, line.text) >= 0.68:
            return recognized
        return line.text

    parts = [
        strip_to_project_value(
            recognize_line(anchor), normalize_after_code=False
        )
    ]
    parts.extend(recognize_line(line).strip(" -:;,)") for line in inline)
    parts.extend(recognize_line(line).strip(" -:;,)") for line in wrapped)
    return re.sub(r"\s+", " ", " ".join(filter(None, parts))).strip()[:320]


def rotate(image, angle: float):
    height, width = image.shape[:2]
    matrix = cv2.getRotationMatrix2D((width / 2, height / 2), angle, 1)
    return cv2.warpAffine(image, matrix, (width, height), borderValue=255)


def strip_to_project_value(value: str, *, normalize_after_code: bool = True) -> str:
    value = re.sub(r"\s+", " ", value).strip(" -:;,.")
    # “Xuất hàng cho” là tên thao tác chung của biểu mẫu, không phải dữ liệu
    # công trình. Chỉ bỏ tiền tố khi ngay sau nó là một mã viết hoa.
    operation = re.search(r"(?i).*?\bcho\s+(?=[A-ZĐ]{2,}(?:\s|\b))", value)
    if operation:
        value = value[operation.end() :]
    elif ":" in value:
        value = value.split(":", 1)[1].strip()
    value = re.sub(r"^[^\wÀ-ỹ]+", "", value).strip()
    words = value.split()
    # Chuẩn hóa kiểu câu sau một mã đầu dòng (ví dụ mã loại công trình).
    if normalize_after_code and len(words) > 2 and words[0].isupper() and len(words[0]) <= 5:
        words[1] = words[1][:1].lower() + words[1][1:]
    return " ".join(words)


def address_score(viet_text: str, tesseract_text: str, probability: float) -> float:
    viet_words = viet_text.split()
    tess_words = tesseract_text.split()
    case_matches = 0
    for left, right in zip(viet_words, tess_words):
        if left[:1].isupper() == right[:1].isupper():
            case_matches += 1
    case_ratio = case_matches / max(1, min(len(viet_words), len(tess_words)))
    folded = f" {fold(viet_text)} "
    structure = sum(
        token in folded for token in (" pho ", " phuong ", " duong ", " tinh ")
    ) / 4
    alphabetic_words = [word for word in viet_words if any(character.isalpha() for character in word)]
    accented_words = sum(
        any(unicodedata.combining(character) for character in unicodedata.normalize("NFD", word))
        for word in alphabetic_words
    )
    accent_ratio = accented_words / max(1, len(alphabetic_words))
    return probability + 0.035 * case_ratio + 0.025 * structure + 0.14 * accent_ratio


def transfer_case(value: str, reference: str) -> str:
    words = value.split()
    reference_words = reference.split()
    if len(words) != len(reference_words):
        return value
    result = []
    for word, source in zip(words, reference_words):
        if source[:1].isupper():
            result.append(word[:1].upper() + word[1:])
        else:
            result.append(word[:1].lower() + word[1:])
    return " ".join(result)


def recognize_address_variant(
    rotated,
    lines: list[OcrLine],
    predictor: Predictor,
):
    address_terms = (" pho ", " phuong ", " duong ", " tinh ", " xa ", " huyen ")
    address = max(
        lines,
        key=lambda line: sum(term in f" {fold(line.text)} " for term in address_terms),
    )
    if not any(term in f" {fold(address.text)} " for term in address_terms):
        return None
    height, width = rotated.shape[:2]
    trim = round(address.height * 0.13)
    left = max(0, address.left - 28)
    top = max(0, address.top - trim)
    right = min(width, round(address.right + (address.right - address.left) * 0.25))
    bottom = min(height, max(top + 1, address.bottom - trim))
    crop = rotated[top:bottom, left:right]
    recognized, probability = predictor.predict(Image.fromarray(crop), return_prob=True)
    recognized = re.sub(r"\s+", " ", recognized).strip(" -:;,.")
    recognized = transfer_case(recognized, address.text)
    return recognized, float(probability), address.text, crop


def run(image_path: Path, output_path: Path, debug_dir: Path, tessdata: Path) -> dict:
    started = time.perf_counter()
    source = cv2.imread(str(image_path))
    if source is None:
        raise FileNotFoundError(image_path)
    page = warp_document(source)
    orientation, oriented = choose_orientation_osd(page, tessdata)
    preview = enhance_for_ocr(oriented, upscale=1.25)
    preview_lines = lines_from_data(preview, tessdata, psm=11)
    predictor = get_predictor()
    geometric_fallback = extract_geometric_project_block(
        preview, preview_lines, predictor
    )
    enhanced = enhance_for_ocr(oriented, upscale=2.0)
    full_lines = lines_from_data(enhanced, tessdata, psm=11)
    anchor, nearby, (left, top, right, bottom) = find_project_neighborhood(
        full_lines, enhanced.shape[1], enhanced.shape[0]
    )
    project_region = enhanced[top:bottom, left:right]
    base_angle = estimate_skew(anchor, nearby)

    candidates = []
    debug_dir.mkdir(parents=True, exist_ok=True)
    # Hai biên đối xứng quanh góc baseline: dòng dài và dòng xuống hàng có thể
    # lệch nhau vì giấy cong. Hai lượt đủ cho ensemble theo dòng và giảm nửa
    # số lần gọi OCR so với quét bốn góc liên tiếp.
    for offset in (-1, 1):
        angle = round(base_angle) + offset
        corrected = rotate(project_region, angle)
        local_lines = group_tesseract_lines(corrected, tessdata)
        if not local_lines:
            continue
        project_line = max(local_lines, key=project_anchor_score)
        if project_anchor_score(project_line) < 0.5:
            continue
        address_result = recognize_address_variant(corrected, local_lines, predictor)
        if address_result is None:
            continue
        address_text, probability, tesseract_address, address_crop = address_result
        project_value = strip_to_project_value(project_line.text)
        candidate_score = address_score(address_text, tesseract_address, probability)
        project_quality = min(len(project_value), 180) / 180
        project_quality += project_line.confidence / 500
        project_quality -= sum(
            not (character.isalnum() or character.isspace() or character in ",.-/")
            for character in project_value
        ) * 0.03
        candidates.append(
            {
                "angle": angle,
                "project": project_value,
                "address": address_text,
                "tesseract_address": tesseract_address,
                "vietocr_probability": probability,
                "address_score": candidate_score,
                "project_score": project_quality,
            }
        )
        cv2.imwrite(str(debug_dir / f"hybrid_address_{angle:+d}.png"), address_crop)
    if candidates:
        best_project = max(candidates, key=lambda item: item["project_score"])
        best_address = max(candidates, key=lambda item: item["address_score"])
        continuation = best_address["address"]
        if continuation:
            continuation = continuation[:1].lower() + continuation[1:]
        project_address = re.sub(
            r"\s+", " ", f'{best_project["project"]} {continuation}'
        ).strip()
        selected = {"project": best_project, "address": best_address}
        selection_mode = "hybrid_line_ensemble"
    elif geometric_fallback:
        project_address = geometric_fallback
        selected = {"geometric_fallback": geometric_fallback}
        selection_mode = "geometric_wrapped_field"
    else:
        raise RuntimeError("Không nhận dạng được vùng địa chỉ công trình")
    payload = {
        "engine": "server_hybrid_tesseract_best_vietocr",
        "elapsed_ms": round((time.perf_counter() - started) * 1000),
        "orientation_degrees": orientation,
        "estimated_local_skew": base_angle,
        "fields": extract_common_fields(full_lines, project_address),
        "selection_mode": selection_mode,
        "selected": selected,
        "candidates": candidates,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "results" / "server_hybrid.json")
    parser.add_argument("--debug-dir", type=Path, default=ROOT / "results" / "debug")
    parser.add_argument("--tesseract", type=Path, default=DEFAULT_TESSERACT)
    parser.add_argument("--tessdata", type=Path, default=DEFAULT_TESSDATA)
    args = parser.parse_args()
    pytesseract.pytesseract.tesseract_cmd = str(args.tesseract)
    os.environ["TESSDATA_PREFIX"] = str(args.tessdata.resolve())
    payload = run(args.image, args.output, args.debug_dir, args.tessdata)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
