"""
Comprehensive Unit & FastAPI Endpoint Tests for Prompt 3:
ReMarket Multi-Agent System with LangGraph (`tests/test_multi_agent_system.py`).

Covers:
1. Agent 1 — Listing Generator (`listing_graph` & `POST /ai/generate-listing`)
2. Agent 2 — Smart Price Estimator (`pricing_graph` & `POST /ai/estimate-price`)
3. Agent 3 — Buyer Inspection Checklist (`inspection_graph` & `POST /ai/buyer-checklist`)
4. Agent 4 — Secondhand Shopping Assistant (`shopping_assistant_graph` & `POST /ai/chat`)
   including multi-turn memory ("laptop dưới 10 triệu" -> "Trong số đó, con nào đáng mua nhất?"),
   zero-match handling (never fabricates products), and RAG buying advice.
5. Supervisor Graph (`supervisor_graph` & `POST /ai/agent/execute`) intent classification & fallback.
6. Per-user Authentication Isolation & Conversation CRUD (`GET` / `DELETE /ai/conversations/{id}`).
7. Rate Limiting & Spoofed `user_id` Rejection.
"""

from pathlib import Path
from typing import Any
from fastapi.testclient import TestClient
import httpx
import pytest

from app.core.config import Settings
from app.main import create_app
from app.memory.checkpointer import CheckpointerManager, reset_checkpointer_manager
from app.rag.embeddings import normalize_vector
from app.rag.pipelines import RAGPipeline
from app.rag.vectorstores.memory_store import InMemoryVectorStore
from app.services.agent_service import (
    AgentApplicationService,
    InMemoryRateLimiter,
    reset_shared_rate_limiter,
)
from app.services.backend_client import BackendClient
from app.api.dependencies import get_agent_application_service


class DeterministicKeywordEmbeddingProvider:
    """Deterministic topic-based embedding provider for fast unit testing."""

    def __init__(self, dimensions: int = 16) -> None:
        self._dimensions = dimensions
        self._topic_keywords: list[tuple[str, ...]] = [
            ("like_new", "good", "fair", "new", "tình trạng", "condition", "phân loại", "95%"),
            ("an toàn", "đặt cọc", "lừa đảo", "chuyển khoản", "safety", "otp"),
            ("kiểm tra", "checklist", "màn hình", "pin", "icloud", "dead pixel", "anc"),
            ("chính sách", "quy định", "cấm", "defectdisclosure", "sold", "report", "báo cáo"),
            ("sinh viên", "thủ đức", "ký túc xá", "khuôn viên", "bách khoa", "hẹn gặp"),
            ("wishlist", "ai", "generate-listing", "estimate-price", "nền tảng", "sử dụng"),
        ]

    @property
    def model_name(self) -> str:
        return "mock-gemini-embedding-001"

    @property
    def dimensions(self) -> int:
        return self._dimensions

    def _encode_single(self, text: str) -> list[float]:
        lowered = text.lower()
        vec = [0.01] * self._dimensions
        for idx, keywords in enumerate(self._topic_keywords):
            hits = sum(1 for kw in keywords if kw in lowered)
            if hits > 0:
                vec[idx] += float(hits) * 2.5
        return normalize_vector(vec)

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        return [self._encode_single(t) for t in texts]

    def embed_query(self, text: str) -> list[float]:
        return self._encode_single(text)


USER_A_ID = "65f1a2b3c4d5e6f7a8b9c0d1"
USER_B_ID = "65f1a2b3c4d5e6f7a8b9c0d2"
PROD_DELL_ID = "65f000000000000000000101"
PROD_THINKPAD_ID = "65f000000000000000000102"
PROD_MACBOOK_ID = "65f000000000000000000103"


def _build_mock_backend_transport() -> httpx.MockTransport:
    """Create a deterministic MockTransport simulating NestJS Backend `/api/v1/products` endpoints."""
    catalog = [
        {
            "_id": PROD_THINKPAD_ID,
            "id": PROD_THINKPAD_ID,
            "title": "Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ",
            "brand": "Lenovo",
            "price": 8500000,
            "originalPrice": 18000000,
            "condition": "LIKE_NEW",
            "status": "ACTIVE",
            "defectDisclosure": "Trầy nhẹ góc nắp lưng, pin còn 91% dùng tốt 5 tiếng",
            "transparencyScore": 95,
            "location": "Thủ Đức, TP.HCM",
            "category": {"id": "65f000000000000000000010", "name": "Máy tính & Phụ kiện", "slug": "computers-accessories"},
            "description": "Máy dùng học lập trình sinh viên CNTT, chưa qua sửa chữa.",
            "images": [{"url": "https://cdn.remarket.vn/thinkpad-t14.jpg", "isPrimary": True}],
        },
        {
            "_id": PROD_DELL_ID,
            "id": PROD_DELL_ID,
            "title": "Laptop Dell Latitude 7400 dành cho sinh viên lập trình",
            "brand": "Dell",
            "price": 7200000,
            "originalPrice": 16500000,
            "condition": "GOOD",
            "status": "ACTIVE",
            "defectDisclosure": "Mòn nhẹ phím Space và xước dăm mặt đáy, pin 82%",
            "transparencyScore": 88,
            "location": "Quận 10, TP.HCM",
            "category": {"id": "65f000000000000000000010", "name": "Máy tính & Phụ kiện", "slug": "computers-accessories"},
            "description": "Laptop mỏng nhẹ phù hợp code web và học tập.",
            "images": [{"url": "https://cdn.remarket.vn/dell-7400.jpg", "isPrimary": True}],
        },
        {
            "_id": PROD_MACBOOK_ID,
            "id": PROD_MACBOOK_ID,
            "title": "MacBook Pro M2 16GB 512GB chính hãng",
            "brand": "Apple",
            "price": 24500000,
            "originalPrice": 32000000,
            "condition": "LIKE_NEW",
            "status": "ACTIVE",
            "defectDisclosure": "Không trầy xước, fullbox",
            "transparencyScore": 98,
            "location": "Quận 1, TP.HCM",
            "category": {"id": "65f000000000000000000010", "name": "Máy tính & Phụ kiện", "slug": "computers-accessories"},
            "description": "MacBook cấu hình cao.",
            "images": [{"url": "https://cdn.remarket.vn/mbp-m2.jpg", "isPrimary": True}],
        },
    ]

    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        params = dict(request.url.params)

        # GET /api/v1/products/:id
        for item in catalog:
            if path.endswith(f"/products/{item['id']}"):
                return httpx.Response(200, json={"data": item})

        # GET /api/v1/products
        if path.endswith("/products"):
            kw = (params.get("keyword") or "").lower().strip()
            max_price = float(params["maxPrice"]) if "maxPrice" in params else None
            results: list[dict[str, Any]] = []
            for item in catalog:
                if kw and kw not in f"{item['title']} {item['brand']} {item['description']}".lower():
                    continue
                if max_price is not None and float(item["price"]) > max_price:
                    continue
                results.append(item)

            return httpx.Response(
                200,
                json={
                    "data": results,
                    "meta": {
                        "total": len(results),
                        "page": 1,
                        "limit": 12,
                        "totalPages": 1,
                    },
                },
            )

        return httpx.Response(404, json={"message": "Not found"})

    return httpx.MockTransport(handler)


@pytest.fixture()
def test_env(
    monkeypatch: pytest.MonkeyPatch,
) -> tuple[TestClient, AgentApplicationService, CheckpointerManager]:
    """Provide a fully wired FastAPI TestClient with seeded RAG knowledge and Mock BackendClient."""
    monkeypatch.setenv("GEMINI_API_KEY", "")
    reset_checkpointer_manager()
    reset_shared_rate_limiter()

    settings = Settings(
        GEMINI_API_KEY="",
        VECTOR_STORE_TYPE="memory",
        CONVERSATION_MAX_HISTORY_MESSAGES=16,
        AI_RATE_LIMIT_REQUESTS=50,
        AI_RATE_LIMIT_WINDOW_SECONDS=60,
    )

    # Seed in-memory RAG pipeline with real ReMarket knowledge base markdown documents
    rag_pipeline = RAGPipeline(
        vector_store=InMemoryVectorStore(),
        embedding_provider=DeterministicKeywordEmbeddingProvider(dimensions=16),
        settings=settings,
    )
    kb_dir = Path(__file__).resolve().parents[1] / "data" / "knowledge_base"
    if kb_dir.exists():
        rag_pipeline.ingestion.ingest_directory(kb_dir)

    backend_client = BackendClient(
        settings=settings,
        http_client=httpx.AsyncClient(
            base_url=settings.BACKEND_API_BASE_URL,
            transport=_build_mock_backend_transport(),
        ),
    )
    checkpointer = CheckpointerManager(settings=settings)
    rate_limiter = InMemoryRateLimiter(max_requests=50, window_seconds=60.0)

    agent_service = AgentApplicationService(
        settings=settings,
        backend_client=backend_client,
        rag_pipeline=rag_pipeline,
        checkpointer_manager=checkpointer,
        rate_limiter=rate_limiter,
    )

    app = create_app(settings_override=settings)
    app.dependency_overrides[get_agent_application_service] = lambda: agent_service

    client = TestClient(app)
    return client, agent_service, checkpointer


# =====================================================================
# 1. AGENT 1 — LISTING GENERATOR TESTS
# =====================================================================


def test_agent1_listing_generator_preserves_defects_and_never_invents_brand(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    payload = {
        "productName": "Bàn phím cơ không dây Gateron Brown Switch",
        # Intentionally omit `brand` to verify Agent 1 never fabricates a brand
        "category": "Máy tính & Phụ kiện",
        "condition": "GOOD",
        "defects": "Trầy nhẹ góc phải khung nhôm và mất đầu thu USB 2.4GHz (chỉ dùng Bluetooth/dây)",
        "originalPrice": 1800000,
        "sellingPrice": 950000,
        "images": [
            "https://cdn.remarket.vn/kb-front.jpg",
            "https://cdn.remarket.vn/kb-back.jpg",
        ],
    }

    resp = client.post("/ai/generate-listing", json=payload)
    assert resp.status_code == 200, resp.text
    data = resp.json()

    # Exact structured output keys required by Prompt 3
    assert "suggestedTitle" in data and len(data["suggestedTitle"]) >= 5
    assert isinstance(data["suggestedDescription"], dict)
    assert set(data["suggestedDescription"].keys()) == {"overview", "condition", "defects"}
    assert data["suggestedCategory"] == "Máy tính & Phụ kiện"
    assert isinstance(data["suggestedTags"], list) and len(data["suggestedTags"]) >= 1
    assert "transparencyNote" in data

    # Must preserve seller-disclosed defects verbatim in description.defects and transparencyNote
    assert "mất đầu thu usb 2.4ghz" in data["suggestedDescription"]["defects"].lower()
    assert "mất đầu thu usb 2.4ghz" in data["transparencyNote"].lower()

    # Human-in-the-loop: never auto-publishes
    assert data["requiresSellerApproval"] is True
    assert data["needsMoreInfo"] is False


def test_agent1_listing_generator_requests_more_info_when_images_unclear(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    payload = {
        "productName": "Tai nghe chụp tai chống ồn",
        "condition": "FAIR",
        # Missing defects and blurry image URL
        "images": ["https://cdn.remarket.vn/photo_blurry_lowres.jpg"],
    }

    resp = client.post("/ai/generate-listing", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["needsMoreInfo"] is True
    assert len(data["clarificationQuestions"]) >= 2


# =====================================================================
# 2. AGENT 2 — SMART PRICE ESTIMATOR TESTS
# =====================================================================


def test_agent2_smart_price_estimator_with_backend_comparables(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    payload = {
        "productName": "Laptop Lenovo ThinkPad T14",
        "brand": "Lenovo",
        "category": "Máy tính & Phụ kiện",
        "condition": "GOOD",
        "defects": "Trầy nhẹ mặt lưng, pin còn 85%",
        "originalPrice": 18000000,
    }

    resp = client.post("/ai/estimate-price", json=payload)
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert data["currency"] == "VND"
    assert 0 < data["quickSellPrice"] <= data["recommendedPrice"] <= data["maxFairPrice"]
    assert data["comparableCount"] >= 1
    assert data["confidence"] == "HIGH"
    assert len(data["factors"]) >= 3
    assert "Backend ReMarket" in data["dataSourceNote"]
    assert data["requiresSellerDecision"] is True


def test_agent2_smart_price_estimator_without_comparables_discloses_ai_estimate(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    payload = {
        "productName": "Đàn Guitar Acoustic Yamaha F310",
        "brand": "Yamaha",
        "category": "Nhạc cụ",
        "condition": "FAIR",
        "defects": "Nứt nhẹ lớp sơn bóng cạnh thùng đàn",
        "originalPrice": 3500000,
    }

    resp = client.post("/ai/estimate-price", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["comparableCount"] == 0
    assert data["quickSellPrice"] <= data["recommendedPrice"] <= data["maxFairPrice"]
    # Must explicitly state there is no Backend comparable data and warn the seller
    assert "Không có dữ liệu sản phẩm tương đồng" in data["dataSourceNote"]
    assert len(data["warnings"]) >= 1


# =====================================================================
# 3. AGENT 3 — BUYER INSPECTION CHECKLIST TESTS
# =====================================================================


def test_agent3_buyer_inspection_checklist_fetches_product_and_rag(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    payload = {
        "productId": PROD_THINKPAD_ID,
    }

    resp = client.post("/ai/buyer-checklist", json=payload)
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert data["productId"] == PROD_THINKPAD_ID
    assert 3 <= len(data["inspectionPoints"]) <= 4
    assert len(data["suggestedQuestions"]) == 3
    assert len(data["safetyTips"]) >= 1
    assert data["advisoryOnly"] is True

    for point in data["inspectionPoints"]:
        assert point["importance"] in ("HIGH", "MEDIUM", "LOW")
        assert len(point["title"]) >= 3
        assert len(point["description"]) >= 10

    # Verify the real defect from Backend ("Trầy nhẹ góc nắp lưng, pin còn 91%") was incorporated
    combined_descriptions = " ".join(p["description"] for p in data["inspectionPoints"])
    assert "trầy nhẹ góc nắp lưng" in combined_descriptions.lower()


# =====================================================================
# 4. AGENT 4 — SECONDHAND SHOPPING ASSISTANT (MULTI-TURN & RAG) TESTS
# =====================================================================


def test_agent4_shopping_assistant_multi_turn_discovery_then_comparison(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    """
    Verify the exact multi-turn requirement from Prompt 3:
    Turn 1: 'Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu'
            -> Finds real laptops <= 10,000,000 VND with real IDs.
    Turn 2: 'Trong số đó, con nào đáng mua nhất?'
            -> Understands 'trong số đó' refers to Turn 1's matched products,
               compares them without asking the user to repeat their query,
               and recommends the best laptop.
    """
    client, _, _ = test_env
    headers = {"X-Authenticated-User-Id": USER_A_ID}
    thread_id = "conv-laptop-multi-turn-01"

    # Turn 1: Product Discovery
    turn1_resp = client.post(
        "/ai/chat",
        headers=headers,
        json={
            "message": "Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu",
            "thread_id": thread_id,
        },
    )
    assert turn1_resp.status_code == 200, turn1_resp.text
    t1 = turn1_resp.json()

    assert t1["thread_id"] == thread_id
    assert t1["intent"] == "PRODUCT_DISCOVERY"
    assert len(t1["matchedProducts"]) == 2  # ThinkPad (8.5M) and Dell (7.2M), excluding MacBook (24.5M)
    matched_ids_t1 = {p["id"] for p in t1["matchedProducts"]}
    assert matched_ids_t1 == {PROD_THINKPAD_ID, PROD_DELL_ID}
    for prod in t1["matchedProducts"]:
        assert prod["price"] <= 10_000_000

    # Turn 2: Product Comparison referencing Turn 1 ("Trong số đó, con nào đáng mua nhất?")
    turn2_resp = client.post(
        "/ai/chat",
        headers=headers,
        json={
            "message": "Trong số đó, con nào đáng mua nhất?",
            "thread_id": thread_id,
        },
    )
    assert turn2_resp.status_code == 200, turn2_resp.text
    t2 = turn2_resp.json()

    assert t2["thread_id"] == thread_id
    assert t2["intent"] == "PRODUCT_COMPARISON"
    assert len(t2["matchedProducts"]) == 2
    assert "Đáng mua nhất" in t2["message"]
    assert "Lenovo ThinkPad T14" in t2["message"]
    assert "Dell Latitude 7400" in t2["message"]


def test_agent4_shopping_assistant_no_products_found_never_fabricates(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    resp = client.post(
        "/ai/chat",
        json={
            "message": "Tôi muốn mua máy ảnh Sony Alpha dưới 1 triệu",
        },
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["intent"] == "PRODUCT_DISCOVERY"
    assert data["matchedProducts"] == []
    assert "chưa tìm thấy" in data["message"].lower()
    assert "mở rộng" in data["message"].lower()


def test_agent4_shopping_assistant_buying_advice_branch_uses_rag(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    resp = client.post(
        "/ai/chat",
        json={
            "message": "Kinh nghiệm kiểm tra đồ điện tử và lưu ý an toàn tránh lừa đảo đặt cọc?",
        },
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["intent"] == "BUYING_ADVICE"
    assert data["matchedProducts"] == []
    assert len(data["sources"]) >= 1
    assert "đặt cọc" in data["message"].lower()


def test_agent4_focused_product_advice_then_similar_products_comparison(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    """
    Verify when a user clicks 'Hỏi thêm AI' on a specific product (Turn 1 -> BUYING_ADVICE)
    and then asks 'hãy đưa ra những sản phẩm tương tự và so sánh' (Turn 2 -> PRODUCT_COMPARISON),
    the AI remembers the focused product, discovers similar products from the catalog,
    and compares them directly.
    """
    client, _, _ = test_env
    headers = {"X-Authenticated-User-Id": USER_A_ID}
    thread_id = "conv-focused-product-compare-01"

    focused_msg_t1 = (
        f'[Ngữ cảnh sản phẩm người dùng đang xem: Tên="Laptop Lenovo ThinkPad T14 Gen 1", '
        f'ID="{PROD_THINKPAD_ID}", Giá=8500000 VNĐ, Giá gốc=18000000, '
        f'Tình trạng=GOOD, Danh mục="Máy tính & Phụ kiện", SlugDanhMuc="computers-accessories", '
        f'Khuyết điểm công khai="Trầy nhẹ góc nắp lưng, pin còn 91%", '
        f'Mô tả="ThinkPad T14 i5 16GB 512GB"]\n'
        f'Câu hỏi của người mua: Tư vấn giúp mình sản phẩm "Laptop Lenovo ThinkPad T14 Gen 1" xem có đáng mua không và cần lưu ý gì?'
    )
    r1 = client.post(
        "/ai/chat",
        headers=headers,
        json={"message": focused_msg_t1, "thread_id": thread_id},
    )
    assert r1.status_code == 200, r1.text
    d1 = r1.json()
    assert d1["intent"] == "BUYING_ADVICE"

    # Turn 2: Ask for similar products and comparison
    focused_msg_t2 = (
        f'[Ngữ cảnh sản phẩm người dùng đang xem: Tên="Laptop Lenovo ThinkPad T14 Gen 1", '
        f'ID="{PROD_THINKPAD_ID}", Giá=8500000 VNĐ, Giá gốc=18000000, '
        f'Tình trạng=GOOD, Danh mục="Máy tính & Phụ kiện", SlugDanhMuc="computers-accessories", '
        f'Khuyết điểm công khai="Trầy nhẹ góc nắp lưng, pin còn 91%", '
        f'Mô tả="ThinkPad T14 i5 16GB 512GB"]\n'
        f"Câu hỏi của người mua: hãy đưa ra những sản phẩm tương tự và so sánh"
    )
    r2 = client.post(
        "/ai/chat",
        headers=headers,
        json={"message": focused_msg_t2, "thread_id": thread_id},
    )
    assert r2.status_code == 200, r2.text
    d2 = r2.json()
    assert d2["intent"] == "PRODUCT_COMPARISON"
    assert len(d2["matchedProducts"]) >= 2
    assert "Đáng mua nhất" in d2["message"]
    assert "Lenovo ThinkPad T14" in d2["message"]
    assert "Dell Latitude 7400" in d2["message"]


# =====================================================================
# 5. SUPERVISOR GRAPH ROUTING TESTS
# =====================================================================


def test_supervisor_graph_intent_classification_and_routing(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env

    # 1. Route to GENERATE_LISTING
    r_listing = client.post(
        "/ai/agent/execute",
        json={
            "message": "Hãy tạo tin đăng bán sản phẩm này giúp tôi",
            "payload": {
                "productName": "Chuột Logitech MX Master 3",
                "condition": "LIKE_NEW",
                "defects": "Bóng nhẹ phần kê ngón cái",
            },
        },
    )
    assert r_listing.status_code == 200
    d_listing = r_listing.json()
    assert d_listing["intent"] == "GENERATE_LISTING"
    assert d_listing["targetGraph"] == "listing_graph"
    assert d_listing["fallbackUsed"] is False
    assert "suggestedTitle" in d_listing["data"]

    # 2. Route to ESTIMATE_PRICE
    r_price = client.post(
        "/ai/agent/execute",
        json={
            "message": "Nhờ AI định giá bán hợp lý cho laptop này",
            "payload": {
                "productName": "Laptop Lenovo ThinkPad T14",
                "condition": "LIKE_NEW",
                "originalPrice": 18000000,
            },
        },
    )
    assert r_price.status_code == 200
    d_price = r_price.json()
    assert d_price["intent"] == "ESTIMATE_PRICE"
    assert d_price["targetGraph"] == "pricing_graph"
    assert d_price["data"]["recommendedPrice"] > 0

    # 3. Route to BUYER_INSPECTION
    r_insp = client.post(
        "/ai/agent/execute",
        json={
            "message": "Tạo danh sách kiểm tra trước khi mua sản phẩm này",
            "payload": {"productId": PROD_DELL_ID},
        },
    )
    assert r_insp.status_code == 200
    d_insp = r_insp.json()
    assert d_insp["intent"] == "BUYER_INSPECTION"
    assert d_insp["targetGraph"] == "inspection_graph"
    assert len(d_insp["data"]["inspectionPoints"]) >= 3

    # 4. Route to GENERAL fallback when intent is ambiguous
    r_gen = client.post(
        "/ai/agent/execute",
        json={"message": "Xin chào bạn!"},
    )
    assert r_gen.status_code == 200
    d_gen = r_gen.json()
    assert d_gen["intent"] == "GENERAL"
    assert d_gen["fallbackUsed"] is True


# =====================================================================
# 6. AUTHENTICATION ISOLATION & CONVERSATION ENDPOINTS TESTS
# =====================================================================


def test_conversation_auth_isolation_and_crud(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    conv_id = "conv-private-user-a"

    # User A creates a conversation turn
    r_chat = client.post(
        "/ai/chat",
        headers={"X-Authenticated-User-Id": USER_A_ID},
        json={
            "message": "Tôi muốn mua laptop cũ dưới 10 triệu",
            "thread_id": conv_id,
        },
    )
    assert r_chat.status_code == 200

    # User A can inspect their conversation history
    r_get_a = client.get(
        f"/ai/conversations/{conv_id}",
        headers={"X-Authenticated-User-Id": USER_A_ID},
    )
    assert r_get_a.status_code == 200
    hist = r_get_a.json()
    assert hist["conversation_id"] == conv_id
    assert hist["owner_user_id"] == USER_A_ID
    assert len(hist["turns"]) == 2

    # User B is strictly blocked from reading User A's conversation (403 Forbidden)
    r_get_b = client.get(
        f"/ai/conversations/{conv_id}",
        headers={"X-Authenticated-User-Id": USER_B_ID},
    )
    assert r_get_b.status_code == 403
    assert r_get_b.json()["error"]["code"] == "SECURITY_VIOLATION"

    # User B is strictly blocked from hijacking User A's thread_id in POST /ai/chat
    r_hijack = client.post(
        "/ai/chat",
        headers={"X-Authenticated-User-Id": USER_B_ID},
        json={"message": "Trong số đó, con nào đáng mua nhất?", "thread_id": conv_id},
    )
    assert r_hijack.status_code == 403

    # User B is strictly blocked from deleting User A's conversation
    r_del_b = client.delete(
        f"/ai/conversations/{conv_id}",
        headers={"X-Authenticated-User-Id": USER_B_ID},
    )
    assert r_del_b.status_code == 403

    # User A can delete their own conversation
    r_del_a = client.delete(
        f"/ai/conversations/{conv_id}",
        headers={"X-Authenticated-User-Id": USER_A_ID},
    )
    assert r_del_a.status_code == 200
    assert r_del_a.json()["deleted"] is True

    # Subsequent GET returns 404 Not Found
    r_after = client.get(
        f"/ai/conversations/{conv_id}",
        headers={"X-Authenticated-User-Id": USER_A_ID},
    )
    assert r_after.status_code == 404


def test_spoofed_user_id_in_request_body_is_rejected(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, _, _ = test_env
    resp = client.post(
        "/ai/chat",
        json={
            "message": "Tìm laptop dưới 10 triệu",
            "user_id": USER_A_ID,
        },
    )
    assert resp.status_code == 422


def test_rate_limiter_enforces_request_cap(
    test_env: tuple[TestClient, AgentApplicationService, CheckpointerManager],
) -> None:
    client, service, _ = test_env
    # Replace rate limiter with a 2-request cap for this test
    service._rate_limiter = InMemoryRateLimiter(max_requests=2, window_seconds=60.0)

    headers = {"X-Authenticated-User-Id": USER_A_ID}
    for _ in range(2):
        ok_resp = client.post(
            "/ai/chat",
            headers=headers,
            json={"message": "Xin chào"},
        )
        assert ok_resp.status_code == 200

    blocked_resp = client.post(
        "/ai/chat",
        headers=headers,
        json={"message": "Xin chào lần 3"},
    )
    assert blocked_resp.status_code == 429
    assert blocked_resp.json()["error"]["code"] == "AI_RATE_LIMIT_EXCEEDED"


# =====================================================================
# 8. GEMINI TIMEOUT, API ERROR & INVALID DATA RESILIENCE TESTS
# =====================================================================


@pytest.mark.asyncio
async def test_agents_resilience_when_gemini_times_out_or_fails() -> None:
    """
    Verify all 4 LangGraph workflows gracefully handle Gemini timeouts and
    upstream API errors (429 / 500) by falling back to deterministic validated outputs.
    """
    import asyncio
    from langchain_core.messages import AIMessage
    from app.graphs.listing_graph import compile_listing_graph
    from app.graphs.pricing_graph import compile_pricing_graph
    from app.graphs.inspection_graph import compile_inspection_graph
    from app.graphs.shopping_assistant_graph import compile_shopping_assistant_graph

    class TimeoutMockLLM:
        model = "gemini-3.8-flash-timeout-test"

        async def ainvoke(self, *_args: Any, **_kwargs: Any) -> AIMessage:
            await asyncio.sleep(0.25)
            return AIMessage(content="{}")

    class QuotaErrorLLM:
        model = "gemini-3.8-flash-error-test"

        async def ainvoke(self, *_args: Any, **_kwargs: Any) -> AIMessage:
            raise RuntimeError("429 RESOURCE_EXHAUSTED: Gemini API quota exceeded")

    fast_timeout_settings = Settings(
        GEMINI_API_KEY="",
        GEMINI_TIMEOUT_SECONDS=0.05,
        GEMINI_MAX_RETRIES=0,
        VECTOR_STORE_TYPE="memory",
    )
    backend_client = BackendClient(
        settings=fast_timeout_settings,
        http_client=httpx.AsyncClient(
            base_url=fast_timeout_settings.BACKEND_API_BASE_URL,
            transport=_build_mock_backend_transport(),
        ),
    )

    # 1. Listing Graph with TimeoutMockLLM
    g_listing = compile_listing_graph(
        llm=TimeoutMockLLM(),  # type: ignore[arg-type]
        settings=fast_timeout_settings,
    )
    res_listing = await g_listing.ainvoke(
        {
            "request_data": {
                "productName": "Bàn phím Keychron K2",
                "condition": "GOOD",
                "defects": "Mòn nhẹ keycap phím A",
            }
        }
    )
    assert "mòn nhẹ keycap phím a" in res_listing["validated_output"]["suggestedDescription"]["defects"].lower()

    # 2. Pricing Graph with QuotaErrorLLM
    g_pricing = compile_pricing_graph(
        llm=QuotaErrorLLM(),  # type: ignore[arg-type]
        backend_client=backend_client,
        settings=fast_timeout_settings,
    )
    res_pricing = await g_pricing.ainvoke(
        {
            "request_data": {
                "productName": "Laptop Lenovo ThinkPad T14",
                "condition": "LIKE_NEW",
                "originalPrice": 18000000,
            }
        }
    )
    p_out = res_pricing["validated_output"]
    assert 0 < p_out["quickSellPrice"] <= p_out["recommendedPrice"] <= p_out["maxFairPrice"]

    # 3. Inspection Graph with TimeoutMockLLM
    g_insp = compile_inspection_graph(
        llm=TimeoutMockLLM(),  # type: ignore[arg-type]
        backend_client=backend_client,
        settings=fast_timeout_settings,
    )
    res_insp = await g_insp.ainvoke(
        {"request_data": {"productId": PROD_THINKPAD_ID}}
    )
    assert len(res_insp["validated_output"]["inspectionPoints"]) >= 3

    # 4. Shopping Assistant Graph with QuotaErrorLLM
    g_chat = compile_shopping_assistant_graph(
        llm=QuotaErrorLLM(),  # type: ignore[arg-type]
        backend_client=backend_client,
        settings=fast_timeout_settings,
    )
    res_chat = await g_chat.ainvoke(
        {
            "request_data": {"message": "Tìm laptop dưới 10 triệu"},
            "thread_id": "conv-resilience-test",
            "user_id": USER_A_ID,
        }
    )
    assert len(res_chat["validated_output"]["matchedProducts"]) == 2


@pytest.mark.asyncio
async def test_agents_validate_and_repair_malformed_llm_outputs() -> None:
    """
    Verify output validation nodes repair invalid LLM JSON (e.g., inverted price tiers
    or missing defect disclosures) and never emit invalid schemas.
    """
    from langchain_core.messages import AIMessage
    from app.graphs.listing_graph import compile_listing_graph
    from app.graphs.pricing_graph import compile_pricing_graph

    class MalformedOutputLLM:
        model = "gemini-3.8-flash-malformed-test"

        async def ainvoke(self, *_args: Any, **_kwargs: Any) -> AIMessage:
            # Returns inverted prices (quickSellPrice > maxFairPrice) and omits seller defect
            return AIMessage(
                content='{"quickSellPrice": 15000000, "recommendedPrice": 9000000, "maxFairPrice": 5000000, '
                '"suggestedTitle": "Tai nghe Sony", "suggestedDescription": {"overview": "Tốt", "condition": "GOOD", "defects": "Không lỗi"}, '
                '"suggestedCategory": "Đồ điện tử", "suggestedTags": ["sony"], "transparencyNote": "Tốt"}'
            )

    settings = Settings(GEMINI_API_KEY="", VECTOR_STORE_TYPE="memory")
    backend_client = BackendClient(
        settings=settings,
        http_client=httpx.AsyncClient(
            base_url=settings.BACKEND_API_BASE_URL,
            transport=_build_mock_backend_transport(),
        ),
    )

    # Listing graph must re-inject the seller's real defect even if LLM output omitted it
    g_listing = compile_listing_graph(
        llm=MalformedOutputLLM(),  # type: ignore[arg-type]
        settings=settings,
    )
    out_listing = await g_listing.ainvoke(
        {
            "request_data": {
                "productName": "Tai nghe Sony XM4",
                "condition": "GOOD",
                "defects": "Rách nhẹ đệm tai bên phải",
            }
        }
    )
    assert "rách nhẹ đệm tai bên phải" in out_listing["validated_output"]["suggestedDescription"]["defects"].lower()

    # Pricing graph must sort/repair inverted price tiers so quickSellPrice <= recommendedPrice <= maxFairPrice
    g_pricing = compile_pricing_graph(
        llm=MalformedOutputLLM(),  # type: ignore[arg-type]
        backend_client=backend_client,
        settings=settings,
    )
    out_pricing = await g_pricing.ainvoke(
        {
            "request_data": {
                "productName": "Laptop Dell Latitude 7400",
                "condition": "GOOD",
                "originalPrice": 16500000,
            }
        }
    )
    vp = out_pricing["validated_output"]
    assert vp["quickSellPrice"] <= vp["recommendedPrice"] <= vp["maxFairPrice"]

