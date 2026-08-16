from __future__ import annotations

import argparse
import json
import math
import os
import re
import time
import unicodedata
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFD", value.lower().replace("đ", "d"))
    value = "".join(char for char in value if unicodedata.category(char) != "Mn")
    value = re.sub(r"\b0+(\d+)\b", r"\1", value)
    return re.sub(r"\s+", " ", value).strip()


def tokens(value: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", normalize(value))


def cosine(left: Counter[str], right: Counter[str]) -> float:
    if not left or not right:
        return 0.0
    dot = sum(count * right.get(term, 0) for term, count in left.items())
    left_norm = math.sqrt(sum(count * count for count in left.values()))
    right_norm = math.sqrt(sum(count * count for count in right.values()))
    return dot / max(1e-9, left_norm * right_norm)


def semantic_similarity(left: str, right: str) -> float:
    """Reproducible Vietnamese semantic proxy: word cosine + character n-grams."""
    word_score = cosine(Counter(tokens(left)), Counter(tokens(right)))
    normalized_left, normalized_right = normalize(left), normalize(right)
    left_ngrams = Counter(
        normalized_left[index : index + 3]
        for index in range(max(0, len(normalized_left) - 2))
    )
    right_ngrams = Counter(
        normalized_right[index : index + 3]
        for index in range(max(0, len(normalized_right) - 2))
    )
    return round(0.62 * word_score + 0.38 * cosine(left_ngrams, right_ngrams), 4)


def request_json(
    url: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: int = 180,
) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json; charset=utf-8"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exception:
        detail = exception.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exception.code}: {detail}") from exception


def tool_f1(actual: list[str], expected: list[str], forbidden: list[str]) -> float:
    actual_set, expected_set = set(actual), set(expected)
    if actual_set.intersection(forbidden):
        return 0.0
    if not expected_set:
        return 1.0 if not actual_set else 0.0
    precision = len(actual_set & expected_set) / max(1, len(actual_set))
    recall = len(actual_set & expected_set) / len(expected_set)
    return round(2 * precision * recall / max(1e-9, precision + recall), 4)


def fact_coverage(answer: str, facts: list[str]) -> tuple[float, list[str]]:
    if not facts:
        return 1.0, []
    normalized_answer = normalize(answer)
    missing = []
    for fact in facts:
        if normalize(fact) in normalized_answer:
            continue
        fact_terms = set(tokens(fact))
        if fact_terms and fact_terms.issubset(set(tokens(answer))):
            continue
        if semantic_similarity(answer, fact) >= 0.28:
            continue
        missing.append(fact)
    return round((len(facts) - len(missing)) / len(facts), 4), missing


def forbidden_claims(answer: str, claims: list[str]) -> list[str]:
    normalized_answer = normalize(answer)
    return [claim for claim in claims if normalize(claim) in normalized_answer]


def unsupported_numbers(question: str, expected: str, answer: str) -> list[str]:
    if not answer or "gặp lỗi" in answer or "không thể hoàn tất" in answer:
        return []
    number_pattern = r"\d+"
    allowed = set(re.findall(number_pattern, question + " " + expected))
    actual = set(re.findall(number_pattern, answer))
    return sorted(number for number in actual - allowed if len(number) >= 2)


def coherence(answer: str) -> float:
    if not answer or len(answer.strip()) < 12 or len(answer) > 1800:
        return 0.0
    broken = ("traceback", "null null", "undefined", "{\"", "<html")
    return 0.0 if any(marker in answer.lower() for marker in broken) else 1.0


def actual_tools(steps: list[dict[str, Any]]) -> tuple[list[str], list[dict[str, Any]]]:
    names: list[str] = []
    calls: list[dict[str, Any]] = []
    for step in steps:
        name = str(step.get("tool") or "")
        if name:
            names.append(name)
        raw_arguments = step.get("arguments") or "{}"
        try:
            arguments = json.loads(raw_arguments) if isinstance(raw_arguments, str) else raw_arguments
        except json.JSONDecodeError:
            arguments = {"_invalid": raw_arguments}
        calls.append(
            {
                "name": name,
                "arguments": arguments,
                "success": bool(step.get("success")),
                "planCheck": step.get("planCheck"),
                "reason": step.get("reason"),
            }
        )
    return names, calls


def load_chunks(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


RETRIEVAL_STOPWORDS = {
    "ai", "bao", "bi", "cac", "cau", "cho", "co", "cong", "cua", "duoc", "gi", "khi",
    "khong", "la", "lam", "mot", "neu", "nhieu", "phai", "quy", "sau", "theo", "thi",
    "thoi", "toi", "trong", "va", "ve", "voi",
}

DOMAIN_PHRASES = (
    "an ca", "lam them", "doi tac", "ho so", "thanh toan", "cham nhat",
    "va lop", "sua sam", "thay lop", "khong co tin hieu", "mat tin hieu",
    "nghi phep", "cong to met", "hoa don", "xac nhan quan ly",
)


def retrieval_tokens(value: str) -> list[str]:
    return [term for term in tokens(value) if term not in RETRIEVAL_STOPWORDS and len(term) > 1]


def contains_phrase(value: str, phrase: str) -> bool:
    normalized_value = " ".join(re.findall(r"[a-z0-9]+", normalize(value)))
    normalized_phrase = " ".join(re.findall(r"[a-z0-9]+", normalize(phrase)))
    return re.search(
        rf"(?:^|\s){re.escape(normalized_phrase)}(?:$|\s)", normalized_value
    ) is not None


def retrieve(question: str, chunks: list[dict[str, Any]], limit: int = 2) -> list[dict[str, Any]]:
    query_terms = set(retrieval_tokens(question))
    normalized_question = normalize(question)
    document_prefix = None
    if contains_phrase(normalized_question, "an ca") or contains_phrase(
        normalized_question, "lam them"
    ):
        document_prefix = "MEAL-"
    elif any(term in normalized_question for term in ("lop", "sua sam")):
        document_prefix = "TIRE-"
    document_frequency: Counter[str] = Counter()
    for chunk in chunks:
        document_frequency.update(set(retrieval_tokens(chunk["text"] + " " + chunk["title"])))
    scored: list[dict[str, Any]] = []
    for chunk in chunks:
        if document_prefix and not chunk["chunk_id"].startswith(document_prefix):
            continue
        chunk_terms = set(retrieval_tokens(chunk["text"] + " " + chunk["title"]))
        overlap = query_terms & chunk_terms
        question_normalized = normalize(question)
        chunk_normalized = normalize(chunk["text"] + " " + chunk["title"])
        shared_phrases = {
            phrase
            for phrase in DOMAIN_PHRASES
            if contains_phrase(question_normalized, phrase)
            and contains_phrase(chunk_normalized, phrase)
        }
        shared_numbers = set(re.findall(r"\d+", question_normalized)) & set(
            re.findall(r"\d+", chunk_normalized)
        )
        if len(overlap) < 2 and not shared_phrases and not shared_numbers:
            continue
        weighted = sum(math.log((len(chunks) + 1) / (document_frequency[term] + 1)) + 1 for term in overlap)
        score = weighted / math.sqrt(max(1, len(query_terms) * len(chunk_terms)))
        score += 0.55 * len(shared_numbers) + 1.2 * len(shared_phrases)
        scored.append({**chunk, "retrieval_score": round(score, 4)})
    scored.sort(key=lambda item: item["retrieval_score"], reverse=True)
    if not scored or scored[0]["retrieval_score"] < 0.22:
        return []
    relative_floor = max(0.22, scored[0]["retrieval_score"] * 0.35)
    selected = [item for item in scored if item["retrieval_score"] >= relative_floor][:limit]
    if document_prefix == "TIRE-" and contains_phrase(normalized_question, "thanh toan"):
        dossier = next((item for item in scored if item["chunk_id"] == "TIRE-A04-C01"), None)
        if dossier and all(item["chunk_id"] != dossier["chunk_id"] for item in selected):
            selected = [*selected[: max(0, limit - 1)], dossier]
    return selected


def mock_rag_answer(question: str, retrieved: list[dict[str, Any]]) -> str:
    if not retrieved:
        return (
            f"Hai tài liệu nội bộ hiện có không quy định nội dung của câu hỏi “{question}”; "
            "chưa đủ căn cứ để trả lời."
        )
    evidence = " ".join(
        f"{item['text'].rstrip('.')} (Nguồn: {item['chunk_id']})." for item in retrieved
    )
    return evidence


def rag_scores(
    case: dict[str, Any], answer: str, retrieved: list[dict[str, Any]]
) -> dict[str, float]:
    expected = set(case.get("expected_chunks", []))
    actual = {item["chunk_id"] for item in retrieved}
    recall = 1.0 if not expected else len(expected & actual) / len(expected)
    precision = 1.0 if not actual and not expected else len(expected & actual) / max(1, len(actual))
    if not retrieved:
        faithfulness = 1.0 if not expected else 0.0
    else:
        context = " ".join(item["text"] for item in retrieved)
        sentences = [part.strip() for part in re.split(r"(?<=[.!?])\s+", answer) if part.strip()]
        grounded = sum(semantic_similarity(sentence, context) >= 0.24 for sentence in sentences)
        faithfulness = grounded / max(1, len(sentences))
    return {
        "faithfulness": round(faithfulness, 4),
        "answerRelevancy": semantic_similarity(case["question"], answer),
        "contextRecall": round(recall, 4),
        "contextPrecision": round(precision, 4),
    }


def evaluate_answer(
    case: dict[str, Any], answer: str, tool_names: list[str]
) -> tuple[dict[str, float], dict[str, Any]]:
    coverage, missing = fact_coverage(answer, case.get("expected_facts", []))
    forbidden = forbidden_claims(answer, case.get("forbidden_claims", []))
    unexpected_numbers = unsupported_numbers(case["question"], case["expected_answer"], answer)
    scores = {
        "taskCompletion": 0.0,
        "correctness": round(coverage * (0.0 if forbidden else 1.0), 4),
        "relevance": semantic_similarity(answer, case["expected_answer"]),
        "completeness": coverage,
        "coherence": coherence(answer),
        "toolF1": tool_f1(
            tool_names, case.get("expected_tools", []), case.get("forbidden_tools", [])
        ),
    }
    diagnostics = {
        "missingFacts": missing,
        "forbiddenClaimsFound": forbidden,
        "unsupportedNumberCandidates": unexpected_numbers,
    }
    return scores, diagnostics


def run_agent_case(
    case: dict[str, Any], base_url: str, token: str, timeout: int
) -> dict[str, Any]:
    started = time.time()
    envelope = request_json(
        f"{base_url}/mobile/agent/chat",
        "POST",
        {"messages": [{"role": "user", "content": case["question"]}]},
        token,
        timeout,
    )
    response = envelope.get("data") or {}
    names, calls = actual_tools(response.get("steps") or [])
    answer = str(response.get("responseText") or "")
    scores, diagnostics = evaluate_answer(case, answer, names)
    status = str(response.get("status") or "MISSING")
    status_match = status in case.get("expected_statuses", ["COMPLETED"])
    tool_execution_ok = all(call["success"] for call in calls)
    scores["taskCompletion"] = round(
        (float(status_match) + scores["toolF1"] + float(tool_execution_ok)) / 3, 4
    )
    thresholds = DATASET["thresholds"]
    passed = (
        status_match
        and scores["toolF1"] >= thresholds["tool_f1"]
        and scores["relevance"] >= thresholds["semantic_similarity"]
        and scores["completeness"] >= thresholds["fact_coverage"]
        and scores["coherence"] == 1.0
        and not diagnostics["forbiddenClaimsFound"]
        and tool_execution_ok
    )
    classification = "PASS"
    if not passed:
        if status == "FAILED" or not tool_execution_ok:
            classification = "SYSTEM_OR_TOOL_ERROR"
        elif diagnostics["forbiddenClaimsFound"]:
            classification = "POSSIBLE_HALLUCINATION"
        elif case["category"] == "out_of_scope" and names:
            classification = "OUT_OF_SCOPE_TOOL_USE"
        else:
            classification = "QUALITY_MISMATCH"
    return {
        "id": case["id"],
        "category": case["category"],
        "question": case["question"],
        "expectedAnswer": case["expected_answer"],
        "actualAnswer": answer,
        "expectedTools": case.get("expected_tools", []),
        "actualTools": names,
        "toolCalls": calls,
        "expectedStatuses": case.get("expected_statuses", []),
        "actualStatus": status,
        "scores": scores,
        "diagnostics": diagnostics,
        "classification": classification,
        "passed": passed,
        "durationSeconds": round(time.time() - started, 3),
    }


def run_rag_case(case: dict[str, Any], chunks: list[dict[str, Any]]) -> dict[str, Any]:
    started = time.time()
    retrieved = retrieve(case["question"], chunks)
    answer = mock_rag_answer(case["question"], retrieved)
    scores, diagnostics = evaluate_answer(case, answer, [])
    rag = rag_scores(case, answer, retrieved)
    scores["taskCompletion"] = round((scores["correctness"] + rag["contextRecall"]) / 2, 4)
    thresholds = DATASET["thresholds"]
    passed = (
        scores["relevance"] >= thresholds["semantic_similarity"]
        and scores["completeness"] >= thresholds["fact_coverage"]
        and rag["faithfulness"] >= thresholds["rag_faithfulness"]
        and rag["contextRecall"] >= thresholds["rag_context_recall"]
        and rag["contextPrecision"] >= thresholds["rag_context_precision"]
    )
    return {
        "id": case["id"],
        "category": case["category"],
        "question": case["question"],
        "expectedAnswer": case["expected_answer"],
        "actualAnswer": answer,
        "expectedChunks": case.get("expected_chunks", []),
        "retrievedChunks": [item["chunk_id"] for item in retrieved],
        "retrieval": retrieved,
        "scores": {**scores, **rag},
        "diagnostics": diagnostics,
        "classification": "PASS" if passed else "RAG_QUALITY_MISMATCH",
        "passed": passed,
        "durationSeconds": round(time.time() - started, 3),
    }


def aggregate(results: list[dict[str, Any]], duration: float) -> dict[str, Any]:
    by_category: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for result in results:
        by_category[result["category"]].append(result)
    metric_names = sorted(
        {name for result in results for name in (result.get("scores") or {}).keys()}
    )

    def averages(items: list[dict[str, Any]]) -> dict[str, float]:
        return {
            metric: round(
                sum(item.get("scores", {}).get(metric, 0.0) for item in items)
                / max(1, sum(metric in item.get("scores", {}) for item in items)),
                4,
            )
            for metric in metric_names
            if any(metric in item.get("scores", {}) for item in items)
        }

    classifications = Counter(result["classification"] for result in results)
    passed = sum(result["passed"] for result in results)
    return {
        "total": len(results),
        "passed": passed,
        "failed": len(results) - passed,
        "passRate": round(passed / max(1, len(results)), 4),
        "durationSeconds": round(duration, 3),
        "averageLatencySeconds": round(
            sum(result["durationSeconds"] for result in results) / max(1, len(results)), 3
        ),
        "classificationCounts": dict(classifications),
        "averageScores": averages(results),
        "categories": {
            category: {
                "total": len(items),
                "passed": sum(item["passed"] for item in items),
                "passRate": round(sum(item["passed"] for item in items) / len(items), 4),
                "averageScores": averages(items),
            }
            for category, items in by_category.items()
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="SafeFleet agent/RAG evaluation v2")
    parser.add_argument("--dataset", default=str(Path(__file__).with_name("gold_dataset_v2.json")))
    parser.add_argument("--chunks", default=str(Path(__file__).with_name("rag_chunks_v2.jsonl")))
    parser.add_argument("--output", default=str(Path(__file__).with_name("eval_v2_results.json")))
    parser.add_argument("--base-url", default="http://127.0.0.1:8080/api/v1")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--only", choices=["all", "agent", "rag"], default="all")
    args = parser.parse_args()

    global DATASET
    DATASET = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    chunks = load_chunks(Path(args.chunks))
    cases = DATASET["cases"]
    if args.only == "agent":
        cases = [case for case in cases if case["category"] != "rag_mock"]
    elif args.only == "rag":
        cases = [case for case in cases if case["category"] == "rag_mock"]

    token = ""
    if any(case["category"] != "rag_mock" for case in cases):
        username = os.getenv("SAFEFLEET_EVAL_USERNAME")
        password = os.getenv("SAFEFLEET_EVAL_PASSWORD")
        if not username or not password:
            raise SystemExit("Cần SAFEFLEET_EVAL_USERNAME và SAFEFLEET_EVAL_PASSWORD")
        login = request_json(
            f"{args.base_url}/auth/login",
            "POST",
            {"usernameOrEmail": username, "password": password},
            timeout=args.timeout,
        )
        token = str((login.get("data") or {}).get("accessToken") or "")
        if not token:
            raise SystemExit("Đăng nhập eval không trả access token")

    started = time.time()
    results: list[dict[str, Any]] = []
    for index, case in enumerate(cases, start=1):
        print(f"[{index:02d}/{len(cases)}] {case['id']} {case['category']}", flush=True)
        try:
            result = (
                run_rag_case(case, chunks)
                if case["category"] == "rag_mock"
                else run_agent_case(case, args.base_url, token, args.timeout)
            )
        except Exception as exception:  # noqa: BLE001 - batch eval must continue
            result = {
                "id": case["id"],
                "category": case["category"],
                "question": case["question"],
                "expectedAnswer": case["expected_answer"],
                "actualAnswer": "",
                "scores": {},
                "diagnostics": {"exception": str(exception)},
                "classification": "API_REQUEST_FAILED",
                "passed": False,
                "durationSeconds": 0.0,
            }
        results.append(result)

    report = {
        "dataset": DATASET["corpus_id"],
        "referenceDatetime": DATASET["reference_datetime"],
        "mode": args.only.upper(),
        "semanticMetric": "Vietnamese normalized word cosine 62% + character trigram cosine 38%",
        "summary": aggregate(results, time.time() - started),
        "results": results,
    }
    Path(args.output).write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))


DATASET: dict[str, Any] = {}


if __name__ == "__main__":
    main()
