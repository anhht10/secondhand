"""
Live Google Gemini Integration Tests (`@pytest.mark.integration`).
Executes real `FastAPI -> LangGraph (START -> llm_node -> END) -> Gemini` and
`GeminiEmbeddingProvider` (`gemini-embedding-001`) invocations when `GEMINI_API_KEY`
is provided in `.env` or environment variables.
Automatically skipped when `GEMINI_API_KEY` is not set or is the placeholder value.
"""

import os
from langchain_core.messages import HumanMessage
from langgraph.checkpoint.memory import MemorySaver
import pytest

from app.core.config import get_settings
from app.graphs.test_chat_graph import compile_test_chat_graph
from app.rag.embeddings import GeminiEmbeddingProvider


def _has_real_gemini_api_key() -> bool:
    raw = os.getenv("GEMINI_API_KEY", "").strip()
    if not raw:
        settings = get_settings()
        raw = settings.gemini_api_key_value
    return bool(raw and raw != "your_gemini_api_key_here" and not raw.startswith("test-dummy"))


@pytest.mark.integration
@pytest.mark.skipif(
    not _has_real_gemini_api_key(),
    reason="Live GEMINI_API_KEY not configured in environment; skipping live Gemini integration test.",
)
@pytest.mark.asyncio
async def test_live_gemini_invocation_via_langgraph() -> None:
    """
    Verify live Google Gemini (`gemini-3.8-flash`) invocation through the compiled
    `START -> llm_node -> END` LangGraph workflow.
    """
    settings = get_settings()
    compiled_graph = compile_test_chat_graph(
        checkpointer=MemorySaver(),
        settings=settings,
    )
    result = await compiled_graph.ainvoke(
        {
            "messages": [
                HumanMessage(
                    content="Reply with the exact word READY if you receive this message."
                )
            ],
            "thread_id": "live-integration-thread",
        },
        config={"configurable": {"thread_id": "live-integration-thread"}},
    )
    assert isinstance(result["reply"], str)
    assert len(result["reply"].strip()) > 0
    assert len(result["messages"]) == 2


@pytest.mark.integration
@pytest.mark.skipif(
    not _has_real_gemini_api_key(),
    reason="Live GEMINI_API_KEY not configured in environment; skipping live Gemini embedding test.",
)
def test_live_gemini_embedding_provider() -> None:
    """
    Verify live Google Gemini Embedding (`gemini-embedding-001`) invocation.
    """
    settings = get_settings()
    provider = GeminiEmbeddingProvider(settings=settings)
    vector = provider.embed_query("Hướng dẫn kiểm tra laptop cũ cho sinh viên ReMarket")
    assert isinstance(vector, list)
    assert len(vector) == settings.GEMINI_EMBEDDING_DIMENSIONS
