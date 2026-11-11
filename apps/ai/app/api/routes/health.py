"""
Health and Readiness endpoints (`GET /health` and `GET /health/ready`).
"""

from fastapi import APIRouter, Depends

from app.agents.registry import GraphRegistry
from app.api.dependencies import get_app_graph_registry, get_app_settings
from app.core.config import Settings
from app.memory.checkpointer import get_checkpointer_manager
from app.schemas.health import HealthResponse, ReadinessResponse
from app.tools.registry import get_tool_registry

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Liveness health check",
)
async def health_check(
    settings: Settings = Depends(get_app_settings),
) -> HealthResponse:
    """Verify the FastAPI process is alive and responsive."""
    return HealthResponse(
        status="ok",
        service="remarket-ai-service",
        version="0.2.0",
        model=settings.GEMINI_MODEL,
    )


@router.get(
    "/health/ready",
    response_model=ReadinessResponse,
    summary="Readiness check for Gemini, LangGraph, Tools, and RAG foundation",
)
async def readiness_check(
    settings: Settings = Depends(get_app_settings),
    registry: GraphRegistry = Depends(get_app_graph_registry),
) -> ReadinessResponse:
    """
    Verify LangGraph compilation, checkpointer status, registered tools count,
    embedding model configuration, and whether `GEMINI_API_KEY` is configured.
    """
    graph_compiled = False
    try:
        compiled = registry.get_test_chat_graph()
        graph_compiled = compiled is not None
    except Exception:
        graph_compiled = False

    checkpointer_manager = get_checkpointer_manager(settings)
    tool_registry = get_tool_registry()
    gemini_ready = settings.has_gemini_api_key
    overall_status = "ready" if (graph_compiled and gemini_ready) else "degraded"

    return ReadinessResponse(
        status=overall_status,
        service="remarket-ai-service",
        gemini_configured=gemini_ready,
        graph_compiled=graph_compiled,
        checkpointer_backend=checkpointer_manager.backend_type,
        vector_store_type=settings.VECTOR_STORE_TYPE,
        model=settings.GEMINI_MODEL,
        embedding_model=settings.GEMINI_EMBEDDING_MODEL,
        registered_tools_count=len(tool_registry.get_all()),
    )
