"""
Foundational LangGraph Test Chat Endpoint (`POST /ai/test-chat`).
Verifies `FastAPI -> TestChatService -> LangGraph (START -> llm_node -> END) -> Gemini -> Response`.
"""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_test_chat_service
from app.schemas.test_chat import TestChatRequest, TestChatResponse
from app.services.graph_runner import TestChatService

router = APIRouter(prefix="/ai", tags=["AI Foundation"])


@router.post(
    "/test-chat",
    response_model=TestChatResponse,
    summary="Send a message through the foundational LangGraph + Gemini workflow",
)
async def test_chat_endpoint(
    payload: TestChatRequest,
    service: TestChatService = Depends(get_test_chat_service),
) -> TestChatResponse:
    """
    Execute the foundational `START -> llm_node -> END` LangGraph workflow with
    thread-level conversation state persistence.
    """
    return await service.execute_chat(payload)
