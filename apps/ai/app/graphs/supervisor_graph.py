"""
Supervisor Graph (`app.graphs.supervisor_graph`).

Classifies incoming user requests into one of 5 top-level intents:
- `GENERATE_LISTING` -> routes to `listing_graph`
- `ESTIMATE_PRICE` -> routes to `pricing_graph`
- `BUYER_INSPECTION` -> routes to `inspection_graph`
- `SHOPPING_ASSISTANT` -> routes to `shopping_assistant_graph`
- `GENERAL` -> routes to `shopping_assistant_graph` (with safe fallback handling)
"""

import logging
from typing import Any, Optional

from langchain_core.language_models.chat_models import BaseChatModel
from langgraph.graph import END, START, StateGraph
from langgraph.graph.state import CompiledStateGraph

from app.core.config import Settings, get_settings
from app.core.logging import get_request_id
from app.core.observability import trace_graph_node
from app.graphs.inspection_graph import compile_inspection_graph
from app.graphs.listing_graph import compile_listing_graph
from app.graphs.pricing_graph import compile_pricing_graph
from app.graphs.shopping_assistant_graph import compile_shopping_assistant_graph
from app.llm.gemini import GeminiModelFactory, get_gemini_factory
from app.memory.checkpointer import CheckpointerManager, get_checkpointer_manager
from app.rag.pipelines import RAGPipeline
from app.schemas.agents import SupervisorExecuteResponse, SupervisorIntentEnum
from app.services.backend_client import BackendClient, get_backend_client
from app.states.agent_states import SupervisorGraphState

logger = logging.getLogger("remarket.ai.graphs.supervisor")


def classify_supervisor_intent(
    message: str | None,
    explicit_intent: str | None,
    payload: dict[str, Any] | None,
) -> tuple[str, bool]:
    """
    Determine `(classified_intent, fallback_used)` from explicit intent, message, and payload.
    """
    if explicit_intent:
        upper = explicit_intent.strip().upper()
        for member in SupervisorIntentEnum:
            if member.value == upper:
                return member.value, False

    text = (message or "").lower().strip()
    data = payload or {}

    # 1. Check Listing Generator cues
    if any(
        kw in text
        for kw in (
            "tạo tin đăng",
            "viết tin đăng",
            "đăng bán",
            "viết bài đăng",
            "generate listing",
            "tạo bài đăng",
        )
    ):
        return SupervisorIntentEnum.GENERATE_LISTING.value, False

    # 2. Check Smart Price Estimator cues
    if any(
        kw in text
        for kw in (
            "định giá",
            "ước tính giá",
            "bán giá bao nhiêu",
            "giá bán hợp lý",
            "estimate price",
            "gợi ý giá bán",
        )
    ):
        return SupervisorIntentEnum.ESTIMATE_PRICE.value, False

    # 3. Check Buyer Inspection Checklist cues
    if any(
        kw in text
        for kw in (
            "checklist kiểm tra",
            "danh sách kiểm tra",
            "kiểm tra trước khi mua",
            "đi xem hàng",
            "buyer checklist",
            "điểm kiểm tra",
        )
    ) or ("productId" in data and "productName" not in data and not text):
        return SupervisorIntentEnum.BUYER_INSPECTION.value, False

    # 4. Check Shopping Assistant cues
    if any(
        kw in text
        for kw in (
            "mua",
            "tìm",
            "so sánh",
            "trong số đó",
            "con nào",
            "ngân sách",
            "triệu",
            "laptop",
            "điện thoại",
            "iphone",
            "macbook",
            "tư vấn",
            "chính sách",
            "an toàn",
        )
    ):
        return SupervisorIntentEnum.SHOPPING_ASSISTANT.value, False

    # 5. Uncertain / General fallback
    return SupervisorIntentEnum.GENERAL.value, True


def build_supervisor_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    checkpointer_manager: Optional[CheckpointerManager] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """Construct the top-level LangGraph Supervisor."""
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)
    client = backend_client or get_backend_client(resolved_settings)
    memory_mgr = checkpointer_manager or get_checkpointer_manager(resolved_settings)

    listing_subgraph = compile_listing_graph(
        llm=llm,
        factory=resolved_factory,
        rag_pipeline=rag_pipeline,
        settings=resolved_settings,
    )
    pricing_subgraph = compile_pricing_graph(
        llm=llm,
        factory=resolved_factory,
        backend_client=client,
        rag_pipeline=rag_pipeline,
        settings=resolved_settings,
    )
    inspection_subgraph = compile_inspection_graph(
        llm=llm,
        factory=resolved_factory,
        rag_pipeline=rag_pipeline,
        backend_client=client,
        settings=resolved_settings,
    )
    shopping_subgraph = compile_shopping_assistant_graph(
        llm=llm,
        factory=resolved_factory,
        rag_pipeline=rag_pipeline,
        backend_client=client,
        checkpointer_manager=memory_mgr,
        settings=resolved_settings,
    )

    @trace_graph_node("supervisor_graph", "classify_intent")
    async def classify_intent_node(state: SupervisorGraphState) -> dict[str, Any]:
        intent, fallback_used = classify_supervisor_intent(
            message=state.get("message"),
            explicit_intent=state.get("explicit_intent"),
            payload=state.get("payload"),
        )
        target_map = {
            SupervisorIntentEnum.GENERATE_LISTING.value: "listing_graph",
            SupervisorIntentEnum.ESTIMATE_PRICE.value: "pricing_graph",
            SupervisorIntentEnum.BUYER_INSPECTION.value: "inspection_graph",
            SupervisorIntentEnum.SHOPPING_ASSISTANT.value: "shopping_assistant_graph",
            SupervisorIntentEnum.GENERAL.value: "shopping_assistant_graph",
        }
        return {
            "classified_intent": intent,
            "target_graph": target_map.get(intent, "shopping_assistant_graph"),
            "fallback_used": fallback_used,
        }

    def route_to_subgraph(state: SupervisorGraphState) -> str:
        intent = state.get("classified_intent") or SupervisorIntentEnum.GENERAL.value
        if intent == SupervisorIntentEnum.GENERATE_LISTING.value:
            return "execute_listing_subgraph"
        if intent == SupervisorIntentEnum.ESTIMATE_PRICE.value:
            return "execute_pricing_subgraph"
        if intent == SupervisorIntentEnum.BUYER_INSPECTION.value:
            return "execute_inspection_subgraph"
        if intent == SupervisorIntentEnum.SHOPPING_ASSISTANT.value:
            return "execute_shopping_subgraph"
        return "execute_general_fallback"

    @trace_graph_node("supervisor_graph", "execute_listing_subgraph")
    async def execute_listing_node(state: SupervisorGraphState) -> dict[str, Any]:
        payload = dict(state.get("payload") or {})
        if not payload.get("productName") and not payload.get("title"):
            payload["productName"] = state.get("message") or "Sản phẩm đồ cũ ReMarket"
        sub_res = await listing_subgraph.ainvoke({"request_data": payload})
        return {"result": sub_res.get("validated_output") or {}}

    @trace_graph_node("supervisor_graph", "execute_pricing_subgraph")
    async def execute_pricing_node(state: SupervisorGraphState) -> dict[str, Any]:
        payload = dict(state.get("payload") or {})
        if not payload.get("productName") and not payload.get("title"):
            payload["productName"] = state.get("message") or "Sản phẩm đồ cũ ReMarket"
        sub_res = await pricing_subgraph.ainvoke({"request_data": payload})
        return {"result": sub_res.get("validated_output") or {}}

    @trace_graph_node("supervisor_graph", "execute_inspection_subgraph")
    async def execute_inspection_node(state: SupervisorGraphState) -> dict[str, Any]:
        payload = dict(state.get("payload") or {})
        if (
            not payload.get("productId")
            and not payload.get("product_id")
            and not payload.get("title")
            and not payload.get("productName")
        ):
            payload["title"] = state.get("message") or "Sản phẩm đồ cũ ReMarket"
        sub_res = await inspection_subgraph.ainvoke({"request_data": payload})
        return {"result": sub_res.get("validated_output") or {}}

    @trace_graph_node("supervisor_graph", "execute_shopping_subgraph")
    async def execute_shopping_node(state: SupervisorGraphState) -> dict[str, Any]:
        payload = dict(state.get("payload") or {})
        if not payload.get("message"):
            payload["message"] = state.get("message") or "Xin chào ReMarket AI"
        if state.get("thread_id") and not payload.get("thread_id"):
            payload["thread_id"] = state["thread_id"]
        sub_res = await shopping_subgraph.ainvoke(
            {"request_data": payload, "thread_id": state.get("thread_id")}
        )
        return {"result": sub_res.get("validated_output") or {}}

    @trace_graph_node("supervisor_graph", "execute_general_fallback")
    async def execute_general_fallback_node(
        state: SupervisorGraphState,
    ) -> dict[str, Any]:
        payload = dict(state.get("payload") or {})
        msg = state.get("message") or payload.get("message") or "Xin chào ReMarket AI"
        payload["message"] = msg
        if state.get("thread_id") and not payload.get("thread_id"):
            payload["thread_id"] = state["thread_id"]
        sub_res = await shopping_subgraph.ainvoke(
            {"request_data": payload, "thread_id": state.get("thread_id")}
        )
        return {"result": sub_res.get("validated_output") or {}}

    @trace_graph_node("supervisor_graph", "finalize_supervisor_output")
    async def finalize_supervisor_output_node(
        state: SupervisorGraphState,
    ) -> dict[str, Any]:
        resp = SupervisorExecuteResponse(
            intent=SupervisorIntentEnum(
                state.get("classified_intent") or SupervisorIntentEnum.GENERAL.value
            ),
            targetGraph=state.get("target_graph") or "shopping_assistant_graph",
            fallbackUsed=bool(state.get("fallback_used", False)),
            data=state.get("result") or {},
            requestId=get_request_id(),
        )
        return {"result": resp.model_dump()}

    graph = StateGraph(SupervisorGraphState)
    graph.add_node("classify_intent", classify_intent_node)
    graph.add_node("execute_listing_subgraph", execute_listing_node)
    graph.add_node("execute_pricing_subgraph", execute_pricing_node)
    graph.add_node("execute_inspection_subgraph", execute_inspection_node)
    graph.add_node("execute_shopping_subgraph", execute_shopping_node)
    graph.add_node("execute_general_fallback", execute_general_fallback_node)
    graph.add_node("finalize_supervisor_output", finalize_supervisor_output_node)

    graph.add_edge(START, "classify_intent")
    graph.add_conditional_edges(
        "classify_intent",
        route_to_subgraph,
        {
            "execute_listing_subgraph": "execute_listing_subgraph",
            "execute_pricing_subgraph": "execute_pricing_subgraph",
            "execute_inspection_subgraph": "execute_inspection_subgraph",
            "execute_shopping_subgraph": "execute_shopping_subgraph",
            "execute_general_fallback": "execute_general_fallback",
        },
    )
    graph.add_edge("execute_listing_subgraph", "finalize_supervisor_output")
    graph.add_edge("execute_pricing_subgraph", "finalize_supervisor_output")
    graph.add_edge("execute_inspection_subgraph", "finalize_supervisor_output")
    graph.add_edge("execute_shopping_subgraph", "finalize_supervisor_output")
    graph.add_edge("execute_general_fallback", "finalize_supervisor_output")
    graph.add_edge("finalize_supervisor_output", END)

    return graph


def compile_supervisor_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    checkpointer_manager: Optional[CheckpointerManager] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the top-level ReMarket Supervisor Graph."""
    builder = build_supervisor_state_graph(
        llm=llm,
        factory=factory,
        rag_pipeline=rag_pipeline,
        backend_client=backend_client,
        checkpointer_manager=checkpointer_manager,
        settings=settings,
    )
    return builder.compile()
