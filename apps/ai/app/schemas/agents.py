"""
Pydantic Request and Response Schemas for ReMarket's 4 Specialized Agents,
Supervisor Router, and Conversation Management Endpoints (`app.schemas.agents`).
Enforces strict input validation, blocks client-supplied `user_id` spoofing,
and validates structured outputs.
"""

from enum import Enum
from typing import Any, Literal, Mapping, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.auth_context import assert_no_spoofed_auth_override
from app.core.observability import TokenUsageMetrics
from app.rag.schemas import RAGSourceAttribution
from app.tools.base import validate_object_id


class _StrictAgentRequestModel(BaseModel):
    """Base request model that strips whitespace and rejects spoofed auth fields."""

    model_config = ConfigDict(extra="ignore", str_strip_whitespace=True)

    @model_validator(mode="before")
    @classmethod
    def check_no_spoofed_auth(cls, values: Any) -> Any:
        if isinstance(values, Mapping):
            # Explicitly reject client-supplied user_id or auth overrides in request body
            if "user_id" in values or "userId" in values:
                raise ValueError(
                    "Client request body must not specify 'user_id'/'userId'. "
                    "User identity must be authenticated and forwarded by NestJS headers."
                )
            assert_no_spoofed_auth_override(values)
        return values


# =====================================================================
# AGENT 1: LISTING GENERATOR SCHEMAS
# =====================================================================


class GenerateListingRequest(_StrictAgentRequestModel):
    """Input schema for `POST /ai/generate-listing`."""

    productName: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Product name (alias: `title`).",
    )
    title: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Product title (alias: `productName`).",
    )
    brand: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Brand or manufacturer name (only if known; never fabricated).",
    )
    category: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Category name or slug.",
    )
    condition: str = Field(
        default="LIKE_NEW",
        max_length=50,
        description="Product condition: NEW, LIKE_NEW, GOOD, or FAIR.",
    )
    defects: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Disclosed defects or wear-and-tear notes (alias: `defectDisclosure`).",
    )
    defectDisclosure: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Seller disclosure of any scratches or defects.",
    )
    originalPrice: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Original retail price in VND (optional).",
    )
    sellingPrice: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Expected selling price in VND (alias: `price`).",
    )
    price: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Expected selling price in VND.",
    )
    images: list[str] = Field(
        default_factory=list,
        max_length=10,
        description="List of product image URLs or data URIs (alias: `imageUrls`).",
    )
    imageUrls: list[str] = Field(
        default_factory=list,
        max_length=10,
        description="Optional list of uploaded image URLs.",
    )
    imageBase64: Optional[str] = Field(
        default=None,
        description="Optional base64-encoded image for multimodal analysis.",
    )
    imageMimeType: Optional[str] = Field(
        default="image/jpeg",
        description="MIME type for `imageBase64`.",
    )

    @property
    def resolved_name(self) -> str:
        return (self.productName or self.title or "").strip()

    @property
    def resolved_defects(self) -> str:
        return (self.defects or self.defectDisclosure or "").strip()

    @property
    def resolved_selling_price(self) -> Optional[float]:
        return self.sellingPrice if self.sellingPrice is not None else self.price

    @property
    def resolved_images(self) -> list[str]:
        combined = list(self.images) + [
            u for u in self.imageUrls if u not in self.images
        ]
        return [u.strip() for u in combined if u and u.strip()]

    @model_validator(mode="after")
    def validate_product_name_present(self) -> "GenerateListingRequest":
        if not self.resolved_name:
            raise ValueError("Either `productName` or `title` must be provided and non-empty.")
        return self


class ListingDescriptionSections(BaseModel):
    """Structured 3-part listing description required by Prompt 3."""

    overview: str = Field(..., min_length=1, description="Product overview and factual highlights.")
    condition: str = Field(..., min_length=1, description="Honest physical and functional condition.")
    defects: str = Field(..., min_length=1, description="Preserved defect disclosure and notes.")


class GenerateListingLLMOutput(BaseModel):
    """Schema used to bind Gemini structured output for Agent 1."""

    suggestedTitle: str = Field(..., min_length=3, max_length=140)
    suggestedDescription: ListingDescriptionSections
    suggestedCategory: str = Field(..., min_length=1)
    suggestedTags: list[str] = Field(default_factory=list)
    transparencyNote: str = Field(..., min_length=1)
    transparencyScore: int = Field(default=92, ge=0, le=100)
    needsMoreInfo: bool = Field(default=False)
    clarificationQuestions: list[str] = Field(default_factory=list)


class GenerateListingResponse(BaseModel):
    """Output JSON schema for `POST /ai/generate-listing`."""

    suggestedTitle: str
    suggestedDescription: ListingDescriptionSections
    suggestedDescriptionText: str = Field(
        default="",
        description="Flattened editable string representation of the 3 description sections.",
    )
    suggestedCategory: str
    suggestedTags: list[str] = Field(default_factory=list)
    transparencyNote: str
    transparencyScore: int = Field(default=92, ge=0, le=100)
    needsMoreInfo: bool = False
    clarificationQuestions: list[str] = Field(default_factory=list)
    requiresSellerApproval: bool = Field(
        default=True,
        description="Human-in-the-loop: seller must review and confirm before publishing.",
    )
    aiProvider: str = "gemini-3.8-flash"
    latencyMs: float = 0.0
    tokenUsage: TokenUsageMetrics = Field(default_factory=TokenUsageMetrics)
    requestId: str = "-"


# =====================================================================
# AGENT 2: SMART PRICE ESTIMATOR SCHEMAS
# =====================================================================


class EstimatePriceRequest(_StrictAgentRequestModel):
    """Input schema for `POST /ai/estimate-price`."""

    productName: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Product name (alias: `title`).",
    )
    title: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Product name.",
    )
    brand: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Brand / manufacturer.",
    )
    category: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Category name or slug.",
    )
    condition: str = Field(
        default="GOOD",
        max_length=50,
        description="Product condition: NEW, LIKE_NEW, GOOD, or FAIR.",
    )
    defects: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Known defects or wear notes (alias: `defectDisclosure`).",
    )
    defectDisclosure: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Known defects or wear notes.",
    )
    originalPrice: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Original retail purchase price in VND.",
    )
    comparableProducts: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Optional inline comparable listings if already fetched.",
    )

    @property
    def resolved_name(self) -> str:
        return (self.productName or self.title or "").strip()

    @property
    def resolved_defects(self) -> str:
        return (self.defects or self.defectDisclosure or "").strip()

    @model_validator(mode="after")
    def validate_name_present(self) -> "EstimatePriceRequest":
        if not self.resolved_name:
            raise ValueError("Either `productName` or `title` must be provided and non-empty.")
        return self


class EstimatePriceLLMOutput(BaseModel):
    """Schema used to bind Gemini structured output for Agent 2."""

    quickSellPrice: int = Field(..., ge=0)
    recommendedPrice: int = Field(..., ge=0)
    maxFairPrice: int = Field(..., ge=0)
    reasoning: str = Field(..., min_length=5)
    factors: list[str] = Field(default_factory=list)
    marketDemand: Literal["HIGH", "MEDIUM", "LOW"] = "MEDIUM"


class EstimatePriceResponse(BaseModel):
    """Output JSON schema for `POST /ai/estimate-price`."""

    quickSellPrice: int = Field(..., ge=0)
    recommendedPrice: int = Field(..., ge=0)
    maxFairPrice: int = Field(..., ge=0)
    currency: str = "VND"
    reasoning: str
    factors: list[str] = Field(default_factory=list)
    confidence: Literal["HIGH", "MEDIUM", "LOW"] = "MEDIUM"
    dataSourceNote: str = Field(
        default="",
        description="Explicit distinction between real Backend comparable data and AI estimation.",
    )
    warnings: list[str] = Field(default_factory=list)
    comparableCount: int = 0
    depreciationPercent: int = 30
    marketDemand: Literal["HIGH", "MEDIUM", "LOW"] = "MEDIUM"
    requiresSellerDecision: bool = Field(
        default=True,
        description="Human-in-the-loop: seller makes the final pricing decision.",
    )
    aiProvider: str = "gemini-3.8-flash"
    latencyMs: float = 0.0
    tokenUsage: TokenUsageMetrics = Field(default_factory=TokenUsageMetrics)
    requestId: str = "-"


# =====================================================================
# AGENT 3: BUYER INSPECTION CHECKLIST SCHEMAS
# =====================================================================


class InspectionImportanceEnum(str, Enum):
    """Importance priority for each buyer inspection point."""

    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class InspectionPointItem(BaseModel):
    """Single actionable inspection point required by Prompt 3."""

    title: str = Field(..., min_length=2, description="Short title of the inspection step.")
    description: str = Field(
        ...,
        min_length=5,
        description="Detailed actionable instructions on how to inspect this point in person.",
    )
    importance: InspectionImportanceEnum = Field(
        default=InspectionImportanceEnum.HIGH,
        description="Priority level: HIGH, MEDIUM, or LOW.",
    )


class BuyerChecklistRequest(_StrictAgentRequestModel):
    """Input schema for `POST /ai/buyer-checklist`."""

    productId: Optional[str] = Field(
        default=None,
        description="Optional 24-character hex MongoDB ObjectId of the product listing.",
    )
    product_id: Optional[str] = Field(
        default=None,
        description="Alias for `productId`.",
    )
    title: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Product title / name.",
    )
    productName: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Alias for `title`.",
    )
    brand: Optional[str] = Field(default=None, max_length=100)
    category: Optional[str] = Field(default=None, max_length=100)
    condition: Optional[str] = Field(default="GOOD", max_length=50)
    defects: Optional[str] = Field(default=None, max_length=1000)
    defectDisclosure: Optional[str] = Field(default=None, max_length=1000)
    description: Optional[str] = Field(default=None, max_length=2000)
    price: Optional[float] = Field(default=None, ge=0.0)
    images: list[str] = Field(default_factory=list, max_length=10)
    imageUrls: list[str] = Field(default_factory=list, max_length=10)
    forceRefresh: bool = False

    @property
    def resolved_product_id(self) -> Optional[str]:
        raw = (self.productId or self.product_id or "").strip()
        return raw or None

    @property
    def resolved_title(self) -> str:
        return (self.title or self.productName or "").strip()

    @property
    def resolved_defects(self) -> str:
        return (self.defects or self.defectDisclosure or "").strip()

    @property
    def resolved_images(self) -> list[str]:
        return list(self.images or self.imageUrls or [])

    @field_validator("productId", "product_id")
    @classmethod
    def validate_optional_object_id(cls, value: Optional[str]) -> Optional[str]:
        if value is None or not value.strip():
            return None
        return validate_object_id(value.strip(), "productId")

    @model_validator(mode="after")
    def validate_id_or_title(self) -> "BuyerChecklistRequest":
        if not self.resolved_product_id and not self.resolved_title:
            raise ValueError(
                "Either `productId` or `title`/`productName` must be provided for inspection checklist generation."
            )
        return self


class BuyerChecklistLLMOutput(BaseModel):
    """Schema used to bind Gemini structured output for Agent 3."""

    inspectionPoints: list[InspectionPointItem] = Field(..., min_length=3, max_length=4)
    suggestedQuestions: list[str] = Field(..., min_length=3, max_length=3)
    safetyTips: list[str] = Field(default_factory=list)


class BuyerChecklistResponse(BaseModel):
    """Output JSON schema for `POST /ai/buyer-checklist`."""

    productId: Optional[str] = None
    inspectionPoints: list[InspectionPointItem] = Field(..., min_length=3, max_length=4)
    suggestedQuestions: list[str] = Field(..., min_length=3, max_length=3)
    safetyTips: list[str] = Field(default_factory=list)
    safetyTip: str = Field(
        default="",
        description="Primary safety tip summary for NestJS compatibility.",
    )
    advisoryOnly: bool = Field(
        default=True,
        description="Human-in-the-loop: checklist is a recommendation for in-person verification only.",
    )
    aiProvider: str = "gemini-3.8-flash"
    latencyMs: float = 0.0
    tokenUsage: TokenUsageMetrics = Field(default_factory=TokenUsageMetrics)
    requestId: str = "-"


# =====================================================================
# AGENT 4: SECONDHAND SHOPPING ASSISTANT SCHEMAS
# =====================================================================


class ShoppingAssistantIntentEnum(str, Enum):
    """4 workflow branches of the Shopping Assistant LangGraph."""

    PRODUCT_DISCOVERY = "PRODUCT_DISCOVERY"
    PRODUCT_COMPARISON = "PRODUCT_COMPARISON"
    BUYING_ADVICE = "BUYING_ADVICE"
    GENERAL_CONVERSATION = "GENERAL_CONVERSATION"


class ShoppingChatRequest(_StrictAgentRequestModel):
    """Input schema for `POST /ai/chat`."""

    message: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="User's message to the Secondhand Shopping Assistant.",
    )
    thread_id: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Conversation thread ID for multi-turn state persistence.",
    )
    conversation_id: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Alias for `thread_id`.",
    )
    previousInteractionId: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Alias for `thread_id` forwarded by NestJS Backend.",
    )
    maxBudget: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Optional maximum budget filter in VND.",
    )
    category: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Optional category preference.",
    )
    condition: Optional[str] = Field(
        default=None,
        max_length=50,
        description="Optional condition filter (NEW, LIKE_NEW, GOOD, FAIR).",
    )
    location: Optional[str] = Field(
        default=None,
        max_length=120,
        description="Optional location filter.",
    )
    catalogContext: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Optional pre-fetched active catalog items passed from NestJS.",
    )

    @field_validator("message")
    @classmethod
    def check_non_blank_message(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("message must not be empty or whitespace.")
        return cleaned

    @property
    def resolved_thread_id(self) -> Optional[str]:
        raw = (
            self.thread_id
            or self.conversation_id
            or self.previousInteractionId
            or ""
        ).strip()
        return raw or None


class MatchedProductCard(BaseModel):
    """
    Real product item returned in `ShoppingChatResponse.matchedProducts`.
    Guaranteed to carry a real Backend product `id` / `_id` and preserve all core fields
    so Frontend can open the detail page.
    """

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(..., min_length=1, description="Real MongoDB ObjectId of the product.")
    raw_id: str = Field(default="", serialization_alias="_id")
    sellerId: str = Field(default="")
    categoryId: str = Field(default="")
    title: str
    description: str = Field(default="")
    price: float
    originalPrice: Optional[float] = None
    brand: Optional[str] = None
    condition: str = "GOOD"
    defectDisclosure: Optional[str] = None
    transparencyScore: Optional[float] = None
    location: str = ""
    status: str = "ACTIVE"
    category: Optional[str] = None
    images: list[dict[str, Any]] = Field(default_factory=list)
    fitScore: float = Field(default=0.0, description="Relevance score for the user's request.")
    fitReason: Optional[str] = None


class ShoppingChatResponse(BaseModel):
    """Output JSON schema for `POST /ai/chat`."""

    message: str = Field(..., description="Assistant response text in Vietnamese.")
    reply: str = Field(
        default="",
        description="Alias for `message` (used by NestJS `AiService`).",
    )
    thread_id: str = Field(..., description="Active conversation thread ID.")
    interactionId: str = Field(
        default="",
        description="Alias for `thread_id` (used by NestJS `AiService`).",
    )
    intent: ShoppingAssistantIntentEnum = ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY
    matchedProducts: list[MatchedProductCard] = Field(default_factory=list)
    matchedProductIds: list[str] = Field(default_factory=list)
    suggestedQuestions: list[str] = Field(default_factory=list)
    suggestedFollowUps: list[str] = Field(default_factory=list)
    sources: list[RAGSourceAttribution] = Field(default_factory=list)
    requiresBuyerConfirmation: bool = Field(
        default=True,
        description="Human-in-the-loop: assistant never places orders or executes payments.",
    )
    aiProvider: str = "gemini-3.8-flash"
    latencyMs: float = 0.0
    tokenUsage: TokenUsageMetrics = Field(default_factory=TokenUsageMetrics)
    requestId: str = "-"


# =====================================================================
# SUPERVISOR & CONVERSATION ENDPOINT SCHEMAS
# =====================================================================


class SupervisorIntentEnum(str, Enum):
    """Supported top-level intents in the ReMarket Supervisor Graph."""

    GENERATE_LISTING = "GENERATE_LISTING"
    ESTIMATE_PRICE = "ESTIMATE_PRICE"
    BUYER_INSPECTION = "BUYER_INSPECTION"
    SHOPPING_ASSISTANT = "SHOPPING_ASSISTANT"
    GENERAL = "GENERAL"


class SupervisorExecuteRequest(_StrictAgentRequestModel):
    """Input schema for `POST /ai/agent/execute`."""

    message: Optional[str] = Field(
        default=None,
        max_length=2000,
        description="User prompt or instruction for automatic intent classification.",
    )
    intent: Optional[SupervisorIntentEnum] = Field(
        default=None,
        description="Optional explicit intent override.",
    )
    payload: dict[str, Any] = Field(
        default_factory=dict,
        description="Optional structured task parameters (e.g., productName, condition, productId).",
    )
    thread_id: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Optional conversation thread ID.",
    )

    @model_validator(mode="after")
    def check_message_or_payload(self) -> "SupervisorExecuteRequest":
        if not (self.message and self.message.strip()) and not self.payload and not self.intent:
            raise ValueError("Provide at least `message`, `intent`, or `payload`.")
        if isinstance(self.payload, Mapping):
            if "user_id" in self.payload or "userId" in self.payload:
                raise ValueError(
                    "Payload must not specify 'user_id'/'userId'. User context is managed by NestJS."
                )
            assert_no_spoofed_auth_override(self.payload)
        return self


class SupervisorExecuteResponse(BaseModel):
    """Unified output schema for `POST /ai/agent/execute`."""

    intent: SupervisorIntentEnum
    targetGraph: str
    fallbackUsed: bool = False
    data: dict[str, Any]
    latencyMs: float = 0.0
    requestId: str = "-"


class ConversationHistoryResponse(BaseModel):
    """Output schema for `GET /ai/conversations/{conversation_id}`."""

    conversation_id: str
    owner_user_id: str
    turns: list[dict[str, Any]] = Field(default_factory=list)
    last_matched_products: list[dict[str, Any]] = Field(default_factory=list)
    preferences: dict[str, Any] = Field(default_factory=dict)
    last_intent: Optional[str] = None
    created_at: str
    updated_at: str
    requestId: str = "-"


class DeleteConversationResponse(BaseModel):
    """Output schema for `DELETE /ai/conversations/{conversation_id}`."""

    conversation_id: str
    deleted: bool = True
    requestId: str = "-"
