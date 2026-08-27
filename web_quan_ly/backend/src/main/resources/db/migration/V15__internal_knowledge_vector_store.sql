CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE knowledge_documents (
    id BIGSERIAL PRIMARY KEY,
    document_key VARCHAR(120) NOT NULL UNIQUE,
    title VARCHAR(500) NOT NULL,
    version VARCHAR(60) NOT NULL,
    effective_date DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    source_uri VARCHAR(1000),
    content_hash VARCHAR(64) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_knowledge_document_status
        CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED'))
);

CREATE TABLE knowledge_chunks (
    id BIGSERIAL PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES knowledge_documents(id) ON DELETE CASCADE,
    chunk_key VARCHAR(180) NOT NULL,
    heading_path VARCHAR(1000) NOT NULL,
    content TEXT NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    embedding_model VARCHAR(255) NOT NULL,
    embedding VECTOR(384) NOT NULL,
    token_estimate INTEGER NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('simple', COALESCE(heading_path, '') || ' ' || COALESCE(content, ''))
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_knowledge_chunk UNIQUE (document_id, chunk_key)
);

CREATE INDEX idx_knowledge_documents_active
    ON knowledge_documents(status, effective_date DESC);
CREATE INDEX idx_knowledge_chunks_document
    ON knowledge_chunks(document_id);
CREATE INDEX idx_knowledge_chunks_search
    ON knowledge_chunks USING GIN(search_vector);
CREATE INDEX idx_knowledge_chunks_embedding_hnsw
    ON knowledge_chunks USING HNSW (embedding vector_cosine_ops);

COMMENT ON TABLE knowledge_documents IS
    'Versioned internal policy/legal documents used by SafeFleet RAG.';
COMMENT ON TABLE knowledge_chunks IS
    'Atomic policy chunks with multilingual embeddings and citation metadata.';
