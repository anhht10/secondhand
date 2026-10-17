"""
Unit tests for Configuration (`app.core.config`) and Secret Redaction (`app.core.logging`).
"""

import logging
from pydantic import ValidationError
import pytest

from app.core.config import Settings
from app.core.logging import SecretRedactionFilter


def test_settings_default_values() -> None:
    """Verify default configuration values when instantiated without overrides."""
    settings = Settings(GEMINI_API_KEY="", BACKEND_SERVICE_TOKEN="")
    assert settings.GEMINI_MODEL == "gemini-3.8-flash"
    assert settings.GEMINI_EMBEDDING_MODEL == "gemini-embedding-001"
    assert settings.AI_SERVICE_PORT == 8000
    assert settings.LOG_LEVEL == "INFO"
    assert settings.CHECKPOINTER_DATABASE_URL == "memory://"
    assert settings.VECTOR_STORE_TYPE == "chroma"
    assert settings.has_gemini_api_key is False


def test_settings_rejects_generation_or_deprecated_embedding_models() -> None:
    """Ensure generation models or deprecated embedding models cannot be configured for embeddings."""
    for invalid_emb_model in [
        "gemini-3.8-flash",
        "gemini-4-argon",
        "text-embedding-004",
        "gemini-1.5-pro",
    ]:
        with pytest.raises(ValidationError):
            Settings(GEMINI_EMBEDDING_MODEL=invalid_emb_model)


def test_settings_secret_str_does_not_leak_in_repr(test_settings: Settings) -> None:
    """Verify GEMINI_API_KEY and BACKEND_SERVICE_TOKEN are masked in repr/str."""
    repr_str = repr(test_settings)
    assert "test-dummy-gemini-api-key-12345" not in repr_str
    assert "test-internal-service-token-xyz" not in repr_str
    assert test_settings.has_gemini_api_key is True
    assert test_settings.gemini_api_key_value == "test-dummy-gemini-api-key-12345"


def test_settings_rejects_deprecated_gemini_models() -> None:
    """Ensure legacy Gemini 1.5, 2.0, and 2.5 models are rejected by validation."""
    for legacy_model in [
        "gemini-1.5-flash",
        "gemini-2.0-flash",
        "gemini-2.5-pro",
    ]:
        with pytest.raises(ValidationError) as exc_info:
            Settings(GEMINI_MODEL=legacy_model)
        assert "deprecated" in str(exc_info.value).lower()


def test_settings_normalizes_backend_url_trailing_slash() -> None:
    """Ensure trailing slash on BACKEND_API_BASE_URL is stripped."""
    settings = Settings(BACKEND_API_BASE_URL="http://localhost:3000/api/v1/")
    assert settings.BACKEND_API_BASE_URL == "http://localhost:3000/api/v1"


def test_secret_redaction_filter_scrubs_secrets() -> None:
    """Verify SecretRedactionFilter scrubs sensitive API keys and query parameters from logs."""
    raw_secret = "AIzaSySecretKey999888777"
    redactor = SecretRedactionFilter(secrets=[raw_secret])
    record = logging.LogRecord(
        name="remarket.ai.test",
        level=logging.INFO,
        pathname=__file__,
        lineno=10,
        msg=f"Calling endpoint with token={raw_secret} and ?key=OtherKey123456",
        args=(),
        exc_info=None,
    )
    redactor.filter(record)
    assert raw_secret not in record.msg
    assert "OtherKey123456" not in record.msg
    assert "***REDACTED***" in record.msg
