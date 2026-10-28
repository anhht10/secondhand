"""
Agent 4 — Secondhand Shopping Assistant LangGraph (`app.graphs.shopping_assistant_graph`).

Multi-turn stateful graph with 4 specialized branches:
START
  -> load_conversation_context
  -> analyze_user_intent
  -> decide_next_action
      ├── Branch A (PRODUCT_DISCOVERY):
      │     search_products_node -> filter_products_node -> rank_results_node -> generate_recommendation_node
      ├── Branch B (PRODUCT_COMPARISON):
      │     get_product_details_node -> compare_products_node -> generate_comparison_node
      ├── Branch C (BUYING_ADVICE):
      │     rag_retrieval_node -> analyze_context_node -> generate_advice_node
      └── Branch D (GENERAL_CONVERSATION):
            general_llm_response_node
  -> validate_response
  -> save_conversation_state
  -> END
"""

import logging
import re
from typing import Any, Optional
from uuid import uuid4

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langgraph.graph import END, START, StateGraph
from langgraph.graph.state import CompiledStateGraph

from app.core.auth_context import get_auth_context
from app.core.config import Settings, get_settings
from app.core.logging import get_request_id
from app.core.observability import extract_token_usage, trace_graph_node
from app.llm.gemini import (
    GeminiModelFactory,
    get_gemini_factory,
    invoke_llm_with_resilience,
)
from app.memory.checkpointer import (
    CheckpointerManager,
    get_checkpointer_manager,
    trim_conversation_messages,
)
from app.rag.pipelines import RAGPipeline
from app.rag.schemas import RAGSourceAttribution
from app.schemas.agents import (
    MatchedProductCard,
    ShoppingAssistantIntentEnum,
    ShoppingChatRequest,
    ShoppingChatResponse,
)
from app.services.backend_client import BackendClient, get_backend_client
from app.states.agent_states import ShoppingAssistantGraphState
from app.tools.base import OBJECT_ID_REGEX, ProductConditionEnum
from app.tools.product_tools import (
    filter_products_async,
    get_product_detail_async,
    get_related_products_async,
    search_products_async,
)

logger = logging.getLogger("remarket.ai.graphs.shopping_assistant")

_CONDITION_SCORE: dict[str, float] = {
    "NEW": 1.0,
    "LIKE_NEW": 0.9,
    "GOOD": 0.78,
    "FAIR": 0.62,
}

_CATEGORY_NAME_TO_SLUG: dict[str, str] = {
    "đồ điện tử": "electronics",
    "điện tử": "electronics",
    "electronics": "electronics",
    "máy tính & phụ kiện": "computers-accessories",
    "máy tính": "computers-accessories",
    "phụ kiện máy tính": "computers-accessories",
    "computers-accessories": "computers-accessories",
    "điện thoại & máy tính bảng": "phones-tablets",
    "điện thoại": "phones-tablets",
    "máy tính bảng": "phones-tablets",
    "phones-tablets": "phones-tablets",
    "đồ gia dụng & nội thất": "home-living",
    "gia dụng": "home-living",
    "nội thất": "home-living",
    "home-living": "home-living",
    "sách & giáo trình": "books",
    "sách": "books",
    "giáo trình": "books",
    "books": "books",
    "thời trang & phụ kiện": "fashion",
    "thời trang": "fashion",
    "fashion": "fashion",
    "thể thao & sở thích": "sports-hobbies",
    "thể thao": "sports-hobbies",
    "sports-hobbies": "sports-hobbies",
}


def _normalize_category_slug(raw_category: str | None) -> str | None:
    if not raw_category:
        return None
    cleaned = raw_category.strip()
    if not cleaned:
        return None
    lowered = cleaned.lower()
    if lowered in _CATEGORY_NAME_TO_SLUG:
        return _CATEGORY_NAME_TO_SLUG[lowered]
    for k, slug in _CATEGORY_NAME_TO_SLUG.items():
        if k in lowered:
            return slug
    return cleaned


def _parse_focused_product_context(
    raw_message: str,
) -> tuple[dict[str, Any] | None, str]:
    """
    Extract embedded `[Ngữ cảnh sản phẩm người dùng đang xem: ...]` header (if present)
    and return `(focused_product_dict, clean_user_question)`.
    """
    text = (raw_message or "").strip()
    marker = "Câu hỏi của người mua:"
    if not text.startswith("[Ngữ cảnh sản phẩm") or marker not in text:
        return None, text

    header_part, question_part = text.split(marker, 1)
    clean_question = question_part.strip() or text

    def _extract_attr(pattern: str) -> str:
        m = re.search(pattern, header_part)
        return m.group(1).strip() if m else ""

    title = _extract_attr(r'Tên="([^"]*)"')
    prod_id = _extract_attr(r'ID="([^"]*)"')
    price_str = _extract_attr(r"Giá=(\d+)")
    orig_price_str = _extract_attr(r"Giá gốc=(\d+)")
    cond_raw = _extract_attr(r"Tình trạng=([^,\]]+)")
    cat_name = _extract_attr(r'Danh mục="([^"]*)"')
    cat_slug = _extract_attr(r'SlugDanhMuc="([^"]*)"')
    cat_id = _extract_attr(r'CategoryId="([^"]*)"')
    defects = _extract_attr(r'Khuyết điểm công khai="([^"]*)"')
    desc = _extract_attr(r'Mô tả="([^"]*)"')

    cond_code = "GOOD"
    for candidate_cond in ("LIKE_NEW", "NEW", "GOOD", "FAIR"):
        if candidate_cond in cond_raw.upper():
            cond_code = candidate_cond
            break

    try:
        price_val = float(price_str) if price_str else 0.0
    except ValueError:
        price_val = 0.0

    orig_val: float | None = None
    if orig_price_str:
        try:
            parsed_orig = float(orig_price_str)
            if parsed_orig > 0:
                orig_val = parsed_orig
        except ValueError:
            orig_val = None

    resolved_slug = _normalize_category_slug(cat_slug or cat_name)
    if not title and not prod_id:
        return None, clean_question

    focused_dict: dict[str, Any] = {
        "id": prod_id or "focused-item",
        "_id": prod_id or "focused-item",
        "sellerId": "",
        "categoryId": cat_id or "",
        "title": title or "Sản phẩm đang xem",
        "description": desc,
        "price": price_val,
        "originalPrice": orig_val,
        "brand": None,
        "condition": cond_code,
        "defectDisclosure": defects if defects and defects != "Không có lỗi" else None,
        "transparencyScore": 92.0,
        "location": "",
        "status": "ACTIVE",
        "category": resolved_slug or cat_name or None,
        "categoryName": cat_name or None,
        "images": [],
    }
    return focused_dict, clean_question


def _parse_budget_from_text(text: str) -> float | None:
    """Extract VND budget from Vietnamese expressions like 'dưới 10 triệu', '15tr', '8.5 triệu', '500k'."""
    lowered = text.lower()
    m_tr = re.search(
        r"(\d+(?:[.,]\d+)?)\s*(?:triệu|trieu|tr|củ)\b",
        lowered,
    )
    if m_tr:
        val = float(m_tr.group(1).replace(",", "."))
        return val * 1_000_000.0

    m_k = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:nghìn|ngàn|nghin|k)\b", lowered)
    if m_k:
        val = float(m_k.group(1).replace(",", "."))
        return val * 1_000.0

    return None


def _extract_search_keyword(text: str, fallback_keyword: str = "") -> str:
    """Extract concise product search keyword from a Vietnamese shopping query."""
    lowered = text.lower()
    product_keywords = [
        ("macbook", "macbook"),
        ("thinkpad", "thinkpad"),
        ("laptop", "laptop"),
        ("máy tính xách tay", "laptop"),
        ("iphone", "iphone"),
        ("ipad", "ipad"),
        ("samsung", "samsung"),
        ("điện thoại", "điện thoại"),
        ("tai nghe", "tai nghe"),
        ("airpods", "airpods"),
        ("sony", "sony"),
        ("màn hình", "màn hình"),
        ("dell", "dell"),
        ("máy ảnh", "máy ảnh"),
        ("bàn phím", "bàn phím"),
        ("keychron", "bàn phím"),
        ("akko", "bàn phím"),
        ("chuột", "chuột"),
        ("logitech", "chuột"),
        ("giá đỡ", "giá đỡ"),
        ("hyperwork", "giá đỡ"),
        ("đèn bàn", "đèn bàn"),
        ("đèn", "đèn"),
        ("ghế", "ghế"),
        ("bàn học", "bàn học"),
        ("bàn", "bàn"),
        ("tủ", "tủ"),
        ("giáo trình", "giáo trình"),
        ("máy đọc sách", "kindle"),
        ("kindle", "kindle"),
        ("sách", "sách"),
        ("casio", "casio"),
        ("đồng hồ", "đồng hồ"),
        ("balo", "balo"),
        ("tomtoc", "balo"),
        ("giày", "giày"),
    ]
    for pattern, canonical in product_keywords:
        if pattern in lowered:
            return canonical

    return fallback_keyword


def _extract_preferences(
    message: str,
    existing_prefs: dict[str, Any],
    req: ShoppingChatRequest,
) -> dict[str, Any]:
    """Merge user preferences across turns so the user never has to repeat themselves."""
    merged = dict(existing_prefs or {})

    parsed_budget = _parse_budget_from_text(message)
    if req.maxBudget is not None:
        merged["max_budget"] = float(req.maxBudget)
    elif parsed_budget is not None:
        merged["max_budget"] = parsed_budget

    extracted_kw = _extract_search_keyword(message, merged.get("keyword", ""))
    if extracted_kw:
        merged["keyword"] = extracted_kw

    norm_cat = _normalize_category_slug(req.category)
    if norm_cat:
        merged["category"] = norm_cat
    elif extracted_kw and not merged.get("category"):
        merged["category"] = extracted_kw

    if req.condition:
        merged["condition"] = req.condition.strip().upper()
    else:
        lowered = message.lower()
        if "như mới" in lowered or "like new" in lowered:
            merged["condition"] = "LIKE_NEW"
        elif "mới 100" in lowered:
            merged["condition"] = "NEW"

    if req.location:
        merged["location"] = req.location.strip()

    if any(
        w in message.lower()
        for w in ("lập trình", "code", "sinh viên", "văn phòng", "đồ họa", "gaming")
    ):
        for purpose in ("lập trình", "sinh viên", "văn phòng", "đồ họa", "gaming"):
            if purpose in message.lower():
                merged["use_case"] = purpose
                break

    return merged


def _classify_shopping_intent(
    message: str,
    last_matched_products: list[dict[str, Any]],
    req: ShoppingChatRequest,
) -> str:
    """Classify the user's message into one of the 4 Shopping Assistant branches."""
    lowered = message.lower().strip()

    # 1. Check comparison intent (especially referencing previous turn's products or asking to compare similar items)
    comparison_cues = (
        "trong số đó",
        "trong các mẫu",
        "trong mấy con",
        "con nào",
        "cái nào",
        "mẫu nào",
        "chiếc nào",
        "đáng mua nhất",
        "tốt nhất",
        "tốt hơn",
        "so sánh",
        "nên chọn",
        "nên mua con nào",
        "chọn máy nào",
        "compare",
        "giữa hai",
        "giữa các",
    )
    if any(cue in lowered for cue in comparison_cues):
        if last_matched_products or "so sánh" in lowered or "đáng mua nhất" in lowered:
            return ShoppingAssistantIntentEnum.PRODUCT_COMPARISON.value

    # 2. Check buying advice / inspection / policy / safety intent
    advice_cues = (
        "kiểm tra",
        "cách test",
        "kinh nghiệm mua",
        "lưu ý gì",
        "cần lưu ý",
        "chính sách",
        "quy định",
        "an toàn",
        "lừa đảo",
        "đặt cọc",
        "bảo hành",
        "hoàn tiền",
        "tranh chấp",
        "tư vấn cách",
        "có đáng mua không",
    )
    discovery_cues = (
        "mua",
        "tìm",
        "ngân sách",
        "dưới ",
        "triệu",
        "laptop",
        "macbook",
        "iphone",
        "điện thoại",
        "ipad",
        "tai nghe",
        "màn hình",
        "bàn phím",
        "chuột",
        "ghế",
        "bàn",
        "sách",
        "giáo trình",
        "balo",
        "đèn",
        "sản phẩm nào",
        "có mẫu nào",
        "gợi ý",
        "tương tự",
        "cùng loại",
        "cùng phân khúc",
        "sản phẩm khác",
        "mẫu khác",
    )
    if any(cue in lowered for cue in advice_cues) and not any(
        k in lowered
        for k in ("mua laptop", "tìm mua", "ngân sách", "dưới ", "tương tự", "so sánh")
    ):
        return ShoppingAssistantIntentEnum.BUYING_ADVICE.value

    # 3. Check casual / general conversation first if no explicit product keyword or shopping action is in the message
    casual_cues = (
        "chơi game",
        "game gì",
        "game j",
        "ăn gì",
        "ăn j",
        "chào",
        "hello",
        "hi ",
        "bạn là ai",
        "bạn tên gì",
        "làm được gì",
        "hôm nay",
        "buồn quá",
        "vui quá",
        "kể chuyện",
        "tâm sự",
    )
    has_product_kw = bool(_extract_search_keyword(lowered, ""))
    if any(c in lowered for c in casual_cues) and not has_product_kw and "mua" not in lowered and "tìm" not in lowered:
        return ShoppingAssistantIntentEnum.GENERAL_CONVERSATION.value

    # 4. Check product discovery intent
    if (
        any(cue in lowered for cue in discovery_cues)
        or has_product_kw
        or _parse_budget_from_text(lowered) is not None
        or bool(req.catalogContext)
    ):
        return ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY.value

    # 5. General conversation
    return ShoppingAssistantIntentEnum.GENERAL_CONVERSATION.value


def _normalize_candidate_product(raw: dict[str, Any]) -> dict[str, Any] | None:
    """Normalize a product dictionary from Tools or catalogContext, requiring a real ID and ACTIVE status."""
    if not isinstance(raw, dict):
        return None
    prod_id = str(raw.get("id") or raw.get("_id") or "").strip()
    if not prod_id:
        return None
    status_val = str(raw.get("status") or "ACTIVE").strip().upper()
    if status_val and status_val != "ACTIVE":
        return None
    title = str(raw.get("title") or raw.get("productName") or "").strip()
    if not title:
        return None
    try:
        price = float(raw.get("price") or 0.0)
    except (TypeError, ValueError):
        price = 0.0

    orig_raw = raw.get("originalPrice")
    orig_price: float | None = None
    if orig_raw is not None:
        try:
            orig_price = float(orig_raw)
        except (TypeError, ValueError):
            orig_price = None

    raw_seller = raw.get("sellerId")
    if isinstance(raw_seller, dict):
        seller_id = str(raw_seller.get("id") or raw_seller.get("_id") or "")
    else:
        seller_id = str(raw_seller or "")

    raw_cat_id = raw.get("categoryId")
    cat_val = raw.get("category")
    category_id = ""
    cat_str = ""
    if isinstance(raw_cat_id, dict):
        category_id = str(raw_cat_id.get("id") or raw_cat_id.get("_id") or "")
        cat_str = str(raw_cat_id.get("name") or raw_cat_id.get("slug") or "")
    elif raw_cat_id is not None:
        category_id = str(raw_cat_id)

    if isinstance(cat_val, dict):
        if not category_id:
            category_id = str(cat_val.get("id") or cat_val.get("_id") or "")
        cat_str = str(cat_val.get("name") or cat_val.get("slug") or cat_str)
    elif isinstance(cat_val, str) and cat_val:
        cat_str = cat_val

    raw_imgs = raw.get("images")
    norm_images: list[dict[str, Any]] = []
    if isinstance(raw_imgs, list):
        for idx, img in enumerate(raw_imgs):
            if isinstance(img, dict) and img.get("url"):
                norm_images.append(
                    {
                        "url": str(img["url"]),
                        "publicId": img.get("publicId"),
                        "sortOrder": int(img.get("sortOrder", idx)),
                        "altText": img.get("altText"),
                    }
                )
            elif isinstance(img, str) and img.strip():
                norm_images.append({"url": img.strip(), "sortOrder": idx})

    return {
        "id": prod_id,
        "_id": prod_id,
        "sellerId": seller_id,
        "categoryId": category_id,
        "title": title,
        "description": str(raw.get("description") or "").strip(),
        "price": price,
        "originalPrice": orig_price,
        "brand": str(raw.get("brand") or "").strip() or None,
        "condition": str(raw.get("condition") or "GOOD").upper(),
        "defectDisclosure": str(
            raw.get("defectDisclosure") or raw.get("defects") or ""
        ).strip()
        or None,
        "transparencyScore": (
            float(raw["transparencyScore"])
            if raw.get("transparencyScore") is not None
            else None
        ),
        "location": str(raw.get("location") or "").strip(),
        "status": status_val or "ACTIVE",
        "category": cat_str or None,
        "images": norm_images,
    }


def build_shopping_assistant_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    checkpointer_manager: Optional[CheckpointerManager] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """Construct the multi-branch `StateGraph` for Agent 4 (Secondhand Shopping Assistant)."""
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)
    client = backend_client or get_backend_client(resolved_settings)
    memory_mgr = checkpointer_manager or get_checkpointer_manager(resolved_settings)

    @trace_graph_node("shopping_assistant_graph", "load_conversation_context")
    async def load_conversation_context_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        req = ShoppingChatRequest.model_validate(raw_req)

        auth_ctx = get_auth_context()
        user_id = (
            auth_ctx.user_id
            if (auth_ctx and auth_ctx.is_authenticated and auth_ctx.user_id)
            else state.get("user_id") or "anonymous"
        )
        thread_id = req.resolved_thread_id or state.get("thread_id") or str(uuid4())

        # Enforce strict session ownership isolation
        session = memory_mgr.verify_or_bind_session(
            conversation_id=thread_id,
            user_id=user_id,
        )
        ltm = memory_mgr.get_long_term_user_memory(user_id)

        focused_prod, clean_question = _parse_focused_product_context(req.message)

        merged_prefs: dict[str, Any] = {}
        if ltm is not None:
            if ltm.preferred_categories:
                merged_prefs["preferred_categories"] = list(ltm.preferred_categories)
            if ltm.typical_max_budget is not None:
                merged_prefs["max_budget"] = ltm.typical_max_budget
        merged_prefs.update(session.preferences)
        merged_prefs = _extract_preferences(clean_question, merged_prefs, req)

        if focused_prod is not None:
            merged_prefs["focused_product"] = focused_prod
            if focused_prod.get("category"):
                merged_prefs["focused_category"] = focused_prod["category"]
            if not merged_prefs.get("keyword"):
                kw_from_focused = _extract_search_keyword(
                    str(focused_prod.get("title") or ""), ""
                )
                if kw_from_focused:
                    merged_prefs["keyword"] = kw_from_focused

        active_focused = focused_prod or (
            merged_prefs.get("focused_product")
            if isinstance(merged_prefs.get("focused_product"), dict)
            else None
        )
        prior_matched = list(session.last_matched_products)
        if isinstance(active_focused, dict) and active_focused.get("id"):
            existing_ids = {
                str(p.get("id") or "") for p in prior_matched if isinstance(p, dict)
            }
            if str(active_focused["id"]) not in existing_ids:
                prior_matched = [active_focused] + prior_matched

        # Build trimmed message history for context window protection
        history_msgs = []
        for turn in session.turns[-10:]:
            role = getattr(turn, "role", None) or (
                turn.get("role", "user") if isinstance(turn, dict) else "user"
            )
            content = getattr(turn, "content", None) or (
                turn.get("content", "") if isinstance(turn, dict) else ""
            )
            if role == "user":
                history_msgs.append(HumanMessage(content=str(content)))
            else:
                history_msgs.append(AIMessage(content=str(content)))
        history_msgs.append(HumanMessage(content=clean_question))
        history_msgs = trim_conversation_messages(
            history_msgs,
            max_messages=resolved_settings.CONVERSATION_MAX_HISTORY_MESSAGES,
        )

        return {
            "thread_id": thread_id,
            "user_id": user_id,
            "user_message": clean_question,
            "preferences": merged_prefs,
            "last_matched_products": prior_matched,
            "messages": history_msgs,
            "token_usage": {
                "input_tokens": 0,
                "output_tokens": 0,
                "total_tokens": 0,
            },
            "model_name": resolved_settings.GEMINI_MODEL,
        }

    @trace_graph_node("shopping_assistant_graph", "analyze_user_intent")
    async def analyze_user_intent_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        req = ShoppingChatRequest.model_validate(raw_req)
        user_message = state.get("user_message") or req.message
        last_matched = state.get("last_matched_products") or []

        intent = _classify_shopping_intent(
            message=user_message,
            last_matched_products=last_matched,
            req=req,
        )
        return {"intent": intent}

    @trace_graph_node("shopping_assistant_graph", "decide_next_action")
    async def decide_next_action_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        return {
            "intent": state.get("intent")
            or ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY.value
        }

    def route_by_intent(state: ShoppingAssistantGraphState) -> str:
        intent = (
            state.get("intent")
            or ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY.value
        )
        if intent == ShoppingAssistantIntentEnum.PRODUCT_COMPARISON.value:
            return "get_product_details_node"
        if intent == ShoppingAssistantIntentEnum.BUYING_ADVICE.value:
            return "rag_retrieval_node"
        if intent == ShoppingAssistantIntentEnum.GENERAL_CONVERSATION.value:
            return "general_llm_response_node"
        return "search_products_node"

    # =====================================================================
    # BRANCH A: PRODUCT DISCOVERY
    # =====================================================================

    @trace_graph_node("shopping_assistant_graph", "search_products")
    async def search_products_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        req = ShoppingChatRequest.model_validate(raw_req)
        prefs = state.get("preferences") or {}
        user_msg = state.get("user_message") or ""
        user_msg_lower = user_msg.lower()
        keyword = str(prefs.get("keyword") or "").strip()
        if not keyword:
            keyword = _extract_search_keyword(user_msg, "")

        candidates: list[dict[str, Any]] = []
        seen_ids: set[str] = set()

        # 1. Include any pre-fetched catalogContext from NestJS Backend
        for item in req.catalogContext:
            norm = _normalize_candidate_product(item)
            if norm and norm["id"] not in seen_ids:
                seen_ids.add(norm["id"])
                candidates.append(norm)

        # 2. If user is asking for similar products to a focused product, query related & category first
        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        wants_similar = any(
            w in user_msg_lower
            for w in ("tương tự", "cùng loại", "cùng phân khúc", "sản phẩm khác", "mẫu khác")
        )
        if wants_similar and focused_prod:
            fid = str(focused_prod.get("id") or "")
            if OBJECT_ID_REGEX.match(fid):
                try:
                    rel_res = await get_related_products_async(
                        product_id=fid,
                        limit=8,
                        price_tolerance_ratio=0.8,
                        client=client,
                    )
                    for item in rel_res.get("items") or []:
                        norm = _normalize_candidate_product(item)
                        if norm and norm["id"] not in seen_ids:
                            seen_ids.add(norm["id"])
                            candidates.append(norm)
                except Exception:
                    pass

        # 3. Query NestJS Backend via `search_products_async` tool
        try:
            search_res = await search_products_async(
                keyword=keyword or user_msg[:60],
                page=1,
                limit=15,
                client=client,
            )
            for item in search_res.get("items") or []:
                norm = _normalize_candidate_product(item)
                if norm and norm["id"] not in seen_ids:
                    seen_ids.add(norm["id"])
                    candidates.append(norm)
        except Exception as exc:
            logger.info("search_products_node backend tool call skipped: %s", type(exc).__name__)

        return {"candidate_products": candidates}

    @trace_graph_node("shopping_assistant_graph", "filter_products")
    async def filter_products_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        candidates = list(state.get("candidate_products") or [])
        prefs = state.get("preferences") or {}
        user_msg_lower = (state.get("user_message") or "").lower()
        max_budget = prefs.get("max_budget")
        condition_pref = prefs.get("condition")
        keyword = str(prefs.get("keyword") or "").lower().strip()
        cat_pref = _normalize_category_slug(
            str(prefs.get("focused_category") or prefs.get("category") or "")
        )
        wants_similar = any(
            w in user_msg_lower
            for w in ("tương tự", "cùng loại", "cùng phân khúc", "sản phẩm khác", "mẫu khác")
        )

        # If search returned nothing or budget/condition filters are active, also try `filter_products_async`
        has_active_filter = bool(
            keyword or cat_pref or max_budget is not None or condition_pref is not None or wants_similar
        )
        if has_active_filter and (
            not candidates or max_budget is not None or condition_pref is not None or wants_similar
        ):
            try:
                cond_enum = (
                    ProductConditionEnum(condition_pref)
                    if condition_pref in ("NEW", "LIKE_NEW", "GOOD", "FAIR")
                    else None
                )
                filter_res = await filter_products_async(
                    category=cat_pref if (wants_similar and cat_pref) else None,
                    max_price=float(max_budget) if max_budget is not None else None,
                    condition=cond_enum,
                    keyword=None if wants_similar else (keyword or (user_msg_lower[:50].strip() or None)),
                    page=1,
                    limit=15,
                    client=client,
                )
                seen_ids = {c["id"] for c in candidates}
                for item in filter_res.get("items") or []:
                    norm = _normalize_candidate_product(item)
                    if norm and norm["id"] not in seen_ids:
                        seen_ids.add(norm["id"])
                        candidates.append(norm)
            except Exception as exc:
                logger.info("filter_products_node backend tool call skipped: %s", type(exc).__name__)

        # Apply strict in-memory filtering on real candidates
        strict_filtered: list[dict[str, Any]] = []
        relaxed_filtered: list[dict[str, Any]] = []
        for prod in candidates:
            if max_budget is not None and prod["price"] > float(max_budget):
                continue
            if condition_pref and prod["condition"] != condition_pref:
                continue
            relaxed_filtered.append(prod)
            if keyword:
                haystack = (
                    f"{prod.get('title', '')} {prod.get('brand', '')} "
                    f"{prod.get('category', '')} {prod.get('description', '')}"
                ).lower()
                if keyword not in haystack:
                    continue
            strict_filtered.append(prod)

        if wants_similar and len(strict_filtered) < 2 and relaxed_filtered:
            return {"candidate_products": relaxed_filtered}

        return {"candidate_products": strict_filtered}

    @trace_graph_node("shopping_assistant_graph", "rank_results")
    async def rank_results_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        candidates = list(state.get("candidate_products") or [])
        prefs = state.get("preferences") or {}
        max_budget = prefs.get("max_budget")
        use_case = str(prefs.get("use_case") or "").lower()

        scored: list[dict[str, Any]] = []
        for prod in candidates:
            cond_weight = _CONDITION_SCORE.get(prod.get("condition", "GOOD"), 0.75)
            trans_score = float(prod.get("transparencyScore") or 85.0) / 100.0
            budget_bonus = 0.0
            if max_budget and float(max_budget) > 0:
                ratio = prod["price"] / float(max_budget)
                budget_bonus = max(0.0, 1.0 - (ratio * 0.25))

            use_case_bonus = 0.0
            if use_case and use_case in (
                f"{prod.get('title', '')} {prod.get('description', '')}".lower()
            ):
                use_case_bonus = 0.15

            fit_score = round(
                (cond_weight * 40.0)
                + (trans_score * 35.0)
                + (budget_bonus * 15.0)
                + (use_case_bonus * 100.0),
                1,
            )
            defect_note = (
                prod.get("defectDisclosure")
                or "Người bán chưa ghi nhận khuyết điểm đáng kể"
            )
            fit_reason = (
                f"Giá {int(prod['price']):,} VND, tình trạng {prod['condition']}, "
                f"khuyết điểm: {defect_note}."
            )
            enriched = dict(prod)
            enriched["fitScore"] = fit_score
            enriched["fitReason"] = fit_reason
            scored.append(enriched)

        scored.sort(key=lambda x: (-x.get("fitScore", 0.0), x.get("price", 0.0)))
        top_ranked = scored[:5]
        return {
            "ranked_products": top_ranked,
            "last_matched_products": top_ranked,
        }

    @trace_graph_node("shopping_assistant_graph", "generate_recommendation")
    async def generate_recommendation_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        ranked = state.get("ranked_products") or []
        prefs = state.get("preferences") or {}
        max_budget = prefs.get("max_budget")
        keyword = prefs.get("keyword") or "sản phẩm"

        if not ranked:
            budget_str = (
                f" dưới {int(max_budget):,} VND" if max_budget is not None else ""
            )
            msg = (
                f"Hiện tại ReMarket chưa tìm thấy **{keyword}** nào{budget_str} khớp hoàn toàn với tiêu chí của bạn trong kho dữ liệu thực tế.\n\n"
                "Bạn có thể thử:\n"
                "- Mở rộng ngân sách thêm khoảng 10% – 20%.\n"
                "- Nới lỏng bộ lọc tình trạng (ví dụ xem thêm cả `GOOD` và `FAIR`).\n"
                "- Tìm kiếm với từ khóa ngắn gọn hơn (như tên dòng máy hoặc danh mục)."
            )
            return {
                "reply_message": msg,
                "suggested_questions": [
                    f"Tìm {keyword} với ngân sách cao hơn một chút",
                    f"Khi mua {keyword} cũ cần kiểm tra những gì?",
                    "Làm sao để giao dịch đồ cũ an toàn trên ReMarket?",
                ],
                "rag_sources": [],
            }

        lines = [
            f"Mình tìm thấy **{len(ranked)} sản phẩm thật** trên ReMarket phù hợp với nhu cầu của bạn:"
        ]
        for idx, item in enumerate(ranked[:3], start=1):
            defect_text = (
                item.get("defectDisclosure")
                or "Không có khuyết điểm đáng kể được khai báo"
            )
            lines.append(
                f"{idx}. **{item['title']}** — Giá: **{int(item['price']):,} VND** "
                f"(Tình trạng: `{item['condition']}` | Khuyết điểm: *{defect_text}*)"
            )
        lines.append(
            "\nBạn muốn mình **so sánh chi tiết** các mẫu trên xem con nào đáng mua nhất, hay tạo **checklist kiểm tra thực tế** cho một mẫu cụ thể?"
        )

        return {
            "reply_message": "\n".join(lines),
            "suggested_questions": [
                "Trong số đó, con nào đáng mua nhất?",
                f"Tạo danh sách kiểm tra khi đi xem {ranked[0]['title']}",
                "Tôi nên hỏi người bán những câu gì trước khi hẹn gặp?",
            ],
            "rag_sources": [],
        }

    # =====================================================================
    # BRANCH B: PRODUCT COMPARISON
    # =====================================================================

    @trace_graph_node("shopping_assistant_graph", "get_product_details")
    async def get_product_details_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        req = ShoppingChatRequest.model_validate(raw_req)
        prefs = state.get("preferences") or {}
        user_msg_lower = (state.get("user_message") or "").lower()
        prior_products = list(state.get("last_matched_products") or [])

        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        if focused_prod and focused_prod.get("id"):
            existing_ids = {
                str(p.get("id") or "") for p in prior_products if isinstance(p, dict)
            }
            if str(focused_prod["id"]) not in existing_ids:
                prior_products = [focused_prod] + prior_products

        if not prior_products and req.catalogContext:
            for item in req.catalogContext:
                norm = _normalize_candidate_product(item)
                if norm:
                    prior_products.append(norm)

        enriched_list: list[dict[str, Any]] = []
        seen_ids: set[str] = set()
        for prod in prior_products[:5]:
            pid = str(prod.get("id") or "")
            if OBJECT_ID_REGEX.match(pid) and not prod.get("defectDisclosure"):
                try:
                    detail_res = await get_product_detail_async(
                        product_id=pid,
                        client=client,
                    )
                    full_obj = (
                        detail_res.get("product")
                        if isinstance(detail_res.get("product"), dict)
                        else detail_res
                    )
                    if isinstance(full_obj, dict) and full_obj:
                        norm = _normalize_candidate_product(full_obj)
                        if norm and norm["id"] not in seen_ids:
                            seen_ids.add(norm["id"])
                            enriched_list.append(norm)
                            continue
                except Exception:
                    pass
            if pid and pid not in seen_ids:
                seen_ids.add(pid)
                enriched_list.append(prod)

        # If we have fewer than 2 products OR the user asked for similar products ("tương tự", "khác", "cùng loại"),
        # automatically discover comparable products from the Backend!
        wants_similar = any(
            w in user_msg_lower
            for w in ("tương tự", "cùng loại", "cùng phân khúc", "khác", "thêm")
        )
        if len(enriched_list) < 2 or wants_similar:
            ref_prod = focused_prod or (enriched_list[0] if enriched_list else None)
            ref_id = str(ref_prod.get("id") or "") if isinstance(ref_prod, dict) else ""

            # Step 1: Use `get_related_products_async` if we have a real reference ObjectId
            if OBJECT_ID_REGEX.match(ref_id):
                try:
                    rel_res = await get_related_products_async(
                        product_id=ref_id,
                        limit=5,
                        price_tolerance_ratio=0.75,
                        client=client,
                    )
                    for item in rel_res.get("items") or []:
                        norm = _normalize_candidate_product(item)
                        if norm and norm["id"] not in seen_ids:
                            seen_ids.add(norm["id"])
                            enriched_list.append(norm)
                except Exception:
                    pass

            # Step 2: Search by keyword if still < 2 products
            if len(enriched_list) < 2:
                kw = str(
                    prefs.get("keyword")
                    or _extract_search_keyword(
                        str(ref_prod.get("title") if isinstance(ref_prod, dict) else ""),
                        "",
                    )
                ).strip()
                if kw:
                    try:
                        s_res = await search_products_async(
                            keyword=kw,
                            page=1,
                            limit=6,
                            client=client,
                        )
                        for item in s_res.get("items") or []:
                            norm = _normalize_candidate_product(item)
                            if norm and norm["id"] not in seen_ids:
                                seen_ids.add(norm["id"])
                                enriched_list.append(norm)
                    except Exception:
                        pass

            # Step 3: Filter by category if still < 2 products
            if len(enriched_list) < 2:
                cat_slug = _normalize_category_slug(
                    str(
                        prefs.get("focused_category")
                        or prefs.get("category")
                        or (ref_prod.get("category") if isinstance(ref_prod, dict) else "")
                        or ""
                    )
                )
                if cat_slug:
                    try:
                        f_res = await filter_products_async(
                            category=cat_slug,
                            page=1,
                            limit=6,
                            client=client,
                        )
                        for item in f_res.get("items") or []:
                            norm = _normalize_candidate_product(item)
                            if norm and norm["id"] not in seen_ids:
                                seen_ids.add(norm["id"])
                                enriched_list.append(norm)
                    except Exception:
                        pass

            # Step 4: If the category only had 1 item in the DB, fetch closest-priced active products on ReMarket
            if len(enriched_list) < 2 and ref_prod is not None:
                try:
                    all_res = await filter_products_async(
                        page=1,
                        limit=10,
                        client=client,
                    )
                    ref_price = float(ref_prod.get("price") or 0.0)
                    extra_norms: list[dict[str, Any]] = []
                    for item in all_res.get("items") or []:
                        norm = _normalize_candidate_product(item)
                        if norm and norm["id"] not in seen_ids:
                            extra_norms.append(norm)
                    extra_norms.sort(key=lambda x: abs(float(x.get("price") or 0.0) - ref_price))
                    for norm in extra_norms[:3]:
                        seen_ids.add(norm["id"])
                        enriched_list.append(norm)
                except Exception:
                    pass

        return {"candidate_products": enriched_list[:5]}

    @trace_graph_node("shopping_assistant_graph", "compare_products")
    async def compare_products_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        products = list(state.get("candidate_products") or [])
        if not products:
            return {
                "ranked_products": [],
                "comparison_summary": {"has_products": False},
            }

        scored: list[dict[str, Any]] = []
        for prod in products:
            cond_score = _CONDITION_SCORE.get(prod.get("condition", "GOOD"), 0.75) * 45.0
            trans_score = (float(prod.get("transparencyScore") or 85.0) / 100.0) * 35.0
            orig = prod.get("originalPrice")
            price = float(prod.get("price") or 0.0)
            if orig and float(orig) > price > 0:
                value_score = min(20.0, ((float(orig) - price) / float(orig)) * 30.0)
            else:
                value_score = 12.0

            total_score = round(cond_score + trans_score + value_score, 1)
            item_copy = dict(prod)
            item_copy["fitScore"] = total_score
            item_copy["fitReason"] = (
                f"Điểm đánh giá tổng hợp {total_score}/100 (Tình trạng {prod.get('condition')}, "
                f"giá {int(price):,} VND)"
            )
            scored.append(item_copy)

        scored.sort(key=lambda x: (-x.get("fitScore", 0.0), x.get("price", 0.0)))
        best = scored[0]
        return {
            "ranked_products": scored,
            "last_matched_products": scored,
            "comparison_summary": {
                "has_products": True,
                "best_product": best,
                "compared_count": len(scored),
            },
        }

    @trace_graph_node("shopping_assistant_graph", "generate_comparison")
    async def generate_comparison_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        summary = state.get("comparison_summary") or {}
        ranked = state.get("ranked_products") or []
        prefs = state.get("preferences") or {}

        if not summary.get("has_products") or not ranked:
            return {
                "reply_message": (
                    "Hiện tại mình chưa có danh sách sản phẩm trong cuộc trò chuyện để so sánh. "
                    "Bạn hãy cho mình biết loại sản phẩm và ngân sách mong muốn (ví dụ: *'Tìm laptop lập trình dưới 10 triệu'*) để mình tìm các mẫu thật trên ReMarket rồi so sánh giúp bạn nhé!"
                ),
                "suggested_questions": [
                    "Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu",
                    "Tìm điện thoại iPhone cũ dưới 8 triệu",
                ],
                "rag_sources": [],
            }

        best = ranked[0]
        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        budget_note = (
            f" (trong ngân sách dưới {int(prefs['max_budget']):,} VND của bạn)"
            if prefs.get("max_budget")
            else ""
        )

        intro_line = (
            f"Dựa trên sản phẩm bạn đang xem (**{focused_prod['title']}**) cùng **{len(ranked)} lựa chọn tương tự / cùng phân khúc** trên ReMarket{budget_note}, mình đã đối chiếu chi tiết về giá, tình trạng và mức độ minh bạch khuyết điểm:\n"
            if focused_prod and focused_prod.get("title")
            else f"Dựa trên **{len(ranked)} sản phẩm** ở lượt tìm kiếm trước{budget_note}, mình đã so sánh chi tiết về giá, tình trạng và mức độ minh bạch khuyết điểm:\n"
        )

        lines = [
            intro_line,
            f"🏆 **Đáng mua nhất: {best['title']}** — Giá **{int(best['price']):,} VND** (Tình trạng: `{best['condition']}`)",
            f"- **Lý do nên chọn**: Điểm phù hợp cao nhất (**{best.get('fitScore', 90)}/100**), cân bằng tốt giữa mức giá và tình trạng thực tế. Khuyết điểm đã khai báo rõ ràng: *{best.get('defectDisclosure') or 'Không có lỗi đáng kể'}*.",
        ]

        if len(ranked) > 1:
            lines.append("\n**So sánh với các lựa chọn còn lại:**")
            for other in ranked[1:5]:
                is_focused_tag = (
                    " *(Sản phẩm bạn đang xem)*"
                    if focused_prod and str(other.get("id")) == str(focused_prod.get("id"))
                    else ""
                )
                lines.append(
                    f"- **{other['title']}**{is_focused_tag} ({int(other['price']):,} VND | `{other['condition']}`): "
                    f"Khuyết điểm khai báo: *{other.get('defectDisclosure') or 'Chưa ghi nhận chi tiết'}* — Điểm phù hợp: {other.get('fitScore', 80)}/100."
                )

        lines.append(
            f"\n💡 **Lời khuyên**: Trước khi chốt mua **{best['title']}**, bạn nên hẹn kiểm tra trực tiếp các điểm khuyết điểm đã nêu và test kỹ chức năng phần cứng."
        )

        return {
            "reply_message": "\n".join(lines),
            "suggested_questions": [
                f"Tạo danh sách kiểm tra thực tế cho {best['title']}",
                f"Tôi nên hỏi người bán {best['title']} những câu gì?",
                "Kinh nghiệm giao dịch đồ cũ an toàn tránh lừa đảo?",
            ],
            "rag_sources": [],
        }

    # =====================================================================
    # BRANCH C: BUYING ADVICE (RAG)
    # =====================================================================

    @trace_graph_node("shopping_assistant_graph", "rag_retrieval")
    async def rag_retrieval_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        user_msg = state.get("user_message") or ""
        prefs = state.get("preferences") or {}
        kw = prefs.get("keyword") or ""
        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        focused_title = str(focused_prod.get("title") or "") if focused_prod else ""
        query = f"{user_msg} {focused_title} {kw}".strip()

        if rag_pipeline is not None:
            try:
                rag_res = rag_pipeline.query(
                    query,
                    top_k=3,
                    similarity_threshold=0.20,
                )
                return {
                    "rag_context": rag_res.grounded_context,
                    "rag_sources": [s.model_dump() for s in rag_res.sources],
                }
            except Exception as exc:
                logger.warning("RAG retrieval failed in shopping_assistant_graph: %s", exc)
        return {"rag_context": "", "rag_sources": []}

    @trace_graph_node("shopping_assistant_graph", "analyze_context")
    async def analyze_context_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        return {"ranked_products": []}

    @trace_graph_node("shopping_assistant_graph", "generate_advice")
    async def generate_advice_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        rag_context = state.get("rag_context") or ""
        user_msg = state.get("user_message") or ""
        prefs = state.get("preferences") or {}
        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        usage = dict(
            state.get("token_usage")
            or {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
        )

        focused_context_block = ""
        if focused_prod:
            focused_context_block = (
                f"\nThông tin sản phẩm người mua đang xem:\n"
                f"- Tên: {focused_prod.get('title')}\n"
                f"- Giá bán: {int(float(focused_prod.get('price') or 0)):,} VND "
                f"(Giá gốc: {int(float(focused_prod['originalPrice'])):,} VND)\n"
                if focused_prod.get("originalPrice")
                else f"\nThông tin sản phẩm người mua đang xem:\n"
                f"- Tên: {focused_prod.get('title')}\n"
                f"- Giá bán: {int(float(focused_prod.get('price') or 0)):,} VND\n"
            )
            focused_context_block += (
                f"- Tình trạng: {focused_prod.get('condition')}\n"
                f"- Khuyết điểm công khai: {focused_prod.get('defectDisclosure') or 'Không có lỗi đáng kể'}\n"
                f"- Mô tả: {focused_prod.get('description') or ''}\n"
            )

        reply_text = ""
        active_llm = llm
        if active_llm is None and resolved_settings.has_gemini_api_key:
            active_llm = resolved_factory.get_chat_model(temperature=0.3)

        if active_llm is not None:
            try:
                sys_prompt = (
                    "Bạn là Trợ lý Mua Sắm Đồ Cũ ReMarket AI. "
                    "Hãy trả lời câu hỏi tư vấn mua hàng/đánh giá sản phẩm/kiểm tra/an toàn của người dùng bằng tiếng Việt rõ ràng, "
                    "bám sát thông tin sản phẩm đang xem (nếu có) và tài liệu RAG bên dưới. Không tự bịa chính sách ngoài tài liệu."
                )
                usr_prompt = (
                    f"Câu hỏi người dùng: {user_msg}\n"
                    f"{focused_context_block}\n"
                    f"Tài liệu hướng dẫn ReMarket:\n{rag_context or 'Luôn kiểm tra trực tiếp tại nơi công cộng và không đặt cọc trước.'}"
                )
                ai_msg = await invoke_llm_with_resilience(
                    active_llm,
                    [SystemMessage(content=sys_prompt), HumanMessage(content=usr_prompt)],
                    timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
                    max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
                )
                usage = extract_token_usage(ai_msg).model_dump()
                if isinstance(ai_msg.content, str) and ai_msg.content.strip():
                    reply_text = ai_msg.content.strip()
            except Exception as exc:
                logger.warning("LLM advice generation fallback: %s", exc)

        if not reply_text:
            if focused_prod:
                f_title = focused_prod.get("title") or "sản phẩm"
                f_price = int(float(focused_prod.get("price") or 0))
                f_defect = (
                    focused_prod.get("defectDisclosure")
                    or "Không có khuyết điểm đáng kể được khai báo"
                )
                reply_text = (
                    f"Đánh giá nhanh cho **{f_title}** (Giá **{f_price:,} VND** | Tình trạng `{focused_prod.get('condition')}`):\n"
                    f"- **Khuyết điểm người bán đã công khai**: *{f_defect}*.\n"
                    "1. **Kiểm tra thực tế điểm khuyết điểm**: Đối chiếu kỹ vết xước/hao mòn đã nêu và test đầy đủ chức năng cốt lõi tại chỗ.\n"
                    "2. **Không chuyển khoản đặt cọc trước**: Chỉ thanh toán sau khi đã gặp trực tiếp và kiểm tra kỹ sản phẩm.\n"
                    "3. **Hẹn gặp nơi công cộng**: Ưu tiên khuôn viên trường học hoặc quán cà phê đủ ánh sáng.\n\n"
                    + (f"📌 *Trích dẫn tài liệu*: {rag_context[:450]}..." if rag_context else "")
                )
            else:
                reply_text = (
                    "Dựa trên **Cẩm nang Mua bán An toàn & Kiểm định Đồ cũ ReMarket**, bạn cần lưu ý:\n"
                    "1. **Không chuyển khoản đặt cọc trước**: Chỉ thanh toán sau khi đã gặp trực tiếp và kiểm tra kỹ sản phẩm.\n"
                    "2. **Đối chiếu khuyết điểm đã khai báo**: Kiểm tra kỹ ngoại hình, chức năng cốt lõi (màn hình, pin, tài khoản iCloud/MDM nếu là đồ điện tử; kết cấu chịu lực nếu là nội thất).\n"
                    "3. **Hẹn gặp nơi công cộng**: Chọn địa điểm đủ ánh sáng, có Wi-Fi/ổ cắm điện nếu cần test thiết bị.\n\n"
                    + (f"📌 *Trích dẫn tài liệu*: {rag_context[:450]}..." if rag_context else "")
                )

        if focused_prod and focused_prod.get("title"):
            ft = focused_prod["title"]
            follow_ups = [
                f"Hãy đưa ra những sản phẩm tương tự {ft} và so sánh",
                f"Tôi nên hỏi người bán {ft} những câu gì trước khi hẹn gặp?",
                "Kinh nghiệm giao dịch đồ cũ an toàn tránh lừa đảo?",
            ]
        else:
            follow_ups = [
                "Tìm sản phẩm đồ cũ uy tín trên ReMarket",
                "Cách kiểm tra điện thoại/laptop cũ tránh máy dựng?",
                "Chính sách bảo vệ người mua của ReMarket là gì?",
            ]

        return {
            "reply_message": reply_text,
            "suggested_questions": follow_ups,
            "token_usage": usage,
        }

    # =====================================================================
    # BRANCH D: GENERAL CONVERSATION
    # =====================================================================

    @trace_graph_node("shopping_assistant_graph", "general_llm_response")
    async def general_llm_response_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        prefs = state.get("preferences") or {}
        last_matched = state.get("last_matched_products") or []
        user_msg = state.get("user_message") or ""
        focused_prod = (
            prefs.get("focused_product")
            if isinstance(prefs.get("focused_product"), dict)
            else None
        )
        usage = dict(
            state.get("token_usage")
            or {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
        )

        active_llm = llm
        if active_llm is None and resolved_settings.has_gemini_api_key:
            active_llm = resolved_factory.get_chat_model(temperature=0.3)

        reply = ""
        # Always attempt contextual LLM reply when Gemini is available
        if active_llm is not None:
            try:
                matched_summary = "\n".join(
                    f"- {p.get('title')} (Giá: {int(float(p.get('price') or 0)):,} VND, Tình trạng: {p.get('condition')}, Khuyết điểm: {p.get('defectDisclosure') or 'Không có'})"
                    for p in last_matched[:4]
                    if isinstance(p, dict)
                )
                sys_prompt = (
                    "Bạn là Trợ lý AI thông minh, thân thiện của sàn giao dịch đồ cũ sinh viên ReMarket. "
                    "Hãy trả lời tin nhắn của người dùng bằng tiếng Việt tự nhiên, gần gũi, thông minh và hữu ích:\n"
                    "- Nếu người dùng hỏi chuyện phiếm (như hôm nay chơi game gì hay, học gì, giải trí gì...), hãy trả lời đúng trọng tâm câu hỏi một cách thú vị, gợi ý cụ thể (ví dụ gợi ý các tựa game hay theo thể loại), sau đó khéo léo gợi mở xem họ có cần tìm mua phụ kiện/thiết bị liên quan (như bàn phím cơ, chuột gaming, tai nghe, màn hình, laptop cũ...) trên ReMarket không.\n"
                    "- Nếu đang thảo luận về sản phẩm trên ReMarket, hãy nhớ rõ sản phẩm và ngữ cảnh cuộc trò chuyện.\n"
                    "- Trả lời ngắn gọn, súc tích, trình bày rõ ràng."
                )
                ctx_prompt = (
                    f"Sản phẩm đang thảo luận trong cuộc trò chuyện:\n{matched_summary or 'Chưa có'}\n\n"
                    f"Tin nhắn của người dùng: {user_msg}"
                )
                ai_msg = await invoke_llm_with_resilience(
                    active_llm,
                    [SystemMessage(content=sys_prompt), *(state.get("messages") or [])[:-1], HumanMessage(content=ctx_prompt)],
                    timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
                    max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
                )
                usage = extract_token_usage(ai_msg).model_dump()
                if isinstance(ai_msg.content, str) and ai_msg.content.strip():
                    reply = ai_msg.content.strip()
            except Exception as exc:
                logger.warning("General conversation LLM fallback: %s", exc)

        lowered_msg = user_msg.lower()
        is_gaming_topic = any(
            g in lowered_msg
            for g in ("game", "chơi gì", "chơi j", "valorant", "lol", "liên minh", "cs2", "pubg", "elden ring", "wukong")
        )

        if not reply:
            if is_gaming_topic:
                reply = (
                    "Nếu hôm nay bạn đang tìm game hay để chiến hoặc giải trí thì mình gợi ý vài lựa chọn cực cuốn theo gu nhé:\n\n"
                    "- **Bắn súng / Esports cùng hội bạn**: **Valorant**, **Counter-Strike 2 (CS2)** hoặc **Liên Minh Huyền Thoại (LoL)** — nhịp độ nhanh, leo rank cực cháy.\n"
                    "- **Nhập vai / Hành động cốt truyện đỉnh (AAA)**: **Black Myth: Wukong**, **Elden Ring** hoặc **Cyberpunk 2077** — đồ họa mãn nhãn, combat đã tay.\n"
                    "- **Co-op / Giải trí nhẹ nhàng xả stress**: **It Takes Two** (chơi 2 người), **Stardew Valley**, hoặc **Party Animals**.\n\n"
                    "Nhân tiện, nếu bạn cần nâng cấp góc chiến game với **bàn phím cơ (Keychron, Akko)**, **chuột Logitech**, **tai nghe chống ồn** hay **màn hình/laptop** giá sinh viên trên ReMarket thì cứ bảo mình tìm giúp nhé!"
                )
            else:
                pref_hint = ""
                if focused_prod and focused_prod.get("title"):
                    pref_hint = f" Mình vẫn đang ghi nhớ bạn đang xem **{focused_prod['title']}** (Giá {int(float(focused_prod.get('price') or 0)):,} VND)."
                elif prefs.get("keyword") or prefs.get("max_budget"):
                    kw = prefs.get("keyword") or "sản phẩm"
                    b_str = (
                        f" với ngân sách dưới {int(prefs['max_budget']):,} VND"
                        if prefs.get("max_budget")
                        else ""
                    )
                    pref_hint = f" Mình vẫn đang ghi nhớ bạn quan tâm đến **{kw}**{b_str}."

                reply = (
                    f"Xin chào! Mình là **Trợ lý Mua sắm Đồ cũ ReMarket AI**.{pref_hint}\n\n"
                    "Mình có thể trò chuyện và hỗ trợ bạn:\n"
                    "- **Tìm kiếm & lọc sản phẩm thật** theo ngân sách, danh mục, tình trạng.\n"
                    "- **So sánh các sản phẩm** tương tự trong cuộc trò chuyện để chọn mẫu đáng mua nhất.\n"
                    "- **Tư vấn kiểm tra hàng cũ & giao dịch an toàn** từ cẩm nang ReMarket.\n\n"
                    "Bạn đang tìm món đồ gì hay cần mình tư vấn chủ đề nào cứ nhắn tự nhiên nhé!"
                )

        if is_gaming_topic:
            follow_ups = [
                "Tìm bàn phím cơ hoặc chuột gaming cũ dưới 2 triệu",
                "Gợi ý tai nghe chụp tai chơi game âm thanh tốt",
                "Tìm màn hình rời hoặc laptop cấu hình khỏe",
            ]
        else:
            follow_ups = [
                "Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu",
                "Kinh nghiệm kiểm tra đồ điện tử cũ trước khi thanh toán",
            ]
            if focused_prod and focused_prod.get("title"):
                follow_ups.insert(
                    0,
                    f"Hãy đưa ra những sản phẩm tương tự {focused_prod['title']} và so sánh",
                )
            elif last_matched:
                follow_ups.insert(0, "Trong số đó, con nào đáng mua nhất?")

        return {
            "ranked_products": [],
            "reply_message": reply,
            "suggested_questions": follow_ups[:3],
            "rag_sources": [],
            "token_usage": usage,
        }

    # =====================================================================
    # VALIDATION & STATE PERSISTENCE
    # =====================================================================

    @trace_graph_node("shopping_assistant_graph", "validate_response")
    async def validate_response_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        ranked = state.get("ranked_products") or []
        validated_cards: list[MatchedProductCard] = []
        matched_ids: list[str] = []

        for item in ranked:
            if not isinstance(item, dict):
                continue
            real_id = str(item.get("id") or "").strip()
            if not real_id:
                continue
            card = MatchedProductCard(
                id=real_id,
                raw_id=real_id,
                sellerId=str(item.get("sellerId") or ""),
                categoryId=str(item.get("categoryId") or ""),
                title=str(item.get("title") or "Sản phẩm ReMarket"),
                description=str(item.get("description") or ""),
                price=float(item.get("price") or 0.0),
                originalPrice=item.get("originalPrice"),
                brand=item.get("brand"),
                condition=str(item.get("condition") or "GOOD"),
                defectDisclosure=item.get("defectDisclosure"),
                transparencyScore=item.get("transparencyScore"),
                location=str(item.get("location") or ""),
                status=str(item.get("status") or "ACTIVE"),
                category=item.get("category"),
                images=item.get("images") if isinstance(item.get("images"), list) else [],
                fitScore=float(item.get("fitScore") or 0.0),
                fitReason=item.get("fitReason"),
            )
            validated_cards.append(card)
            matched_ids.append(real_id)

        raw_sources = state.get("rag_sources") or []
        sources = [
            RAGSourceAttribution.model_validate(s) if isinstance(s, dict) else s
            for s in raw_sources
        ]

        intent_str = (
            state.get("intent")
            or ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY.value
        )
        msg = (
            state.get("reply_message")
            or "Mình có thể hỗ trợ gì thêm cho nhu cầu mua sắm đồ cũ của bạn?"
        )
        questions = list(state.get("suggested_questions") or [])[:4]
        thread_id = state.get("thread_id") or str(uuid4())
        usage = state.get("token_usage") or {
            "input_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
        }

        resp = ShoppingChatResponse(
            message=msg,
            reply=msg,
            thread_id=thread_id,
            interactionId=thread_id,
            intent=ShoppingAssistantIntentEnum(intent_str),
            matchedProducts=validated_cards,
            matchedProductIds=matched_ids,
            suggestedQuestions=questions,
            suggestedFollowUps=questions,
            sources=sources,
            requiresBuyerConfirmation=True,
            aiProvider=state.get("model_name") or resolved_settings.GEMINI_MODEL,
            tokenUsage=usage,
            requestId=get_request_id(),
        )
        return {"validated_output": resp.model_dump()}

    @trace_graph_node("shopping_assistant_graph", "save_conversation_state")
    async def save_conversation_state_node(
        state: ShoppingAssistantGraphState,
    ) -> dict[str, Any]:
        thread_id = state.get("thread_id") or str(uuid4())
        user_id = state.get("user_id") or "anonymous"
        user_msg = state.get("user_message") or ""
        reply_msg = state.get("reply_message") or ""
        intent_str = (
            state.get("intent")
            or ShoppingAssistantIntentEnum.PRODUCT_DISCOVERY.value
        )
        matched_to_keep = state.get("last_matched_products")
        prefs = state.get("preferences") or {}

        memory_mgr.update_session(
            conversation_id=thread_id,
            user_id=user_id,
            user_message=user_msg,
            assistant_message=reply_msg,
            intent=intent_str,
            matched_products=matched_to_keep,
            preferences=prefs,
        )
        return {}

    graph = StateGraph(ShoppingAssistantGraphState)
    graph.add_node("load_conversation_context", load_conversation_context_node)
    graph.add_node("analyze_user_intent", analyze_user_intent_node)
    graph.add_node("decide_next_action", decide_next_action_node)

    # Branch A
    graph.add_node("search_products_node", search_products_node)
    graph.add_node("filter_products_node", filter_products_node)
    graph.add_node("rank_results_node", rank_results_node)
    graph.add_node("generate_recommendation_node", generate_recommendation_node)

    # Branch B
    graph.add_node("get_product_details_node", get_product_details_node)
    graph.add_node("compare_products_node", compare_products_node)
    graph.add_node("generate_comparison_node", generate_comparison_node)

    # Branch C
    graph.add_node("rag_retrieval_node", rag_retrieval_node)
    graph.add_node("analyze_context_node", analyze_context_node)
    graph.add_node("generate_advice_node", generate_advice_node)

    # Branch D
    graph.add_node("general_llm_response_node", general_llm_response_node)

    # Converge
    graph.add_node("validate_response", validate_response_node)
    graph.add_node("save_conversation_state", save_conversation_state_node)

    graph.add_edge(START, "load_conversation_context")
    graph.add_edge("load_conversation_context", "analyze_user_intent")
    graph.add_edge("analyze_user_intent", "decide_next_action")

    graph.add_conditional_edges(
        "decide_next_action",
        route_by_intent,
        {
            "search_products_node": "search_products_node",
            "get_product_details_node": "get_product_details_node",
            "rag_retrieval_node": "rag_retrieval_node",
            "general_llm_response_node": "general_llm_response_node",
        },
    )

    # Branch A edges
    graph.add_edge("search_products_node", "filter_products_node")
    graph.add_edge("filter_products_node", "rank_results_node")
    graph.add_edge("rank_results_node", "generate_recommendation_node")
    graph.add_edge("generate_recommendation_node", "validate_response")

    # Branch B edges
    graph.add_edge("get_product_details_node", "compare_products_node")
    graph.add_edge("compare_products_node", "generate_comparison_node")
    graph.add_edge("generate_comparison_node", "validate_response")

    # Branch C edges
    graph.add_edge("rag_retrieval_node", "analyze_context_node")
    graph.add_edge("analyze_context_node", "generate_advice_node")
    graph.add_edge("generate_advice_node", "validate_response")

    # Branch D edges
    graph.add_edge("general_llm_response_node", "validate_response")

    # Convergence edges
    graph.add_edge("validate_response", "save_conversation_state")
    graph.add_edge("save_conversation_state", END)

    return graph


def compile_shopping_assistant_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    checkpointer_manager: Optional[CheckpointerManager] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the Secondhand Shopping Assistant graph."""
    builder = build_shopping_assistant_state_graph(
        llm=llm,
        factory=factory,
        rag_pipeline=rag_pipeline,
        backend_client=backend_client,
        checkpointer_manager=checkpointer_manager,
        settings=settings,
    )
    return builder.compile()
