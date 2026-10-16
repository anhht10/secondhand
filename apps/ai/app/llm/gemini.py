"""
Centralized Google Gemini Model Factory for ReMarket AI Service.
Provides cached `ChatGoogleGenerativeAI` instances (backed by `google-genai`),
structured output binding, timeout enforcement, exponential retry/backoff,
and classification of Quota / Rate Limit / Auth / Timeout errors without
ever exposing API keys.
"""

import asyncio
import logging
import time
from typing import Any, Optional, Type, TypeVar

from google import genai
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import BaseMessage
from langchain_core.runnables import Runnable
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import BaseModel

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    AIServiceError,
    LLMAuthenticationError,
    LLMConfigurationError,
    LLMExecutionError,
    LLMQuotaExceededError,
    LLMTimeoutError,
)

logger = logging.getLogger("remarket.ai.llm.gemini")

TSchema = TypeVar("TSchema", bound=BaseModel)


def classify_llm_exception(exc: Exception) -> AIServiceError:
    """Map raw SDK / LangChain / HTTP exceptions to safe domain exceptions."""
    if isinstance(exc, AIServiceError):
        return exc

    if isinstance(exc, (asyncio.TimeoutError, TimeoutError)):
        return LLMTimeoutError("Gemini LLM request timed out.")

    raw_msg = str(exc)
    upper_msg = raw_msg.upper()

    if "TIMEOUT" in upper_msg or "DEADLINE_EXCEEDED" in upper_msg or "TIMED OUT" in upper_msg:
        return LLMTimeoutError("Gemini LLM request exceeded the configured timeout.")

    if (
        "429" in upper_msg
        or "RESOURCE_EXHAUSTED" in upper_msg
        or "QUOTA" in upper_msg
        or "RATE_LIMIT" in upper_msg
        or "TOO MANY REQUESTS" in upper_msg
    ):
        return LLMQuotaExceededError(
            "Gemini API quota or rate limit exceeded (HTTP 429 / RESOURCE_EXHAUSTED)."
        )

    if (
        "API_KEY_INVALID" in upper_msg
        or "INVALID API KEY" in upper_msg
        or "PERMISSION_DENIED" in upper_msg
        or "UNAUTHENTICATED" in upper_msg
        or "401" in upper_msg
        or "403" in upper_msg
    ):
        return LLMAuthenticationError(
            "Gemini API authentication failed. Verify GEMINI_API_KEY configuration."
        )

    return LLMExecutionError("Upstream Gemini LLM invocation failed.")


class GeminiModelFactory:
    """
    Singleton-style factory that caches initialized `ChatGoogleGenerativeAI`
    and `genai.Client` instances by configuration signature so models are not
    recreated on every HTTP request.
    """

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._model_cache: dict[tuple[str, float, float, int], ChatGoogleGenerativeAI] = {}
        self._genai_client: Optional[genai.Client] = None

    @property
    def settings(self) -> Settings:
        return self._settings

    def validate_api_key(self) -> str:
        """Return the raw API key string or raise LLMConfigurationError if missing."""
        if not self._settings.has_gemini_api_key:
            raise LLMConfigurationError(
                "GEMINI_API_KEY is not configured. Set GEMINI_API_KEY in environment or .env."
            )
        return self._settings.GEMINI_API_KEY.get_secret_value().strip()

    def get_chat_model(
        self,
        *,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
        max_retries: Optional[int] = None,
    ) -> ChatGoogleGenerativeAI:
        """
        Return a cached `ChatGoogleGenerativeAI` instance configured for `gemini-3.8-flash`
        (or the specified model). Raises `LLMConfigurationError` if `GEMINI_API_KEY` is missing.
        """
        api_key = self.validate_api_key()
        resolved_model = (model or self._settings.GEMINI_MODEL).strip()
        resolved_temp = (
            temperature if temperature is not None else self._settings.GEMINI_TEMPERATURE
        )
        resolved_timeout = (
            timeout if timeout is not None else self._settings.GEMINI_TIMEOUT_SECONDS
        )
        resolved_retries = (
            max_retries if max_retries is not None else self._settings.GEMINI_MAX_RETRIES
        )

        cache_key = (
            resolved_model,
            float(resolved_temp),
            float(resolved_timeout),
            int(resolved_retries),
        )

        cached = self._model_cache.get(cache_key)
        if cached is not None:
            return cached

        logger.info(
            "Initializing ChatGoogleGenerativeAI model=%s temperature=%s timeout=%ss max_retries=%s",
            resolved_model,
            resolved_temp,
            resolved_timeout,
            resolved_retries,
        )

        chat_model = ChatGoogleGenerativeAI(
            model=resolved_model,
            google_api_key=api_key,
            temperature=resolved_temp,
            timeout=resolved_timeout,
            max_retries=resolved_retries,
        )
        self._model_cache[cache_key] = chat_model
        return chat_model

    def get_structured_model(
        self,
        schema: Type[TSchema],
        *,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
    ) -> Runnable[Any, TSchema]:
        """Return a Runnable chat model bound with Pydantic structured output schema."""
        base_model = self.get_chat_model(
            model=model,
            temperature=temperature,
            timeout=timeout,
        )
        return base_model.with_structured_output(schema)

    get_structured_chat_model = get_structured_model

    def get_genai_sdk_client(self) -> genai.Client:
        """
        Return a cached `google.genai.Client` instance for direct Interactions API calls
        when features beyond LangChain's standard chat adapter are required.
        """
        api_key = self.validate_api_key()
        if self._genai_client is None:
            self._genai_client = genai.Client(api_key=api_key)
        return self._genai_client

    def clear_cache(self) -> None:
        """Clear cached model instances."""
        self._model_cache.clear()
        self._genai_client = None


async def invoke_llm_with_resilience(
    llm: BaseChatModel,
    messages: list[BaseMessage],
    *,
    timeout_seconds: float = 30.0,
    max_attempts: int = 2,
    initial_backoff_seconds: float = 0.5,
) -> BaseMessage:
    """
    Invoke a LangChain `BaseChatModel` with explicit timeout, exponential backoff for
    transient failures, and structured exception classification.
    """
    last_error: Optional[Exception] = None

    for attempt in range(1, max(1, max_attempts) + 1):
        try:
            if hasattr(llm, "ainvoke"):
                response = await asyncio.wait_for(
                    llm.ainvoke(messages),
                    timeout=timeout_seconds,
                )
            else:
                response = await asyncio.wait_for(
                    asyncio.to_thread(llm.invoke, messages),
                    timeout=timeout_seconds,
                )
            return response
        except Exception as exc:
            classified = classify_llm_exception(exc)
            last_error = classified

            # If primary ChatGoogleGenerativeAI model (e.g. gemini-3.8-flash) fails with NOT_FOUND/404,
            # automatically try fallback Gemini Flash models before giving up.
            if isinstance(llm, ChatGoogleGenerativeAI) and (
                "NOT_FOUND" in str(exc).upper() or "404" in str(exc)
            ):
                for fb_model_name in ("gemini-2.5-flash", "gemini-2.0-flash"):
                    try:
                        api_key = get_settings().GEMINI_API_KEY.get_secret_value().strip()
                        if api_key:
                            fb_llm = ChatGoogleGenerativeAI(
                                model=fb_model_name,
                                google_api_key=api_key,
                                temperature=getattr(llm, "temperature", 0.3) or 0.3,
                                timeout=timeout_seconds,
                                max_retries=1,
                            )
                            return await asyncio.wait_for(
                                fb_llm.ainvoke(messages),
                                timeout=timeout_seconds,
                            )
                    except Exception:
                        continue

            # Do not retry authentication or configuration errors
            if isinstance(classified, (LLMAuthenticationError, LLMConfigurationError)):
                raise classified from exc

            if attempt < max_attempts:
                backoff = initial_backoff_seconds * (2 ** (attempt - 1))
                logger.warning(
                    "LLM invocation attempt %d/%d failed (%s), retrying in %.2fs",
                    attempt,
                    max_attempts,
                    classified.code,
                    backoff,
                )
                await asyncio.sleep(backoff)
            else:
                raise classified from exc

    raise classify_llm_exception(last_error or RuntimeError("LLM invocation failed"))


def invoke_llm_sync_with_resilience(
    llm: BaseChatModel,
    messages: list[BaseMessage],
    *,
    timeout_seconds: float = 30.0,
    max_attempts: int = 2,
    initial_backoff_seconds: float = 0.5,
) -> BaseMessage:
    """Synchronous counterpart to `invoke_llm_with_resilience` for sync graph execution."""
    last_error: Optional[Exception] = None

    for attempt in range(1, max(1, max_attempts) + 1):
        try:
            start = time.perf_counter()
            response = llm.invoke(messages)
            elapsed = time.perf_counter() - start
            if elapsed > timeout_seconds:
                raise LLMTimeoutError("Gemini LLM request exceeded timeout.")
            return response
        except Exception as exc:
            classified = classify_llm_exception(exc)
            last_error = classified

            if isinstance(classified, (LLMAuthenticationError, LLMConfigurationError)):
                raise classified from exc

            if attempt < max_attempts:
                backoff = initial_backoff_seconds * (2 ** (attempt - 1))
                logger.warning(
                    "Sync LLM invocation attempt %d/%d failed (%s), retrying in %.2fs",
                    attempt,
                    max_attempts,
                    classified.code,
                    backoff,
                )
                time.sleep(backoff)
            else:
                raise classified from exc

    raise classify_llm_exception(last_error or RuntimeError("LLM invocation failed"))


_default_factory: Optional[GeminiModelFactory] = None


def get_gemini_factory(settings: Optional[Settings] = None) -> GeminiModelFactory:
    """Return the shared GeminiModelFactory singleton."""
    global _default_factory
    if settings is not None:
        return GeminiModelFactory(settings=settings)
    if _default_factory is None:
        _default_factory = GeminiModelFactory(settings=get_settings())
    return _default_factory


def reset_gemini_factory() -> None:
    """Reset the shared GeminiModelFactory singleton (used in tests)."""
    global _default_factory
    if _default_factory is not None:
        _default_factory.clear_cache()
    _default_factory = None
