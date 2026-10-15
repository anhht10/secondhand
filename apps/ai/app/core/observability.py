"""
Observability, Node Tracing, Token Usage Tracking, and Rate Limiting (`app.core.observability`).
Provides:
- `trace_graph_node`: Decorator for LangGraph nodes that logs execution time and errors.
- `extract_token_usage`: Extracts token usage metadata from LangChain `BaseMessage` responses.
- `InMemoryRateLimiter`: Sliding-window rate limiter per client/user to protect AI endpoints.
"""

from collections import deque
from functools import wraps
import inspect
import logging
import time
from typing import Any, Callable, Optional

from fastapi import status
from langchain_core.messages import BaseMessage
from pydantic import BaseModel

from app.core.exceptions import AIServiceError
from app.core.logging import get_request_id

logger = logging.getLogger("remarket.ai.observability")


class TokenUsageMetrics(BaseModel):
    """Token usage statistics extracted from an LLM invocation."""

    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0


class RateLimitExceededError(AIServiceError):
    """Raised when a client exceeds the configured AI request rate limit."""

    def __init__(
        self,
        message: str = "Too many AI requests. Please wait before retrying.",
    ) -> None:
        super().__init__(
            message=message,
            code="AI_RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )


def extract_token_usage(message: Optional[BaseMessage]) -> TokenUsageMetrics:
    """Extract token usage counts from a LangChain `AIMessage` if provided by the model."""
    if message is None:
        return TokenUsageMetrics()

    usage_meta = getattr(message, "usage_metadata", None)
    if isinstance(usage_meta, dict):
        inp = int(usage_meta.get("input_tokens") or usage_meta.get("prompt_token_count") or 0)
        out = int(usage_meta.get("output_tokens") or usage_meta.get("candidates_token_count") or 0)
        tot = int(usage_meta.get("total_tokens") or (inp + out))
        return TokenUsageMetrics(
            input_tokens=inp,
            output_tokens=out,
            total_tokens=tot,
        )

    resp_meta = getattr(message, "response_metadata", None)
    if isinstance(resp_meta, dict):
        token_usage = resp_meta.get("token_usage") or resp_meta.get("usage_metadata") or {}
        if isinstance(token_usage, dict):
            inp = int(
                token_usage.get("input_tokens")
                or token_usage.get("prompt_tokens")
                or token_usage.get("prompt_token_count")
                or 0
            )
            out = int(
                token_usage.get("output_tokens")
                or token_usage.get("completion_tokens")
                or token_usage.get("candidates_token_count")
                or 0
            )
            tot = int(token_usage.get("total_tokens") or (inp + out))
            return TokenUsageMetrics(
                input_tokens=inp,
                output_tokens=out,
                total_tokens=tot,
            )

    return TokenUsageMetrics()


def trace_graph_node(graph_name: str, node_name: str) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    """
    Decorator for sync or async LangGraph node functions that logs node entry,
    completion latency (`latency_ms`), and error details with `request_id`.
    """

    def decorator(func: Callable[..., Any]) -> Callable[..., Any]:
        if inspect.iscoroutinefunction(func):

            @wraps(func)
            async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
                start = time.perf_counter()
                try:
                    result = await func(*args, **kwargs)
                    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)
                    logger.info(
                        "GraphNodeTrace graph=%s node=%s status=ok latency_ms=%.2f request_id=%s",
                        graph_name,
                        node_name,
                        elapsed_ms,
                        get_request_id(),
                    )
                    return result
                except Exception as exc:
                    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)
                    logger.error(
                        "GraphNodeTrace graph=%s node=%s status=error error_type=%s latency_ms=%.2f request_id=%s",
                        graph_name,
                        node_name,
                        type(exc).__name__,
                        elapsed_ms,
                        get_request_id(),
                    )
                    raise

            return async_wrapper

        @wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> Any:
            start = time.perf_counter()
            try:
                result = func(*args, **kwargs)
                elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)
                logger.info(
                    "GraphNodeTrace graph=%s node=%s status=ok latency_ms=%.2f request_id=%s",
                    graph_name,
                    node_name,
                    elapsed_ms,
                    get_request_id(),
                )
                return result
            except Exception as exc:
                elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)
                logger.error(
                    "GraphNodeTrace graph=%s node=%s status=error error_type=%s latency_ms=%.2f request_id=%s",
                    graph_name,
                    node_name,
                    type(exc).__name__,
                    elapsed_ms,
                    get_request_id(),
                )
                raise

        return sync_wrapper

    return decorator


class InMemoryRateLimiter:
    """Sliding-window rate limiter keyed by user ID or client identifier."""

    def __init__(self, max_requests: int = 60, window_seconds: float = 60.0) -> None:
        self._max_requests = max(1, max_requests)
        self._window_seconds = max(1.0, window_seconds)
        self._buckets: dict[str, deque[float]] = {}

    def check_rate_limit(self, key: str) -> None:
        """Raise `RateLimitExceededError` if `key` has exceeded `max_requests` in the window."""
        now = time.monotonic()
        cutoff = now - self._window_seconds
        bucket = self._buckets.setdefault(key, deque())
        while bucket and bucket[0] < cutoff:
            bucket.popleft()
        if len(bucket) >= self._max_requests:
            raise RateLimitExceededError(
                f"Rate limit exceeded ({self._max_requests} requests per {int(self._window_seconds)}s)."
            )
        bucket.append(now)

    def clear(self) -> None:
        self._buckets.clear()
