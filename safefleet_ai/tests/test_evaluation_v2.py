from __future__ import annotations

import json
from pathlib import Path

from evaluation import run_eval_v2 as evaluator


ROOT = Path(__file__).parents[1]
EVALUATION = ROOT / "evaluation"


def test_gold_dataset_has_30_unique_cases_and_expected_groups() -> None:
    dataset = json.loads((EVALUATION / "gold_dataset_v2.json").read_text(encoding="utf-8"))
    cases = dataset["cases"]

    assert len(cases) == 30
    assert len({case["id"] for case in cases}) == 30
    assert sum(case["category"] == "rag_mock" for case in cases) == 6
    assert sum(case["category"] != "rag_mock" for case in cases) == 24


def test_legal_chunks_have_stable_article_clause_ids() -> None:
    chunks = evaluator.load_chunks(EVALUATION / "rag_chunks_v2.jsonl")

    assert len(chunks) == 12
    assert len({chunk["chunk_id"] for chunk in chunks}) == 12
    assert all(chunk["article"] >= 1 and chunk["clause"] >= 1 for chunk in chunks)
    assert {chunk["document"] for chunk in chunks} == {"01/2026/QĐ-SF", "02/2026/QĐ-SF"}


def test_mock_rag_passes_all_six_basic_cases() -> None:
    dataset = json.loads((EVALUATION / "gold_dataset_v2.json").read_text(encoding="utf-8"))
    evaluator.DATASET = dataset
    chunks = evaluator.load_chunks(EVALUATION / "rag_chunks_v2.jsonl")
    cases = [case for case in dataset["cases"] if case["category"] == "rag_mock"]

    results = [evaluator.run_rag_case(case, chunks) for case in cases]

    assert all(result["passed"] for result in results)
    assert results[-1]["retrievedChunks"] == []
    assert "chưa đủ căn cứ" in results[-1]["actualAnswer"]


def test_tool_and_semantic_metrics_are_deterministic() -> None:
    assert evaluator.tool_f1(["a", "b"], ["a", "b"], []) == 1.0
    assert evaluator.tool_f1(["forbidden"], [], ["forbidden"]) == 0.0
    assert evaluator.semantic_similarity("Điểm an toàn là 24", "Điểm an toàn là 24") == 1.0
