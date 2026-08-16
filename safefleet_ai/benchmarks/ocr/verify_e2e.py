from __future__ import annotations

import argparse
import json
import mimetypes
import secrets
import sys
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DEFAULT_IMAGE = Path(r"C:\Users\ADMIN\Downloads\phieutest.jpg")


def normalize(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).split())


def request_json(request: urllib.request.Request, timeout: float) -> dict:
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {body}") from error


def login(base_url: str, username: str, password: str, timeout: float) -> str:
    body = json.dumps(
        {"usernameOrEmail": username, "password": password}
    ).encode("utf-8")
    payload = request_json(
        urllib.request.Request(
            f"{base_url}/api/v1/auth/login",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        ),
        timeout,
    )
    token = payload.get("data", {}).get("accessToken")
    if not token:
        raise RuntimeError(f"Đăng nhập không trả access token: {payload}")
    return str(token)


def multipart_image(image_path: Path) -> tuple[bytes, str]:
    boundary = f"----SafeFleetOcr{secrets.token_hex(12)}"
    mime_type = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
    chunks = [
        f"--{boundary}\r\n".encode(),
        (
            'Content-Disposition: form-data; name="file"; '
            f'filename="{image_path.name}"\r\n'
        ).encode(),
        f"Content-Type: {mime_type}\r\n\r\n".encode(),
        image_path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    return b"".join(chunks), boundary


def recognize(
    base_url: str, token: str, image_path: Path, timeout: float
) -> tuple[str, dict]:
    body, boundary = multipart_image(image_path)
    payload = request_json(
        urllib.request.Request(
            f"{base_url}/api/v1/mobile/documents/ocr",
            data=body,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            },
            method="POST",
        ),
        timeout,
    )
    actual = payload.get("data", {}).get("projectAddress")
    if not isinstance(actual, str):
        raise RuntimeError(f"API không trả projectAddress: {payload}")
    return actual, payload


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Acceptance gate OCR qua đúng luồng app -> backend -> AI service"
    )
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE)
    parser.add_argument(
        "--ground-truth",
        type=Path,
        default=ROOT / "fixtures" / "ground_truth.json",
    )
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()

    expected = json.loads(
        args.ground_truth.resolve().read_text(encoding="utf-8")
    )["fields"]["project_address"]
    token = login(args.base_url.rstrip("/"), args.username, args.password, args.timeout)
    actual, payload = recognize(
        args.base_url.rstrip("/"), token, args.image.resolve(), args.timeout
    )
    passed = normalize(actual) == normalize(expected)
    report = {
        "image": str(args.image.resolve()),
        "expected": expected,
        "actual": actual,
        "exact_match": passed,
        "engine": payload.get("data", {}).get("engine"),
        "elapsed_ms": payload.get("data", {}).get("elapsedMs"),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
