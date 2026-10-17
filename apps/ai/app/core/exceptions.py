"""
Domain Exceptions and FastAPI Exception Handlers for ReMarket AI Service.
"""

import logging
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.core.logging import get_request_id

logger = logging.getLogger("remarket.ai.exceptions")


class AIServiceError(Exception):
    """Base exception for all ReMarket AI Service errors."""

    def __init__(
        self,
        message: str,
        code: str = "AI_SERVICE_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code


class LLMConfigurationError(AIServiceError):
    """Raised when GEMINI_API_KEY or model configuration is missing or invalid."""

    def __init__(self, message: str = "Gemini LLM is not configured with a valid API key.") -> None:
        super().__init__(
            message=message,
            code="LLM_CONFIGURATION_ERROR",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


class LLMAuthenticationError(AIServiceError):
    """Raised when Gemini rejects the provided API key."""

    def __init__(self, message: str = "Gemini API authentication failed.") -> None:
        super().__init__(
            message=message,
            code="LLM_AUTHENTICATION_ERROR",
            status_code=status.HTTP_502_BAD_GATEWAY,
        )


class LLMQuotaExceededError(AIServiceError):
    """Raised when Gemini quota or rate limit (HTTP 429 / RESOURCE_EXHAUSTED) is hit."""

    def __init__(
        self,
        message: str = "Gemini API rate limit or quota exceeded. Please retry later.",
    ) -> None:
        super().__init__(
            message=message,
            code="LLM_QUOTA_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )


class LLMTimeoutError(AIServiceError):
    """Raised when an LLM request exceeds GEMINI_TIMEOUT_SECONDS."""

    def __init__(
        self,
        message: str = "Gemini LLM request timed out.",
    ) -> None:
        super().__init__(
            message=message,
            code="LLM_TIMEOUT_ERROR",
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
        )


class LLMExecutionError(AIServiceError):
    """Raised when an unexpected upstream error occurs during LLM or graph execution."""

    def __init__(
        self,
        message: str = "Failed to execute AI workflow.",
    ) -> None:
        super().__init__(
            message=message,
            code="LLM_EXECUTION_ERROR",
            status_code=status.HTTP_502_BAD_GATEWAY,
        )


class BackendAPIError(AIServiceError):
    """Base exception for NestJS Backend API communication failures."""

    def __init__(
        self,
        message: str = "Backend API request failed.",
        code: str = "BACKEND_API_ERROR",
        status_code: int = status.HTTP_502_BAD_GATEWAY,
        details: list[str] | None = None,
    ) -> None:
        super().__init__(message=message, code=code, status_code=status_code)
        self.details = details or []


class BackendTimeoutError(BackendAPIError):
    """Raised when a NestJS Backend API request times out."""

    def __init__(self, message: str = "Backend API request timed out.") -> None:
        super().__init__(
            message=message,
            code="BACKEND_TIMEOUT_ERROR",
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
        )


class BackendUnavailableError(BackendAPIError):
    """Raised when the NestJS Backend API is unreachable or returns 5xx."""

    def __init__(self, message: str = "Backend API service is unavailable.") -> None:
        super().__init__(
            message=message,
            code="BACKEND_UNAVAILABLE_ERROR",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


class BackendAuthenticationError(BackendAPIError):
    """Raised when the Backend API returns 401 Unauthorized."""

    def __init__(self, message: str = "Backend authentication required or invalid token.") -> None:
        super().__init__(
            message=message,
            code="BACKEND_UNAUTHORIZED",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )


class BackendForbiddenError(BackendAPIError):
    """Raised when the Backend API returns 403 Forbidden."""

    def __init__(self, message: str = "Access to the requested backend resource is forbidden.") -> None:
        super().__init__(
            message=message,
            code="BACKEND_FORBIDDEN",
            status_code=status.HTTP_403_FORBIDDEN,
        )


class BackendNotFoundError(BackendAPIError):
    """Raised when the Backend API returns 404 Not Found."""

    def __init__(self, message: str = "Requested resource was not found on Backend.") -> None:
        super().__init__(
            message=message,
            code="BACKEND_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )


class BackendValidationError(BackendAPIError):
    """Raised when the Backend API returns 400 Bad Request / validation error."""

    def __init__(
        self,
        message: str = "Backend rejected request parameters.",
        details: list[str] | None = None,
    ) -> None:
        super().__init__(
            message=message,
            code="BACKEND_VALIDATION_ERROR",
            status_code=status.HTTP_400_BAD_REQUEST,
            details=details,
        )


class SecurityViolationError(AIServiceError):
    """Raised when a tool call or input violates security/authorization constraints."""

    def __init__(self, message: str = "Operation violates security policy.") -> None:
        super().__init__(
            message=message,
            code="SECURITY_VIOLATION",
            status_code=status.HTTP_403_FORBIDDEN,
        )


class ConversationNotFoundError(AIServiceError):
    """Raised when a requested AI conversation thread does not exist."""

    def __init__(self, message: str = "Conversation not found.") -> None:
        super().__init__(
            message=message,
            code="CONVERSATION_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )


class RAGError(AIServiceError):
    """Base exception for RAG ingestion, embedding, or retrieval errors."""

    def __init__(
        self,
        message: str = "RAG operation failed.",
        code: str = "RAG_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
    ) -> None:
        super().__init__(message=message, code=code, status_code=status_code)


class EmbeddingError(RAGError):
    """Raised when embedding generation fails."""

    def __init__(self, message: str = "Failed to generate embeddings.") -> None:
        super().__init__(
            message=message,
            code="EMBEDDING_ERROR",
            status_code=status.HTTP_502_BAD_GATEWAY,
        )


def register_exception_handlers(app: FastAPI) -> None:
    """Attach structured JSON exception handlers to the FastAPI instance."""

    @app.exception_handler(AIServiceError)
    async def handle_ai_service_error(_request: Request, exc: AIServiceError) -> JSONResponse:
        logger.warning(
            "AIServiceError code=%s status=%s message=%s",
            exc.code,
            exc.status_code,
            exc.message,
        )
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "statusCode": exc.status_code,
                "message": exc.message,
                "error": {
                    "code": exc.code,
                    "requestId": get_request_id(),
                },
            },
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        _request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        details = [
            f"{'.'.join(str(loc) for loc in err.get('loc', []))}: {err.get('msg', '')}"
            for err in exc.errors()
        ]
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content={
                "success": False,
                "statusCode": status.HTTP_422_UNPROCESSABLE_CONTENT,
                "message": details[0] if details else "Request validation failed",
                "error": {
                    "code": "VALIDATION_ERROR",
                    "details": details,
                    "requestId": get_request_id(),
                },
            },
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(_request: Request, exc: Exception) -> JSONResponse:
        logger.error("Unhandled exception in AI Service: %s", type(exc).__name__, exc_info=True)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "statusCode": status.HTTP_500_INTERNAL_SERVER_ERROR,
                "message": "Internal AI service error",
                "error": {
                    "code": "INTERNAL_SERVER_ERROR",
                    "requestId": get_request_id(),
                },
            },
        )
