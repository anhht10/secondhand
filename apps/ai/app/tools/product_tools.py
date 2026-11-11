"""
Product Domain Agent Tools (`app.tools.product_tools`).
Implements read-only LangChain StructuredTools backed by NestJS Backend REST APIs:
1. `search_products`      -> `GET /api/v1/products?keyword=...&page=...&limit=...`
2. `filter_products`      -> `GET /api/v1/products?category=...&minPrice=...&maxPrice=...&condition=...&status=...`
3. `get_product_detail`   -> `GET /api/v1/products/:id`
4. `get_related_products` -> Composes `GET /api/v1/products/:id` + `GET /api/v1/products?category=...`
"""

from typing import Any, Optional

from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field, field_validator, model_validator

from app.services.backend_client import (
    BackendClient,
    get_backend_client,
    run_async_safely,
)
from app.tools.base import (
    PaginatedProductsToolOutput,
    ProductConditionEnum,
    ProductSortEnum,
    ProductStatusEnum,
    ProductToolItem,
    ToolStrictInputModel,
    normalize_pagination_meta,
    normalize_product_item,
    validate_object_id,
)


class SearchProductsInput(ToolStrictInputModel):
    """Input schema for `search_products` tool."""

    keyword: str = Field(
        ...,
        min_length=1,
        max_length=120,
        description="Search keyword matching product title and description (e.g., 'Sony WH-1000XM4', 'bàn phím cơ').",
    )
    page: int = Field(
        default=1,
        ge=1,
        le=1000,
        description="1-indexed page number for pagination.",
    )
    limit: int = Field(
        default=12,
        ge=1,
        le=50,
        description="Number of product items per page (1 to 50).",
    )
    sort: ProductSortEnum = Field(
        default=ProductSortEnum.NEWEST,
        description="Sort order: 'newest', 'price_asc', or 'price_desc'.",
    )

    @field_validator("keyword")
    @classmethod
    def validate_non_blank_keyword(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("keyword must not be empty or whitespace.")
        return cleaned


class FilterProductsInput(ToolStrictInputModel):
    """Input schema for `filter_products` tool."""

    category: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=100,
        description="Category MongoDB ObjectId or slug (e.g., 'electronics', 'computers-accessories', 'phones-tablets', 'books').",
    )
    min_price: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Minimum product price in VND (>= 0).",
    )
    max_price: Optional[float] = Field(
        default=None,
        ge=0.0,
        description="Maximum product price in VND (>= 0).",
    )
    condition: Optional[ProductConditionEnum] = Field(
        default=None,
        description="Product physical condition: 'NEW', 'LIKE_NEW', 'GOOD', or 'FAIR'.",
    )
    status: Optional[ProductStatusEnum] = Field(
        default=ProductStatusEnum.ACTIVE,
        description="Product listing status: 'DRAFT', 'ACTIVE', 'RESERVED', 'SOLD', or 'ARCHIVED'.",
    )
    location: Optional[str] = Field(
        default=None,
        max_length=120,
        description="Case-insensitive partial location match (e.g., 'Thủ Đức', 'Quận 10').",
    )
    keyword: Optional[str] = Field(
        default=None,
        max_length=120,
        description="Optional keyword query combined with filters.",
    )
    sort: ProductSortEnum = Field(
        default=ProductSortEnum.NEWEST,
        description="Sort order: 'newest', 'price_asc', or 'price_desc'.",
    )
    page: int = Field(
        default=1,
        ge=1,
        le=1000,
        description="1-indexed page number.",
    )
    limit: int = Field(
        default=12,
        ge=1,
        le=50,
        description="Items per page (1 to 50).",
    )

    @model_validator(mode="after")
    def validate_price_range(self) -> "FilterProductsInput":
        if (
            self.min_price is not None
            and self.max_price is not None
            and self.min_price > self.max_price
        ):
            raise ValueError("min_price cannot be greater than max_price.")
        return self


class GetProductDetailInput(ToolStrictInputModel):
    """Input schema for `get_product_detail` tool."""

    product_id: str = Field(
        ...,
        description="24-character hex MongoDB ObjectId of the product listing.",
    )

    @field_validator("product_id")
    @classmethod
    def check_product_id(cls, value: str) -> str:
        return validate_object_id(value, "product_id")


class GetRelatedProductsInput(ToolStrictInputModel):
    """Input schema for `get_related_products` tool."""

    product_id: str = Field(
        ...,
        description="24-character hex MongoDB ObjectId of the reference product.",
    )
    limit: int = Field(
        default=6,
        ge=1,
        le=20,
        description="Maximum number of related products to return (1 to 20).",
    )
    price_tolerance_ratio: float = Field(
        default=0.5,
        ge=0.1,
        le=2.0,
        description="Relative price tolerance around reference product price (e.g., 0.5 means +/- 50%).",
    )

    @field_validator("product_id")
    @classmethod
    def check_product_id(cls, value: str) -> str:
        return validate_object_id(value, "product_id")


class RelatedProductsToolOutput(BaseModel):
    """Output schema for `get_related_products` tool."""

    referenceProductId: str
    referenceTitle: str
    referenceCategory: Optional[str] = None
    referencePrice: float
    items: list[ProductToolItem] = Field(default_factory=list)
    totalRelated: int = 0
    strategy: str = "category_and_price_band"
    backendNote: Optional[str] = None


async def search_products_async(
    keyword: str,
    page: int = 1,
    limit: int = 12,
    sort: ProductSortEnum = ProductSortEnum.NEWEST,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """Execute `search_products` asynchronously via `BackendClient`."""
    validated = SearchProductsInput(
        keyword=keyword,
        page=page,
        limit=limit,
        sort=sort,
    )
    backend = client or get_backend_client()
    response = await backend.list_products(
        keyword=validated.keyword,
        page=validated.page,
        limit=validated.limit,
        sort=validated.sort.value,
    )

    raw_items = response.get("data") or []
    items = [
        normalize_product_item(item)
        for item in raw_items
        if isinstance(item, dict)
    ]
    meta = normalize_pagination_meta(
        response.get("meta"),
        default_page=validated.page,
        default_limit=validated.limit,
        item_count=len(items),
    )

    output = PaginatedProductsToolOutput(
        items=items,
        meta=meta,
        appliedFilters={
            "keyword": validated.keyword,
            "page": validated.page,
            "limit": validated.limit,
            "sort": validated.sort.value,
        },
    )
    return output.model_dump()


async def filter_products_async(
    category: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    condition: Optional[ProductConditionEnum] = None,
    status: Optional[ProductStatusEnum] = ProductStatusEnum.ACTIVE,
    location: Optional[str] = None,
    keyword: Optional[str] = None,
    sort: ProductSortEnum = ProductSortEnum.NEWEST,
    page: int = 1,
    limit: int = 12,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """Execute `filter_products` asynchronously via `BackendClient`."""
    validated = FilterProductsInput(
        category=category,
        min_price=min_price,
        max_price=max_price,
        condition=condition,
        status=status,
        location=location,
        keyword=keyword,
        sort=sort,
        page=page,
        limit=limit,
    )
    backend = client or get_backend_client()
    resolved_condition = validated.condition.value if validated.condition else None
    resolved_status = validated.status.value if validated.status else None

    response = await backend.list_products(
        keyword=validated.keyword,
        category=validated.category,
        condition=resolved_condition,
        min_price=validated.min_price,
        max_price=validated.max_price,
        location=validated.location,
        status=resolved_status,
        sort=validated.sort.value,
        page=validated.page,
        limit=validated.limit,
    )

    raw_items = response.get("data") or []
    items = [
        normalize_product_item(item)
        for item in raw_items
        if isinstance(item, dict)
    ]
    meta = normalize_pagination_meta(
        response.get("meta"),
        default_page=validated.page,
        default_limit=validated.limit,
        item_count=len(items),
    )

    backend_note: Optional[str] = None
    if validated.status and validated.status != ProductStatusEnum.ACTIVE:
        backend_note = (
            f"Note: Requested status='{validated.status.value}', but NestJS public endpoint "
            "`GET /api/v1/products` enforces status='ACTIVE' for public marketplace queries."
        )

    output = PaginatedProductsToolOutput(
        items=items,
        meta=meta,
        appliedFilters={
            "category": validated.category,
            "min_price": validated.min_price,
            "max_price": validated.max_price,
            "condition": resolved_condition,
            "status": resolved_status,
            "location": validated.location,
            "keyword": validated.keyword,
            "sort": validated.sort.value,
            "page": validated.page,
            "limit": validated.limit,
        },
        backendNote=backend_note,
    )
    return output.model_dump()


async def get_product_detail_async(
    product_id: str,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """Execute `get_product_detail` asynchronously via `BackendClient`."""
    validated = GetProductDetailInput(product_id=product_id)
    backend = client or get_backend_client()
    response = await backend.get_product_by_id(validated.product_id)
    raw_data = response.get("data")
    if not isinstance(raw_data, dict):
        raw_data = response
    product = normalize_product_item(raw_data)
    return product.model_dump()


async def get_related_products_async(
    product_id: str,
    limit: int = 6,
    price_tolerance_ratio: float = 0.5,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """
    Execute `get_related_products` asynchronously using real NestJS endpoints:
    1. Fetch reference product details via `GET /api/v1/products/:id`.
    2. Query active listings in the same category and price band via `GET /api/v1/products`.
    3. If no items match the price band, fall back to same category without price bounds.
    """
    validated = GetRelatedProductsInput(
        product_id=product_id,
        limit=limit,
        price_tolerance_ratio=price_tolerance_ratio,
    )
    backend = client or get_backend_client()

    detail_resp = await backend.get_product_by_id(validated.product_id)
    raw_detail = detail_resp.get("data")
    if not isinstance(raw_detail, dict):
        raw_detail = detail_resp
    ref_product = normalize_product_item(raw_detail)

    category_key = (
        (ref_product.category.slug if ref_product.category and ref_product.category.slug else None)
        or ref_product.categoryId
    )
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    if ref_product.price > 0:
        min_price = max(0.0, round(ref_product.price * (1.0 - validated.price_tolerance_ratio), 2))
        max_price = round(ref_product.price * (1.0 + validated.price_tolerance_ratio), 2)

    strategy = "category_and_price_band"
    list_resp = await backend.list_products(
        category=category_key or None,
        min_price=min_price,
        max_price=max_price,
        page=1,
        limit=min(50, validated.limit + 4),
    )
    raw_candidates = list_resp.get("data") or []
    related_items = [
        normalize_product_item(item)
        for item in raw_candidates
        if isinstance(item, dict)
        and str(item.get("id") or item.get("_id") or "") != ref_product.id
    ]

    # Fallback: if price band was too narrow, query same category without price filter
    if not related_items and category_key and (min_price is not None or max_price is not None):
        strategy = "category_fallback"
        fallback_resp = await backend.list_products(
            category=category_key,
            page=1,
            limit=min(50, validated.limit + 4),
        )
        fallback_candidates = fallback_resp.get("data") or []
        related_items = [
            normalize_product_item(item)
            for item in fallback_candidates
            if isinstance(item, dict)
            and str(item.get("id") or item.get("_id") or "") != ref_product.id
        ]

    trimmed_items = related_items[: validated.limit]
    output = RelatedProductsToolOutput(
        referenceProductId=ref_product.id,
        referenceTitle=ref_product.title,
        referenceCategory=category_key or None,
        referencePrice=ref_product.price,
        items=trimmed_items,
        totalRelated=len(trimmed_items),
        strategy=strategy,
        backendNote=(
            "Composed via `GET /api/v1/products/:id` + `GET /api/v1/products` "
            "(Backend does not expose a dedicated `/products/:id/related` endpoint)."
        ),
    )
    return output.model_dump()


def build_product_tools(client: Optional[BackendClient] = None) -> list[StructuredTool]:
    """Create the 4 product-focused LangChain `StructuredTool` instances."""

    def _search_sync(
        keyword: str,
        page: int = 1,
        limit: int = 12,
        sort: ProductSortEnum = ProductSortEnum.NEWEST,
    ) -> dict[str, Any]:
        return run_async_safely(
            search_products_async(
                keyword=keyword,
                page=page,
                limit=limit,
                sort=sort,
                client=client,
            )
        )

    async def _search_async(
        keyword: str,
        page: int = 1,
        limit: int = 12,
        sort: ProductSortEnum = ProductSortEnum.NEWEST,
    ) -> dict[str, Any]:
        return await search_products_async(
            keyword=keyword,
            page=page,
            limit=limit,
            sort=sort,
            client=client,
        )

    def _filter_sync(
        category: Optional[str] = None,
        min_price: Optional[float] = None,
        max_price: Optional[float] = None,
        condition: Optional[ProductConditionEnum] = None,
        status: Optional[ProductStatusEnum] = ProductStatusEnum.ACTIVE,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        sort: ProductSortEnum = ProductSortEnum.NEWEST,
        page: int = 1,
        limit: int = 12,
    ) -> dict[str, Any]:
        return run_async_safely(
            filter_products_async(
                category=category,
                min_price=min_price,
                max_price=max_price,
                condition=condition,
                status=status,
                location=location,
                keyword=keyword,
                sort=sort,
                page=page,
                limit=limit,
                client=client,
            )
        )

    async def _filter_async(
        category: Optional[str] = None,
        min_price: Optional[float] = None,
        max_price: Optional[float] = None,
        condition: Optional[ProductConditionEnum] = None,
        status: Optional[ProductStatusEnum] = ProductStatusEnum.ACTIVE,
        location: Optional[str] = None,
        keyword: Optional[str] = None,
        sort: ProductSortEnum = ProductSortEnum.NEWEST,
        page: int = 1,
        limit: int = 12,
    ) -> dict[str, Any]:
        return await filter_products_async(
            category=category,
            min_price=min_price,
            max_price=max_price,
            condition=condition,
            status=status,
            location=location,
            keyword=keyword,
            sort=sort,
            page=page,
            limit=limit,
            client=client,
        )

    def _detail_sync(product_id: str) -> dict[str, Any]:
        return run_async_safely(
            get_product_detail_async(product_id=product_id, client=client)
        )

    async def _detail_async(product_id: str) -> dict[str, Any]:
        return await get_product_detail_async(product_id=product_id, client=client)

    def _related_sync(
        product_id: str,
        limit: int = 6,
        price_tolerance_ratio: float = 0.5,
    ) -> dict[str, Any]:
        return run_async_safely(
            get_related_products_async(
                product_id=product_id,
                limit=limit,
                price_tolerance_ratio=price_tolerance_ratio,
                client=client,
            )
        )

    async def _related_async(
        product_id: str,
        limit: int = 6,
        price_tolerance_ratio: float = 0.5,
    ) -> dict[str, Any]:
        return await get_related_products_async(
            product_id=product_id,
            limit=limit,
            price_tolerance_ratio=price_tolerance_ratio,
            client=client,
        )

    return [
        StructuredTool.from_function(
            func=_search_sync,
            coroutine=_search_async,
            name="search_products",
            description=(
                "Search active second-hand products on ReMarket by keyword with pagination "
                "and sorting ('newest', 'price_asc', 'price_desc')."
            ),
            args_schema=SearchProductsInput,
        ),
        StructuredTool.from_function(
            func=_filter_sync,
            coroutine=_filter_async,
            name="filter_products",
            description=(
                "Filter second-hand products on ReMarket by category (slug or ID), "
                "price range (min_price, max_price), condition (NEW, LIKE_NEW, GOOD, FAIR), "
                "status, location, and sort order."
            ),
            args_schema=FilterProductsInput,
        ),
        StructuredTool.from_function(
            func=_detail_sync,
            coroutine=_detail_async,
            name="get_product_detail",
            description=(
                "Get full details of a specific product listing by its MongoDB ObjectId, "
                "including condition, defectDisclosure (wear & tear notes), transparencyNote, "
                "images, price, originalPrice, seller summary, and category."
            ),
            args_schema=GetProductDetailInput,
        ),
        StructuredTool.from_function(
            func=_related_sync,
            coroutine=_related_async,
            name="get_related_products",
            description=(
                "Find related active products for a given product_id based on its real "
                "category and price band on ReMarket."
            ),
            args_schema=GetRelatedProductsInput,
        ),
    ]


_default_product_tools = build_product_tools()
search_products_tool = _default_product_tools[0]
filter_products_tool = _default_product_tools[1]
get_product_detail_tool = _default_product_tools[2]
get_related_products_tool = _default_product_tools[3]

# Convenient aliases matching the exact tool names in Prompt 2
search_products = search_products_tool
filter_products = filter_products_tool
get_product_detail = get_product_detail_tool
get_related_products = get_related_products_tool
