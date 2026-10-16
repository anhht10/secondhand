"""
TypedDict and Pydantic State definitions for ReMarket LangGraph workflows.
"""

from typing import Annotated, Any, TypedDict
from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages


class TestChatGraphState(TypedDict, total=False):
    """
    State schema for the foundational `START -> llm_node -> END` LangGraph workflow.
    Uses LangGraph's `add_messages` reducer to append conversation turns across checkpoints.
    """

    messages: Annotated[list[AnyMessage], add_messages]
    thread_id: str
    model_name: str
    reply: str
    metadata: dict[str, Any]
