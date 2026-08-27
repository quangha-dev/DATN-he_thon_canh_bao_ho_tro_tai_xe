from __future__ import annotations

import hashlib
import json
import os
import re
import threading
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any


class KnowledgeBaseError(RuntimeError):
    pass


@dataclass(frozen=True)
class KnowledgeChunk:
    key: str
    heading_path: str
    content: str
    content_hash: str
    token_estimate: int


@dataclass(frozen=True)
class KnowledgeDocument:
    key: str
    title: str
    version: str
    effective_date: date | None
    status: str
    source_uri: str
    content_hash: str
    metadata: dict[str, Any]
    chunks: tuple[KnowledgeChunk, ...]


class KnowledgeBase:
    """Synchronizes versioned Markdown policies and performs hybrid vector/text search."""

    def __init__(self) -> None:
        self.enabled = os.getenv("RAG_ENABLED", "true").lower() in {"1", "true", "yes"}
        self.corpus_path = Path(os.getenv("RAG_CORPUS_PATH", "/app/knowledge"))
        self.model_name = os.getenv(
            "RAG_EMBEDDING_MODEL", "intfloat/multilingual-e5-small"
        )
        self.model_cache = os.getenv("RAG_MODEL_CACHE", "/models/sentence-transformers")
        self._model: Any | None = None
        self._synchronized_signature: str | None = None
        self._lock = threading.RLock()

    def search(self, query: str, limit: int = 5) -> dict[str, Any]:
        normalized = " ".join(query.split()).strip()
        if not self.enabled:
            raise KnowledgeBaseError("Kho tài liệu nội bộ đang bị tắt bởi cấu hình RAG_ENABLED")
        if len(normalized) < 2:
            raise KnowledgeBaseError("Câu hỏi tra cứu quá ngắn")
        limit = max(1, min(10, int(limit)))
        self.synchronize()
        query_vector = self._encode([f"query: {normalized}"])[0]
        vector_literal = self._vector_literal(query_vector)
        try:
            with self._connect() as connection, connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT d.document_key,
                           d.title,
                           d.version,
                           d.effective_date,
                           c.chunk_key,
                           c.heading_path,
                           c.content,
                           1 - (c.embedding <=> %s::vector) AS semantic_score,
                           ts_rank_cd(c.search_vector, plainto_tsquery('simple', %s)) AS text_score
                    FROM knowledge_chunks c
                    JOIN knowledge_documents d ON d.id = c.document_id
                    WHERE d.status = 'ACTIVE'
                      AND (d.effective_date IS NULL OR d.effective_date <= CURRENT_DATE)
                    ORDER BY (
                        (1 - (c.embedding <=> %s::vector)) * 0.85
                        + LEAST(ts_rank_cd(
                            c.search_vector,
                            plainto_tsquery('simple', %s)
                        ), 1) * 0.15
                    ) DESC
                    LIMIT %s
                    """,
                    (vector_literal, normalized, vector_literal, normalized, limit),
                )
                rows = cursor.fetchall()
        except Exception as exception:
            raise KnowledgeBaseError(
                "Không thể tra cứu pgvector; hãy kiểm tra migration V15 và kết nối PostgreSQL"
            ) from exception

        citations = []
        for row in rows:
            semantic_score = float(row[7] or 0)
            text_score = float(row[8] or 0)
            citations.append(
                {
                    "documentKey": row[0],
                    "title": row[1],
                    "version": row[2],
                    "effectiveDate": row[3].isoformat() if row[3] else None,
                    "chunkKey": row[4],
                    "headingPath": row[5],
                    "content": row[6],
                    "score": round(semantic_score * 0.85 + min(text_score, 1) * 0.15, 4),
                }
            )
        return {
            "ok": True,
            "query": normalized,
            "count": len(citations),
            "embeddingModel": self.model_name,
            "citations": citations,
            "answerPolicy": (
                "Chỉ trả lời từ citations; phải nêu [documentKey – headingPath]. "
                "Nếu citations không đủ, nói rõ và chuyển bộ phận có thẩm quyền."
            ),
        }

    def synchronize(self) -> None:
        documents = self._load_documents()
        signature = hashlib.sha256(
            "|".join(f"{item.key}:{item.content_hash}:{self.model_name}" for item in documents).encode(
                "utf-8"
            )
        ).hexdigest()
        if signature == self._synchronized_signature:
            return
        with self._lock:
            if signature == self._synchronized_signature:
                return
            try:
                with self._connect() as connection:
                    for document in documents:
                        self._upsert_document(connection, document)
                    active_keys = [item.key for item in documents]
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE knowledge_documents SET status = 'RETIRED', updated_at = NOW() "
                            "WHERE NOT (document_key = ANY(%s)) AND status = 'ACTIVE'",
                            (active_keys,),
                        )
                    connection.commit()
            except KnowledgeBaseError:
                raise
            except Exception as exception:
                raise KnowledgeBaseError(
                    "Không thể đồng bộ tài liệu nội bộ vào pgvector"
                ) from exception
            self._synchronized_signature = signature

    def _upsert_document(self, connection: Any, document: KnowledgeDocument) -> None:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, content_hash FROM knowledge_documents WHERE document_key = %s",
                (document.key,),
            )
            existing = cursor.fetchone()
            cursor.execute(
                """
                INSERT INTO knowledge_documents (
                    document_key, title, version, effective_date, status, source_uri,
                    content_hash, metadata
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                ON CONFLICT (document_key) DO UPDATE SET
                    title = EXCLUDED.title,
                    version = EXCLUDED.version,
                    effective_date = EXCLUDED.effective_date,
                    status = EXCLUDED.status,
                    source_uri = EXCLUDED.source_uri,
                    content_hash = EXCLUDED.content_hash,
                    metadata = EXCLUDED.metadata,
                    updated_at = NOW()
                RETURNING id
                """,
                (
                    document.key,
                    document.title,
                    document.version,
                    document.effective_date,
                    document.status,
                    document.source_uri,
                    document.content_hash,
                    json.dumps(document.metadata, ensure_ascii=False),
                ),
            )
            document_id = int(cursor.fetchone()[0])
            cursor.execute(
                "SELECT COUNT(*) FROM knowledge_chunks "
                "WHERE document_id = %s AND embedding_model = %s",
                (document_id, self.model_name),
            )
            stored_chunks = int(cursor.fetchone()[0])
            unchanged = (
                existing is not None
                and existing[1] == document.content_hash
                and stored_chunks == len(document.chunks)
            )
            if unchanged:
                return

            passages = [
                f"passage: {document.title}. {chunk.heading_path}. {chunk.content}"
                for chunk in document.chunks
            ]
            embeddings = self._encode(passages)
            cursor.execute("DELETE FROM knowledge_chunks WHERE document_id = %s", (document_id,))
            for chunk, embedding in zip(document.chunks, embeddings, strict=True):
                cursor.execute(
                    """
                    INSERT INTO knowledge_chunks (
                        document_id, chunk_key, heading_path, content, content_hash,
                        embedding_model, embedding, token_estimate, metadata
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s::vector, %s, %s::jsonb)
                    """,
                    (
                        document_id,
                        chunk.key,
                        chunk.heading_path,
                        chunk.content,
                        chunk.content_hash,
                        self.model_name,
                        self._vector_literal(embedding),
                        chunk.token_estimate,
                        json.dumps({"sourceUri": document.source_uri}, ensure_ascii=False),
                    ),
                )

    def _load_documents(self) -> tuple[KnowledgeDocument, ...]:
        if not self.corpus_path.exists():
            raise KnowledgeBaseError(f"Không tìm thấy corpus RAG tại {self.corpus_path}")
        documents = tuple(self._parse_document(path) for path in sorted(self.corpus_path.glob("*.md")))
        if not documents:
            raise KnowledgeBaseError("Corpus RAG không có tài liệu Markdown")
        keys = [item.key for item in documents]
        if len(keys) != len(set(keys)):
            raise KnowledgeBaseError("Corpus RAG có document_key bị trùng")
        return documents

    def _parse_document(self, path: Path) -> KnowledgeDocument:
        raw = path.read_text(encoding="utf-8")
        metadata, body = self._front_matter(raw)
        key = metadata.get("document_key", "").strip()
        title = metadata.get("title", "").strip()
        version = metadata.get("version", "").strip()
        if not key or not title or not version:
            raise KnowledgeBaseError(f"Tài liệu {path.name} thiếu document_key/title/version")
        effective_raw = metadata.get("effective_date", "").strip()
        try:
            effective_date = date.fromisoformat(effective_raw) if effective_raw else None
        except ValueError as exception:
            raise KnowledgeBaseError(f"effective_date không hợp lệ trong {path.name}") from exception
        status = metadata.get("status", "ACTIVE").strip().upper()
        if status not in {"DRAFT", "ACTIVE", "RETIRED"}:
            raise KnowledgeBaseError(f"status không hợp lệ trong {path.name}")
        chunks = self._chunk_markdown(key, body)
        return KnowledgeDocument(
            key=key,
            title=title,
            version=version,
            effective_date=effective_date,
            status=status,
            source_uri=f"knowledge/{path.name}",
            content_hash=hashlib.sha256(raw.encode("utf-8")).hexdigest(),
            metadata={
                item_key: value
                for item_key, value in metadata.items()
                if item_key
                not in {"document_key", "title", "version", "effective_date", "status"}
            },
            chunks=chunks,
        )

    @staticmethod
    def _front_matter(raw: str) -> tuple[dict[str, str], str]:
        if not raw.startswith("---\n"):
            return {}, raw
        end = raw.find("\n---\n", 4)
        if end < 0:
            return {}, raw
        values: dict[str, str] = {}
        for line in raw[4:end].splitlines():
            key, separator, value = line.partition(":")
            if separator:
                values[key.strip()] = value.strip().strip('"').strip("'")
        return values, raw[end + 5 :]

    @staticmethod
    def _chunk_markdown(document_key: str, body: str) -> tuple[KnowledgeChunk, ...]:
        headings: list[str] = []
        blocks: list[tuple[str, str]] = []
        current_lines: list[str] = []
        current_path = "Nội dung"

        def flush() -> None:
            nonlocal current_lines
            content = "\n".join(current_lines).strip()
            if content:
                blocks.append((current_path, content))
            current_lines = []

        for raw_line in body.splitlines():
            match = re.match(r"^(#{1,4})\s+(.+?)\s*$", raw_line)
            if match:
                flush()
                level = len(match.group(1))
                headings[:] = headings[: level - 1]
                while len(headings) < level - 1:
                    headings.append("")
                headings.append(match.group(2).strip())
                current_path = " > ".join(item for item in headings if item)
            else:
                current_lines.append(raw_line)
        flush()

        chunks: list[KnowledgeChunk] = []
        for index, (heading_path, content) in enumerate(blocks, start=1):
            digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
            slug = re.sub(r"[^a-z0-9]+", "-", heading_path.lower()).strip("-")[:60]
            chunks.append(
                KnowledgeChunk(
                    key=f"{document_key}-{index:03d}-{slug or 'section'}",
                    heading_path=heading_path,
                    content=content,
                    content_hash=digest,
                    token_estimate=max(1, len(content) // 4),
                )
            )
        if not chunks:
            raise KnowledgeBaseError(f"Tài liệu {document_key} không có nội dung để chia chunk")
        return tuple(chunks)

    def _encode(self, texts: list[str]) -> list[list[float]]:
        if self._model is None:
            with self._lock:
                if self._model is None:
                    try:
                        from sentence_transformers import SentenceTransformer

                        self._model = SentenceTransformer(
                            self.model_name,
                            cache_folder=self.model_cache,
                        )
                    except Exception as exception:
                        raise KnowledgeBaseError(
                            f"Không tải được embedding model {self.model_name}"
                        ) from exception
        vectors = self._model.encode(
            texts,
            batch_size=32,
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        result = vectors.tolist()
        if result and len(result[0]) != 384:
            raise KnowledgeBaseError(
                f"Embedding model phải có 384 chiều, nhận được {len(result[0])}"
            )
        return result

    @staticmethod
    def _vector_literal(vector: list[float]) -> str:
        return "[" + ",".join(f"{float(value):.8f}" for value in vector) + "]"

    @staticmethod
    def _connect() -> Any:
        try:
            import psycopg

            return psycopg.connect(
                host=os.getenv("POSTGRES_HOST", "postgres"),
                port=int(os.getenv("POSTGRES_PORT", "5432")),
                dbname=os.getenv("POSTGRES_DB", "safefleet"),
                user=os.getenv("POSTGRES_USER", "safefleet"),
                password=os.getenv("POSTGRES_PASSWORD", ""),
                connect_timeout=8,
            )
        except Exception as exception:
            raise KnowledgeBaseError("Không thể kết nối PostgreSQL cho RAG") from exception


knowledge_base = KnowledgeBase()
