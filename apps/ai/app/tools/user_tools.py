"""
User & Seller Public Profile Agent Tools (`app.tools.user_tools`).
Implements `get_seller_public_profile` backed by `GET /api/v1/users/:id` on NestJS Backend.
Strictly enforces privacy rules:
- Only public seller profile fields are returned (`id`, `displayName`, `avatarUrl`, `bio`,
  `location`, `university`, `isEmailVerified`, `status`, `stats`, `createdAt`).
- Sensitive/personal fields (`email`, `phoneNumber`, `passwordHash`, `wishlist`, etc.)
  are stripped and never exposed to the Agent.
"""

from typing import Any, Mapping, Optional

from langchain_core.tools import StructuredTool
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services.backend_client import (
    BackendClient,
    get_backend_client,
    run_async_safely,
)
from app.tools.base import (
    ToolStrictInputModel,
    strip_private_user_fields,
    validate_object_id,
)


class GetSellerPublicProfileInput(ToolStrictInputModel):
    """Input schema for `get_seller_public_profile` tool."""

    seller_id: str = Field(
        ...,
        description="24-character hex MongoDB ObjectId of the seller user account.",
    )

    @field_validator("seller_id")
    @classmethod
    def check_seller_id(cls, value: str) -> str:
        return validate_object_id(value, "seller_id")


class SellerStatsItem(BaseModel):
    """Public seller activity statistics."""

    model_config = ConfigDict(extra="ignore")

    activeListingsCount: int = 0
    soldListingsCount: int = 0
    rating: float = 4.9
    transparencyRate: float = 100.0


class PublicSellerProfileToolOutput(BaseModel):
    """
    Strict whitelist output schema for `get_seller_public_profile`.
    Excludes `email`, `phoneNumber`, `passwordHash`, and `wishlist`.
    """

    model_config = ConfigDict(extra="ignore")

    id: str
    displayName: str
    avatarUrl: Optional[str] = None
    bio: Optional[str] = None
    location: Optional[str] = None
    university: Optional[str] = None
    isEmailVerified: bool = False
    status: str = "ACTIVE"
    stats: SellerStatsItem = Field(default_factory=SellerStatsItem)
    createdAt: Optional[str] = None


def normalize_public_seller_profile(raw: Mapping[str, Any]) -> PublicSellerProfileToolOutput:
    """
    Sanitize and normalize a raw NestJS user/seller JSON payload into
    `PublicSellerProfileToolOutput`, guaranteeing no private PII leaks.
    """
    sanitized = strip_private_user_fields(raw)
    seller_id = str(sanitized.get("id") or sanitized.get("_id") or "")

    raw_stats = sanitized.get("stats")
    stats = (
        SellerStatsItem(
            activeListingsCount=int(raw_stats.get("activeListingsCount", 0)),
            soldListingsCount=int(raw_stats.get("soldListingsCount", 0)),
            rating=float(raw_stats.get("rating", 4.9)),
            transparencyRate=float(raw_stats.get("transparencyRate", 100.0)),
        )
        if isinstance(raw_stats, Mapping)
        else SellerStatsItem()
    )

    created_at = sanitized.get("createdAt")
    return PublicSellerProfileToolOutput(
        id=seller_id,
        displayName=str(sanitized.get("displayName") or ""),
        avatarUrl=sanitized.get("avatarUrl"),
        bio=sanitized.get("bio"),
        location=sanitized.get("location"),
        university=sanitized.get("university"),
        isEmailVerified=bool(sanitized.get("isEmailVerified", False)),
        status=str(sanitized.get("status") or "ACTIVE"),
        stats=stats,
        createdAt=str(created_at) if created_at is not None else None,
    )


async def get_seller_public_profile_async(
    seller_id: str,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """Execute `get_seller_public_profile` asynchronously via `BackendClient`."""
    validated = GetSellerPublicProfileInput(seller_id=seller_id)
    backend = client or get_backend_client()
    response = await backend.get_seller_public_profile(validated.seller_id)
    raw_data = response.get("data")
    if not isinstance(raw_data, Mapping):
        raw_data = response
    profile = normalize_public_seller_profile(raw_data)
    return profile.model_dump()


def build_user_tools(client: Optional[BackendClient] = None) -> list[StructuredTool]:
    """Build the `get_seller_public_profile` LangChain `StructuredTool`."""

    def _seller_profile_sync(seller_id: str) -> dict[str, Any]:
        return run_async_safely(
            get_seller_public_profile_async(seller_id=seller_id, client=client)
        )

    async def _seller_profile_async(seller_id: str) -> dict[str, Any]:
        return await get_seller_public_profile_async(seller_id=seller_id, client=client)

    return [
        StructuredTool.from_function(
            func=_seller_profile_sync,
            coroutine=_seller_profile_async,
            name="get_seller_public_profile",
            description=(
                "Retrieve public profile and reputation statistics of a seller on ReMarket "
                "by seller_id (displayName, university, location, bio, isEmailVerified, "
                "activeListingsCount, soldListingsCount, rating, transparencyRate). "
                "Does not expose private contact details like email or phone number."
            ),
            args_schema=GetSellerPublicProfileInput,
        )
    ]


_default_user_tools = build_user_tools()
get_seller_public_profile_tool = _default_user_tools[0]
get_seller_public_profile = get_seller_public_profile_tool
