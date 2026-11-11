"""
Base Vector Store Protocol and Cosine Similarity Utilities (`app.rag.vectorstores.base`).
"""

import math
from typing import Optional, Protocol, runtime_checkable

from app.rag.schemas import RAGDocumentChunk, RAGRetrievedChunk


def cosine_similarity_score(vec_a: list[float], vec_b: list[float]) -> float:
    """
    Compute bounded cosine similarity in [0.0, 1.0] between two vectors.
    """
    if not vec_a or not vec_b or len(vec_a) != len(vec_b):
        return 0.0
    dot = sum(a * b for a, b in zip(vec_a, vec_b))
    norm_a = math.sqrt(sum(a * a for a in vec_a))
    norm_b = math.sqrt(sum(b * b for b in vec_b))
    if norm_a <= 1e-12 or norm_b <= 1e-12:
        return 0.0
    raw_cos = dot / (norm_a * norm_b)
    return max(0.0, min(1.0, float(raw_cos)))


@runtime_checkable
class VectorStoreProtocol(Protocol):
    """Protocol implemented by all pluggable RAG vector stores."""

    @property
    def store_type(self) -> str: ...

    def upsert_chunks(
        self,
        chunks: list[RAGDocumentChunk],
        embeddings: list[list[float]],
    ) -> int: ...

    def get_document_content_hash(self, document_id: str) -> Optional[str]: ...

    def delete_document(self, document_id: str) -> int: ...

    def similarity_search(
        self,
        query_embedding: list[float],
        *,
        top_k: int = 4,
        similarity_threshold: float = 0.0,
        category: Optional[str] = None,
    ) -> list[RAGRetrievedChunk]: ...

    def count_chunks(self) -> int: ...

    def list_document_ids(self) -> list[str]: ...
