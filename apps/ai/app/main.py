"""
FastAPI Application Entrypoint for ReMarket AI Service (`D:\\cross-ck\\apps\\ai`).
Architecture: FastAPI -> AI Application Layer -> LangGraph Supervisor & Subgraphs -> Tools + RAG + Gemini (`gemini-3.8-flash`).
"""

from contextlib import asynccontextmanager
import logging
import time
import uuid
from typing import AsyncIterator, Optional

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
import uvicorn

from app.agents.registry import get_graph_registry
from app.api.routes.agents import router as agents_router
from app.api.routes.health import router as health_router
from app.api.routes.test_chat import router as test_chat_router
from app.core.auth_context import auth_context_scope, extract_auth_context_from_headers
from app.core.config import Settings, get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging, set_request_id
from app.services.backend_client import get_backend_client
from app.tools.registry import get_tool_registry

logger = logging.getLogger("remarket.ai.main")


class RequestIdMiddleware(BaseHTTPMiddleware):
    """
    Propagate or generate `X-Request-ID` for every incoming HTTP request,
    bind it and the verified `VerifiedUserContext` into `contextvars` for structured
    logging and downstream Backend tool calls, and return `X-Request-ID` on the response.
    """

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        incoming_id = request.headers.get("X-Request-ID") or request.headers.get("x-request-id")
        req_id = (incoming_id or "").strip() or f"req-{uuid.uuid4().hex[:16]}"
        set_request_id(req_id)

        user_ctx = extract_auth_context_from_headers(request.headers)
        start = time.perf_counter()
        with auth_context_scope(user_ctx):
            response = await call_next(request)
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        response.headers["X-Request-ID"] = req_id
        logger.info(
            "HTTP %s %s status=%d latency_ms=%.2f",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response


def create_app(settings_override: Optional[Settings] = None) -> FastAPI:
    """Create and configure the FastAPI application instance."""
    active_settings = settings_override or get_settings()
    configure_logging(active_settings)

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        configure_logging(active_settings)
        registry = get_graph_registry(active_settings)
        # Pre-compile all LangGraph workflows and initialize ToolRegistry at startup
        registry.get_test_chat_graph()
        registry.get_listing_graph()
        registry.get_pricing_graph()
        registry.get_inspection_graph()
        registry.get_shopping_assistant_graph()
        registry.get_supervisor_graph()
        tool_reg = get_tool_registry()
        logger.info(
            "ReMarket AI Service started port=%d model=%s embedding=%s graphs=%d tools=%d gemini_configured=%s",
            active_settings.AI_SERVICE_PORT,
            active_settings.GEMINI_MODEL,
            active_settings.GEMINI_EMBEDDING_MODEL,
            len(registry.list_registered_graphs()),
            len(tool_reg.get_all()),
            active_settings.has_gemini_api_key,
        )
        yield
        await get_backend_client().aclose()
        logger.info("ReMarket AI Service shutting down.")

    application = FastAPI(
        title="ReMarket AI Service",
        description=(
            "LangGraph Multi-Agent + Google Gemini AI Service for ReMarket Second-hand Marketplace. "
            "Provides Listing Generator, Smart Price Estimator, Buyer Inspection Checklist, "
            "Secondhand Shopping Assistant, and Supervisor Routing backed by Backend Tools and RAG."
        ),
        version="0.3.0",
        lifespan=lifespan,
    )

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    application.add_middleware(RequestIdMiddleware)

    register_exception_handlers(application)
    application.include_router(health_router)
    application.include_router(test_chat_router)
    application.include_router(agents_router)

    return application


app = create_app()


if __name__ == "__main__":
    cfg = get_settings()
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=cfg.AI_SERVICE_PORT,
        reload=False,
    )
