"""
Unit tests for LangGraph compilation, state transitions, and thread persistence (`app.graphs.test_chat_graph`).
"""

from langchain_core.messages import HumanMessage
from langgraph.checkpoint.memory import MemorySaver
import pytest

from app.core.config import Settings
from app.graphs.test_chat_graph import (
    build_test_chat_state_graph,
    compile_test_chat_graph,
)
from tests.conftest import DeterministicMockChatModel


def test_build_and_compile_test_chat_graph(
    test_settings: Settings, mock_llm: DeterministicMockChatModel
) -> None:
    """Verify StateGraph topology (`START -> llm_node -> END`) and compilation."""
    state_graph = build_test_chat_state_graph(llm=mock_llm, settings=test_settings)
    assert "llm_node" in state_graph.nodes

    compiled = compile_test_chat_graph(
        llm=mock_llm,
        checkpointer=MemorySaver(),
        settings=test_settings,
    )
    assert compiled is not None


def test_graph_sync_invoke_state_transition(
    test_settings: Settings, mock_llm: DeterministicMockChatModel
) -> None:
    """Verify synchronous `.invoke()` transitions state from HumanMessage to AIMessage."""
    compiled = compile_test_chat_graph(
        llm=mock_llm,
        checkpointer=MemorySaver(),
        settings=test_settings,
    )
    result = compiled.invoke(
        {
            "messages": [HumanMessage(content="Testing sync LangGraph invocation")],
            "thread_id": "sync-thread-1",
        },
        config={"configurable": {"thread_id": "sync-thread-1"}},
    )

    assert result["reply"] == "[MockGemini turn=1] Echo: Testing sync LangGraph invocation"
    assert result["model_name"] == "gemini-3.8-flash"
    assert len(result["messages"]) == 2
    assert result["messages"][0].type == "human"
    assert result["messages"][1].type == "ai"


@pytest.mark.asyncio
async def test_graph_multi_turn_thread_state_persistence(
    test_settings: Settings, mock_llm: DeterministicMockChatModel
) -> None:
    """
    Verify multi-turn conversation state persistence across invocations sharing the same `thread_id`
    and isolation across different `thread_id` values.
    """
    checkpointer = MemorySaver()
    compiled = compile_test_chat_graph(
        llm=mock_llm,
        checkpointer=checkpointer,
        settings=test_settings,
    )

    config_thread_a = {"configurable": {"thread_id": "thread-alpha"}}
    config_thread_b = {"configurable": {"thread_id": "thread-beta"}}

    # Turn 1 on thread-alpha
    state_a1 = await compiled.ainvoke(
        {"messages": [HumanMessage(content="First message on alpha")]},
        config=config_thread_a,
    )
    assert state_a1["reply"] == "[MockGemini turn=1] Echo: First message on alpha"
    assert len(state_a1["messages"]) == 2

    # Turn 2 on thread-alpha (should accumulate 4 total messages: 2 human + 2 AI)
    state_a2 = await compiled.ainvoke(
        {"messages": [HumanMessage(content="Second message on alpha")]},
        config=config_thread_a,
    )
    assert state_a2["reply"] == "[MockGemini turn=2] Echo: Second message on alpha"
    assert len(state_a2["messages"]) == 4

    # Turn 1 on thread-beta (isolated state — only 2 messages)
    state_b1 = await compiled.ainvoke(
        {"messages": [HumanMessage(content="First message on beta")]},
        config=config_thread_b,
    )
    assert state_b1["reply"] == "[MockGemini turn=1] Echo: First message on beta"
    assert len(state_b1["messages"]) == 2
