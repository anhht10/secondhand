"""
Unit tests for FastAPI Health, Readiness, and Test Chat endpoints (`app.api.routes`).
"""

from fastapi.testclient import TestClient

from app.api.dependencies import get_app_settings, get_test_chat_service
from app.core.config import Settings
from app.main import create_app
from app.services.graph_runner import TestChatService


def test_health_endpoint(client_with_mock_llm: TestClient) -> None:
    """Verify GET /health returns status=ok and X-Request-ID header."""
    response = client_with_mock_llm.get(
        "/health",
        headers={"X-Request-ID": "req-health-check-001"},
    )
    assert response.status_code == 200
    assert response.headers.get("X-Request-ID") == "req-health-check-001"
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "remarket-ai-service"
    assert body["model"] == "gemini-3.8-flash"


def test_readiness_endpoint_when_ready(client_with_mock_llm: TestClient) -> None:
    """Verify GET /health/ready returns status=ready when graph is compiled and API key is present."""
    response = client_with_mock_llm.get("/health/ready")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["gemini_configured"] is True
    assert body["graph_compiled"] is True
    assert body["checkpointer_backend"] == "memory"
    assert body["vector_store_type"] == "memory"


def test_readiness_endpoint_when_degraded_without_api_key() -> None:
    """Verify GET /health/ready reports status=degraded when GEMINI_API_KEY is empty."""
    unconfigured_settings = Settings(GEMINI_API_KEY="")
    app = create_app(settings_override=unconfigured_settings)
    app.dependency_overrides[get_app_settings] = lambda: unconfigured_settings

    with TestClient(app) as client:
        response = client.get("/health/ready")
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "degraded"
        assert body["gemini_configured"] is False
        assert body["graph_compiled"] is True


def test_test_chat_endpoint_multi_turn_with_mock_llm(
    client_with_mock_llm: TestClient,
) -> None:
    """
    Verify POST /ai/test-chat executes `FastAPI -> LangGraph -> MockLLM -> Response`
    and persists conversation state across turns with the same `thread_id`.
    """
    # Turn 1
    resp1 = client_with_mock_llm.post(
        "/ai/test-chat",
        json={
            "message": "Xin chào ReMarket AI!",
            "thread_id": "api-thread-101",
            "system_prompt": "You are ReMarket assistant.",
        },
        headers={"X-Request-ID": "req-chat-turn-1"},
    )
    assert resp1.status_code == 200
    body1 = resp1.json()
    assert body1["reply"] == "[MockGemini turn=1] Echo: Xin chào ReMarket AI!"
    assert body1["thread_id"] == "api-thread-101"
    assert body1["model"] == "gemini-3.8-flash"
    # SystemMessage + HumanMessage + AIMessage = 3 messages
    assert body1["message_count"] == 3
    assert body1["request_id"] == "req-chat-turn-1"

    # Turn 2 on the same thread_id
    resp2 = client_with_mock_llm.post(
        "/ai/test-chat",
        json={
            "message": "Bàn phím cơ cũ giá bao nhiêu hợp lý?",
            "thread_id": "api-thread-101",
        },
        headers={"X-Request-ID": "req-chat-turn-2"},
    )
    assert resp2.status_code == 200
    body2 = resp2.json()
    assert body2["reply"] == "[MockGemini turn=2] Echo: Bàn phím cơ cũ giá bao nhiêu hợp lý?"
    assert body2["thread_id"] == "api-thread-101"
    # Previous 3 messages + HumanMessage + AIMessage = 5 messages
    assert body2["message_count"] == 5
    assert body2["request_id"] == "req-chat-turn-2"


def test_test_chat_endpoint_validation_error_on_blank_message(
    client_with_mock_llm: TestClient,
) -> None:
    """Verify POST /ai/test-chat rejects empty or whitespace-only messages with HTTP 422."""
    response = client_with_mock_llm.post(
        "/ai/test-chat",
        json={"message": "   "},
    )
    assert response.status_code == 422
    body = response.json()
    assert body["success"] is False
    assert body["error"]["code"] == "VALIDATION_ERROR"


def test_test_chat_endpoint_returns_503_when_api_key_missing() -> None:
    """Verify POST /ai/test-chat returns structured HTTP 503 when GEMINI_API_KEY is not configured."""
    unconfigured_settings = Settings(GEMINI_API_KEY="")
    app = create_app(settings_override=unconfigured_settings)
    app.dependency_overrides[get_app_settings] = lambda: unconfigured_settings
    app.dependency_overrides[get_test_chat_service] = lambda: TestChatService(
        settings=unconfigured_settings
    )

    with TestClient(app) as client:
        response = client.post(
            "/ai/test-chat",
            json={"message": "Hello without API key"},
        )
        assert response.status_code == 503
        body = response.json()
        assert body["success"] is False
        assert body["error"]["code"] == "LLM_CONFIGURATION_ERROR"
