"""
Graph Execution Service (`TestChatService`).
Separates runtime LangGraph invocation (`invoke` / `ainvoke`) and thread state
management from the static graph topology definition (`app.graphs.test_chat_graph`).
"""

import logging
import time
import uuid
from typing import Optional

from langchain_core.messages import AnyMessage, HumanMessage, SystemMessage
from langchain_core.runnables import RunnableConfig
from langgraph.graph.state import CompiledStateGraph

from app.agents.registry import GraphRegistry, get_graph_registry
from app.core.config import Settings, get_settings
from app.core.logging import get_request_id
from app.schemas.test_chat import TestChatRequest, TestChatResponse

logger = logging.getLogger("remarket.ai.services.graph_runner")


class TestChatService:
    """
    Executes the compiled `test_chat` LangGraph workflow for incoming requests
    while maintaining conversation state per `thread_id`.
    """

    __test__ = False

    def __init__(
        self,
        *,
        compiled_graph: Optional[CompiledStateGraph] = None,
        registry: Optional[GraphRegistry] = None,
        settings: Optional[Settings] = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._registry = registry or get_graph_registry(self._settings)
        self._compiled_graph = compiled_graph

    @property
    def graph(self) -> CompiledStateGraph:
        """Lazily resolve the compiled `test_chat` graph."""
        if self._compiled_graph is None:
            self._compiled_graph = self._registry.get_test_chat_graph()
        return self._compiled_graph

    async def execute_chat(self, payload: TestChatRequest) -> TestChatResponse:
        """
        Invoke the compiled `START -> llm_node -> END` graph asynchronously
        with LangGraph thread checkpointing.
        """
        resolved_thread_id = (payload.thread_id or "").strip() or f"thread-{uuid.uuid4().hex[:16]}"
        config: RunnableConfig = {"configurable": {"thread_id": resolved_thread_id}}

        input_messages: list[AnyMessage] = []
        if payload.system_prompt and payload.system_prompt.strip():
            # Only prepend SystemMessage if this thread does not already have prior messages
            existing_state = await self._get_existing_messages(config)
            if not existing_state:
                input_messages.append(SystemMessage(content=payload.system_prompt.strip()))

        input_messages.append(HumanMessage(content=payload.message))

        start_perf = time.perf_counter()
        logger.info(
            "Executing test_chat graph thread_id=%s input_messages=%d",
            resolved_thread_id,
            len(input_messages),
        )

        result_state = await self.graph.ainvoke(
            {
                "messages": input_messages,
                "thread_id": resolved_thread_id,
            },
            config=config,
        )
        latency_ms = round((time.perf_counter() - start_perf) * 1000.0, 2)

        all_messages = result_state.get("messages", [])
        reply_text = str(result_state.get("reply", ""))
        model_used = str(result_state.get("model_name") or self._settings.GEMINI_MODEL)

        logger.info(
            "Completed test_chat graph thread_id=%s message_count=%d latency_ms=%.2f",
            resolved_thread_id,
            len(all_messages),
            latency_ms,
        )

        return TestChatResponse(
            reply=reply_text,
            thread_id=resolved_thread_id,
            model=model_used,
            message_count=len(all_messages),
            latency_ms=latency_ms,
            request_id=get_request_id(),
        )

    async def _get_existing_messages(self, config: RunnableConfig) -> list[AnyMessage]:
        """Inspect current checkpoint state for `thread_id` if available."""
        try:
            snapshot = await self.graph.aget_state(config)
            if snapshot and snapshot.values:
                return list(snapshot.values.get("messages", []))
        except Exception:
            # If checkpointer has no state yet, return empty list
            pass
        return []
