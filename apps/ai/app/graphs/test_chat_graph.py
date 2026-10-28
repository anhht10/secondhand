"""
Foundational LangGraph Workflow: `START -> llm_node -> END`.
Strictly separates graph definition (`build_test_chat_state_graph`) and
compilation (`compile_test_chat_graph`) from runtime invocation.
"""

import logging
from typing import Any, Optional

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage, BaseMessage
from langchain_core.runnables import RunnableLambda
from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.graph import END, START, StateGraph
from langgraph.graph.state import CompiledStateGraph

from app.core.config import Settings, get_settings
from app.llm.gemini import (
    GeminiModelFactory,
    get_gemini_factory,
    invoke_llm_sync_with_resilience,
    invoke_llm_with_resilience,
)
from app.memory.checkpointer import get_checkpointer_manager
from app.states.chat_state import TestChatGraphState

logger = logging.getLogger("remarket.ai.graphs.test_chat")


def _extract_text_content(message: BaseMessage) -> str:
    """Normalize LangChain AIMessage content (str or list of content blocks) into a string."""
    content = message.content
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and "text" in item:
                parts.append(str(item["text"]))
        return "\n".join(parts).strip()
    return str(content)


def build_test_chat_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """
    Construct the uncompiled `StateGraph(TestChatGraphState)` with topology:
    `START -> llm_node -> END`.
    """
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)

    async def llm_node_async(state: TestChatGraphState) -> dict[str, Any]:
        messages = list(state.get("messages", []))
        active_llm = llm or resolved_factory.get_chat_model()
        model_name = getattr(active_llm, "model", resolved_settings.GEMINI_MODEL)

        response_msg = await invoke_llm_with_resilience(
            active_llm,
            messages,
            timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
            max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
        )
        reply_text = _extract_text_content(response_msg)
        ai_message = (
            response_msg
            if isinstance(response_msg, AIMessage)
            else AIMessage(content=reply_text)
        )

        return {
            "messages": [ai_message],
            "reply": reply_text,
            "model_name": str(model_name),
        }

    def llm_node_sync(state: TestChatGraphState) -> dict[str, Any]:
        messages = list(state.get("messages", []))
        active_llm = llm or resolved_factory.get_chat_model()
        model_name = getattr(active_llm, "model", resolved_settings.GEMINI_MODEL)

        response_msg = invoke_llm_sync_with_resilience(
            active_llm,
            messages,
            timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
            max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
        )
        reply_text = _extract_text_content(response_msg)
        ai_message = (
            response_msg
            if isinstance(response_msg, AIMessage)
            else AIMessage(content=reply_text)
        )

        return {
            "messages": [ai_message],
            "reply": reply_text,
            "model_name": str(model_name),
        }

    # Support both synchronous .invoke() and asynchronous .ainvoke() seamlessly
    workflow = StateGraph(TestChatGraphState)
    workflow.add_node(
        "llm_node",
        RunnableLambda(func=llm_node_sync, afunc=llm_node_async),
    )
    workflow.add_edge(START, "llm_node")
    workflow.add_edge("llm_node", END)
    return workflow


def compile_test_chat_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    checkpointer: Optional[BaseCheckpointSaver] = None,
    factory: Optional[GeminiModelFactory] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the `START -> llm_node -> END` StateGraph with a checkpointer."""
    resolved_settings = settings or get_settings()
    resolved_checkpointer = (
        checkpointer
        if checkpointer is not None
        else get_checkpointer_manager(resolved_settings).get_checkpointer()
    )
    state_graph = build_test_chat_state_graph(
        llm=llm,
        factory=factory,
        settings=resolved_settings,
    )
    return state_graph.compile(checkpointer=resolved_checkpointer)
