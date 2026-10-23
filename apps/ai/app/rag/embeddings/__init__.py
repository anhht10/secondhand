"""
Embeddings Package (`app.rag.embeddings`).
"""

from app.rag.embeddings.gemini_embeddings import (
    EmbeddingProviderProtocol,
    GeminiEmbeddingProvider,
    normalize_vector,
    validate_embedding_model_name,
)

__all__ = [
    "EmbeddingProviderProtocol",
    "GeminiEmbeddingProvider",
    "normalize_vector",
    "validate_embedding_model_name",
]
