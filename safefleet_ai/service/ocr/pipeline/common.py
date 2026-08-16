from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

import cv2
import numpy as np


@dataclass(frozen=True)
class OcrLine:
    text: str
    left: int
    top: int
    right: int
    bottom: int
    confidence: float

    @property
    def height(self) -> int:
        return max(1, self.bottom - self.top)


def fold(value: str) -> str:
    value = unicodedata.normalize("NFD", value).lower().replace("đ", "d")
    value = "".join(character for character in value if not unicodedata.combining(character))
    return re.sub(r"[^a-z0-9]+", " ", value).strip()


def order_points(points: np.ndarray) -> np.ndarray:
    points = points.astype("float32")
    result = np.zeros((4, 2), dtype="float32")
    sums = points.sum(axis=1)
    differences = np.diff(points, axis=1).reshape(-1)
    result[0] = points[np.argmin(sums)]
    result[2] = points[np.argmax(sums)]
    result[1] = points[np.argmin(differences)]
    result[3] = points[np.argmax(differences)]
    return result


def warp_document(image: np.ndarray) -> np.ndarray:
    """Detect the sheet generically and rectify it without knowing its contents."""
    height, width = image.shape[:2]
    scale = min(1.0, 1400.0 / max(height, width))
    preview = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    gray = cv2.cvtColor(preview, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    # Ngưỡng tương đối thấp giữ lại cả mép giấy bị bóng tối. Các nếp gấp có
    # thể làm contour có hơn bốn đỉnh, nên tăng epsilon dần để lấy tứ giác.
    _, bright = cv2.threshold(gray, 105, 255, cv2.THRESH_BINARY)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (19, 19))
    mask = cv2.morphologyEx(bright, cv2.MORPH_CLOSE, kernel, iterations=2)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return image
    candidates = sorted(contours, key=cv2.contourArea, reverse=True)
    page = next(
        (contour for contour in candidates if cv2.contourArea(contour) > preview.size * 0.035),
        candidates[0],
    )
    perimeter = cv2.arcLength(page, True)
    polygon = None
    for epsilon in (0.02, 0.03, 0.04, 0.045, 0.05, 0.06):
        candidate = cv2.approxPolyDP(page, epsilon * perimeter, True)
        if len(candidate) == 4:
            polygon = candidate
            break
    if polygon is None:
        polygon = cv2.approxPolyDP(page, 0.025 * perimeter, True)
    if len(polygon) == 4:
        points = polygon.reshape(4, 2).astype("float32") / scale
    else:
        rectangle = cv2.minAreaRect(page)
        points = cv2.boxPoints(rectangle).astype("float32") / scale

    top_left, top_right, bottom_right, bottom_left = order_points(points)
    target_width = int(
        max(np.linalg.norm(bottom_right - bottom_left), np.linalg.norm(top_right - top_left))
    )
    target_height = int(
        max(np.linalg.norm(top_right - bottom_right), np.linalg.norm(top_left - bottom_left))
    )
    if target_width < width * 0.35 or target_height < height * 0.35:
        return image
    destination = np.array(
        [[0, 0], [target_width - 1, 0], [target_width - 1, target_height - 1], [0, target_height - 1]],
        dtype="float32",
    )
    matrix = cv2.getPerspectiveTransform(
        np.array([top_left, top_right, bottom_right, bottom_left], dtype="float32"),
        destination,
    )
    return cv2.warpPerspective(
        image,
        matrix,
        (target_width, target_height),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_REPLICATE,
    )


def enhance_for_ocr(image: np.ndarray, upscale: float = 2.0) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    background = cv2.GaussianBlur(gray, (0, 0), sigmaX=19, sigmaY=19)
    normalized = cv2.divide(gray, background, scale=245)
    normalized = cv2.createCLAHE(clipLimit=1.7, tileGridSize=(8, 8)).apply(normalized)
    if upscale != 1:
        normalized = cv2.resize(
            normalized, None, fx=upscale, fy=upscale, interpolation=cv2.INTER_CUBIC
        )
    return cv2.fastNlMeansDenoising(normalized, None, 7, 7, 21)


def rotate_right_angle(image: np.ndarray, angle: int) -> np.ndarray:
    return {
        0: image,
        90: cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE),
        180: cv2.rotate(image, cv2.ROTATE_180),
        270: cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE),
    }[angle]
