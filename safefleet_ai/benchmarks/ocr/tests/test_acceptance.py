from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AI_ROOT = ROOT.parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(AI_ROOT))

from compare import normalize  # noqa: E402
import pytesseract  # noqa: E402
from service.ocr.pipeline.run_hybrid import DEFAULT_TESSERACT, run  # noqa: E402


class OcrAcceptanceTest(unittest.TestCase):
    def test_phieutest_project_address_exact_match(self) -> None:
        pytesseract.pytesseract.tesseract_cmd = str(DEFAULT_TESSERACT)
        tessdata = AI_ROOT / "models" / "ocr" / "tessdata_best"
        os.environ["TESSDATA_PREFIX"] = str(tessdata.resolve())
        expected = json.loads(
            (ROOT / "fixtures" / "ground_truth.json").read_text(encoding="utf-8")
        )["fields"]["project_address"]
        with tempfile.TemporaryDirectory(prefix="safefleet_ocr_acceptance_") as directory:
            temporary = Path(directory)
            payload = run(
                ROOT / "fixtures" / "phieutest.jpg",
                temporary / "result.json",
                temporary / "debug",
                tessdata,
            )
        self.assertEqual(normalize(payload["fields"]["project_address"]), normalize(expected))

    def test_phieutest2_project_address_exact_match(self) -> None:
        image = Path.home() / "Downloads" / "phieutest2.jpg"
        if not image.is_file():
            self.skipTest(f"Missing local acceptance fixture: {image}")
        pytesseract.pytesseract.tesseract_cmd = str(DEFAULT_TESSERACT)
        tessdata = AI_ROOT / "models" / "ocr" / "tessdata_best"
        os.environ["TESSDATA_PREFIX"] = str(tessdata.resolve())
        expected = json.loads(
            (ROOT / "fixtures" / "ground_truth_phieutest2.json").read_text(encoding="utf-8")
        )["fields"]["project_address"]
        with tempfile.TemporaryDirectory(prefix="safefleet_ocr_acceptance_2_") as directory:
            temporary = Path(directory)
            payload = run(
                image,
                temporary / "result.json",
                temporary / "debug",
                tessdata,
            )
        self.assertEqual(normalize(payload["fields"]["project_address"]), normalize(expected))

    def test_inference_does_not_import_ground_truth_or_contain_expected_value(self) -> None:
        expected_values = [
            json.loads(path.read_text(encoding="utf-8"))["fields"]["project_address"]
            for path in (ROOT / "fixtures").glob("ground_truth*.json")
        ]
        for source in (AI_ROOT / "service" / "ocr" / "pipeline").glob("*.py"):
            contents = source.read_text(encoding="utf-8")
            self.assertNotIn("ground_truth", contents, source.name)
            for expected in expected_values:
                self.assertNotIn(expected, contents, source.name)


if __name__ == "__main__":
    unittest.main()
