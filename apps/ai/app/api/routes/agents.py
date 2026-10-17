"""
FastAPI Routes for ReMarket's 4 Specialized Agents, Supervisor Graph,
and Conversation State Management (`app.api.routes.agents`).

Endpoints:
1. `POST /ai/generate-listing`                 -> Agent 1 (Listing Generator)
2. `POST /ai/estimate-price`                   -> Agent 2 (Smart Price Estimator)
3. `POST /ai/buyer-checklist`                  -> Agent 3 (Buyer Inspection Checklist)
4. `POST /ai/chat`                             -> Agent 4 (Secondhand Shopping Assistant)
5. `POST /ai/agent/execute`                    -> Supervisor Graph Router
6. `GET /ai/conversations/{conversation_id}`   -> Inspect conversation history
7. `DELETE /ai/conversations/{conversation_id}`-> Delete conversation memory
"""

from fastapi import APIRouter, Depends, Path

from app.api.dependencies import get_agent_application_service
from app.schemas.agents import (
    BuyerChecklistRequest,
    BuyerChecklistResponse,
    ConversationHistoryResponse,
    DeleteConversationResponse,
    EstimatePriceRequest,
    EstimatePriceResponse,
    GenerateListingRequest,
    GenerateListingResponse,
    ShoppingChatRequest,
    ShoppingChatResponse,
    SupervisorExecuteRequest,
    SupervisorExecuteResponse,
)
from app.services.agent_service import AgentApplicationService

router = APIRouter(prefix="/ai", tags=["Multi-Agent AI"])


@router.post(
    "/generate-listing",
    response_model=GenerateListingResponse,
    summary="Agent 1 — Generate transparent secondhand product listing",
)
async def generate_listing_endpoint(
    payload: GenerateListingRequest,
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> GenerateListingResponse:
    """
    Execute the Listing Generator LangGraph (`listing_graph`).
    Preserves seller-disclosed defects, never fabricates brand/hardware specs,
    and requires seller approval before publishing.
    """
    return await service.generate_listing(payload)


@router.post(
    "/estimate-price",
    response_model=EstimatePriceResponse,
    summary="Agent 2 — Estimate 3 fair secondhand price tiers (Quick Sell, Recommended, Max Fair)",
)
async def estimate_price_endpoint(
    payload: EstimatePriceRequest,
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> EstimatePriceResponse:
    """
    Execute the Smart Price Estimator LangGraph (`pricing_graph`).
    Combines real comparable listings from NestJS Backend (when available) with
    condition and defect depreciation analysis.
    """
    return await service.estimate_price(payload)


@router.post(
    "/buyer-checklist",
    response_model=BuyerChecklistResponse,
    summary="Agent 3 — Generate 3-4 tailored buyer inspection points and 3 seller questions",
)
async def buyer_checklist_endpoint(
    payload: BuyerChecklistRequest,
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> BuyerChecklistResponse:
    """
    Execute the Buyer Inspection Checklist LangGraph (`inspection_graph`).
    Combines real product details via `get_product_detail` tool with ReMarket RAG
    inspection and safety guides.
    """
    return await service.buyer_checklist(payload)


@router.post(
    "/chat",
    response_model=ShoppingChatResponse,
    summary="Agent 4 — Multi-turn Secondhand Shopping Assistant",
)
async def shopping_chat_endpoint(
    payload: ShoppingChatRequest,
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> ShoppingChatResponse:
    """
    Execute the multi-branch Secondhand Shopping Assistant LangGraph (`shopping_assistant_graph`)
    with persistent `thread_id` memory and per-user authentication isolation.
    """
    return await service.shopping_chat(payload)


@router.post(
    "/agent/execute",
    response_model=SupervisorExecuteResponse,
    summary="Supervisor Graph — Classify intent and route to the specialized agent subgraph",
)
async def supervisor_execute_endpoint(
    payload: SupervisorExecuteRequest,
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> SupervisorExecuteResponse:
    """
    Execute the top-level LangGraph Supervisor (`supervisor_graph`), classifying intent into
    `GENERATE_LISTING`, `ESTIMATE_PRICE`, `BUYER_INSPECTION`, `SHOPPING_ASSISTANT`, or `GENERAL`.
    """
    return await service.execute_supervisor(payload)


@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationHistoryResponse,
    summary="Inspect multi-turn conversation history and session state",
)
async def get_conversation_endpoint(
    conversation_id: str = Path(..., min_length=1, max_length=128),
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> ConversationHistoryResponse:
    """
    Retrieve short-term conversation turns, matched products, and preferences
    for `conversation_id`. Enforces strict ownership isolation (HTTP 403 if owned by another user).
    """
    return await service.get_conversation_history(conversation_id)


@router.delete(
    "/conversations/{conversation_id}",
    response_model=DeleteConversationResponse,
    summary="Delete a conversation thread and purge its checkpointer state",
)
async def delete_conversation_endpoint(
    conversation_id: str = Path(..., min_length=1, max_length=128),
    service: AgentApplicationService = Depends(get_agent_application_service),
) -> DeleteConversationResponse:
    """
    Delete conversation session state and checkpointer history for `conversation_id`.
    Enforces strict ownership isolation (HTTP 403 if owned by another user).
    """
    return await service.delete_conversation(conversation_id)
