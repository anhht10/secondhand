"""
Unit Tests for BackendClient, Authentication Context, Tool Input Validation,
Tool Registry, and all 6 ReMarket Phase 2 Agent Tools (`tests/test_tools_and_backend.py`).
All NestJS Backend HTTP calls are mocked via `httpx.MockTransport`.
"""

import json
from typing import Any

import httpx
from pydantic import SecretStr, ValidationError
import pytest

from app.core.auth_context import (
    VerifiedUserContext,
     assert_no_spoofed_auth_override,
    auth_context_scope,
    extract_auth_context_from_headers,
    get_auth_context,
)
from app.core.config import Settings
from app.core.exceptions import (
    BackendAuthenticationError,
    BackendForbiddenError,
    BackendNotFoundError,
    BackendTimeoutError,
    BackendUnavailableError,
    BackendValidationError,
    SecurityViolationError,
)
from app.core.logging import set_request_id
from app.services.backend_client import BackendClient
from app.tools.category_tools import (
    GetProductCategoriesInput,
    build_category_tools,
    get_product_categories_async,
)
from app.tools.product_tools import (
    FilterProductsInput,
    GetProductDetailInput,
    GetRelatedProductsInput,
    SearchProductsInput,
    build_product_tools,
    filter_products_async,
    get_product_detail_async,
    get_related_products_async,
    search_products_async,
)
from app.tools.registry import ToolRegistry, create_default_tool_registry
from app.tools.user_tools import (
    GetSellerPublicProfileInput,
    build_user_tools,
    get_seller_public_profile_async,
)

SAMPLE_PRODUCT_ID_1 = "672b3a9f8e1b2c0012345679"
SAMPLE_PRODUCT_ID_2 = "672b3a9f8e1b2c0012345680"
SAMPLE_SELLER_ID = "672b3a9f8e1b2c0012345671"
SAMPLE_CATEGORY_ID = "672b3a9f8e1b2c0012345678"


def _make_sample_product(
    product_id: str = SAMPLE_PRODUCT_ID_1,
    title: str = "Sony WH-1000XM4 Wireless Headphones",
    price: float = 4200000,
    condition: str = "LIKE_NEW",
) -> dict[str, Any]:
    return {
        "_id": product_id,
        "id": product_id,
        "title": title,
        "description": "Tai nghe chống ồn Sony WH-1000XM4 dùng kỹ 8 tháng, đầy đủ hộp cáp.",
        "price": price,
        "originalPrice": 6990000,
        "brand": "Sony",
        "condition": condition,
        "defectDisclosure": "Đệm tai còn êm, xước dăm rất nhẹ ở vỏ hộp.",
        "transparencyNote": "Pin thực tế còn hơn 26h bật ANC.",
        "transparencyScore": 96,
        "images": [
            {
                "url": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e",
                "publicId": "products/sony-xm4",
                "sortOrder": 0,
                "altText": "Sony WH-1000XM4 front view",
            }
        ],
        "location": "Thủ Đức, TP.HCM",
        "status": "ACTIVE",
        "tags": ["#sony", "#wh1000xm4"],
        "sellerId": {
            "_id": SAMPLE_SELLER_ID,
            "id": SAMPLE_SELLER_ID,
            "displayName": "Khoa Nguyễn",
            "avatarUrl": "https://example.com/avatar.jpg",
            "location": "Thủ Đức, TP.HCM",
            "university": "ĐH Bách Khoa TP.HCM",
            "isEmailVerified": True,
            "status": "ACTIVE",
            "email": "should-never-leak@remarket.vn",
            "phoneNumber": "+84909999999",
        },
        "categoryId": {
            "_id": SAMPLE_CATEGORY_ID,
            "id": SAMPLE_CATEGORY_ID,
            "name": "Đồ điện tử",
            "slug": "electronics",
            "icon": "devices",
        },
        "viewCount": 18,
        "createdAt": "2026-11-06T08:00:00.000Z",
        "updatedAt": "2026-11-06T08:30:00.000Z",
    }


def _make_mock_backend_client(
    handler: Any,
    *,
    max_retries: int = 1,
) -> BackendClient:
    settings = Settings(
        BACKEND_API_BASE_URL="http://backend.test/api/v1",
        BACKEND_SERVICE_TOKEN=SecretStr("internal-svc-secret-999"),
        BACKEND_TIMEOUT_SECONDS=5.0,
        BACKEND_MAX_RETRIES=max_retries,
    )
    transport = httpx.MockTransport(handler)
    http_client = httpx.AsyncClient(
        base_url=settings.BACKEND_API_BASE_URL,
        transport=transport,
    )
    return BackendClient(
        settings=settings,
        http_client=http_client,
        initial_backoff_seconds=0.01,
    )


# =====================================================================
# 1. Authentication Context & Security Boundary Tests
# =====================================================================


def test_verified_user_context_immutability_and_header_extraction() -> None:
    """Verify VerifiedUserContext is extracted from NestJS headers and is immutable."""
    headers = {
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
        "X-Authenticated-User-Id": SAMPLE_SELLER_ID,
        "X-Request-ID": "req-auth-test-001",
    }
    ctx = extract_auth_context_from_headers(headers)
    assert ctx.is_authenticated is True
    assert ctx.user_id == SAMPLE_SELLER_ID
    assert ctx.raw_bearer_token == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
    assert "eyJhbGci" not in repr(ctx)
    assert ctx.roles == ("user",)

    with pytest.raises(ValidationError):
        ctx.user_id = "672b3a9f8e1b2c0012345699"  # type: ignore[misc]

    with auth_context_scope(ctx):
        assert get_auth_context().user_id == SAMPLE_SELLER_ID
    assert get_auth_context().is_authenticated is False


def test_spoofed_auth_override_fields_rejected() -> None:
    """Ensure LLM tool inputs attempting to spoof user identity or tokens raise SecurityViolationError."""
    for forbidden_key in [
        "current_user_id",
        "acting_user_id",
        "bearer_token",
        "access_token",
        "is_admin",
        "role",
    ]:
        with pytest.raises(SecurityViolationError):
            assert_no_spoofed_auth_override({forbidden_key: "spoofed", "keyword": "laptop"})

        with pytest.raises(SecurityViolationError):
            SearchProductsInput.model_validate({forbidden_key: "spoofed", "keyword": "laptop"})


# =====================================================================
# 2. BackendClient HTTP, Retry, Timeout & Error Mapping Tests
# =====================================================================


@pytest.mark.asyncio
async def test_backend_client_propagates_auth_and_request_id_headers() -> None:
    """Verify BackendClient attaches X-Request-ID, Authorization, X-Authenticated-User-Id, and service token."""
    captured_headers: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured_headers.update(dict(request.headers))
        return httpx.Response(200, json={"success": True, "data": [], "meta": {}})

    client = _make_mock_backend_client(handler)
    set_request_id("req-trace-777")
    user_ctx = VerifiedUserContext(
        user_id=SAMPLE_SELLER_ID,
        bearer_token=SecretStr("jwt-user-token-abc"),
        roles=("user",),
        request_id="req-trace-777",
    )

    with auth_context_scope(user_ctx):
        await client.list_categories()

    assert captured_headers.get("x-request-id") == "req-trace-777"
    assert captured_headers.get("authorization") == "Bearer jwt-user-token-abc"
    assert captured_headers.get("x-authenticated-user-id") == SAMPLE_SELLER_ID
    assert captured_headers.get("x-internal-service-token") == "internal-svc-secret-999"


@pytest.mark.asyncio
async def test_backend_client_retries_transient_503_and_succeeds() -> None:
    """Verify BackendClient retries transient 503 responses and succeeds on retry."""
    attempts = 0

    def handler(_request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            return httpx.Response(
                503,
                json={"success": False, "statusCode": 503, "message": "Service busy"},
            )
        return httpx.Response(
            200,
            json={"success": True, "data": [_make_sample_product()], "meta": {"total": 1}},
        )

    client = _make_mock_backend_client(handler, max_retries=2)
    result = await client.list_products(keyword="Sony")
    assert attempts == 2
    assert len(result["data"]) == 1


@pytest.mark.asyncio
async def test_backend_client_error_mapping_and_no_retry_on_4xx() -> None:
    """Verify 400, 401, 403, 404, 503, and timeout errors map to domain exceptions."""
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        path = request.url.path
        if path.endswith("/400"):
            return httpx.Response(
                400,
                json={
                    "success": False,
                    "statusCode": 400,
                    "message": ["minPrice must not be less than 0"],
                    "error": {"code": "VALIDATION_ERROR", "details": ["minPrice must not be less than 0"]},
                },
            )
        if path.endswith("/401"):
            return httpx.Response(401, json={"message": "Unauthorized"})
        if path.endswith("/403"):
            return httpx.Response(403, json={"message": "Forbidden"})
        if path.endswith("/404"):
            return httpx.Response(404, json={"message": "Product listing not found"})
        if path.endswith("/timeout"):
            raise httpx.ReadTimeout("Read timed out")
        return httpx.Response(503, json={"message": "Down"})

    client = _make_mock_backend_client(handler, max_retries=1)

    with pytest.raises(BackendValidationError) as exc_400:
        await client.request("GET", "/400")
    assert "minPrice" in exc_400.value.message
    assert calls == 1  # No retry on 400

    with pytest.raises(BackendAuthenticationError):
        await client.request("GET", "/401")

    with pytest.raises(BackendForbiddenError):
        await client.request("GET", "/403")

    with pytest.raises(BackendNotFoundError):
        await client.request("GET", "/404")

    with pytest.raises(BackendTimeoutError):
        await client.request("GET", "/timeout")

    with pytest.raises(BackendUnavailableError):
        await client.request("GET", "/503")


@pytest.mark.asyncio
async def test_backend_client_blocks_write_methods() -> None:
    """Verify POST, PATCH, PUT, DELETE requests are blocked in Phase 2."""
    client = _make_mock_backend_client(lambda req: httpx.Response(200, json={}))
    for method in ["POST", "PATCH", "PUT", "DELETE"]:
        with pytest.raises(SecurityViolationError):
            await client.request(method, "/products")


# =====================================================================
# 3. Tool Input Validation Tests
# =====================================================================


def test_tool_input_schemas_validation() -> None:
    """Verify Pydantic input validation for all 6 tools."""
    # 1. search_products rejects empty keyword or excessive limit
    with pytest.raises(ValidationError):
        SearchProductsInput(keyword="   ")
    with pytest.raises(ValidationError):
        SearchProductsInput(keyword="laptop", limit=101)

    # 2. filter_products rejects min_price > max_price and invalid condition
    with pytest.raises(ValidationError):
        FilterProductsInput(min_price=5000000, max_price=1000000)
    with pytest.raises(ValidationError):
        FilterProductsInput(condition="BROKEN")  # type: ignore[arg-type]

    # 3. get_product_detail rejects invalid ObjectId
    with pytest.raises(ValidationError):
        GetProductDetailInput(product_id="not-an-object-id")

    # 4. get_related_products rejects invalid ObjectId or out-of-range ratio
    with pytest.raises(ValidationError):
        GetRelatedProductsInput(product_id="12345", limit=5)
    with pytest.raises(ValidationError):
        GetRelatedProductsInput(product_id=SAMPLE_PRODUCT_ID_1, price_tolerance_ratio=0.01)

    # 5. get_product_categories accepts None, 'root', or valid ObjectId, rejects invalid string
    assert GetProductCategoriesInput(parent_id="root").parent_id == "root"
    assert GetProductCategoriesInput(parent_id=SAMPLE_CATEGORY_ID).parent_id == SAMPLE_CATEGORY_ID
    with pytest.raises(ValidationError):
        GetProductCategoriesInput(parent_id="invalid-parent-slug")

    # 6. get_seller_public_profile rejects invalid ObjectId
    with pytest.raises(ValidationError):
        GetSellerPublicProfileInput(seller_id="bad-seller-id")


# =====================================================================
# 4. Product, Category & User Tools Execution Tests
# =====================================================================


@pytest.mark.asyncio
async def test_all_six_tools_with_mocked_backend() -> None:
    """Test each of the 6 tools against realistic NestJS Backend responses."""
    recorded_requests: list[tuple[str, str, dict[str, str]]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        params = dict(request.url.params)
        recorded_requests.append((request.method, path, params))

        if path == "/api/v1/products":
            # Simulate empty result when narrow price band is queried for related products fallback test
            if params.get("minPrice") == "9000000.0":
                return httpx.Response(
                    200,
                    json={
                        "success": True,
                        "data": [],
                        "meta": {"page": 1, "limit": 10, "total": 0, "totalPages": 1},
                    },
                )
            return httpx.Response(
                200,
                json={
                    "success": True,
                    "data": [
                        _make_sample_product(SAMPLE_PRODUCT_ID_1, "Sony WH-1000XM4", 4200000),
                        _make_sample_product(SAMPLE_PRODUCT_ID_2, "Marshall Major IV", 2100000),
                    ],
                    "meta": {
                        "page": int(params.get("page", 1)),
                        "limit": int(params.get("limit", 12)),
                        "total": 2,
                        "totalPages": 1,
                        "hasNextPage": False,
                        "hasPrevPage": False,
                    },
                },
            )

        if path == f"/api/v1/products/{SAMPLE_PRODUCT_ID_1}":
            return httpx.Response(
                200,
                json={
                    "success": True,
                    "data": _make_sample_product(SAMPLE_PRODUCT_ID_1, "Sony WH-1000XM4", 4200000),
                },
            )

        if path == "/api/v1/categories":
            return httpx.Response(
                200,
                json={
                    "success": True,
                    "data": [
                        {
                            "id": SAMPLE_CATEGORY_ID,
                            "name": "Đồ điện tử",
                            "slug": "electronics",
                            "description": "Tai nghe, loa, màn hình sinh viên.",
                            "icon": "devices",
                            "parentId": None,
                            "isActive": True,
                            "sortOrder": 1,
                        }
                    ],
                },
            )

        if path == f"/api/v1/users/{SAMPLE_SELLER_ID}":
            return httpx.Response(
                200,
                json={
                    "success": True,
                    "data": {
                        "id": SAMPLE_SELLER_ID,
                        "displayName": "Khoa Nguyễn",
                        "avatarUrl": "https://example.com/avatar.jpg",
                        "bio": "Sinh viên năm cuối Bách Khoa thanh lý đồ công nghệ.",
                        "location": "Thủ Đức, TP.HCM",
                        "university": "ĐH Bách Khoa TP.HCM",
                        "isEmailVerified": True,
                        "status": "ACTIVE",
                        "email": "private-email@remarket.vn",
                        "phoneNumber": "+84901234567",
                        "passwordHash": "$2b$10$secret",
                        "wishlist": [SAMPLE_PRODUCT_ID_1],
                        "stats": {
                            "activeListingsCount": 5,
                            "soldListingsCount": 3,
                            "rating": 4.9,
                            "transparencyRate": 98.0,
                        },
                    },
                },
            )

        return httpx.Response(404, json={"message": "Not found"})

    client = _make_mock_backend_client(handler)

    # Tool 1: search_products
    search_res = await search_products_async(keyword="Sony", page=1, limit=5, client=client)
    assert len(search_res["items"]) == 2
    assert search_res["meta"]["total"] == 2
    assert search_res["appliedFilters"]["keyword"] == "Sony"

    # Tool 2: filter_products (including non-ACTIVE status note)
    filter_res = await filter_products_async(
        category="electronics",
        min_price=1000000,
        max_price=5000000,
        condition="LIKE_NEW",  # type: ignore[arg-type]
        status="SOLD",  # type: ignore[arg-type]
        client=client,
    )
    assert len(filter_res["items"]) == 2
    assert filter_res["backendNote"] is not None
    assert "ACTIVE" in filter_res["backendNote"]

    # Tool 3: get_product_detail
    detail_res = await get_product_detail_async(SAMPLE_PRODUCT_ID_1, client=client)
    assert detail_res["id"] == SAMPLE_PRODUCT_ID_1
    assert detail_res["condition"] == "LIKE_NEW"
    assert detail_res["defectDisclosure"] == "Đệm tai còn êm, xước dăm rất nhẹ ở vỏ hộp."
    assert len(detail_res["images"]) == 1
    assert detail_res["price"] == 4200000
    # Ensure embedded seller object in product detail does not leak private email or phone
    seller_json = json.dumps(detail_res["seller"])
    assert "should-never-leak@remarket.vn" not in seller_json
    assert "+84909999999" not in seller_json

    # Tool 4: get_related_products (excludes reference product ID)
    related_res = await get_related_products_async(
        SAMPLE_PRODUCT_ID_1,
        limit=4,
        price_tolerance_ratio=0.5,
        client=client,
    )
    assert related_res["referenceProductId"] == SAMPLE_PRODUCT_ID_1
    assert related_res["totalRelated"] == 1
    assert related_res["items"][0]["id"] == SAMPLE_PRODUCT_ID_2

    # Tool 5: get_product_categories
    cat_res = await get_product_categories_async(parent_id="root", client=client)
    assert cat_res["total"] == 1
    assert cat_res["categories"][0]["slug"] == "electronics"

    # Tool 6: get_seller_public_profile (strictly strips private PII)
    profile_res = await get_seller_public_profile_async(SAMPLE_SELLER_ID, client=client)
    assert profile_res["id"] == SAMPLE_SELLER_ID
    assert profile_res["displayName"] == "Khoa Nguyễn"
    assert profile_res["university"] == "ĐH Bách Khoa TP.HCM"
    assert profile_res["stats"]["activeListingsCount"] == 5
    assert "email" not in profile_res
    assert "phoneNumber" not in profile_res
    assert "passwordHash" not in profile_res
    assert "wishlist" not in profile_res


def test_tool_registry_registers_six_tools_and_blocks_crud_tools() -> None:
    """Verify ToolRegistry contains all 6 tools, executes sync invoke, and blocks CRUD tools."""
    client = _make_mock_backend_client(
        lambda req: httpx.Response(200, json={"success": True, "data": [], "meta": {}})
    )
    registry = create_default_tool_registry(client=client)
    expected_names = [
        "search_products",
        "filter_products",
        "get_product_detail",
        "get_related_products",
        "get_product_categories",
        "get_seller_public_profile",
    ]
    assert registry.list_names() == expected_names
    assert len(registry.get_all()) == 6

    # Execute synchronous invocation via registry
    cat_out = registry.invoke_tool("get_product_categories", {"parent_id": "root"})
    assert cat_out["total"] == 0

    # Verify registering a mutation tool is blocked by SecurityViolationError
    from langchain_core.tools import StructuredTool

    forbidden_tool = StructuredTool.from_function(
        func=lambda title: title,
        name="create_product",
        description="Forbidden CRUD tool",
    )
    with pytest.raises(SecurityViolationError):
        registry.register(forbidden_tool)
