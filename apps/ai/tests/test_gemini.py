"""
Unit tests for Gemini Integration (`app.llm.gemini`).
"""

import asyncio
from pydantic import BaseModel
import pytest

from app.core.config import Settings
from app.core.exceptions import (
    LLMAuthenticationError,
    LLMConfigurationError,
    LLMExecutionError,
    LLMQuotaExceededError,
    LLMTimeoutError,
)
from app.llm.gemini import (
    GeminiModelFactory,
    classify_llm_exception,
    invoke_llm_with_resilience,
)
from tests.conftest import DeterministicMockChatModel


class SampleStructuredSchema(BaseModel):
    category: str
    confidence: float


def test_gemini_factory_raises_when_api_key_missing() -> None:
    """Ensure GeminiModelFactory raises LLMConfigurationError when GEMINI_API_KEY is empty."""
    empty_key_settings = Settings(GEMINI_API_KEY="")
    factory = GeminiModelFactory(settings=empty_key_settings)
    with pytest.raises(LLMConfigurationError) as exc_info:
        factory.get_chat_model()
    assert exc_info.value.code == "LLM_CONFIGURATION_ERROR"
    assert exc_info.value.status_code == 503


def test_gemini_factory_initializes_and_caches_chat_model(test_settings: Settings) -> None:
    """Verify ChatGoogleGenerativeAI initialization and instance caching by configuration."""
    factory = GeminiModelFactory(settings=test_settings)
    model_default_1 = factory.get_chat_model()
    model_default_2 = factory.get_chat_model()
    model_creative = factory.get_chat_model(temperature=0.7)

    assert model_default_1 is model_default_2
    assert model_default_1 is not model_creative
    assert model_default_1.model == "gemini-3.8-flash"
    assert model_default_1.temperature == 0.1
    assert model_creative.temperature == 0.7


def test_gemini_factory_creates_structured_output_runnable(test_settings: Settings) -> None:
    """Verify `.get_structured_chat_model(schema)` returns a bound structured output Runnable."""
    factory = GeminiModelFactory(settings=test_settings)
    structured_runnable = factory.get_structured_chat_model(SampleStructuredSchema)
    assert structured_runnable is not None
    assert hasattr(structured_runnable, "invoke")
    assert hasattr(structured_runnable, "ainvoke")


def test_classify_llm_exception_mappings() -> None:
    """Verify upstream Gemini exceptions map to structured domain exceptions."""
    quota_exc = classify_llm_exception(RuntimeError("429 RESOURCE_EXHAUSTED: Quota exceeded"))
    assert isinstance(quota_exc, LLMQuotaExceededError)
    assert quota_exc.status_code == 429

    auth_exc = classify_llm_exception(RuntimeError("401 API_KEY_INVALID: API key not valid"))
    assert isinstance(auth_exc, LLMAuthenticationError)
    assert auth_exc.status_code == 502

    timeout_exc = classify_llm_exception(TimeoutError("Request timed out after 30s"))
    assert isinstance(timeout_exc, LLMTimeoutError)
    assert timeout_exc.status_code == 504

    generic_exc = classify_llm_exception(ValueError("Unexpected model failure"))
    assert isinstance(generic_exc, LLMExecutionError)
    assert generic_exc.status_code == 502


@pytest.mark.asyncio
async def test_invoke_llm_with_resilience_succeeds_with_mock(
    mock_llm: DeterministicMockChatModel,
) -> None:
    """Verify invoke_llm_with_resilience executes cleanly with a mock LLM."""
    result = await invoke_llm_with_resilience(
        mock_llm,
        "Hello Gemini!",
        timeout_seconds=5.0,
        max_attempts=2,
    )
    assert "Echo: Hello Gemini!" in str(result.content)


@pytest.mark.asyncio
async def test_invoke_llm_with_resilience_timeout_handling() -> None:
    """Verify invoke_llm_with_resilience raises LLMTimeoutError when timeout is exceeded."""

    class SlowRunnable:
        async def ainvoke(self, _input: object) -> str:
            await asyncio.sleep(0.3)
            return "too late"

    with pytest.raises(LLMTimeoutError):
        await invoke_llm_with_resilience(
            SlowRunnable(),
            "Slow prompt",
            timeout_seconds=0.05,
            max_attempts=1,
        )
