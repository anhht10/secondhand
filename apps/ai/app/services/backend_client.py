"""
Async NestJS Backend HTTP Client (`BackendClient`) for ReMarket AI Service.
Enforces architectural boundaries:
- AI Service NEVER queries MongoDB directly for business entities.
- All product, category, and seller profile queries go through NestJS REST APIs.
- Supports connection pooling, configurable timeouts, bounded retries with exponential
  backoff, X-Request-ID propagation, error mapping from NestJS `GlobalExceptionFilter`,
  and verified authentication context forwarding.
- Blocks unauthorized mutation methods (POST/PUT/PATCH/DELETE) by default in Phase 2.
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
import logging
from typing import Any, Mapping, Optional

import httpx

from app.core.auth_context import VerifiedUserContext, get_auth_context
from app.core.config import Settings, get_settings
from app.core.exceptions import (
    BackendAPIError,
    BackendAuthenticationError,
    BackendForbiddenError,
    BackendNotFoundError,
    BackendTimeoutError,
    BackendUnavailableError,
    BackendValidationError,
    SecurityViolationError,
)
from app.core.logging import get_request_id

logger = logging.getLogger("remarket.ai.services.backend_client")

_ALLOWED_READ_METHODS = frozenset({"GET", "HEAD"})
_TRANSIENT_STATUS_CODES = frozenset({408, 429, 500, 502, 503, 504})


def map_backend_error_response(status_code: int, payload: Any) -> BackendAPIError:
    """
    Map NestJS `GlobalExceptionFilter` JSON error payload and HTTP status code
    into a strongly-typed `BackendAPIError` subclass.
    """
    message = f"Backend API error (HTTP {status_code})"
    details: list[str] = []

    if isinstance(payload, Mapping):
        raw_msg = payload.get("message")
        if isinstance(raw_msg, str) and raw_msg.strip():
            message = raw_msg.strip()
        elif isinstance(raw_msg, list) and raw_msg:
            details = [str(item) for item in raw_msg]
            message = details[0]

        err_obj = payload.get("error")
        if isinstance(err_obj, Mapping):
            raw_details = err_obj.get("details")
            if isinstance(raw_details, list):
                details = [str(item) for item in raw_details]

    if status_code == 400 or status_code == 422:
        return BackendValidationError(message=message, details=details)
    if status_code == 401:
        return BackendAuthenticationError(message=message)
    if status_code == 403:
        return BackendForbiddenError(message=message)
    if status_code == 404:
        return BackendNotFoundError(message=message)
    if status_code == 408 or status_code == 504:
        return BackendTimeoutError(message=message)
    if status_code >= 500:
        return BackendUnavailableError(message=message)

    return BackendAPIError(
        message=message,
        code=f"BACKEND_HTTP_{status_code}",
        status_code=status_code,
        details=details,
    )


class BackendClient:
    """
    Asynchronous HTTP client for communicating with the NestJS ReMarket Backend API.
    Maintains a pooled `httpx.AsyncClient` and enforces read-only access for Phase 2 tools.
    """

    def __init__(
        self,
        *,
        settings: Optional[Settings] = None,
        http_client: Optional[httpx.AsyncClient] = None,
        initial_backoff_seconds: float = 0.25,
    ) -> None:
        self._settings = settings or get_settings()
        self._external_client = http_client is not None
        self._client: Optional[httpx.AsyncClient] = http_client
        self._initial_backoff_seconds = initial_backoff_seconds

    @property
    def base_url(self) -> str:
        return self._settings.BACKEND_API_BASE_URL

    def _get_or_create_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            limits = httpx.Limits(
                max_connections=self._settings.BACKEND_POOL_MAX_CONNECTIONS,
                max_keepalive_connections=self._settings.BACKEND_POOL_MAX_KEEPALIVE,
            )
            timeout = httpx.Timeout(self._settings.BACKEND_TIMEOUT_SECONDS)
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                limits=limits,
                timeout=timeout,
                headers={"Accept": "application/json"},
            )
        return self._client

    async def aclose(self) -> None:
        """Close the underlying `httpx.AsyncClient` connection pool if owned by this instance."""
        if self._client is not None and not self._external_client and not self._client.is_closed:
            await self._client.aclose()
            self._client = None

    def _build_headers(
        self,
        auth_context: Optional[VerifiedUserContext] = None,
        extra_headers: Optional[Mapping[str, str]] = None,
    ) -> dict[str, str]:
        """
        Build outgoing HTTP headers including `X-Request-ID`, verified `Authorization`
        Bearer token from `VerifiedUserContext`, and optional `X-Internal-Service-Token`.
        """
        ctx = auth_context or get_auth_context()
        req_id = ctx.request_id or get_request_id()
        if not req_id or req_id == "-":
            req_id = "req-ai-internal"

        headers: dict[str, str] = {
            "Accept": "application/json",
            "X-Request-ID": req_id,
        }

        # Attach verified user Bearer token if provided by NestJS context
        if ctx.raw_bearer_token:
            headers["Authorization"] = f"Bearer {ctx.raw_bearer_token}"

        # Attach verified user ID metadata header if authenticated
        if ctx.user_id:
            headers["X-Authenticated-User-Id"] = ctx.user_id

        # Attach internal service token if configured in environment
        if self._settings.backend_service_token_value:
            headers["X-Internal-Service-Token"] = self._settings.backend_service_token_value

        if extra_headers:
            for k, v in extra_headers.items():
                headers[k] = v

        return headers

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: Optional[Mapping[str, Any]] = None,
        auth_context: Optional[VerifiedUserContext] = None,
        headers: Optional[Mapping[str, str]] = None,
    ) -> dict[str, Any]:
        """
        Execute an HTTP request against the NestJS Backend with bounded retry,
        timeout handling, and standard envelope unwrapping.
        Only read-only methods (GET, HEAD) are permitted in Phase 2.
        """
        upper_method = method.strip().upper()
        if upper_method not in _ALLOWED_READ_METHODS:
            raise SecurityViolationError(
                f"HTTP method '{upper_method}' is blocked. Agent tools are strictly read-only in Phase 2."
            )

        clean_path = "/" + path.strip().lstrip("/")
        cleaned_params = {
            k: v
            for k, v in (params or {}).items()
            if v is not None and v != ""
        }
        req_headers = self._build_headers(auth_context=auth_context, extra_headers=headers)
        max_attempts = max(1, self._settings.BACKEND_MAX_RETRIES + 1)
        client = self._get_or_create_client()

        last_error: Optional[BackendAPIError] = None

        for attempt in range(1, max_attempts + 1):
            try:
                response = await client.request(
                    method=upper_method,
                    url=clean_path,
                    params=cleaned_params,
                    headers=req_headers,
                )

                try:
                    payload = response.json()
                except Exception:
                    payload = {"message": response.text or f"HTTP {response.status_code}"}

                if response.status_code >= 400:
                    mapped_err = map_backend_error_response(response.status_code, payload)
                    if (
                        response.status_code in _TRANSIENT_STATUS_CODES
                        and attempt < max_attempts
                    ):
                        backoff = self._initial_backoff_seconds * (2 ** (attempt - 1))
                        logger.warning(
                            "Backend %s %s returned %d on attempt %d/%d, retrying in %.2fs",
                            upper_method,
                            clean_path,
                            response.status_code,
                            attempt,
                            max_attempts,
                            backoff,
                        )
                        last_error = mapped_err
                        await asyncio.sleep(backoff)
                        continue
                    raise mapped_err

                if isinstance(payload, dict):
                    return payload
                return {"success": True, "data": payload, "meta": {}}

            except (httpx.TimeoutException, asyncio.TimeoutError) as exc:
                timeout_err = BackendTimeoutError(
                    f"Backend API request {upper_method} {clean_path} timed out after "
                    f"{self._settings.BACKEND_TIMEOUT_SECONDS}s."
                )
                last_error = timeout_err
                if attempt < max_attempts:
                    backoff = self._initial_backoff_seconds * (2 ** (attempt - 1))
                    logger.warning(
                        "Backend %s %s timed out on attempt %d/%d, retrying in %.2fs",
                        upper_method,
                        clean_path,
                        attempt,
                        max_attempts,
                        backoff,
                    )
                    await asyncio.sleep(backoff)
                    continue
                raise timeout_err from exc

            except httpx.HTTPError as exc:
                unavail_err = BackendUnavailableError(
                    f"Failed to connect to NestJS Backend API at {self.base_url}{clean_path}."
                )
                last_error = unavail_err
                if attempt < max_attempts:
                    backoff = self._initial_backoff_seconds * (2 ** (attempt - 1))
                    logger.warning(
                        "Backend %s %s connection error (%s) on attempt %d/%d, retrying in %.2fs",
                        upper_method,
                        clean_path,
                        type(exc).__name__,
                        attempt,
                        max_attempts,
                        backoff,
                    )
                    await asyncio.sleep(backoff)
                    continue
                raise unavail_err from exc

        raise last_error or BackendUnavailableError("Backend API request failed.")

    async def list_products(
        self,
        *,
        keyword: Optional[str] = None,
        category: Optional[str] = None,
        condition: Optional[str] = None,
        min_price: Optional[float] = None,
        max_price: Optional[float] = None,
        location: Optional[str] = None,
        status: Optional[str] = None,
        sort: Optional[str] = None,
        page: int = 1,
        limit: int = 12,
        auth_context: Optional[VerifiedUserContext] = None,
    ) -> dict[str, Any]:
        """
        Call `GET /api/v1/products` on the NestJS Backend.
        Maps parameters to `QueryProductDto`.
        """
        params: dict[str, Any] = {
            "page": page,
            "limit": limit,
        }
        if keyword:
            params["keyword"] = keyword.strip()
        if category:
            params["category"] = category.strip()
        if condition:
            params["condition"] = condition.strip().upper()
        if min_price is not None:
            params["minPrice"] = min_price
        if max_price is not None:
            params["maxPrice"] = max_price
        if location:
            params["location"] = location.strip()
        if status:
            params["status"] = status.strip().upper()
        if sort:
            params["sort"] = sort.strip()

        return await self.request(
            "GET",
            "/products",
            params=params,
            auth_context=auth_context,
        )

    async def get_product_by_id(
        self,
        product_id: str,
        *,
        auth_context: Optional[VerifiedUserContext] = None,
    ) -> dict[str, Any]:
        """Call `GET /api/v1/products/:id` on the NestJS Backend."""
        clean_id = product_id.strip()
        return await self.request(
            "GET",
            f"/products/{clean_id}",
            auth_context=auth_context,
        )

    async def list_categories(
        self,
        *,
        parent_id: Optional[str] = None,
        auth_context: Optional[VerifiedUserContext] = None,
    ) -> dict[str, Any]:
        """Call `GET /api/v1/categories` on the NestJS Backend."""
        params: dict[str, Any] = {}
        if parent_id:
            params["parentId"] = parent_id.strip()
        return await self.request(
            "GET",
            "/categories",
            params=params,
            auth_context=auth_context,
        )

    async def get_category_by_id(
        self,
        category_id: str,
        *,
        auth_context: Optional[VerifiedUserContext] = None,
    ) -> dict[str, Any]:
        """Call `GET /api/v1/categories/:id` on the NestJS Backend."""
        clean_id = category_id.strip()
        return await self.request(
            "GET",
            f"/categories/{clean_id}",
            auth_context=auth_context,
        )

    async def get_seller_public_profile(
        self,
        seller_id: str,
        *,
        auth_context: Optional[VerifiedUserContext] = None,
    ) -> dict[str, Any]:
        """Call `GET /api/v1/users/:id` on the NestJS Backend."""
        clean_id = seller_id.strip()
        return await self.request(
            "GET",
            f"/users/{clean_id}",
            auth_context=auth_context,
        )


def run_async_safely(coro: Any) -> Any:
    """
    Execute an async coroutine safely from synchronous tool execution contexts,
    handling both cases where an event loop is or is not already running on the current thread.
    """
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = None

    if loop is not None and loop.is_running():
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(asyncio.run, coro)
            return future.result()
    return asyncio.run(coro)


_default_backend_client: Optional[BackendClient] = None


def get_backend_client(settings: Optional[Settings] = None) -> BackendClient:
    """Return the shared BackendClient singleton."""
    global _default_backend_client
    if settings is not None:
        return BackendClient(settings=settings)
    if _default_backend_client is None:
        _default_backend_client = BackendClient(settings=get_settings())
    return _default_backend_client


def set_backend_client(client: Optional[BackendClient]) -> None:
    """Override the shared BackendClient singleton (useful for dependency injection in tests)."""
    global _default_backend_client
    _default_backend_client = client
