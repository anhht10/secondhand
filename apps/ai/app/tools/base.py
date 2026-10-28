"""
Base Schemas, Security Validators, and Data Normalizers for ReMarket Agent Tools (`app.tools.base`).
Enforces:
- Strict Pydantic v2 input validation (`extra="forbid"`).
- Prevention of LLM auth/identity spoofing (`assert_no_spoofed_auth_override`).
- Sanitization of Backend responses so no private PII (email, phoneNumber, passwordHash, wishlist)
  is ever leaked through Agent tools.
"""

from enum import Enum
import re
from typing import Any, Mapping, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.auth_context import assert_no_spoofed_auth_override

OBJECT_ID_REGEX = re.compile(r"^[0-9a-fA-F]{24}$")

# Private user fields that must NEVER be exposed by any Agent tool
PRIVATE_USER_FIELDS = frozenset(
    {
        "email",
        "phoneNumber",
        "phone_number",
        "password",
        "passwordHash",
        "password_hash",
        "tokenHash",
        "refreshToken",
        "wishlist",
    }
)


def validate_object_id(value: str, field_name: str = "id") -> str:
    """Validate that `value` is a 24-character hexadecimal MongoDB ObjectId."""
    if not isinstance(value, str):
        raise ValueError(f"{field_name} must be a string.")
    cleaned = value.strip()
    if not OBJECT_ID_REGEX.match(cleaned):
        raise ValueError(
            f"Invalid {field_name} '{cleaned}'. Must be a 24-character hex MongoDB ObjectId."
        )
    return cleaned


class ProductConditionEnum(str, Enum):
    """Valid product conditions matching NestJS `ProductCondition`."""

    NEW = "NEW"
    LIKE_NEW = "LIKE_NEW"
    GOOD = "GOOD"
    FAIR = "FAIR"


class ProductStatusEnum(str, Enum):
    """Valid product statuses matching NestJS `ProductStatus`."""

    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    RESERVED = "RESERVED"
    SOLD = "SOLD"
    ARCHIVED = "ARCHIVED"


class ProductSortEnum(str, Enum):
    """Valid product sort options matching NestJS `ProductSortBy`."""

    NEWEST = "newest"
    PRICE_ASC = "price_asc"
    PRICE_DESC = "price_desc"


class ToolStrictInputModel(BaseModel):
    """
    Base Pydantic input model for all ReMarket Agent Tools.
    Forbids unexpected fields and blocks any attempt to inject auth/user override parameters.
    """

    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    @model_validator(mode="before")
    @classmethod
    def reject_spoofed_auth_fields(cls, values: Any) -> Any:
        if isinstance(values, Mapping):
            assert_no_spoofed_auth_override(values)
        return values


class ProductImageItem(BaseModel):
    """Normalized product image metadata."""

    url: str
    publicId: Optional[str] = None
    sortOrder: int = 0
    altText: Optional[str] = None


class SellerSummaryItem(BaseModel):
    """Sanitized public seller summary embedded in product responses."""

    id: str
    displayName: Optional[str] = None
    avatarUrl: Optional[str] = None
    location: Optional[str] = None
    university: Optional[str] = None
    isEmailVerified: Optional[bool] = None
    status: Optional[str] = None


class CategorySummaryItem(BaseModel):
    """Normalized category summary embedded in product responses."""

    id: str
    name: Optional[str] = None
    slug: Optional[str] = None
    icon: Optional[str] = None


class ProductToolItem(BaseModel):
    """Normalized product representation returned by ReMarket Product Tools."""

    model_config = ConfigDict(populate_by_name=True)

    id: str
    raw_id: str = Field(default="", serialization_alias="_id")
    title: str
    description: str
    price: float
    originalPrice: Optional[float] = None
    brand: Optional[str] = None
    condition: str
    defectDisclosure: Optional[str] = None
    transparencyNote: Optional[str] = None
    transparencyScore: Optional[float] = None
    images: list[ProductImageItem] = Field(default_factory=list)
    location: str
    status: str = "ACTIVE"
    tags: list[str] = Field(default_factory=list)
    sellerId: str
    seller: Optional[SellerSummaryItem] = None
    categoryId: str
    category: Optional[CategorySummaryItem] = None
    viewCount: int = 0
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None


class PaginationMetaItem(BaseModel):
    """Pagination metadata returned by NestJS paginated endpoints."""

    page: int = 1
    limit: int = 12
    total: int = 0
    totalPages: int = 1
    hasNextPage: bool = False
    hasPrevPage: bool = False


class PaginatedProductsToolOutput(BaseModel):
    """Standardized output schema for paginated product search and filter tools."""

    items: list[ProductToolItem] = Field(default_factory=list)
    meta: PaginationMetaItem = Field(default_factory=PaginationMetaItem)
    appliedFilters: dict[str, Any] = Field(default_factory=dict)
    backendNote: Optional[str] = None


def strip_private_user_fields(raw: Mapping[str, Any]) -> dict[str, Any]:
    """Remove any private PII or credential fields from a user dictionary."""
    return {
        k: v
        for k, v in raw.items()
        if k not in PRIVATE_USER_FIELDS and not str(k).startswith("__")
    }


def normalize_product_item(raw: Mapping[str, Any]) -> ProductToolItem:
    """
    Convert a raw NestJS Product JSON object (with either populated or unpopulated
    `sellerId` and `categoryId`) into a validated `ProductToolItem`.
    """
    prod_id = str(raw.get("id") or raw.get("_id") or "")

    # Extract sellerId and optional populated seller object (stripping private fields)
    raw_seller = raw.get("sellerId")
    seller_id = ""
    seller_obj: Optional[SellerSummaryItem] = None
    if isinstance(raw_seller, Mapping):
        clean_seller = strip_private_user_fields(raw_seller)
        seller_id = str(clean_seller.get("id") or clean_seller.get("_id") or "")
        seller_obj = SellerSummaryItem(
            id=seller_id,
            displayName=clean_seller.get("displayName"),
            avatarUrl=clean_seller.get("avatarUrl"),
            location=clean_seller.get("location"),
            university=clean_seller.get("university"),
            isEmailVerified=clean_seller.get("isEmailVerified"),
            status=clean_seller.get("status"),
        )
    elif raw_seller is not None:
        seller_id = str(raw_seller)

    # Extract categoryId and optional populated category object
    raw_category = raw.get("categoryId")
    category_id = ""
    category_obj: Optional[CategorySummaryItem] = None
    if isinstance(raw_category, Mapping):
        category_id = str(raw_category.get("id") or raw_category.get("_id") or "")
        category_obj = CategorySummaryItem(
            id=category_id,
            name=raw_category.get("name"),
            slug=raw_category.get("slug"),
            icon=raw_category.get("icon"),
        )
    elif raw_category is not None:
        category_id = str(raw_category)

    raw_images = raw.get("images") or []
    images: list[ProductImageItem] = []
    if isinstance(raw_images, list):
        for idx, img in enumerate(raw_images):
            if isinstance(img, Mapping) and img.get("url"):
                images.append(
                    ProductImageItem(
                        url=str(img["url"]),
                        publicId=img.get("publicId"),
                        sortOrder=int(img.get("sortOrder", idx)),
                        altText=img.get("altText"),
                    )
                )

    raw_tags = raw.get("tags") or []
    tags = [str(t) for t in raw_tags] if isinstance(raw_tags, list) else []

    created_at = raw.get("createdAt")
    updated_at = raw.get("updatedAt")

    return ProductToolItem(
        id=prod_id,
        raw_id=prod_id,
        title=str(raw.get("title") or ""),
        description=str(raw.get("description") or ""),
        price=float(raw.get("price") or 0.0),
        originalPrice=(
            float(raw["originalPrice"])
            if raw.get("originalPrice") is not None
            else None
        ),
        brand=raw.get("brand"),
        condition=str(raw.get("condition") or "GOOD"),
        defectDisclosure=raw.get("defectDisclosure"),
        transparencyNote=raw.get("transparencyNote"),
        transparencyScore=(
            float(raw["transparencyScore"])
            if raw.get("transparencyScore") is not None
            else None
        ),
        images=images,
        location=str(raw.get("location") or ""),
        status=str(raw.get("status") or "ACTIVE"),
        tags=tags,
        sellerId=seller_id,
        seller=seller_obj,
        categoryId=category_id,
        category=category_obj,
        viewCount=int(raw.get("viewCount") or 0),
        createdAt=str(created_at) if created_at is not None else None,
        updatedAt=str(updated_at) if updated_at is not None else None,
    )


def normalize_pagination_meta(
    raw_meta: Optional[Mapping[str, Any]],
    *,
    default_page: int = 1,
    default_limit: int = 12,
    item_count: int = 0,
) -> PaginationMetaItem:
    """Normalize pagination metadata from NestJS `meta` envelope."""
    if not isinstance(raw_meta, Mapping) or not raw_meta:
        return PaginationMetaItem(
            page=default_page,
            limit=default_limit,
            total=item_count,
            totalPages=1,
            hasNextPage=False,
            hasPrevPage=default_page > 1,
        )
    return PaginationMetaItem(
        page=int(raw_meta.get("page", default_page)),
        limit=int(raw_meta.get("limit", default_limit)),
        total=int(raw_meta.get("total", item_count)),
        totalPages=int(raw_meta.get("totalPages", 1)),
        hasNextPage=bool(raw_meta.get("hasNextPage", False)),
        hasPrevPage=bool(raw_meta.get("hasPrevPage", False)),
    )
