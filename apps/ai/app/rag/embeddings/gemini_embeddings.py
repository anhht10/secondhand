"""
Google Gemini Embedding Provider (`app.rag.embeddings.gemini_embeddings`).
Uses `google.genai.Client.models.embed_content` with dedicated configuration:
- Configured via `Settings.GEMINI_EMBEDDING_MODEL` (default: `gemini-embedding-001`),
  never hardcoded and never accepting a text generation model.
- Enforces batching (`GEMINI_EMBEDDING_BATCH_SIZE`), L2 vector normalization,
  bounded retries with exponential backoff, and rate-limit/quota classification.
"""

import asyncio
import logging
import math
import time
from typing import Any, Optional, Protocol, runtime_checkable

from google.genai import types
from langchain_core.embeddings import Embeddings

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    AIServiceError,
    EmbeddingError,
    LLMAuthenticationError,
    LLMConfigurationError,
)
from app.llm.gemini import (
    GeminiModelFactory,
    classify_llm_exception,
    get_gemini_factory,
)

logger = logging.getLogger("remarket.ai.rag.embeddings")


@runtime_checkable
class EmbeddingProviderProtocol(Protocol):
    """Protocol for pluggable text embedding providers."""

    @property
    def model_name(self) -> str: ...

    @property
    def dimensions(self) -> int: ...

    def embed_documents(self, texts: list[str]) -> list[list[float]]: ...

    def embed_query(self, text: str) -> list[float]: ...


def normalize_vector(vec: list[float]) -> list[float]:
    """L2-normalize a float vector so dot product equals cosine similarity."""
    norm = math.sqrt(sum(v * v for v in vec))
    if norm <= 1e-12:
        return list(vec)
    return [v / norm for v in vec]


def validate_embedding_model_name(model_name: str) -> str:
    """
    Ensure the configured embedding model name is a dedicated embedding model
    and not a deprecated or generation model.
    """
    if not isinstance(model_name, str) or not model_name.strip():
        raise LLMConfigurationError("GEMINI_EMBEDDING_MODEL must be a non-empty string.")
    cleaned = model_name.strip()
    lowered = cleaned.lower()
    if lowered.startswith(("gemini-1.5", "gemini-2.0", "gemini-2.5", "text-embedding-004")):
        raise LLMConfigurationError(
            f"Embedding model '{cleaned}' is deprecated. Use 'gemini-embedding-001' or 'gemini-embedding-2'."
        )
    if "embedding" not in lowered:
        raise LLMConfigurationError(
            f"Model '{cleaned}' is a generation model and cannot be used for embeddings. "
            "Configure 'gemini-embedding-001' or 'gemini-embedding-2'."
        )
    return cleaned


class GeminiEmbeddingProvider(Embeddings):
    """
    Production Google Gemini Embedding service implementing LangChain `Embeddings`
    and `EmbeddingProviderProtocol`.
    """

    def __init__(
        self,
        *,
        settings: Optional[Settings] = None,
        factory: Optional[GeminiModelFactory] = None,
        genai_client: Optional[Any] = None,
        initial_backoff_seconds: float = 0.4,
    ) -> None:
        self._settings = settings or get_settings()
        self._model_name = validate_embedding_model_name(self._settings.GEMINI_EMBEDDING_MODEL)
        self._dimensions = self._settings.GEMINI_EMBEDDING_DIMENSIONS
        self._batch_size = max(1, self._settings.GEMINI_EMBEDDING_BATCH_SIZE)
        self._max_attempts = max(1, self._settings.GEMINI_MAX_RETRIES + 1)
        self._initial_backoff_seconds = initial_backoff_seconds
        self._factory = factory or get_gemini_factory(self._settings)
        self._genai_client = genai_client

    @property
    def model_name(self) -> str:
        return self._model_name

    @property
    def dimensions(self) -> int:
        return self._dimensions

    def _get_client(self) -> Any:
        if self._genai_client is not None:
            return self._genai_client
        return self._factory.get_genai_sdk_client()

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        """Embed a list of document chunks in rate-limit-safe batches."""
        if not texts:
            return []

        cleaned_texts = [t.strip() or " " for t in texts]
        all_vectors: list[list[float]] = []

        for start in range(0, len(cleaned_texts), self._batch_size):
            batch = cleaned_texts[start : start + self._batch_size]
            batch_vectors = self._embed_batch_with_retry(batch)
            all_vectors.extend(batch_vectors)

        return all_vectors

    def embed_query(self, text: str) -> list[float]:
        """Embed a single search query string."""
        cleaned = (text or "").strip()
        if not cleaned:
            raise ValueError("Query text for embedding must not be empty.")
        vectors = self._embed_batch_with_retry([cleaned])
        if not vectors:
            raise EmbeddingError("Gemini embedding API returned no vector for query.")
        return vectors[0]

    async def aembed_documents(self, texts: list[str]) -> list[list[float]]:
        """Asynchronously embed a list of document chunks."""
        return await asyncio.to_thread(self.embed_documents, texts)

    async def aembed_query(self, text: str) -> list[float]:
        """Asynchronously embed a single search query."""
        return await asyncio.to_thread(self.embed_query, text)

    def _embed_batch_with_retry(self, batch: list[str]) -> list[list[float]]:
        """Call `client.models.embed_content` with bounded exponential backoff."""
        client = self._get_client()
        config = types.EmbedContentConfig(output_dimensionality=self._dimensions)
        last_error: Optional[Exception] = None

        for attempt in range(1, self._max_attempts + 1):
            try:
                response = client.models.embed_content(
                    model=self._model_name,
                    contents=batch,
                    config=config,
                )
                embeddings_list = getattr(response, "embeddings", None)
                if not embeddings_list or len(embeddings_list) != len(batch):
                    raise EmbeddingError(
                        f"Expected {len(batch)} embeddings from '{self._model_name}', "
                        f"received {len(embeddings_list) if embeddings_list else 0}."
                    )

                vectors: list[list[float]] = []
                for emb_obj in embeddings_list:
                    raw_values = getattr(emb_obj, "values", None)
                    if not raw_values:
                        raise EmbeddingError("Gemini embedding object contained empty vector values.")
                    vectors.append(normalize_vector([float(x) for x in raw_values]))
                return vectors

            except Exception as exc:
                if isinstance(exc, (LLMConfigurationError, LLMAuthenticationError)):
                    raise
                classified = classify_llm_exception(exc)
                if isinstance(classified, (LLMConfigurationError, LLMAuthenticationError)):
                    raise classified from exc

                last_error = classified
                if attempt < self._max_attempts:
                    backoff = self._initial_backoff_seconds * (2 ** (attempt - 1))
                    logger.warning(
                        "Gemini embed_content attempt %d/%d failed (%s), retrying in %.2fs",
                        attempt,
                        self._max_attempts,
                        classified.code,
                        backoff,
                    )
                    time.sleep(backoff)
                else:
                    if isinstance(exc, EmbeddingError):
                        raise
                    if isinstance(classified, AIServiceError):
                        raise classified from exc
                    raise EmbeddingError(str(exc)) from exc

        raise EmbeddingError(str(last_error or "Gemini embedding request failed."))
