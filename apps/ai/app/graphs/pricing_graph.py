"""
Agent 2: Smart Price Estimator LangGraph Workflow (`app.graphs.pricing_graph`).

Topology:
START
  -> validate_product_info
  -> search_comparable_products
  -> analyze_product_condition
  -> estimate_price
  -> generate_explanation
  -> validate_output
  -> END
"""

import json
import logging
import re
import statistics
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
from app.schemas.agents import EstimatePriceRequest, EstimatePriceResponse
from app.services.backend_client import BackendClient, get_backend_client
from app.states.agent_states import PricingGraphState
from app.tools.product_tools import search_products_async

logger = logging.getLogger("remarket.ai.graphs.pricing")

_CONDITION_RATIOS: dict[str, float] = {
    "NEW": 0.84,
    "LIKE_NEW": 0.70,
    "GOOD": 0.55,
    "FAIR": 0.38,
}

_SEVERE_DEFECT_KEYWORDS = (
    "nứt",
    "vỡ",
    "móp",
    "hỏng",
    "liệt",
    "sọc màn",
    "ám màn",
    "chai pin",
    "mất nguồn",
    "lỗi",
)


def _round_vnd(amount: float) -> int:
    """Round VND amount to nearest 10,000 VND (or 1,000 VND for small items)."""
    if amount <= 0:
        return 10000
    if amount < 100000:
        return max(5000, int(round(amount / 1000.0) * 1000))
    return max(10000, int(round(amount / 10000.0) * 10000))


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


def build_pricing_state_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    backend_client: Optional[BackendClient] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    settings: Optional[Settings] = None,
) -> StateGraph:
    """Build the 6-node StateGraph for Agent 2 (Smart Price Estimator)."""
    resolved_settings = settings or get_settings()
    resolved_factory = factory or get_gemini_factory(resolved_settings)

    @trace_graph_node("pricing_graph", "validate_product_info")
    async def validate_product_info_node(state: PricingGraphState) -> dict[str, Any]:
        raw_req = state.get("request_data") or {}
        validated = EstimatePriceRequest.model_validate(raw_req)
        cond_upper = (validated.condition or "GOOD").strip().upper()
        if cond_upper not in _CONDITION_RATIOS:
            cond_upper = "GOOD"

        return {
            "product_name": validated.resolved_name,
            "brand": (validated.brand or "").strip(),
            "category": (validated.category or "").strip(),
            "condition": cond_upper,
            "defects": validated.resolved_defects,
            "original_price": validated.originalPrice,
            "comparable_products": list(validated.comparableProducts or []),
        }

    @trace_graph_node("pricing_graph", "search_comparable_products")
    async def search_comparable_products_node(state: PricingGraphState) -> dict[str, Any]:
        name = state.get("product_name", "")
        brand = state.get("brand", "")
        inline_comparables = list(state.get("comparable_products") or [])
        client = backend_client or get_backend_client(resolved_settings)

        fetched_items: list[dict[str, Any]] = list(inline_comparables)
        query_kw = f"{brand} {name}".strip() if brand and brand.lower() not in name.lower() else name

        try:
            search_res = await search_products_async(
                keyword=query_kw[:100],
                page=1,
                limit=8,
                client=client,
            )
            backend_items = search_res.get("items") or []
            for item in backend_items:
                if isinstance(item, dict) and item.get("price", 0) > 0:
                    fetched_items.append(item)
        except Exception as exc:
            logger.info(
                "Backend comparable search unavailable or returned error (%s); proceeding with AI estimation.",
                type(exc).__name__,
            )

        valid_prices = [
            float(item["price"])
            for item in fetched_items
            if isinstance(item, dict) and isinstance(item.get("price"), (int, float)) and float(item["price"]) > 0
        ]

        if valid_prices:
            stats = {
                "count": len(valid_prices),
                "min_price": min(valid_prices),
                "median_price": float(statistics.median(valid_prices)),
                "max_price": max(valid_prices),
                "has_backend_data": True,
            }
        else:
            stats = {
                "count": 0,
                "min_price": None,
                "median_price": None,
                "max_price": None,
                "has_backend_data": False,
            }

        return {
            "comparable_products": fetched_items,
            "comparable_stats": stats,
        }

    @trace_graph_node("pricing_graph", "analyze_product_condition")
    async def analyze_product_condition_node(state: PricingGraphState) -> dict[str, Any]:
        condition = state.get("condition", "GOOD")
        defects = state.get("defects", "")
        base_ratio = _CONDITION_RATIOS.get(condition, 0.58)

        lowered_defects = defects.lower()
        severe_hits = sum(1 for kw in _SEVERE_DEFECT_KEYWORDS if kw in lowered_defects)
        defect_penalty = min(0.20, severe_hits * 0.06) if severe_hits > 0 else (0.03 if defects else 0.0)
        effective_ratio = max(0.20, round(base_ratio - defect_penalty, 2))
        depreciation_pct = max(5, min(85, int(round((1.0 - effective_ratio) * 100))))

        rag_context = ""
        if rag_pipeline is not None:
            try:
                res = rag_pipeline.query(
                    f"Tiêu chuẩn phân loại tình trạng {condition} và tỷ lệ giá tham khảo",
                    top_k=2,
                    similarity_threshold=0.25,
                    category="condition_grading",
                )
                if res.has_sufficient_context:
                    rag_context = res.grounded_context
            except Exception:
                pass

        return {
            "condition_analysis": {
                "condition": condition,
                "base_ratio": base_ratio,
                "defect_penalty": defect_penalty,
                "effective_ratio": effective_ratio,
                "depreciation_percent": depreciation_pct,
                "has_defects": bool(defects),
            },
            "rag_context": rag_context,
        }

    @trace_graph_node("pricing_graph", "estimate_price")
    async def estimate_price_node(state: PricingGraphState) -> dict[str, Any]:
        orig_price = state.get("original_price")
        comp_stats = state.get("comparable_stats") or {}
        cond_analysis = state.get("condition_analysis") or {}
        effective_ratio = float(cond_analysis.get("effective_ratio", 0.60))

        comp_count = int(comp_stats.get("count", 0))
        median_comp = comp_stats.get("median_price")

        warnings: list[str] = []
        if comp_count > 0 and median_comp and orig_price and orig_price > 0:
            # Blend real Backend comparable median (60% weight) with condition-adjusted originalPrice (40% weight)
            formula_price = float(orig_price) * effective_ratio
            base_recommended = 0.6 * float(median_comp) + 0.4 * formula_price
            confidence = "HIGH"
        elif comp_count > 0 and median_comp:
            base_recommended = float(median_comp)
            confidence = "MEDIUM"
            warnings.append(
                "Người bán chưa cung cấp giá mua mới (originalPrice); mức giá dựa trên các tin đăng tương đồng trên ReMarket."
            )
        elif orig_price and orig_price > 0:
            base_recommended = float(orig_price) * effective_ratio
            confidence = "MEDIUM"
            warnings.append(
                "Chưa có sản phẩm tương đồng đang đăng trên Backend ReMarket; mức giá là ước tính của AI từ giá mua mới và tình trạng."
            )
        else:
            # Fallback when neither comparable listings nor originalPrice is available
            base_recommended = 500000.0 * effective_ratio
            confidence = "LOW"
            warnings.append(
                "Thiếu cả dữ liệu sản phẩm tương đồng trên Backend lẫn giá mua mới (originalPrice). Độ tin cậy ước tính thấp."
            )

        recommended = _round_vnd(base_recommended)
        quick_sell = _round_vnd(recommended * 0.88)
        max_fair = _round_vnd(recommended * 1.12)
        if quick_sell > recommended:
            quick_sell = recommended
        if max_fair < recommended:
            max_fair = recommended

        return {
            "estimated_prices": {
                "quickSellPrice": quick_sell,
                "recommendedPrice": recommended,
                "maxFairPrice": max_fair,
                "confidence": confidence,
                "warnings": warnings,
            }
        }

    @trace_graph_node("pricing_graph", "generate_explanation")
    async def generate_explanation_node(state: PricingGraphState) -> dict[str, Any]:
        name = state.get("product_name", "")
        brand = state.get("brand", "")
        condition = state.get("condition", "GOOD")
        defects = state.get("defects", "")
        orig_price = state.get("original_price")
        comp_stats = state.get("comparable_stats") or {}
        cond_analysis = state.get("condition_analysis") or {}
        est = state.get("estimated_prices") or {}

        comp_count = int(comp_stats.get("count", 0))
        depreciation_pct = int(cond_analysis.get("depreciation_percent", 35))
        rec_price = int(est.get("recommendedPrice", 300000))
        quick_price = int(est.get("quickSellPrice", 260000))
        max_price = int(est.get("maxFairPrice", 340000))

        factors: list[str] = [
            f"Tình trạng thực tế: {condition} (khấu hao ước tính ~{depreciation_pct}%)",
        ]
        if orig_price and orig_price > 0:
            factors.append(f"Giá mua mới khai báo: {int(orig_price):,} VND")
        if defects:
            factors.append(f"Điều chỉnh theo khuyết điểm đã khai báo: {defects}")
        if comp_count > 0:
            factors.append(
                f"Dữ liệu thực tế từ {comp_count} tin đăng tương đồng trên ReMarket "
                f"(trung vị: {int(comp_stats['median_price']):,} VND)"
            )
        else:
            factors.append("Ước tính từ AI (hiện chưa có tin đăng tương đồng trực tiếp trên Backend)")

        if comp_count > 0:
            data_source_note = (
                f"Kết hợp dữ liệu thực tế từ {comp_count} sản phẩm tương đồng trên Backend ReMarket "
                f"(khoảng giá {int(comp_stats['min_price']):,} - {int(comp_stats['max_price']):,} VND) "
                "và mô hình khấu hao theo tình trạng của AI."
            )
        else:
            data_source_note = (
                "Không có dữ liệu sản phẩm tương đồng từ Backend ReMarket ở thời điểm truy vấn. "
                "Ba mức giá này hoàn toàn là ước tính của AI dựa trên tình trạng, khuyết điểm và giá gốc."
            )

        default_reasoning = (
            f"{data_source_note} Với tình trạng {condition} (khấu hao ~{depreciation_pct}%)"
            + (f" và lưu ý khuyết điểm '{defects}'" if defects else "")
            + f", mức giá đề xuất {rec_price:,} VND cân bằng giữa quyền lợi người bán và khả năng thanh khoản cho sinh viên "
            f"(Bán nhanh: {quick_price:,} VND | Tối đa hợp lý: {max_price:,} VND)."
        )

        active_llm = llm
        if active_llm is None and resolved_settings.has_gemini_api_key:
            active_llm = resolved_factory.get_chat_model()

        token_usage = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
        model_name = resolved_settings.GEMINI_MODEL
        reasoning_text = default_reasoning
        demand: str = "HIGH" if condition in ("NEW", "LIKE_NEW") else "MEDIUM"

        if active_llm is not None:
            model_name = str(getattr(active_llm, "model", resolved_settings.GEMINI_MODEL))
            prompt = (
                "Bạn là Chuyên gia Định giá Đồ cũ (Smart Price Estimator) của ReMarket.\n"
                "QUY TẮC BẮT BUỘC:\n"
                "1. Phân biệt rõ dữ liệu thực tế từ Backend (số lượng tin tương đồng = "
                f"{comp_count}) và ước tính của AI.\n"
                "2. Nếu số lượng tin tương đồng = 0, TUYỆT ĐỐI KHÔNG tuyên bố có dữ liệu giao dịch thị trường.\n"
                "3. Trả về JSON: {\"quickSellPrice\": int, \"recommendedPrice\": int, \"maxFairPrice\": int, "
                "\"reasoning\": str, \"factors\": [str], \"marketDemand\": \"HIGH\"|\"MEDIUM\"|\"LOW\"}.\n\n"
                f"Sản phẩm: {brand} {name} | Tình trạng: {condition} | Khuyết điểm: {defects or 'Không'}\n"
                f"Giá gốc: {orig_price or 'Chưa rõ'} | Giá tính toán cơ sở: {quick_price} / {rec_price} / {max_price} VND."
            )
            try:
                response_msg = await invoke_llm_with_resilience(
                    active_llm,
                    [SystemMessage(content="Trả về JSON định giá minh bạch."), HumanMessage(content=prompt)],
                    timeout_seconds=resolved_settings.GEMINI_TIMEOUT_SECONDS,
                    max_attempts=max(1, resolved_settings.GEMINI_MAX_RETRIES + 1),
                )
                token_usage = extract_token_usage(response_msg).model_dump()
                raw_content = (
                    response_msg.content
                    if isinstance(response_msg.content, str)
                    else str(response_msg.content)
                )
                parsed = _extract_json_dict(raw_content)
                if parsed:
                    if isinstance(parsed.get("reasoning"), str) and parsed["reasoning"].strip():
                        reasoning_text = parsed["reasoning"].strip()
                    if isinstance(parsed.get("factors"), list) and parsed["factors"]:
                        factors = [str(f) for f in parsed["factors"] if str(f).strip()]
                    if parsed.get("marketDemand") in ("HIGH", "MEDIUM", "LOW"):
                        demand = str(parsed["marketDemand"])
            except Exception as exc:
                logger.warning(
                    "Gemini pricing explanation fallback to deterministic output: %s",
                    exc,
                )

        return {
            "explanation": {
                "reasoning": reasoning_text,
                "factors": factors,
                "dataSourceNote": data_source_note,
                "marketDemand": demand,
            },
            "token_usage": token_usage,
            "model_name": model_name,
        }

    @trace_graph_node("pricing_graph", "validate_output")
    async def validate_output_node(state: PricingGraphState) -> dict[str, Any]:
        est = state.get("estimated_prices") or {}
        expl = state.get("explanation") or {}
        comp_stats = state.get("comparable_stats") or {}
        cond_analysis = state.get("condition_analysis") or {}

        quick_sell = int(est.get("quickSellPrice", 250000))
        recommended = int(est.get("recommendedPrice", 300000))
        max_fair = int(est.get("maxFairPrice", 350000))

        # Guarantee monotonic ordering: quickSellPrice <= recommendedPrice <= maxFairPrice
        sorted_prices = sorted([max(0, quick_sell), max(0, recommended), max(0, max_fair)])
        quick_sell, recommended, max_fair = sorted_prices[0], sorted_prices[1], sorted_prices[2]

        validated = EstimatePriceResponse(
            quickSellPrice=quick_sell,
            recommendedPrice=recommended,
            maxFairPrice=max_fair,
            currency="VND",
            reasoning=str(expl.get("reasoning") or "Ước tính giá dựa trên tình trạng và khuyết điểm."),
            factors=list(expl.get("factors") or []),
            confidence=est.get("confidence", "MEDIUM"),
            dataSourceNote=str(expl.get("dataSourceNote") or ""),
            warnings=list(est.get("warnings") or []),
            comparableCount=int(comp_stats.get("count", 0)),
            depreciationPercent=int(cond_analysis.get("depreciation_percent", 30)),
            marketDemand=expl.get("marketDemand", "MEDIUM"),
            requiresSellerDecision=True,
            aiProvider=str(state.get("model_name") or resolved_settings.GEMINI_MODEL),
        )
        return {"validated_output": validated.model_dump()}

    workflow = StateGraph(PricingGraphState)
    workflow.add_node("validate_product_info", validate_product_info_node)
    workflow.add_node("search_comparable_products", search_comparable_products_node)
    workflow.add_node("analyze_product_condition", analyze_product_condition_node)
    workflow.add_node("estimate_price", estimate_price_node)
    workflow.add_node("generate_explanation", generate_explanation_node)
    workflow.add_node("validate_output", validate_output_node)

    workflow.add_edge(START, "validate_product_info")
    workflow.add_edge("validate_product_info", "search_comparable_products")
    workflow.add_edge("search_comparable_products", "analyze_product_condition")
    workflow.add_edge("analyze_product_condition", "estimate_price")
    workflow.add_edge("estimate_price", "generate_explanation")
    workflow.add_edge("generate_explanation", "validate_output")
    workflow.add_edge("validate_output", END)
    return workflow


def compile_pricing_graph(
    *,
    llm: Optional[BaseChatModel] = None,
    factory: Optional[GeminiModelFactory] = None,
    backend_client: Optional[BackendClient] = None,
    rag_pipeline: Optional[RAGPipeline] = None,
    settings: Optional[Settings] = None,
) -> CompiledStateGraph:
    """Compile the Agent 2 Smart Price Estimator StateGraph."""
    graph = build_pricing_state_graph(
        llm=llm,
        factory=factory,
        backend_client=backend_client,
        rag_pipeline=rag_pipeline,
        settings=settings,
    )
    return graph.compile()
