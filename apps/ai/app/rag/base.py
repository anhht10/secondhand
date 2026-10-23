"""
Retrieval Interface Foundation for ReMarket AI Service.
Defines the structural protocol for future vector store integrations without
implementing RAG pipelines in Phase 1.
"""

from typing import Any, Protocol


class RetrieverProviderProtocol(Protocol):
    """Protocol for pluggable vector store retrievers configured via VECTOR_STORE_TYPE."""

    @property
    def store_type(self) -> str: ...

    def is_enabled(self) -> bool: ...

    def retrieve(self, query: str, top_k: int = 5) -> list[dict[str, Any]]: ...
