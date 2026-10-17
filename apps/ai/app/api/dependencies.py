"""
FastAPI Dependency Injection providers for ReMarket AI Service.
Allows clean override in unit and integration tests via `app.dependency_overrides`.
"""

from fastapi import Depends

from app.agents.registry import GraphRegistry, get_graph_registry
from app.core.auth_context import VerifiedUserContext, get_auth_context
from app.core.config import Settings, get_settings
from app.memory.checkpointer import CheckpointerManager, get_checkpointer_manager
from app.rag.pipelines import RAGPipeline
from app.services.agent_service import AgentApplicationService, get_shared_rate_limiter
from app.services.backend_client import BackendClient, get_backend_client
from app.services.graph_runner import TestChatService
from app.tools.registry import ToolRegistry, get_tool_registry


def get_app_settings() -> Settings:
    """Provide the active application settings."""
    return get_settings()


def get_current_auth_context() -> VerifiedUserContext:
    """Provide the verified user authentication context for the current request."""
    return get_auth_context()


def get_app_backend_client(
    settings: Settings = Depends(get_app_settings),
) -> BackendClient:
    """Provide the shared async NestJS Backend HTTP client."""
    return get_backend_client(settings)


def get_app_tool_registry(
    backend_client: BackendClient = Depends(get_app_backend_client),
) -> ToolRegistry:
    """Provide the ToolRegistry populated with the 6 ReMarket Phase 2 tools."""
    return get_tool_registry(client=backend_client)


def get_app_rag_pipeline(
    settings: Settings = Depends(get_app_settings),
) -> RAGPipeline:
    """Provide the RAGPipeline instance for semantic retrieval and ingestion."""
    return RAGPipeline(settings=settings)


def get_app_graph_registry(
    settings: Settings = Depends(get_app_settings),
) -> GraphRegistry:
    """Provide the shared LangGraph workflow registry."""
    return get_graph_registry(settings)


def get_app_checkpointer_manager(
    settings: Settings = Depends(get_app_settings),
) -> CheckpointerManager:
    """Provide the shared CheckpointerManager singleton."""
    return get_checkpointer_manager(settings)


def get_test_chat_service(
    settings: Settings = Depends(get_app_settings),
    registry: GraphRegistry = Depends(get_app_graph_registry),
) -> TestChatService:
    """Provide the TestChatService instance for `POST /ai/test-chat`."""
    return TestChatService(registry=registry, settings=settings)


def get_agent_application_service(
    settings: Settings = Depends(get_app_settings),
    registry: GraphRegistry = Depends(get_app_graph_registry),
    backend_client: BackendClient = Depends(get_app_backend_client),
    rag_pipeline: RAGPipeline = Depends(get_app_rag_pipeline),
    checkpointer_manager: CheckpointerManager = Depends(get_app_checkpointer_manager),
) -> AgentApplicationService:
    """Provide the `AgentApplicationService` orchestrating all 4 specialized Agents + Supervisor."""
    return AgentApplicationService(
        settings=settings,
        registry=registry,
        backend_client=backend_client,
        rag_pipeline=rag_pipeline,
        checkpointer_manager=checkpointer_manager,
        rate_limiter=get_shared_rate_limiter(settings),
    )
