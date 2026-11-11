"""
In-Memory Vector Store (`app.rag.vectorstores.memory_store`).
Provides an isolated in-memory implementation of `VectorStoreProtocol` for fast
unit testing or ephemeral runs when `VECTOR_STORE_TYPE=memory`.
"""

from typing import Optional

from app.rag.schemas import RAGDocumentChunk, RAGRetrievedChunk
from app.rag.vectorstores.base import cosine_similarity_score


class InMemoryVectorStore:
    """In-memory cosine similarity vector store implementing `VectorStoreProtocol`."""

    def __init__(self) -> None:
        self._chunks: dict[str, tuple[RAGDocumentChunk, list[float]]] = {}

    @property
    def store_type(self) -> str:
        return "memory"

    def upsert_chunks(
        self,
        chunks: list[RAGDocumentChunk],
        embeddings: list[list[float]],
    ) -> int:
        if len(chunks) != len(embeddings):
            raise ValueError("Chunks and embeddings must have identical lengths.")
        for chunk, vec in zip(chunks, embeddings):
            self._chunks[chunk.chunk_id] = (chunk, list(vec))
        return len(chunks)

    def get_document_content_hash(self, document_id: str) -> Optional[str]:
        clean_id = document_id.strip()
        for chunk, _ in self._chunks.values():
            if chunk.metadata.document_id == clean_id:
                return chunk.metadata.content_hash
        return None

    def delete_document(self, document_id: str) -> int:
        clean_id = document_id.strip()
        to_delete = [
            cid
            for cid, (chunk, _) in self._chunks.items()
            if chunk.metadata.document_id == clean_id
        ]
        for cid in to_delete:
            del self._chunks[cid]
        return len(to_delete)

    def similarity_search(
        self,
        query_embedding: list[float],
        *,
        top_k: int = 4,
        similarity_threshold: float = 0.0,
        category: Optional[str] = None,
    ) -> list[RAGRetrievedChunk]:
        scored: list[RAGRetrievedChunk] = []
        cat_filter = category.strip() if category and category.strip() else None

        for chunk, vec in self._chunks.values():
            if cat_filter and chunk.metadata.category != cat_filter:
                continue
            score = cosine_similarity_score(query_embedding, vec)
            if score >= similarity_threshold:
                scored.append(
                    RAGRetrievedChunk(
                        chunk_id=chunk.chunk_id,
                        content=chunk.content,
                        similarity_score=round(score, 4),
                        metadata=chunk.metadata,
                    )
                )

        scored.sort(key=lambda item: item.similarity_score, reverse=True)
        return scored[: max(1, top_k)]

    def count_chunks(self) -> int:
        return len(self._chunks)

    def list_document_ids(self) -> list[str]:
        return sorted({chunk.metadata.document_id for chunk, _ in self._chunks.values()})
