"""
TypedDict State Definitions for ReMarket's 4 Specialized LangGraph Workflows
and the Supervisor Graph (`app.states.agent_states`).
"""

from typing import Annotated, Any, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages


class ListingGraphState(TypedDict, total=False):
    """State for Agent 1 (`listing_graph`)."""

    request_data: dict[str, Any]
    product_name: str
    brand: str
    category: str
    condition: str
    defects: str
    original_price: float | None
    selling_price: float | None
    images: list[str]
    image_base64: str | None
    image_mime_type: str
    product_analysis: dict[str, Any]
    image_analysis: dict[str, Any]
    needs_more_info: bool
    clarification_questions: list[str]
    rag_context: str
    raw_output: dict[str, Any]
    validated_output: dict[str, Any]
    token_usage: dict[str, int]
    model_name: str


class PricingGraphState(TypedDict, total=False):
    """State for Agent 2 (`pricing_graph`)."""

    request_data: dict[str, Any]
    product_name: str
    brand: str
    category: str
    condition: str
    defects: str
    original_price: float | None
    comparable_products: list[dict[str, Any]]
    comparable_stats: dict[str, Any]
    condition_analysis: dict[str, Any]
    rag_context: str
    estimated_prices: dict[str, Any]
    explanation: dict[str, Any]
    validated_output: dict[str, Any]
    token_usage: dict[str, int]
    model_name: str


class InspectionGraphState(TypedDict, total=False):
    """State for Agent 3 (`inspection_graph`)."""

    request_data: dict[str, Any]
    product_id: str | None
    product_detail: dict[str, Any]
    product_analysis: dict[str, Any]
    rag_context: str
    rag_safety_tips: list[str]
    inspection_points: list[dict[str, Any]]
    suggested_questions: list[str]
    validated_output: dict[str, Any]
    token_usage: dict[str, int]
    model_name: str


class ShoppingAssistantGraphState(TypedDict, total=False):
    """State for Agent 4 (`shopping_assistant_graph`)."""

    messages: Annotated[list[AnyMessage], add_messages]
    thread_id: str
    user_id: str | None
    user_message: str
    request_data: dict[str, Any]
    preferences: dict[str, Any]
    intent: str
    candidate_products: list[dict[str, Any]]
    last_matched_products: list[dict[str, Any]]
    ranked_products: list[dict[str, Any]]
    comparison_summary: dict[str, Any]
    rag_context: str
    rag_sources: list[dict[str, Any]]
    reply_message: str
    suggested_questions: list[str]
    validated_output: dict[str, Any]
    token_usage: dict[str, int]
    model_name: str


class SupervisorGraphState(TypedDict, total=False):
    """State for the top-level Supervisor Graph (`supervisor_graph`)."""

    message: str
    explicit_intent: str | None
    payload: dict[str, Any]
    thread_id: str | None
    classified_intent: str
    target_graph: str
    fallback_used: bool
    result: dict[str, Any]
