from pathlib import Path

from service.rag.knowledge_base import KnowledgeBase


def test_policy_corpus_has_unique_structured_citations(monkeypatch) -> None:
    corpus = Path(__file__).resolve().parents[1] / "knowledge"
    monkeypatch.setenv("RAG_CORPUS_PATH", str(corpus))
    knowledge_base = KnowledgeBase()

    documents = knowledge_base._load_documents()

    assert len(documents) >= 5
    assert len({document.key for document in documents}) == len(documents)
    assert all(document.version for document in documents)
    assert all(document.chunks for document in documents)
    assert all(
        "Điều" in chunk.heading_path and "Khoản" in chunk.heading_path
        for document in documents
        for chunk in document.chunks
        if "Khoản" in chunk.heading_path
    )


def test_markdown_chunking_keeps_atomic_heading_path() -> None:
    chunks = KnowledgeBase._chunk_markdown(
        "SF-TEST",
        "# Quy chế\n## Điều 1. Hỗ trợ\n### Khoản 1. Mức chi\nTối đa 50.000 đồng.",
    )

    assert len(chunks) == 1
    assert chunks[0].heading_path == "Quy chế > Điều 1. Hỗ trợ > Khoản 1. Mức chi"
    assert chunks[0].content == "Tối đa 50.000 đồng."
