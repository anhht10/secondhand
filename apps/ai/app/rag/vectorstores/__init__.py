"""
Vector Stores Package (`app.rag.vectorstores`).
Provides factory `create_vector_store` configured via `Settings.VECTOR_STORE_TYPE`.
"""

from typing import Optional

from app.core.config import Settings, get_settings
from app.rag.vectorstores.base import VectorStoreProtocol, cosine_similarity_score
from app.rag.vectorstores.chroma_store import ChromaVectorStore
from app.rag.vectorstores.memory_store import InMemoryVectorStore


def create_vector_store(settings: Optional[Settings] = None) -> VectorStoreProtocol:
    """
    Instantiate the configured vector store (`chroma` persistent storage by default,
    or `memory` for isolated in-memory testing).
    """
    cfg = settings or get_settings()
    if cfg.VECTOR_STORE_TYPE == "memory":
        return InMemoryVectorStore()
    return ChromaVectorStore(
        persist_directory=cfg.CHROMA_PERSIST_DIRECTORY,
        collection_name=cfg.CHROMA_COLLECTION_NAME,
    )


__all__ = [
    "VectorStoreProtocol",
    "ChromaVectorStore",
    "InMemoryVectorStore",
    "create_vector_store",
    "cosine_similarity_score",
]
