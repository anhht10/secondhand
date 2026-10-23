"""
Pydantic Schemas for the ReMarket RAG System (`app.rag.schemas`).
Defines standardized data models for Knowledge Categories, Document & Chunk Metadata,
Ingestion Reports, Retrieved Chunks, Source Attributions, and Grounded Context Assembly.
"""

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class KnowledgeCategory(str, Enum):
    """
    Canonical knowledge source categories supported by the ReMarket RAG system:
    1. `policy`              — Chính sách và quy định của ReMarket
    2. `safety_guide`        — Hướng dẫn mua bán đồ cũ an toàn
    3. `inspection_guide`    — Hướng dẫn kiểm tra chất lượng sản phẩm
    4. `condition_grading`   — Kiến thức phân loại tình trạng sản phẩm
    5. `student_transaction` — Hướng dẫn giao dịch giữa sinh viên
    6. `platform_guide`      — Tài liệu hướng dẫn sử dụng nền tảng
    7. `general`             — Kiến thức tổng hợp khác
    """

    POLICY = "policy"
    SAFETY_GUIDE = "safety_guide"
    INSPECTION_GUIDE = "inspection_guide"
    CONDITION_GRADING = "condition_grading"
    STUDENT_TRANSACTION = "student_transaction"
    PLATFORM_GUIDE = "platform_guide"
    GENERAL = "general"


class RAGDocumentMetadata(BaseModel):
    """Required metadata attached to every ingested document."""

    model_config = ConfigDict(extra="allow")

    document_id: str = Field(
        ...,
        min_length=1,
        description="Deterministic unique identifier for the source document.",
    )
    source: str = Field(
        ...,
        min_length=1,
        description="Canonical source file path or document URI.",
    )
    category: KnowledgeCategory = Field(
        default=KnowledgeCategory.GENERAL,
        description="Knowledge domain category of the document.",
    )
    title: str = Field(
        default="",
        description="Human-readable document title.",
    )
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(),
        description="ISO-8601 timestamp when the document was created or ingested.",
    )
    content_hash: str = Field(
        default="",
        description="SHA-256 hex digest of cleaned document content for deduplication and updates.",
    )
    file_type: str = Field(
        default="markdown",
        description="Source format ('markdown' or 'pdf').",
    )
    sanitized_injection_patterns: int = Field(
        default=0,
        ge=0,
        description="Count of prompt-injection patterns neutralized during text cleaning.",
    )


class RawLoadedDocument(BaseModel):
    """A loaded and cleaned document prior to text splitting."""

    content: str = Field(..., description="Cleaned document text content.")
    metadata: RAGDocumentMetadata


class RAGChunkMetadata(BaseModel):
    """Metadata attached to an individual split text chunk stored in the vector store."""

    model_config = ConfigDict(extra="allow")

    chunk_id: str = Field(..., description="Deterministic unique ID for this chunk.")
    document_id: str = Field(..., description="Parent document ID.")
    source: str = Field(..., description="Source path or URI.")
    category: str = Field(..., description="Knowledge category string.")
    title: str = Field(default="", description="Parent document title.")
    section: str = Field(default="", description="Markdown heading or PDF page section.")
    chunk_index: int = Field(default=0, ge=0, description="0-based index of chunk within document.")
    total_chunks: int = Field(default=1, ge=1, description="Total chunks in parent document.")
    created_at: str = Field(..., description="ISO-8601 creation timestamp.")
    content_hash: str = Field(..., description="SHA-256 hash of parent document content.")

    def to_flat_dict(self) -> dict[str, str | int | float | bool]:
        """Convert metadata to flat primitive key-value pairs compatible with ChromaDB."""
        return {
            "chunk_id": self.chunk_id,
            "document_id": self.document_id,
            "source": self.source,
            "category": str(self.category),
            "title": self.title,
            "section": self.section,
            "chunk_index": int(self.chunk_index),
            "total_chunks": int(self.total_chunks),
            "created_at": self.created_at,
            "content_hash": self.content_hash,
        }


class RAGDocumentChunk(BaseModel):
    """A single text chunk ready for embedding and vector storage."""

    chunk_id: str
    content: str
    metadata: RAGChunkMetadata


class DocumentIngestionItemResult(BaseModel):
    """Ingestion result for a single document."""

    document_id: str
    source: str
    category: str
    status: str = Field(
        ...,
        description="'ingested' | 'updated' | 'skipped_duplicate'",
    )
    chunks_count: int = 0
    content_hash: str = ""


class IngestionSummaryReport(BaseModel):
    """Summary report returned after running document ingestion."""

    total_documents_processed: int = 0
    ingested_count: int = 0
    updated_count: int = 0
    skipped_duplicate_count: int = 0
    total_chunks_upserted: int = 0
    documents: list[DocumentIngestionItemResult] = Field(default_factory=list)


class RAGSourceAttribution(BaseModel):
    """Citation / source reference returned alongside RAG retrieval results."""

    document_id: str
    title: str
    source: str
    category: str
    section: str = ""
    created_at: str = ""
    similarity_score: float = Field(..., ge=0.0, le=1.0)


class RAGRetrievedChunk(BaseModel):
    """A retrieved chunk with its similarity score and metadata."""

    chunk_id: str
    content: str
    similarity_score: float = Field(..., ge=0.0, le=1.0)
    metadata: RAGChunkMetadata


class RAGRetrievalResult(BaseModel):
    """
    Complete output of the RAG retrieval & context assembly pipeline.
    Contains retrieved chunks, deduplicated source citations, grounded context string,
    and a grounding flag indicating whether the knowledge base actually matched the query.
    """

    query: str
    top_k: int
    similarity_threshold: float
    has_sufficient_context: bool
    grounded_context: str
    grounding_instruction: str
    chunks: list[RAGRetrievedChunk] = Field(default_factory=list)
    sources: list[RAGSourceAttribution] = Field(default_factory=list)
    metadata_filter: Optional[dict[str, Any]] = None
