# ReMarket AI Service (`apps/ai`)

Python **FastAPI + LangGraph Multi-Agent + Google Gemini (`gemini-3.8-flash`) + RAG** microservice powering the 4 intelligent second-hand marketplace capabilities of **ReMarket**:

1. **Agent 1 — Listing Generator (`listing_graph`)**: Generates transparent, editable product listings from seller inputs and images while preserving 100% of disclosed defects and never fabricating brand or hardware specs.
2. **Agent 2 — Smart Price Estimator (`pricing_graph`)**: Recommends 3 VND price tiers (`quickSellPrice`, `recommendedPrice`, `maxFairPrice`) by blending real comparable products from NestJS Backend with condition & defect depreciation analysis.
3. **Agent 3 — Buyer Inspection Checklist (`inspection_graph`)**: Generates 3–4 tailored physical inspection points (`HIGH | MEDIUM | LOW`), 3 seller questions, and safety tips combining real product details via Tools and ReMarket RAG guides.
4. **Agent 4 — Secondhand Shopping Assistant (`shopping_assistant_graph`)**: Multi-turn stateful conversational assistant with 4 branches (`PRODUCT_DISCOVERY`, `PRODUCT_COMPARISON`, `BUYING_ADVICE`, `GENERAL_CONVERSATION`), `thread_id` checkpointer memory, and per-user authentication isolation.
5. **Supervisor Graph (`supervisor_graph`)**: Classifies top-level user intents (`GENERATE_LISTING`, `ESTIMATE_PRICE`, `BUYER_INSPECTION`, `SHOPPING_ASSISTANT`, `GENERAL`) and routes execution to the specialized subgraph with safe fallback.

---

## 1. Agent Architecture

```text
FastAPI (`app/main.py` & `app/api/routes/agents.py`)
  └── AI Application Layer (`AgentApplicationService` in `app/services/agent_service.py`)
        ├── Rate Limiter (`InMemoryRateLimiter`) & Auth Context (`VerifiedUserContext`)
        └── LangGraph Supervisor (`supervisor_graph`) / Direct Subgraph Execution
              ├── Agent 1: `listing_graph`             (Multimodal + RAG + Structured Output)
              ├── Agent 2: `pricing_graph`             (Backend Tools + Condition Depreciation)
              ├── Agent 3: `inspection_graph`          (Backend Tools + RAG Inspection/Safety Guides)
              └── Agent 4: `shopping_assistant_graph`  (4-Branch Stateful Graph + Tools + RAG + Checkpointer)
```

### Human-in-the-Loop & Safety Guarantees
- **Listing Generator**: Never auto-publishes a listing (`requiresSellerApproval: true`). All fields remain editable by the seller.
- **Smart Price Estimator**: Seller makes the final pricing decision (`requiresSellerDecision: true`). Explicitly distinguishes real Backend comparable data from AI estimation (`dataSourceNote`, `comparableCount`).
- **Buyer Inspection Checklist**: Advisory checklist for in-person verification only (`advisoryOnly: true`); never guarantees an uninspected item is defect-free.
- **Shopping Assistant**: Never places orders or executes payments (`requiresBuyerConfirmation: true`). Every product in `matchedProducts` comes strictly from Backend Tools or verified catalog data and carries a real MongoDB ObjectId (`id`).

---

## 2. Graph Flows

### 2.1 Agent 1 — Listing Generator (`app/graphs/listing_graph.py`)
```text
START
  -> validate_input
  -> analyze_product_info
  -> analyze_images
  -> retrieve_relevant_knowledge
  -> generate_listing
  -> validate_structured_output
  -> END
```

### 2.2 Agent 2 — Smart Price Estimator (`app/graphs/pricing_graph.py`)
```text
START
  -> validate_product_info
  -> search_comparable_products
  -> analyze_product_condition
  -> estimate_price
  -> generate_explanation
  -> validate_output
  -> END
```

### 2.3 Agent 3 — Buyer Inspection Checklist (`app/graphs/inspection_graph.py`)
```text
START
  -> get_product_detail
  -> analyze_product_info
  -> retrieve_inspection_knowledge
  -> generate_inspection_points
  -> generate_seller_questions
  -> validate_output
  -> END
```

### 2.4 Agent 4 — Secondhand Shopping Assistant (`app/graphs/shopping_assistant_graph.py`)
```text
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
```

### 2.5 Supervisor Graph (`app/graphs/supervisor_graph.py`)
```text
START
  -> classify_intent
      ├── GENERATE_LISTING   -> execute_listing_subgraph
      ├── ESTIMATE_PRICE     -> execute_pricing_subgraph
      ├── BUYER_INSPECTION   -> execute_inspection_subgraph
      ├── SHOPPING_ASSISTANT -> execute_shopping_subgraph
      └── GENERAL (fallback) -> execute_general_fallback
  -> finalize_supervisor_output
  -> END
```

---

## 3. Tool Registry (`app/tools/`)

All tools are strictly **read-only** and communicate with NestJS Backend (`apps/backend`) via `BackendClient` (`httpx.AsyncClient` with connection pooling, timeouts, bounded retries, `X-Request-ID` propagation, and verified user auth forwarding):

| Tool Name | Module | Backend Endpoint | Description |
| :--- | :--- | :--- | :--- |
| `search_products` | `app/tools/product_tools.py` | `GET /api/v1/products?keyword=...` | Full-text product search with pagination & sort |
| `filter_products` | `app/tools/product_tools.py` | `GET /api/v1/products?category=...&minPrice=...&maxPrice=...&condition=...` | Multi-criteria catalog filtering |
| `get_product_detail` | `app/tools/product_tools.py` | `GET /api/v1/products/:id` | Fetch full product details including `defectDisclosure` & `images` |
| `get_related_products` | `app/tools/product_tools.py` | Composes `GET /api/v1/products/:id` + `GET /api/v1/products` | Find comparable/related active listings |
| `get_product_categories` | `app/tools/category_tools.py` | `GET /api/v1/categories` | List active ReMarket product categories |
| `get_seller_public_profile` | `app/tools/user_tools.py` | `GET /api/v1/users/:id/public` | Public seller profile sanitized via `PublicSellerProfileOutput` allowlist |

---

## 4. RAG Architecture (`app/rag/`)

```text
app/rag/
├── schemas.py                  # KnowledgeCategory, RAGDocumentMetadata, RAGChunkMetadata, RAGRetrievalResult
├── loaders/                    # MarkdownDocumentLoader, PDFDocumentLoader, prompt-injection sanitizer
├── splitters/                  # MarkdownAwareTextSplitter (preserves headings & metadata)
├── embeddings/                 # GeminiEmbeddingProvider (`gemini-embedding-001` via `google-genai`)
├── vectorstores/               # ChromaVectorStore (persistent) & InMemoryVectorStore
├── retrievers/                 # SemanticKnowledgeRetriever (top_k, similarity_threshold, category filter)
├── pipelines/rag_pipeline.py   # Grounded context assembly (`<retrieved_knowledge_context>`) + citations
├── ingestion.py                # SHA-256 content-hash deduplication, update, and deletion
└── cli.py                      # CLI for `ingest` and `query`
```

Knowledge base files in `data/knowledge_base/`:
1. `01_remarket_policies.md` (`policy`)
2. `02_safe_trading_guide.md` (`safety_guide`)
3. `03_product_inspection_guide.md` (`inspection_guide`)
4. `04_condition_grading_guide.md` (`condition_grading`)
5. `05_student_transaction_guide.md` (`student_transaction`)
6. `06_platform_usage_guide.md` (`platform_guide`)

---

## 5. API Endpoints & Request / Response Examples

### 5.1 `POST /ai/generate-listing` (Agent 1)
**Request:**
```json
{
  "productName": "Bàn phím cơ Keychron K2 V2 Brown Switch",
  "brand": "Keychron",
  "category": "Máy tính & Phụ kiện",
  "condition": "GOOD",
  "defects": "Trầy nhẹ góc phải khung nhôm, pin còn dùng tốt 4 ngày",
  "originalPrice": 2100000,
  "sellingPrice": 1150000,
  "images": ["https://cdn.remarket.vn/keychron-k2.jpg"]
}
```
**Response:**
```json
{
  "suggestedTitle": "Keychron Bàn phím cơ Keychron K2 V2 Brown Switch - Tốt 85-94% (GOOD)",
  "suggestedDescription": {
    "overview": "Nhượng lại Keychron Bàn phím cơ Keychron K2 V2 Brown Switch thuộc danh mục Máy tính & Phụ kiện...",
    "condition": "Phân loại tình trạng: Tốt 85-94% (GOOD)...",
    "defects": "Khuyết điểm người bán đã khai báo: Trầy nhẹ góc phải khung nhôm, pin còn dùng tốt 4 ngày"
  },
  "suggestedCategory": "Máy tính & Phụ kiện",
  "suggestedTags": ["#keychron", "#good", "#sinhvien", "#remarket"],
  "transparencyNote": "Đã bảo toàn khai báo khuyết điểm (Tốt 85-94% (GOOD)): Trầy nhẹ góc phải khung nhôm, pin còn dùng tốt 4 ngày",
  "transparencyScore": 96,
  "needsMoreInfo": false,
  "clarificationQuestions": [],
  "requiresSellerApproval": true
}
```

### 5.2 `POST /ai/estimate-price` (Agent 2)
**Request:**
```json
{
  "productName": "Laptop Lenovo ThinkPad T14 Gen 1",
  "brand": "Lenovo",
  "category": "Máy tính & Phụ kiện",
  "condition": "LIKE_NEW",
  "defects": "Xước dăm nhẹ nắp lưng",
  "originalPrice": 18000000
}
```
**Response:**
```json
{
  "quickSellPrice": 9970000,
  "recommendedPrice": 11330000,
  "maxFairPrice": 12690000,
  "currency": "VND",
  "reasoning": "Kết hợp dữ liệu thực tế từ 1 sản phẩm tương đồng trên Backend ReMarket...",
  "factors": [
    "Tình trạng thực tế: LIKE_NEW (khấu hao ước tính ~33%)",
    "Giá mua mới khai báo: 18,000,000 VND",
    "Điều chỉnh theo khuyết điểm đã khai báo: Xước dăm nhẹ nắp lưng"
  ],
  "confidence": "HIGH",
  "comparableCount": 1,
  "requiresSellerDecision": true
}
```

### 5.3 `POST /ai/buyer-checklist` (Agent 3)
**Request:**
```json
{
  "productId": "65f000000000000000000102"
}
```
**Response:**
```json
{
  "productId": "65f000000000000000000102",
  "inspectionPoints": [
    {
      "title": "Xác minh thực tế khuyết điểm và ngoại hình đã khai báo",
      "description": "Kiểm tra kỹ vị trí khuyết điểm người bán đã khai báo (Trầy nhẹ góc nắp lưng, pin còn 91% dùng tốt 5 tiếng)...",
      "importance": "HIGH"
    },
    {
      "title": "Kiểm tra màn hình, cảm ứng và các cổng kết nối phần cứng",
      "description": "Mở nền trắng/đen kiểm tra điểm chết, ám màn...",
      "importance": "HIGH"
    },
    {
      "title": "Kiểm tra tài khoản bảo mật (iCloud / Google / MDM) và IMEI/Serial",
      "description": "Đảm bảo thiết bị đã đăng xuất hoàn toàn tài khoản ẩn...",
      "importance": "HIGH"
    }
  ],
  "suggestedQuestions": [
    "Ngoài khuyết điểm đã nêu (...), sản phẩm còn lỗi phát sinh nào khác hoặc đã từng sửa chữa/thay thế linh kiện chưa?",
    "Bạn có thể quay video cận cảnh sản phẩm đang hoạt động thực tế dưới ánh sáng rõ trước khi hẹn gặp được không?",
    "Sản phẩm còn đầy đủ phụ kiện đi kèm không và mình có thể kiểm tra trực tiếp tại địa điểm công cộng trước khi thanh toán chứ?"
  ],
  "safetyTips": [
    "Luôn kiểm tra trực tiếp sản phẩm ở nơi công cộng, đủ ánh sáng và chỉ thanh toán sau khi đã test xong mọi chức năng."
  ],
  "advisoryOnly": true
}
```

### 5.4 `POST /ai/chat` (Agent 4 — Multi-Turn Shopping Assistant)
**Turn 1 Request:**
```json
{
  "message": "Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu",
  "thread_id": "conv-student-01"
}
```
**Turn 2 Request (same `thread_id`):**
```json
{
  "message": "Trong số đó, con nào đáng mua nhất?",
  "thread_id": "conv-student-01"
}
```
**Response:**
```json
{
  "message": "Dựa trên **2 sản phẩm** ở lượt tìm kiếm trước (trong ngân sách dưới 10,000,000 VND của bạn)... 🏆 **Đáng mua nhất: Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ**...",
  "thread_id": "conv-student-01",
  "intent": "PRODUCT_COMPARISON",
  "matchedProducts": [
    {
      "id": "65f000000000000000000102",
      "title": "Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ",
      "price": 8500000.0,
      "condition": "LIKE_NEW",
      "defectDisclosure": "Trầy nhẹ góc nắp lưng, pin còn 91% dùng tốt 5 tiếng",
      "fitScore": 91.5
    }
  ],
  "suggestedQuestions": [
    "Tạo danh sách kiểm tra thực tế cho Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ",
    "Tôi nên hỏi người bán Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ những câu gì?"
  ],
  "sources": []
}
```

### 5.5 `POST /ai/agent/execute` (Supervisor Router)
Classifies intent (`GENERATE_LISTING | ESTIMATE_PRICE | BUYER_INSPECTION | SHOPPING_ASSISTANT | GENERAL`) and routes to the matching subgraph.

### 5.6 `GET /ai/conversations/{conversation_id}` & `DELETE /ai/conversations/{conversation_id}`
Inspect or purge conversation history for the authenticated owner (`X-Authenticated-User-Id`). Requests from a different user ID are rejected with `403 Forbidden` (`SECURITY_VIOLATION`).

---

## 6. Environment Variables

See [`.env.example`](file:///D:/cross-ck/apps/ai/.env.example) for the complete list:
- `GEMINI_API_KEY`: Google Gemini API key.
- `GEMINI_MODEL`: Defaults to `gemini-3.8-flash` (deprecated 1.5/2.0/2.5 models are blocked).
- `GEMINI_EMBEDDING_MODEL`: Defaults to `gemini-embedding-001`.
- `BACKEND_API_BASE_URL`: NestJS API root (`http://localhost:5000/api/v1`).
- `CONVERSATION_MAX_HISTORY_MESSAGES`: Sliding window cap for multi-turn memory (default `20`).
- `AI_RATE_LIMIT_REQUESTS` / `AI_RATE_LIMIT_WINDOW_SECONDS`: Per-user sliding-window rate limit.

---

## 7. How to Run and Test

```powershell
# 1. Run the FastAPI server
cd D:\cross-ck\apps\ai
python -m app.main

# 2. Run the RAG CLI (ingest & query knowledge base)
python -m app.rag.cli ingest --dir ./data/knowledge_base
python -m app.rag.cli query "Cách kiểm tra laptop cũ và giao dịch an toàn"

# 3. Run the complete unit & endpoint test suite (49 tests)
python -m pytest tests -v -m "not integration"
```
