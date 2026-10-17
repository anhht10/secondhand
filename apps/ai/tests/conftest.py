"""
Shared pytest fixtures and deterministic MockChatModel for unit testing.
"""

from typing import Any, List, Optional
from fastapi.testclient import TestClient
from langchain_core.callbacks import CallbackManagerForLLMRun
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage, BaseMessage
from langchain_core.outputs import ChatGeneration, ChatResult
from langgraph.checkpoint.memory import MemorySaver
import pytest

from app.agents.registry import GraphRegistry, reset_graph_registry
from app.api.dependencies import (
    get_app_graph_registry,
    get_app_settings,
    get_test_chat_service,
)
from app.core.config import Settings, clear_settings_cache
from app.graphs.test_chat_graph import compile_test_chat_graph
from app.llm.gemini import reset_gemini_factory
from app.main import create_app
from app.memory.checkpointer import reset_checkpointer_manager
from app.services.graph_runner import TestChatService


class DeterministicMockChatModel(BaseChatModel):
    """
    Deterministic LangChain BaseChatModel used in unit tests to verify
    LangGraph state transitions without making external network requests.
    """

    model: str = "gemini-3.8-flash"
    recorded_histories: List[List[BaseMessage]] = []

    @property
    def _llm_type(self) -> str:
        return "deterministic-mock-gemini"

    def _generate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager: Optional[CallbackManagerForLLMRun] = None,
        **kwargs: Any,
    ) -> ChatResult:
        self.recorded_histories.append(list(messages))
        last_content = str(messages[-1].content) if messages else ""
        turn_count = len([m for m in messages if m.type == "human"])
        reply_text = f"[MockGemini turn={turn_count}] Echo: {last_content}"
        message = AIMessage(content=reply_text)
        return ChatResult(generations=[ChatGeneration(message=message)])


@pytest.fixture(autouse=True)
def reset_singletons() -> None:
    """Ensure singleton caches are clean before and after each test."""
    clear_settings_cache()
    reset_gemini_factory()
    reset_checkpointer_manager()
    reset_graph_registry()
    yield
    clear_settings_cache()
    reset_gemini_factory()
    reset_checkpointer_manager()
    reset_graph_registry()


@pytest.fixture()
def test_settings() -> Settings:
    """Provide isolated Settings with a dummy API key for unit testing."""
    return Settings(
        GEMINI_API_KEY="test-dummy-gemini-api-key-12345",
        GEMINI_MODEL="gemini-3.8-flash",
        GEMINI_TEMPERATURE=0.1,
        GEMINI_TIMEOUT_SECONDS=10.0,
        GEMINI_MAX_RETRIES=1,
        BACKEND_API_BASE_URL="http://localhost:3000/api/v1",
        BACKEND_SERVICE_TOKEN="test-internal-service-token-xyz",
        AI_SERVICE_PORT=8000,
        LOG_LEVEL="INFO",
        CHECKPOINTER_DATABASE_URL="memory://",
        VECTOR_STORE_TYPE="memory",
    )


@pytest.fixture()
def mock_llm() -> DeterministicMockChatModel:
    """Provide a fresh DeterministicMockChatModel instance."""
    return DeterministicMockChatModel(recorded_histories=[])


@pytest.fixture()
def client_with_mock_llm(
    test_settings: Settings, mock_llm: DeterministicMockChatModel
) -> TestClient:
    """
    Provide a FastAPI TestClient wired with `test_settings` and `mock_llm`
    inside the compiled LangGraph workflow.
    """
    app = create_app(settings_override=test_settings)
    checkpointer = MemorySaver()
    compiled_graph = compile_test_chat_graph(
        llm=mock_llm,
        checkpointer=checkpointer,
        settings=test_settings,
    )
    registry = GraphRegistry(settings=test_settings)
    registry.register("test_chat", compiled_graph)
    chat_service = TestChatService(
        compiled_graph=compiled_graph,
        registry=registry,
        settings=test_settings,
    )

    app.dependency_overrides[get_app_settings] = lambda: test_settings
    app.dependency_overrides[get_app_graph_registry] = lambda: registry
    app.dependency_overrides[get_test_chat_service] = lambda: chat_service

    with TestClient(app) as test_client:
        yield test_client
