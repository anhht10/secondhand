"""
Agent 3 — Buyer Inspection Checklist LangGraph (`app.graphs.inspection_graph`).

Workflow topology:
START
  -> get_product_detail
  -> analyze_product_info
  -> retrieve_inspection_knowledge
  -> generate_inspection_points
  -> generate_seller_questions
  -> validate_output
  -> END

Design guarantees:
- Calls `get_product_detail_async` via `BackendClient` when `productId` is supplied,
  merging real listing attributes (condition, defectDisclosure, category, brand, price)
  with any inline request attributes.
- Queries the Phase 2 RAG pipeline (`inspection_guide`, `safety_guide`) for category-specific
  physical verification rules and anti-scam tips.
- Produces 3 to 4 tailored `inspectionPoints` (`HIGH | MEDIUM | LOW`), 3 `suggestedQuestions`,
  and actionable `safetyTips`.
- Never guarantees a secondhand item is defect-free outside the checklist (`advisoryOnly=True`).
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
from app.core.logging import get_request_id
from app.core.observability import extract_token_usage, trace_graph_node
from app.llm.gemini import (
    GeminiModelFactory,
    get_gemini_factory,
    invoke_llm_with_resilience,
)
from app.rag.pipelines import RAGPipeline
from app.schemas.agents import (
    BuyerChecklistRequest,
    BuyerChecklistResponse,
    InspectionImportanceEnum,
    InspectionPointItem,
)
from app.services.backend_client import BackendClient, get_backend_client
from app.states.agent_states import InspectionGraphState
from app.tools.product_tools import get_product_detail_async

logger = logging.getLogger("remarket.ai.graphs.inspection")


def _detect_domain_category(title: str, category: str) -> str:
    """Classify the item into an inspection domain for deterministic fallback & RAG query enrichment."""
    combined = f"{title} {category}".lower()
    if any(
        kw in combined
        for kw in (
            "iphone",
            "samsung",
            "xiaomi",
            "oppo",
            "macbook",
            "laptop",
            "ipad",
            "airpods",
            "phone",
            "điện thoại",
            "máy tính",
            "tai nghe",
            "màn hình",
            "camera",
            "máy ảnh",
            "loa",
            "electronic",
            "điện tử",
            "bàn phím",
            "chuột",
        )
    ):
        return "electronics"
    if any(
        kw in combined
        for kw in (
            "bàn",
            "ghế",
            "tủ",
            "giường",
            "sofa",
            "kệ",
            "nội thất",
            "furniture",
            "đèn",
            "phòng trọ",
        )
    ):
        return "furniture"
    if any(
        kw in combined
        for kw in (
            "áo",
            "quần",
            "giày",
            "túi",
            "balo",
            "đồng hồ",
            "thời trang",
            "fashion",
            "sneaker",
        )
    ):
        return "fashion"
    if any(
        kw in combined
        for kw in ("sách", "book", "truyện", "giáo trình", "tiểu thuyết")
    ):
        return "books"
    return "general"


def _extract_json_dict(text: str) -> Optional[dict[str, Any]]:
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


def build_inspection_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """Construct the `StateGraph` for Agent 3 (Buyer Inspection Checklist)."""
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)
    client = backend_client or get_backend_client(resolved_settings)

    @trace_graph_node("inspection_graph", "get_product_detail")
    async def get_product_detail_node(state: InspectionGraphState) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        validated_req = BuyerChecklistRequest.model_validate(raw_req)
        product_id = validated_req.resolved_product_id

        detail: dict[str, Any] = {
            "id": product_id,
            "title": validated_req.resolved_title,
            "brand": (validated_req.brand or "").strip(),
            "category": (validated_req.category or "").strip(),
            "condition": (validated_req.condition or "GOOD").strip().upper(),
            "defects": validated_req.resolved_defects,
            "description": (validated_req.description or "").strip(),
            "price": validated_req.price,
            "images": validated_req.resolved_images,
            "fetchedFromBackend": False,
        }

        if product_id:
            try:
                product_obj = await get_product_detail_async(
                    product_id=product_id,
                    client=client,
                )
                if isinstance(product_obj, dict) and product_obj:
                    # Support both flat product dict and wrapped {"product": {...}}
                    inner = (
                        product_obj["product"]
                        if isinstance(product_obj.get("product"), dict)
                        else product_obj
                    )
                    cat_obj = inner.get("category")
                    cat_name = ""
                    if isinstance(cat_obj, dict):
                        cat_name = str(cat_obj.get("name") or cat_obj.get("slug") or "")
                    elif isinstance(cat_obj, str):
                        cat_name = cat_obj

                    detail.update(
                        {
                            "title": str(inner.get("title") or detail["title"]).strip(),
                            "brand": str(inner.get("brand") or detail["brand"] or "").strip(),
                            "category": cat_name or detail["category"],
                            "condition": str(
                                inner.get("condition") or detail["condition"]
                            ).upper(),
                            "defects": str(
                                inner.get("defectDisclosure")
                                or inner.get("defects")
                                or detail["defects"]
                                or ""
                            ).strip(),
                            "description": str(
                                inner.get("description") or detail["description"] or ""
                            ).strip(),
                            "price": (
                                float(inner["price"])
                                if inner.get("price") is not None
                                else detail["price"]
                            ),
                            "fetchedFromBackend": True,
                        }
                    )
            except Exception as exc:
                logger.info(
                    "get_product_detail_node fallback to inline fields for productId=%s: %s",
                    product_id,
                    type(exc).__name__,
                )

        if not detail["title"]:
            detail["title"] = f"Sản phẩm #{product_id or 'ReMarket'}"

        return {
            "product_id": product_id,
            "product_detail": detail,
            "token_usage": {
                "input_tokens": 0,
                "output_tokens": 0,
                "total_tokens": 0,
            },
            "model_name": resolved_settings.GEMINI_MODEL,
        }

    @trace_graph_node("inspection_graph", "analyze_product_info")
    async def analyze_product_info_node(state: InspectionGraphState) -> dict[str, Any]:
        detail = state.get("product_detail") or {}
        title = detail.get("title", "")
        category = detail.get("category", "")
        defects = detail.get("defects", "")
        condition = detail.get("condition", "GOOD")

        domain = _detect_domain_category(title, category)
        has_disclosed_defects = bool(
            defects
            and defects.lower()
            not in ("none", "không", "không có", "khong co", "n/a")
        )

        return {
            "product_analysis": {
                "domain": domain,
                "has_disclosed_defects": has_disclosed_defects,
                "disclosed_defects_text": (
                    defects
                    if has_disclosed_defects
                    else "Người bán chưa khai báo khuyết điểm cụ thể"
                ),
                "condition": condition,
            }
        }

    @trace_graph_node("inspection_graph", "retrieve_inspection_knowledge")
    async def retrieve_inspection_knowledge_node(
        state: InspectionGraphState,
    ) -> dict[str, Any]:
        detail = state.get("product_detail") or {}
        analysis = state.get("product_analysis") or {}
        query = (
            f"Hướng dẫn kiểm tra hàng cũ {detail.get('category', '')} "
            f"{detail.get('title', '')} {analysis.get('domain', '')} "
            f"khuyết điểm {detail.get('defects', '')} giao dịch an toàn"
        ).strip()

        rag_context = ""
        if rag_pipeline is not None:
            try:
                rag_res = rag_pipeline.query(
                    query,
                    top_k=3,
                    similarity_threshold=0.20,
                )
                if rag_res.has_sufficient_context:
                    rag_context = rag_res.grounded_context
            except Exception as exc:
                logger.warning("RAG retrieval skipped in inspection_graph: %s", exc)

        safety_tips = [
            "Luôn kiểm tra trực tiếp sản phẩm ở nơi công cộng, đủ ánh sáng và chỉ thanh toán sau khi đã test xong mọi chức năng.",
            "Không chuyển khoản đặt cọc trước khi chưa kiểm tra thực tế sản phẩm để phòng tránh rủi ro lừa đảo.",
            "Lưu ý: Danh sách kiểm tra này là gợi ý hỗ trợ của AI dựa trên thông tin tin đăng, không thay thế việc kiểm định thực tế và không cam kết sản phẩm không có lỗi ẩn.",
        ]

        return {
            "rag_context": rag_context,
            "rag_safety_tips": safety_tips,
        }

    @trace_graph_node("inspection_graph", "generate_inspection_points")
    async def generate_inspection_points_node(
        state: InspectionGraphState,
    ) -> dict[str, Any]:
        detail = state.get("product_detail") or {}
        analysis = state.get("product_analysis") or {}
        rag_context = state.get("rag_context") or ""
        title = detail.get("title", "Sản phẩm")
        brand = detail.get("brand") or "Không rõ"
        category = detail.get("category") or analysis.get("domain", "general")
        condition = detail.get("condition", "GOOD")
        defects_text = analysis.get(
            "disclosed_defects_text", "Người bán chưa khai báo khuyết điểm cụ thể"
        )
        has_defects = analysis.get("has_disclosed_defects", False)
        domain = analysis.get("domain", "general")

        usage = dict(
            state.get("token_usage")
            or {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
        )
        model_used = state.get("model_name") or resolved_settings.GEMINI_MODEL

        points_list: list[dict[str, Any]] = []
        questions_list: list[str] = []
        llm_safety_tips: list[str] = []

        active_llm = llm
        if active_llm is None and resolved_settings.has_gemini_api_key:
            active_llm = resolved_factory.get_chat_model(temperature=0.2)

        if active_llm is not None:
            model_used = str(getattr(active_llm, "model", resolved_settings.GEMINI_MODEL))
            try:
                sys_prompt = (
                    "Bạn là chuyên gia kiểm định đồ cũ ReMarket AI. "
                    "Hãy trả về JSON với 3 khóa: `inspectionPoints` (3-4 phần tử có `title`, `description`, `importance`: HIGH|MEDIUM|LOW), "
                    "`suggestedQuestions` (3 câu hỏi cho người bán), và `safetyTips` (mảng lời khuyên an toàn).\n"
                    "QUY TẮC BẮT BUỘC:\n"
                    "1. Bám sát danh mục sản phẩm và bắt buộc có 1 điểm kiểm tra `HIGH` xác minh trực tiếp khuyết điểm đã khai báo.\n"
                    "2. Không cam kết sản phẩm không có lỗi ngoài danh sách kiểm tra.\n"
                    "3. Viết bằng tiếng Việt rõ ràng, thực tế."
                )
                user_prompt = (
                    f"- Tên sản phẩm: {title}\n"
                    f"- Thương hiệu: {brand}\n"
                    f"- Danh mục: {category}\n"
                    f"- Tình trạng khai báo: {condition}\n"
                    f"- Khuyết điểm người bán khai báo: {defects_text}\n"
                    f"- Mô tả thêm: {detail.get('description') or 'Không có'}\n\n"
                    f"Tài liệu hướng dẫn kiểm tra từ ReMarket RAG:\n{rag_context or 'Áp dụng quy chuẩn kiểm định đồ cũ ReMarket.'}"
                )
                resp_msg = await invoke_llm_with_resilience(
                    active_llm,
                    [SystemMessage(content=sys_prompt), HumanMessage(content=user_prompt)],
                    timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
                    max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
                )
                usage = extract_token_usage(resp_msg).model_dump()
                raw_text = (
                    resp_msg.content
                    if isinstance(resp_msg.content, str)
                    else str(resp_msg.content)
                )
                parsed = _extract_json_dict(raw_text)
                if parsed:
                    if isinstance(parsed.get("inspectionPoints"), list):
                        points_list = [
                            p for p in parsed["inspectionPoints"][:4] if isinstance(p, dict)
                        ]
                    if isinstance(parsed.get("suggestedQuestions"), list):
                        questions_list = [
                            str(q).strip()
                            for q in parsed["suggestedQuestions"][:3]
                            if str(q).strip()
                        ]
                    if isinstance(parsed.get("safetyTips"), list):
                        llm_safety_tips = [
                            str(s).strip()
                            for s in parsed["safetyTips"]
                            if str(s).strip()
                        ]
            except Exception as exc:
                logger.warning(
                    "Gemini inspection generation fallback to deterministic checklist: %s",
                    exc,
                )

        if len(points_list) < 3:
            defect_point_desc = (
                f"Kiểm tra kỹ vị trí khuyết điểm người bán đã khai báo ({defects_text}) xem có ảnh hưởng đến chức năng cốt lõi hoặc lan rộng hơn mô tả hay không."
                if has_defects
                else f"Kiểm tra tổng thể ngoại hình của {title} dưới ánh sáng tốt để đối chiếu với mức tình trạng '{condition}' mà người bán đăng tải."
            )
            points_list = [
                {
                    "title": "Xác minh thực tế khuyết điểm và ngoại hình đã khai báo",
                    "description": defect_point_desc,
                    "importance": InspectionImportanceEnum.HIGH.value,
                }
            ]

            if domain == "electronics":
                points_list.extend(
                    [
                        {
                            "title": "Kiểm tra màn hình, cảm ứng và các cổng kết nối phần cứng",
                            "description": "Mở nền trắng/đen kiểm tra điểm chết, ám màn, độ nhạy cảm ứng/phím bấm, cắm thử sạc, kiểm tra Wi-Fi, Bluetooth, loa, mic và camera.",
                            "importance": InspectionImportanceEnum.HIGH.value,
                        },
                        {
                            "title": "Kiểm tra tài khoản bảo mật (iCloud / Google / MDM) và IMEI/Serial",
                            "description": "Đảm bảo thiết bị đã đăng xuất hoàn toàn tài khoản ẩn, không bị khóa từ xa và trùng khớp số Serial/IMEI trên vỏ máy.",
                            "importance": InspectionImportanceEnum.HIGH.value,
                        },
                        {
                            "title": "Đánh giá dung lượng pin thực tế và nhiệt độ khi hoạt động",
                            "description": "Theo dõi phần trăm pin trong 10–15 phút sử dụng liên tục để phát hiện tình trạng tụt pin ảo hoặc nóng máy bất thường.",
                            "importance": InspectionImportanceEnum.MEDIUM.value,
                        },
                    ]
                )
            elif domain == "furniture":
                points_list.extend(
                    [
                        {
                            "title": "Kiểm tra kết cấu chịu lực, khớp nối và ốc vít",
                            "description": "Lắc nhẹ sản phẩm để kiểm tra độ vững chắc, đảm bảo khung không bị cong vênh, nứt gãy hoặc mối mọt.",
                            "importance": InspectionImportanceEnum.HIGH.value,
                        },
                        {
                            "title": "Kiểm tra bề mặt chất liệu, lớp sơn/da/vải bọc",
                            "description": "Quan sát kỹ các vết bong tróc, ố màu, mùi ẩm mốc hoặc vết rách ở các góc khuất.",
                            "importance": InspectionImportanceEnum.MEDIUM.value,
                        },
                        {
                            "title": "Đo đạc kích thước thực tế và khả năng tháo lắp vận chuyển",
                            "description": "Đo chiều dài, rộng, cao để chắc chắn vừa với không gian dự kiến và kiểm tra phụ kiện tháo lắp đi kèm.",
                            "importance": InspectionImportanceEnum.LOW.value,
                        },
                    ]
                )
            else:
                points_list.extend(
                    [
                        {
                            "title": "Kiểm tra chức năng sử dụng thực tế và độ hoàn thiện",
                            "description": f"Vận hành hoặc sử dụng thử mọi tính năng chính của {title} để chắc chắn sản phẩm hoạt động ổn định đúng như mô tả.",
                            "importance": InspectionImportanceEnum.HIGH.value,
                        },
                        {
                            "title": "Kiểm tra phụ kiện đi kèm, tem nhãn và nguồn gốc sản phẩm",
                            "description": "Đối chiếu đầy đủ phụ kiện, hộp, hóa đơn hoặc mã hiệu thương hiệu (nếu có) như người bán đã thông tin.",
                            "importance": InspectionImportanceEnum.MEDIUM.value,
                        },
                        {
                            "title": "Kiểm tra các chi tiết hao mòn tự nhiên ở góc cạnh hoặc khớp nối",
                            "description": "Quan sát kỹ các bộ phận chịu ma sát nhiều để đánh giá tuổi thọ sử dụng còn lại của sản phẩm.",
                            "importance": InspectionImportanceEnum.LOW.value,
                        },
                    ]
                )

        # Ensure Disclosed Defects are explicitly mentioned in at least one inspection point if present
        if has_defects:
            combined_desc = " ".join(str(p.get("description", "")) for p in points_list).lower()
            if defects_text.lower() not in combined_desc:
                points_list[0]["description"] = (
                    f"{points_list[0].get('description', '')} (Lưu ý kiểm tra kỹ khuyết điểm đã khai báo: {defects_text})"
                ).strip()

        return {
            "inspection_points": points_list[:4],
            "suggested_questions": questions_list,
            "rag_safety_tips": llm_safety_tips or state.get("rag_safety_tips") or [],
            "token_usage": usage,
            "model_name": model_used,
        }

    @trace_graph_node("inspection_graph", "generate_seller_questions")
    async def generate_seller_questions_node(
        state: InspectionGraphState,
    ) -> dict[str, Any]:
        existing_questions = state.get("suggested_questions") or []
        detail = state.get("product_detail") or {}
        analysis = state.get("product_analysis") or {}
        title = detail.get("title", "sản phẩm")
        has_defects = analysis.get("has_disclosed_defects", False)
        defects_text = analysis.get("disclosed_defects_text", "")

        fallback_questions = [
            (
                f"Ngoài khuyết điểm đã nêu ({defects_text}), {title} còn lỗi phát sinh nào khác hoặc đã từng sửa chữa/thay thế linh kiện chưa?"
                if has_defects
                else f"Sản phẩm {title} đã sử dụng thực tế bao lâu và đã từng qua sửa chữa, bảo hành hay thay thế bộ phận nào chưa?"
            ),
            "Bạn có thể quay video cận cảnh sản phẩm đang hoạt động thực tế dưới ánh sáng rõ trước khi hẹn gặp được không?",
            "Sản phẩm còn đầy đủ phụ kiện đi kèm không và mình có thể kiểm tra trực tiếp tại địa điểm công cộng trước khi thanh toán chứ?",
        ]

        merged: list[str] = []
        for q in list(existing_questions) + fallback_questions:
            cleaned = q.strip()
            if cleaned and cleaned not in merged:
                merged.append(cleaned)
            if len(merged) == 3:
                break

        return {"suggested_questions": merged[:3]}

    @trace_graph_node("inspection_graph", "validate_output")
    async def validate_output_node(state: InspectionGraphState) -> dict[str, Any]:
        raw_points = state.get("inspection_points") or []
        validated_points: list[InspectionPointItem] = []
        for p in raw_points[:4]:
            if isinstance(p, InspectionPointItem):
                validated_points.append(p)
            elif isinstance(p, dict):
                imp_raw = str(p.get("importance", "HIGH")).upper()
                if imp_raw not in ("HIGH", "MEDIUM", "LOW"):
                    imp_raw = "HIGH"
                validated_points.append(
                    InspectionPointItem(
                        title=str(p.get("title") or "Điểm kiểm tra thực tế").strip(),
                        description=str(
                            p.get("description")
                            or "Kiểm tra trực tiếp tình trạng và chức năng của sản phẩm trước khi nhận hàng."
                        ).strip(),
                        importance=InspectionImportanceEnum(imp_raw),
                    )
                )

        questions = list(state.get("suggested_questions") or [])[:3]
        safety_tips = list(state.get("rag_safety_tips") or [])
        if not safety_tips:
            safety_tips = [
                "Luôn kiểm tra trực tiếp sản phẩm tại nơi công cộng và không chuyển khoản đặt cọc trước khi nhận hàng."
            ]

        usage = state.get("token_usage") or {
            "input_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
        }

        validated_resp = BuyerChecklistResponse(
            productId=state.get("product_id"),
            inspectionPoints=validated_points,
            suggestedQuestions=questions,
            safetyTips=safety_tips,
            safetyTip=safety_tips[0],
            advisoryOnly=True,
            aiProvider=state.get("model_name") or resolved_settings.GEMINI_MODEL,
            tokenUsage=usage,
            requestId=get_request_id(),
        )
        return {"validated_output": validated_resp.model_dump()}

    graph = StateGraph(InspectionGraphState)
    graph.add_node("get_product_detail", get_product_detail_node)
    graph.add_node("analyze_product_info", analyze_product_info_node)
    graph.add_node("retrieve_inspection_knowledge", retrieve_inspection_knowledge_node)
    graph.add_node("generate_inspection_points", generate_inspection_points_node)
    graph.add_node("generate_seller_questions", generate_seller_questions_node)
    graph.add_node("validate_output", validate_output_node)

    graph.add_edge(START, "get_product_detail")
    graph.add_edge("get_product_detail", "analyze_product_info")
    graph.add_edge("analyze_product_info", "retrieve_inspection_knowledge")
    graph.add_edge("retrieve_inspection_knowledge", "generate_inspection_points")
    graph.add_edge("generate_inspection_points", "generate_seller_questions")
    graph.add_edge("generate_seller_questions", "validate_output")
    graph.add_edge("validate_output", END)

    return graph


def compile_inspection_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    backend_client: Optional[BackendClient] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the Buyer Inspection Checklist graph."""
    builder = build_inspection_state_graph(
        llm=llm,
        factory=factory,
        rag_pipeline=rag_pipeline,
        backend_client=backend_client,
        settings=settings,
    )
    return builder.compile()
