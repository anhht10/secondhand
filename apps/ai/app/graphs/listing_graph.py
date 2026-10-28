"""
Agent 1: Listing Generator LangGraph Workflow (`app.graphs.listing_graph`).

Topology:
START
  -> validate_input
  -> analyze_product_info
  -> analyze_images
  -> retrieve_relevant_knowledge
  -> generate_listing
  -> validate_structured_output
  -> END
"""

import json
import logging
import re
from typing import Any, Optional

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import END, START, StateGraph
from langgraph.graph.state import CompiledStateGraph

from app.core.config import Settings, get_settings
from app.core.observability import extract_token_usage, trace_graph_node
from app.llm.gemini import (
    GeminiModelFactory,
    get_gemini_factory,
    invoke_llm_with_resilience,
)
from app.rag.pipelines import RAGPipeline
from app.schemas.agents import (
    GenerateListingLLMOutput,
    GenerateListingRequest,
    ListingDescriptionSections,
)
from app.states.agent_states import ListingGraphState

logger = logging.getLogger("remarket.ai.graphs.listing")

_CONDITION_LABELS_VI: dict[str, str] = {
    "NEW": "Mới 100% (NEW)",
    "LIKE_NEW": "Như mới 95-99% (LIKE_NEW)",
    "GOOD": "Tốt 85-94% (GOOD)",
    "FAIR": "Khá / Có hao mòn rõ (FAIR)",
}

_CATEGORY_INFERENCE_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("Máy tính & Phụ kiện", ("laptop", "macbook", "bàn phím", "keychron", "chuột", "logitech", "màn hình", "dell", "asus", "lenovo")),
    ("Điện thoại & Máy tính bảng", ("iphone", "ipad", "samsung", "galaxy", "xiaomi", "kindle", "điện thoại", "tablet")),
    ("Đồ điện tử", ("tai nghe", "sony", "wh-1000", "airpods", "loa", "marshall", "máy ảnh", "camera")),
    ("Sách & Giáo trình", ("sách", "giáo trình", "toeic", "ielts", "tài liệu", "calculus", "book")),
    ("Đồ phòng trọ", ("bàn học", "ghế", "đèn", "kệ", "tủ", "quạt", "ấm siêu tốc")),
    ("Quần áo & Thời trang", ("áo", "hoodie", "balo", "giày", "khoác", "quần")),
]


def _infer_category_name(name: str, explicit_category: str) -> str:
    if explicit_category and explicit_category.strip():
        return explicit_category.strip()
    lowered = name.lower()
    for cat_name, kws in _CATEGORY_INFERENCE_KEYWORDS:
        if any(kw in lowered for kw in kws):
            return cat_name
    return "Phụ kiện & Khác"


def _extract_json_dict(text: str) -> Optional[dict[str, Any]]:
    """Extract a JSON object from raw LLM text or fenced markdown block."""
    cleaned = text.strip()
    fence_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", cleaned, re.DOTALL)
    if fence_match:
        cleaned = fence_match.group(1)
    else:
        brace_start = cleaned.find("{")
        brace_end = cleaned.rfind("}")
        if brace_start != -1 and brace_end > brace_start:
            cleaned = cleaned[brace_start : brace_end + 1]
    try:
        parsed = json.loads(cleaned)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        return None


def build_listing_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """Build the 6-node StateGraph for Agent 1 (Listing Generator)."""
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)

    @trace_graph_node("listing_graph", "validate_input")
    async def validate_input_node(state: ListingGraphState) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        validated = GenerateListingRequest.model_validate(raw_req)
        cond_upper = (validated.condition or "LIKE_NEW").strip().upper()
        if cond_upper not in _CONDITION_LABELS_VI:
            cond_upper = "GOOD"

        return {
            "product_name": validated.resolved_name,
            "brand": (validated.brand or "").strip(),
            "category": _infer_category_name(validated.resolved_name, validated.category or ""),
            "condition": cond_upper,
            "defects": validated.resolved_defects,
            "original_price": validated.originalPrice,
            "selling_price": validated.resolved_selling_price,
            "images": validated.resolved_images,
            "image_base64": validated.imageBase64,
            "image_mime_type": validated.imageMimeType or "image/jpeg",
        }

    @trace_graph_node("listing_graph", "analyze_product_info")
    async def analyze_product_info_node(state: ListingGraphState) -> dict[str, Any]:
        name = state.get("product_name", "")
        brand = state.get("brand", "")
        condition = state.get("condition", "LIKE_NEW")
        defects = state.get("defects", "")
        orig_price = state.get("original_price")
        sell_price = state.get("selling_price")

        missing_fields: list[str] = []
        if not defects:
            missing_fields.append("defectDisclosure")
        if not brand:
            missing_fields.append("brand")
        if orig_price is None and sell_price is None:
            missing_fields.append("price_info")

        analysis = {
            "has_explicit_brand": bool(brand),
            "has_explicit_defects": bool(defects),
            "condition_label": _CONDITION_LABELS_VI.get(condition, condition),
            "missing_optional_fields": missing_fields,
            "summary": (
                f"Sản phẩm: {name} | Thương hiệu khai báo: {brand or 'Chưa cung cấp (không tự suy đoán)'} | "
                f"Tình trạng: {condition} | Khuyết điểm khai báo: {defects or 'Chưa khai báo cụ thể'}"
            ),
        }
        return {"product_analysis": analysis}

    @trace_graph_node("listing_graph", "analyze_images")
    async def analyze_images_node(state: ListingGraphState) -> dict[str, Any]:
        images = state.get("images") or []
        image_b64 = state.get("image_base64")
        defects = state.get("defects", "")

        clarification_questions: list[str] = []
        needs_more_info = False

        # Check if no images provided or image markers indicate unclear/blurry image
        unclear_markers = ("blur", "mờ", "unclear", "lowres", "dark", "tối")
        has_unclear_image = any(
            any(m in img.lower() for m in unclear_markers) for img in images
        )

        if not images and not image_b64:
            needs_more_info = True
            clarification_questions.append(
                "Vui lòng tải lên ít nhất 2–3 ảnh chụp thực tế rõ nét (mặt trước, mặt sau và vị trí hao mòn) để người mua yên tâm."
            )
        elif has_unclear_image:
            needs_more_info = True
            clarification_questions.append(
                "Ảnh chụp hiện tại chưa đủ rõ nét. Bạn vui lòng chụp lại dưới ánh sáng tốt và bổ sung ảnh cận cảnh các góc sản phẩm."
            )

        if not defects:
            needs_more_info = True
            clarification_questions.append(
                "Sản phẩm có vết trầy xước, hao mòn pin hoặc thiếu phụ kiện đi kèm nào cần khai báo minh bạch không?"
            )

        image_analysis = {
            "image_count": len(images) + (1 if image_b64 else 0),
            "has_multimodal_input": bool(images or image_b64),
            "has_unclear_image": has_unclear_image,
            "note": (
                "Chỉ mô tả các chi tiết quan sát được trực tiếp hoặc người bán đã khai báo; "
                "tuyệt đối không suy đoán khuyết điểm ẩn bên trong."
            ),
        }
        return {
            "image_analysis": image_analysis,
            "needs_more_info": needs_more_info,
            "clarification_questions": clarification_questions,
        }

    @trace_graph_node("listing_graph", "retrieve_relevant_knowledge")
    async def retrieve_relevant_knowledge_node(state: ListingGraphState) -> dict[str, Any]:
        condition = state.get("condition", "LIKE_NEW")
        category = state.get("category", "")
        rag_context = ""

        if rag_pipeline is not None:
            try:
                res = rag_pipeline.query(
                    f"Quy định minh bạch defectDisclosure và phân loại tình trạng {condition} {category}",
                    top_k=2,
                    similarity_threshold=0.25,
                )
                if res.has_sufficient_context:
                    rag_context = res.grounded_context
            except Exception as exc:
                logger.warning("RAG retrieval in listing_graph skipped: %s", exc)

        return {"rag_context": rag_context}

    @trace_graph_node("listing_graph", "generate_listing")
    async def generate_listing_node(state: ListingGraphState) -> dict[str, Any]:
        name = state.get("product_name", "")
        brand = state.get("brand", "")
        category = state.get("category", "Đồ điện tử")
        condition = state.get("condition", "LIKE_NEW")
        defects = state.get("defects", "")
        orig_price = state.get("original_price")
        sell_price = state.get("selling_price")
        images = state.get("images") or []
        image_b64 = state.get("image_base64")
        image_mime = state.get("image_mime_type", "image/jpeg")
        rag_ctx = state.get("rag_context", "")

        system_prompt = (
            "Bạn là Chuyên gia Hỗ trợ Đăng tin Minh bạch (Listing Generator) của sàn đồ cũ sinh viên ReMarket.\n"
            "QUY TẮC BẮT BUỘC:\n"
            "1. KHÔNG TỰ BỊA thương hiệu (brand), cấu hình phần cứng (RAM/SSD/Chip) hoặc thông số kỹ thuật nếu người bán không cung cấp.\n"
            "2. KHÔNG SUY ĐOÁN khuyết điểm ẩn không nhìn thấy được.\n"
            "3. BẢO TOÀN 100% thông tin khuyết điểm mà người bán đã khai báo trong phần `defects` và `transparencyNote`.\n"
            "4. Nếu ảnh không rõ hoặc thiếu thông tin khuyết điểm, nhắc người bán bổ sung.\n"
            "5. Trả về đúng định dạng JSON với các khóa: "
            "suggestedTitle, suggestedDescription {overview, condition, defects}, "
            "suggestedCategory, suggestedTags, transparencyNote, transparencyScore."
        )

        user_text = (
            f"Thông tin người bán cung cấp:\n"
            f"- Tên sản phẩm: {name}\n"
            f"- Thương hiệu: {brand or 'Không cung cấp (KHÔNG tự thêm tên hãng)'}\n"
            f"- Danh mục: {category}\n"
            f"- Tình trạng: {condition} ({_CONDITION_LABELS_VI.get(condition, condition)})\n"
            f"- Khuyết điểm khai báo: {defects or 'Người bán chưa ghi nhận khuyết điểm cụ thể'}\n"
            f"- Giá mua mới: {f'{int(orig_price):,} VND' if orig_price else 'Không cung cấp'}\n"
            f"- Giá bán dự kiến: {f'{int(sell_price):,} VND' if sell_price else 'Không cung cấp'}\n"
            f"- Số lượng ảnh đính kèm: {len(images) + (1 if image_b64 else 0)}\n"
        )
        if rag_ctx:
            user_text += f"\nKiến thức tham khảo ReMarket:\n{rag_ctx}\n"

        content_blocks: list[Any] = [{"type": "text", "text": user_text}]
        if image_b64:
            data_uri = (
                image_b64
                if image_b64.startswith("data:")
                else f"data:{image_mime};base64,{image_b64}"
            )
            content_blocks.append({"type": "image_url", "image_url": {"url": data_uri}})

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=content_blocks if image_b64 else user_text),
        ]

        active_llm = llm
        if active_llm is None and resolved_settings.has_gemini_api_key:
            active_llm = resolved_factory.get_chat_model()

        token_usage = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
        model_name = resolved_settings.GEMINI_MODEL
        parsed_json: Optional[dict[str, Any]] = None

        if active_llm is not None:
            model_name = str(getattr(active_llm, "model", resolved_settings.GEMINI_MODEL))
            try:
                response_msg = await invoke_llm_with_resilience(
                    active_llm,
                    messages,
                    timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
                    max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
                )
                usage = extract_token_usage(response_msg)
                token_usage = usage.model_dump()
                raw_content = (
                    response_msg.content
                    if isinstance(response_msg.content, str)
                    else str(response_msg.content)
                )
                parsed_json = _extract_json_dict(raw_content)
            except Exception as exc:
                logger.warning(
                    "Gemini listing generation fallback to deterministic output: %s",
                    exc,
                )

        return {
            "raw_output": parsed_json or {},
            "token_usage": token_usage,
            "model_name": model_name,
        }

    @trace_graph_node("listing_graph", "validate_structured_output")
    async def validate_structured_output_node(state: ListingGraphState) -> dict[str, Any]:
        name = state.get("product_name", "Sản phẩm đồ cũ")
        brand = state.get("brand", "")
        category = state.get("category", "Đồ điện tử")
        condition = state.get("condition", "LIKE_NEW")
        defects = state.get("defects", "")
        needs_more_info = bool(state.get("needs_more_info", False))
        clarification_questions = list(state.get("clarification_questions") or [])
        raw_out = state.get("raw_output") or {}

        cond_label = _CONDITION_LABELS_VI.get(condition, condition)

        # Build safe defaults that never invent brand/specs and always preserve seller defects
        title_prefix = f"{brand} {name}".strip() if brand and brand.lower() not in name.lower() else name
        default_title = f"{title_prefix} - {cond_label}"[:140]

        default_overview = (
            f"Nhượng lại {title_prefix} thuộc danh mục {category}, phù hợp cho nhu cầu học tập và sinh hoạt sinh viên. "
            "Thông tin mô tả đúng theo khai báo thực tế của người bán, không tự suy đoán thông số kỹ thuật."
        )
        default_condition_desc = (
            f"Phân loại tình trạng: {cond_label}. "
            + (
                "Cần bổ sung thêm hình ảnh thực tế rõ nét để người mua đối chiếu ngoại hình."
                if needs_more_info
                else "Ngoại hình và chức năng phản ánh trung thực theo thông tin và ảnh chụp người bán cung cấp."
            )
        )
        default_defects_desc = (
            f"Khuyết điểm người bán đã khai báo: {defects}"
            if defects
            else "Người bán chưa ghi nhận khuyết điểm cụ thể (vui lòng kiểm tra trực tiếp hoặc bổ sung thông tin nếu có vết trầy xước/hao mòn)."
        )

        raw_desc = raw_out.get("suggestedDescription")
        if isinstance(raw_desc, dict):
            overview_text = str(raw_desc.get("overview") or default_overview).strip()
            cond_text = str(raw_desc.get("condition") or default_condition_desc).strip()
            defects_text = str(raw_desc.get("defects") or default_defects_desc).strip()
        else:
            overview_text = default_overview
            cond_text = default_condition_desc
            defects_text = default_defects_desc

        # Enforce mandatory preservation of seller's declared defects
        if defects and defects.lower() not in defects_text.lower():
            defects_text = f"{defects_text} | Khai báo gốc của người bán: {defects}"

        suggested_title = str(raw_out.get("suggestedTitle") or default_title).strip()[:140]
        suggested_category = str(raw_out.get("suggestedCategory") or category).strip()

        raw_tags = raw_out.get("suggestedTags")
        if isinstance(raw_tags, list) and raw_tags:
            tags = [
                str(t).strip() if str(t).strip().startswith("#") else f"#{str(t).strip()}"
                for t in raw_tags
                if str(t).strip()
            ][:6]
        else:
            slug_tag = re.sub(r"[^a-z0-9]", "", (brand or name.split()[0]).lower()) or "docu"
            tags = [f"#{slug_tag}", f"#{condition.lower()}", "#sinhvien", "#remarket"]

        transparency_note = str(
            raw_out.get("transparencyNote")
            or (
                f"Đã bảo toàn khai báo khuyết điểm ({cond_label}): {defects}"
                if defects
                else f"Tình trạng khai báo {cond_label}. Đề nghị người bán xác nhận thêm nếu có vết xước hoặc hao mòn nhỏ."
            )
        ).strip()
        if defects and defects.lower() not in transparency_note.lower():
            transparency_note = f"{transparency_note} (Khuyết điểm khai báo: {defects})"

        score = int(raw_out.get("transparencyScore") or (96 if defects and not needs_more_info else 82))
        score = max(0, min(100, score))

        llm_validated = GenerateListingLLMOutput(
            suggestedTitle=suggested_title,
            suggestedDescription=ListingDescriptionSections(
                overview=overview_text,
                condition=cond_text,
                defects=defects_text,
            ),
            suggestedCategory=suggested_category,
            suggestedTags=tags,
            transparencyNote=transparency_note,
            transparencyScore=score,
            needsMoreInfo=needs_more_info,
            clarificationQuestions=clarification_questions,
        )

        return {"validated_output": llm_validated.model_dump()}

    workflow = StateGraph(ListingGraphState)
    workflow.add_node("validate_input", validate_input_node)
    workflow.add_node("analyze_product_info", analyze_product_info_node)
    workflow.add_node("analyze_images", analyze_images_node)
    workflow.add_node("retrieve_relevant_knowledge", retrieve_relevant_knowledge_node)
    workflow.add_node("generate_listing", generate_listing_node)
    workflow.add_node("validate_structured_output", validate_structured_output_node)

    workflow.add_edge(START, "validate_input")
    workflow.add_edge("validate_input", "analyze_product_info")
    workflow.add_edge("analyze_product_info", "analyze_images")
    workflow.add_edge("analyze_images", "retrieve_relevant_knowledge")
    workflow.add_edge("retrieve_relevant_knowledge", "generate_listing")
    workflow.add_edge("generate_listing", "validate_structured_output")
    workflow.add_edge("validate_structured_output", END)
    return workflow


def compile_listing_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the Agent 1 Listing Generator StateGraph."""
    graph = build_listing_state_graph(
        llm=llm,
        factory=factory,
        rag_pipeline=rag_pipeline,
        settings=settings,
    )
    return graph.compile()
