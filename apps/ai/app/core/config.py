"""
Pydantic v2 Settings Configuration for ReMarket AI Service.
Loads environment variables from `.env` or OS environment without exposing secrets.
"""

from functools import lru_cache
from typing import Literal, Optional

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Centralized application settings validated via Pydantic v2."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # Gemini LLM Settings
    GEMINI_API_KEY: SecretStr = Field(
        default=SecretStr(""),
        description="Google Gemini API Key (stored as SecretStr to prevent accidental logging).",
    )
    GEMINI_MODEL: str = Field(
        default="gemini-3.8-flash",
        min_length=1,
        description="Configured Gemini model identifier.",
    )
    GEMINI_TEMPERATURE: float = Field(
        default=0.2,
        ge=0.0,
        le=2.0,
        description="Default sampling temperature for Gemini model calls.",
    )
    GEMINI_TIMEOUT_SECONDS: float = Field(
        default=30.0,
        gt=0.0,
        le=300.0,
        description="Timeout in seconds for each LLM request.",
    )
    GEMINI_MAX_RETRIES: int = Field(
        default=2,
        ge=0,
        le=5,
        description="Maximum automatic retries for transient LLM errors.",
    )

    # Gemini Embedding Settings (Dedicated Embedding Configuration)
    GEMINI_EMBEDDING_MODEL: str = Field(
        default="gemini-embedding-001",
        min_length=1,
        description="Dedicated Google Gemini embedding model identifier (e.g., gemini-embedding-001, gemini-embedding-2).",
    )
    GEMINI_EMBEDDING_DIMENSIONS: int = Field(
        default=768,
        ge=128,
        le=3072,
        description="Output vector dimensionality for Gemini embeddings.",
    )
    GEMINI_EMBEDDING_BATCH_SIZE: int = Field(
        default=32,
        ge=1,
        le=100,
        description="Maximum number of texts embedded per Gemini API batch request.",
    )

    # Backend Integration Settings
    BACKEND_API_BASE_URL: str = Field(
        default="http://localhost:5000/api/v1",
        description="Base URL of the NestJS ReMarket Backend API.",
    )
    BACKEND_SERVICE_TOKEN: Optional[SecretStr] = Field(
        default=None,
        description="Optional internal service token for authenticating with NestJS Backend.",
    )
    BACKEND_TIMEOUT_SECONDS: float = Field(
        default=10.0,
        gt=0.0,
        le=120.0,
        description="HTTP timeout in seconds for NestJS Backend API calls.",
    )
    BACKEND_MAX_RETRIES: int = Field(
        default=2,
        ge=0,
        le=5,
        description="Maximum bounded retries for transient NestJS Backend HTTP errors.",
    )
    BACKEND_POOL_MAX_CONNECTIONS: int = Field(
        default=20,
        ge=1,
        le=200,
        description="Maximum HTTP connection pool size for Backend API client.",
    )
    BACKEND_POOL_MAX_KEEPALIVE: int = Field(
        default=10,
        ge=1,
        le=100,
        description="Maximum keepalive connections for Backend API client.",
    )

    # Server & Runtime Settings
    AI_SERVICE_PORT: int = Field(
        default=8000,
        ge=1,
        le=65535,
        description="Port on which the FastAPI AI microservice listens.",
    )
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        default="INFO",
        description="Application log level.",
    )

    # Persistence & RAG Infrastructure Settings
    CHECKPOINTER_DATABASE_URL: str = Field(
        default="memory://",
        description="Checkpointer storage URI (e.g., memory:// or sqlite/postgres URI).",
    )
    VECTOR_STORE_TYPE: Literal["none", "memory", "chroma", "qdrant", "pgvector"] = Field(
        default="chroma",
        description="Vector store provider type for RAG workflows (default: chroma persistent storage).",
    )
    CHROMA_PERSIST_DIRECTORY: str = Field(
        default="./data/chroma",
        description="Filesystem path for ChromaDB persistent vector storage.",
    )
    CHROMA_COLLECTION_NAME: str = Field(
        default="remarket_knowledge_base",
        min_length=1,
        description="ChromaDB collection name for ReMarket RAG documents.",
    )
    RAG_KNOWLEDGE_BASE_DIR: str = Field(
        default="./data/knowledge_base",
        description="Default directory containing Markdown/PDF knowledge base documents.",
    )
    RAG_CHUNK_SIZE: int = Field(
        default=800,
        ge=100,
        le=4000,
        description="Target character size for RAG text splitting chunks.",
    )
    RAG_CHUNK_OVERLAP: int = Field(
        default=120,
        ge=0,
        le=1000,
        description="Character overlap between consecutive RAG text chunks.",
    )
    RAG_DEFAULT_TOP_K: int = Field(
        default=4,
        ge=1,
        le=20,
        description="Default number of top chunks retrieved in semantic search.",
    )
    RAG_SIMILARITY_THRESHOLD: float = Field(
        default=0.35,
        ge=0.0,
        le=1.0,
        description="Minimum similarity score threshold [0.0..1.0] for RAG retrieval.",
    )
    CONVERSATION_MAX_HISTORY_MESSAGES: int = Field(
        default=20,
        ge=4,
        le=100,
        description="Maximum number of messages retained in active short-term conversation window.",
    )
    AI_RATE_LIMIT_REQUESTS: int = Field(
        default=60,
        ge=1,
        le=10000,
        description="Maximum AI requests permitted per client/user within the rate limit window.",
    )
    AI_RATE_LIMIT_WINDOW_SECONDS: float = Field(
        default=60.0,
        ge=1.0,
        le=3600.0,
        description="Sliding window duration in seconds for AI endpoint rate limiting.",
    )
    LANGSMITH_TRACING: bool = Field(
        default=False,
        description="Enable optional LangSmith tracing if configured.",
    )
    LANGSMITH_PROJECT: str = Field(
        default="remarket-ai-service",
        description="LangSmith project name when tracing is enabled.",
    )

    @field_validator("BACKEND_API_BASE_URL", mode="before")
    @classmethod
    def normalize_backend_base_url(cls, value: str) -> str:
        if isinstance(value, str):
            return value.strip().rstrip("/")
        return "http://localhost:5000/api/v1"

    @field_validator("LOG_LEVEL", mode="before")
    @classmethod
    def normalize_log_level(cls, value: str) -> str:
        if isinstance(value, str):
            return value.strip().upper()
        return "INFO"

    @field_validator("GEMINI_MODEL", mode="before")
    @classmethod
    def validate_gemini_model(cls, value: str) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError("GEMINI_MODEL must be a non-empty string")
        cleaned = value.strip()
        deprecated_prefixes = ("gemini-1.5", "gemini-2.0", "gemini-2.5")
        if cleaned.lower().startswith(deprecated_prefixes):
            raise ValueError(
                f"Model '{cleaned}' is deprecated. Use 'gemini-3.8-flash' or current Gemini 3.x/4.x models."
            )
        return cleaned

    @field_validator("GEMINI_EMBEDDING_MODEL", mode="before")
    @classmethod
    def validate_gemini_embedding_model(cls, value: str) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError("GEMINI_EMBEDDING_MODEL must be a non-empty string")
        cleaned = value.strip()
        lowered = cleaned.lower()
        deprecated_prefixes = ("gemini-1.5", "gemini-2.0", "gemini-2.5", "embedding-001", "text-embedding-004")
        if lowered.startswith(deprecated_prefixes):
            raise ValueError(
                f"Embedding model '{cleaned}' is deprecated. Use 'gemini-embedding-001' or 'gemini-embedding-2'."
            )
        if "embedding" not in lowered:
            raise ValueError(
                f"Model '{cleaned}' is a generation model and cannot be used for embeddings. "
                "Configure 'gemini-embedding-001' or 'gemini-embedding-2'."
            )
        return cleaned

    @property
    def gemini_api_key_value(self) -> str:
        """Return the raw GEMINI_API_KEY string."""
        return self.GEMINI_API_KEY.get_secret_value().strip()

    @property
    def backend_service_token_value(self) -> str:
        """Return the raw BACKEND_SERVICE_TOKEN string."""
        if self.BACKEND_SERVICE_TOKEN is None:
            return ""
        return self.BACKEND_SERVICE_TOKEN.get_secret_value().strip()

    @property
    def has_gemini_api_key(self) -> bool:
        """Return True if a non-empty GEMINI_API_KEY is configured."""
        raw = self.gemini_api_key_value
        return bool(raw and raw != "your_gemini_api_key_here")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached singleton Settings instance."""
    return Settings()


def clear_settings_cache() -> None:
    """Clear settings cache (useful in unit tests when monkeypatching env vars)."""
    get_settings.cache_clear()
