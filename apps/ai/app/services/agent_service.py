"""
AI Application Layer Service (`app.services.agent_service`).

Orchestrates execution of ReMarket's 4 Specialized LangGraph Workflows,
the Supervisor Graph, and Conversation Memory CRUD endpoints.
Enforces rate limiting, latency measurement, token usage reporting,
and strict per-user authentication isolation.
"""

import logging
import time
from typing import Optional

from app.agents.registry import GraphRegistry, get_graph_registry
from app.core.auth_context import get_auth_context
from app.core.config import Settings, get_settings
from app.core.logging import get_request_id
from app.core.observability import InMemoryRateLimiter, TokenUsageMetrics
from app.graphs.inspection_graph import compile_inspection_graph
from app.graphs.listing_graph import compile_listing_graph
from app.graphs.pricing_graph import compile_pricing_graph
from app.graphs.shopping_assistant_graph import compile_shopping_assistant_graph
from app.graphs.supervisor_graph import compile_supervisor_graph
from app.memory.checkpointer import CheckpointerManager, get_checkpointer_manager
from app.rag.pipelines import RAGPipeline
from app.schemas.agents import (
    BuyerChecklistRequest,
    BuyerChecklistResponse,
    ConversationHistoryResponse,
    DeleteConversationResponse,
    EstimatePriceRequest,
    EstimatePriceResponse,
    GenerateListingRequest,
    GenerateListingResponse,
    ListingDescriptionSections,
    ShoppingChatRequest,
    ShoppingChatResponse,
    SupervisorExecuteRequest,
    SupervisorExecuteResponse,
)
from app.services.backend_client import BackendClient, get_backend_client

logger = logging.getLogger("remarket.ai.services.agent")

_shared_rate_limiter: Optional[InMemoryRateLimiter] = None


def get_shared_rate_limiter(settings: Optional[Settings] = None) -> InMemoryRateLimiter:
    """Return the shared sliding-window rate limiter."""
    global _shared_rate_limiter
    cfg = settings or get_settings()
    if _shared_rate_limiter is None:
        _shared_rate_limiter = InMemoryRateLimiter(
            max_requests=cfg.AI_RATE_LIMIT_REQUESTS,
            window_seconds=float(cfg.AI_RATE_LIMIT_WINDOW_SECONDS),
        )
    return _shared_rate_limiter


def reset_shared_rate_limiter() -> None:
    """Reset the shared rate limiter (used in tests)."""
    global _shared_rate_limiter
    if _shared_rate_limiter is not None:
        _shared_rate_limiter.clear()
    _shared_rate_limiter = None


class AgentApplicationService:
    """
    Application service bridging FastAPI routes with the LangGraph Supervisor
    and the 4 specialized Agent subgraphs.
    """

    def __init__(
        self,
        *,
        settings: Optional[Settings] = None,
        registry: Optional[GraphRegistry] = None,
        backend_client: Optional[BackendClient] = None,
        rag_pipeline: Optional[RAGPipeline] = None,
        checkpointer_manager: Optional[CheckpointerManager] = None,
        rate_limiter: Optional[InMemoryRateLimiter] = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._registry = registry or get_graph_registry(self._settings)
        self._backend_client = backend_client or get_backend_client(self._settings)
        self._rag_pipeline = rag_pipeline or RAGPipeline(settings=self._settings)
        self._checkpointer = checkpointer_manager or get_checkpointer_manager(self._settings)
        self._rate_limiter = rate_limiter or get_shared_rate_limiter(self._settings)

    def _check_rate_limit(self) -> str:
        """Check per-user rate limit and return the verified user_id (or 'anonymous')."""
        auth_ctx = get_auth_context()
        user_id = (
            auth_ctx.user_id
            if (auth_ctx and auth_ctx.is_authenticated and auth_ctx.user_id)
            else "anonymous"
        )
        self._rate_limiter.check_rate_limit(user_id)
        return user_id

    async def generate_listing(
        self, request: GenerateListingRequest
    ) -> GenerateListingResponse:
        """Execute Agent 1 (`listing_graph`) for `POST /ai/generate-listing`."""
        self._check_rate_limit()
        start = time.perf_counter()

        graph = compile_listing_graph(
            rag_pipeline=self._rag_pipeline,
            settings=self._settings,
        )
        state_out = await graph.ainvoke({"request_data": request.model_dump()})
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        validated_dict = state_out.get("validated_output") or {}
        desc_obj = ListingDescriptionSections.model_validate(
            validated_dict.get("suggestedDescription")
            or {
                "overview": request.resolved_name,
                "condition": request.condition,
                "defects": request.resolved_defects or "Chưa ghi nhận khuyết điểm.",
            }
        )
        flattened_text = (
            f"Tổng quan: {desc_obj.overview}\n"
            f"Tình trạng: {desc_obj.condition}\n"
            f"Khuyết điểm khai báo: {desc_obj.defects}"
        )
        token_usage = TokenUsageMetrics.model_validate(
            state_out.get("token_usage") or {}
        )

        return GenerateListingResponse(
            suggestedTitle=validated_dict.get("suggestedTitle", request.resolved_name),
            suggestedDescription=desc_obj,
            suggestedDescriptionText=flattened_text,
            suggestedCategory=validated_dict.get("suggestedCategory", "Phụ kiện & Khác"),
            suggestedTags=list(validated_dict.get("suggestedTags") or []),
            transparencyNote=validated_dict.get("transparencyNote", ""),
            transparencyScore=int(validated_dict.get("transparencyScore", 90)),
            needsMoreInfo=bool(validated_dict.get("needsMoreInfo", False)),
            clarificationQuestions=list(
                validated_dict.get("clarificationQuestions") or []
            ),
            requiresSellerApproval=True,
            aiProvider=str(state_out.get("model_name") or self._settings.GEMINI_MODEL),
            latencyMs=elapsed_ms,
            tokenUsage=token_usage,
            requestId=get_request_id(),
        )

    async def estimate_price(
        self, request: EstimatePriceRequest
    ) -> EstimatePriceResponse:
        """Execute Agent 2 (`pricing_graph`) for `POST /ai/estimate-price`."""
        self._check_rate_limit()
        start = time.perf_counter()

        graph = compile_pricing_graph(
            backend_client=self._backend_client,
            rag_pipeline=self._rag_pipeline,
            settings=self._settings,
        )
        state_out = await graph.ainvoke({"request_data": request.model_dump()})
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        validated_dict = dict(state_out.get("validated_output") or {})
        validated_dict["latencyMs"] = elapsed_ms
        validated_dict["tokenUsage"] = TokenUsageMetrics.model_validate(
            state_out.get("token_usage") or {}
        ).model_dump()
        validated_dict["requestId"] = get_request_id()

        return EstimatePriceResponse.model_validate(validated_dict)

    async def buyer_checklist(
        self, request: BuyerChecklistRequest
    ) -> BuyerChecklistResponse:
        """Execute Agent 3 (`inspection_graph`) for `POST /ai/buyer-checklist`."""
        self._check_rate_limit()
        start = time.perf_counter()

        graph = compile_inspection_graph(
            rag_pipeline=self._rag_pipeline,
            backend_client=self._backend_client,
            settings=self._settings,
        )
        state_out = await graph.ainvoke({"request_data": request.model_dump()})
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        validated_dict = dict(state_out.get("validated_output") or {})
        validated_dict["latencyMs"] = elapsed_ms
        validated_dict["requestId"] = get_request_id()

        return BuyerChecklistResponse.model_validate(validated_dict)

    async def shopping_chat(
        self, request: ShoppingChatRequest
    ) -> ShoppingChatResponse:
        """Execute Agent 4 (`shopping_assistant_graph`) for `POST /ai/chat`."""
        user_id = self._check_rate_limit()
        start = time.perf_counter()

        graph = compile_shopping_assistant_graph(
            rag_pipeline=self._rag_pipeline,
            backend_client=self._backend_client,
            checkpointer_manager=self._checkpointer,
            settings=self._settings,
        )
        state_out = await graph.ainvoke(
            {
                "request_data": request.model_dump(),
                "thread_id": request.resolved_thread_id,
                "user_id": user_id,
            }
        )
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        validated_dict = dict(state_out.get("validated_output") or {})
        validated_dict["latencyMs"] = elapsed_ms
        validated_dict["requestId"] = get_request_id()

        return ShoppingChatResponse.model_validate(validated_dict)

    async def execute_supervisor(
        self, request: SupervisorExecuteRequest
    ) -> SupervisorExecuteResponse:
        """Execute the top-level `supervisor_graph` for `POST /ai/agent/execute`."""
        self._check_rate_limit()
        start = time.perf_counter()

        graph = compile_supervisor_graph(
            rag_pipeline=self._rag_pipeline,
            backend_client=self._backend_client,
            checkpointer_manager=self._checkpointer,
            settings=self._settings,
        )
        state_out = await graph.ainvoke(
            {
                "message": request.message or "",
                "explicit_intent": request.intent.value if request.intent else None,
                "payload": request.payload,
                "thread_id": request.thread_id,
            }
        )
        elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

        result_dict = dict(state_out.get("result") or {})
        result_dict["latencyMs"] = elapsed_ms
        result_dict["requestId"] = get_request_id()

        return SupervisorExecuteResponse.model_validate(result_dict)

    async def get_conversation_history(
        self, conversation_id: str
    ) -> ConversationHistoryResponse:
        """Retrieve conversation history for `GET /ai/conversations/{conversation_id}` with ownership verification."""
        user_id = self._check_rate_limit()
        record = self._checkpointer.get_session(
            conversation_id=conversation_id,
            user_id=user_id,
        )
        return ConversationHistoryResponse(
            conversation_id=record.conversation_id,
            owner_user_id=record.owner_user_id,
            turns=[t.model_dump() for t in record.turns],
            last_matched_products=list(record.last_matched_products),
            preferences=dict(record.preferences),
            last_intent=record.last_intent,
            created_at=record.created_at,
            updated_at=record.updated_at,
            requestId=get_request_id(),
        )

    async def delete_conversation(
        self, conversation_id: str
    ) -> DeleteConversationResponse:
        """Delete a conversation for `DELETE /ai/conversations/{conversation_id}` with ownership verification."""
        user_id = self._check_rate_limit()
        deleted = self._checkpointer.delete_session(
            conversation_id=conversation_id,
            user_id=user_id,
        )
        return DeleteConversationResponse(
            conversation_id=conversation_id.strip(),
            deleted=deleted,
            requestId=get_request_id(),
        )
