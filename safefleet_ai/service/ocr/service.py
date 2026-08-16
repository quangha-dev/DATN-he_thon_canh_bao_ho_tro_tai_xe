from __future__ import annotations

import os
import tempfile
import threading
from pathlib import Path
from typing import Any


_OCR_LOCK = threading.Lock()


def recognize_document(content: bytes, suffix: str = ".jpg") -> dict[str, Any]:
    """Run the resident server OCR pipeline; imports heavy ML libraries lazily."""
    try:
        from service.ocr.pipeline.run_hybrid import (
            DEFAULT_TESSDATA,
            DEFAULT_TESSERACT,
            run,
        )
    except ImportError:
        # Direct package execution fallback.
        from .pipeline.run_hybrid import (
            DEFAULT_TESSDATA,
            DEFAULT_TESSERACT,
            run,
        )
    import pytesseract

    pytesseract.pytesseract.tesseract_cmd = str(DEFAULT_TESSERACT)
    os.environ["TESSDATA_PREFIX"] = str(DEFAULT_TESSDATA.resolve())
    with _OCR_LOCK, tempfile.TemporaryDirectory(prefix="safefleet_ocr_") as directory:
        root = Path(directory)
        source = root / f"upload{suffix}"
        source.write_bytes(content)
        payload = run(
            source,
            root / "result.json",
            root / "debug",
            DEFAULT_TESSDATA,
        )
    return {
        "engine": payload["engine"],
        "elapsed_ms": payload["elapsed_ms"],
        "fields": payload["fields"],
    }
