"""
Semantic Knowledge Retriever (`app.rag.retrievers.semantic_retriever`).
Implements `RetrieverProviderProtocol` and supports configurable `top_k`,
`similarity_threshold`, and optional `category` filtering.
"""

from typing import Any, Optional

from app.core.config import Settings, get_settings
from app.rag.base import RetrieverProviderProtocol
from app.rag.embeddings import EmbeddingProviderProtocol, GeminiEmbeddingProvider
from app.rag.loaders.cleaner import sanitize_and_clean_text
from app.rag.schemas import RAGRetrievedChunk
from app.rag.vectorstores import VectorStoreProtocol, create_vector_store


class SemanticKnowledgeRetriever(RetrieverProviderProtocol):
    """
    Semantic retriever that embeds queries via `EmbeddingProviderProtocol` and
    searches `VectorStoreProtocol` with configurable `top_k` and `similarity_threshold`.
    """

    def __init__(
        self,
        *,
        vector_store: Optional[VectorStoreProtocol] = None,
        embedding_provider: Optional[EmbeddingProviderProtocol] = None,
        settings: Optional[Settings] = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._vector_store = vector_store or create_vector_store(self._settings)
        self._embedding_provider = embedding_provider or GeminiEmbeddingProvider(
            settings=self._settings
        )

    @property
    def store_type(self) -> str:
        return self._vector_store.store_type

    def is_enabled(self) -> bool:
        return self._settings.VECTOR_STORE_TYPE != "none"

    def retrieve_chunks(
        self,
        query: str,
        *,
        top_k: Optional[int] = None,
        similarity_threshold: Optional[float] = None,
        category: Optional[str] = None,
    ) -> list[RAGRetrievedChunk]:
        """
        Retrieve matching `RAGRetrievedChunk` objects ordered by descending similarity score.
        """
        cleaned_query, _ = sanitize_and_clean_text(query)
        if not cleaned_query:
            return []

        resolved_top_k = top_k if top_k is not None else self._settings.RAG_DEFAULT_TOP_K
        resolved_threshold = (
            similarity_threshold
            if similarity_threshold is not None
            else self._settings.RAG_SIMILARITY_THRESHOLD
        )

        query_vec = self._embedding_provider.embed_query(cleaned_query)
        return self._vector_store.similarity_search(
            query_vec,
            top_k=resolved_top_k,
            similarity_threshold=resolved_threshold,
            category=category,
        )

    def retrieve(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """
        Satisfy Phase 1 `RetrieverProviderProtocol.retrieve(query, top_k)` interface.
        """
        chunks = self.retrieve_chunks(query, top_k=top_k)
        return [chunk.model_dump() for chunk in chunks]
