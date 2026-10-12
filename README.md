# ReMarket — Second-Hand Marketplace Platform

ReMarket is a mobile-first second-hand marketplace application with integrated AI capabilities for transparent listing generation, 3-tier secondhand pricing, buyer inspection checklists, and a multi-turn shopping assistant.

---

## Repository Structure

```text
remarket/
├── apps/
│   ├── backend/                 # NestJS + TypeScript + MongoDB Core & AI Gateway API (:3000)
│   ├── ai/                      # Python FastAPI + LangGraph + RAG + Gemini AI Service (:8000)
│   └── fe/                      # Flutter + Riverpod 2 Mobile & Web Client
├── docs/
│   ├── api/
│   │   ├── API_CONTRACT.md      # Master REST API Contract for Flutter (Auth, Products, Orders, Payments, AI)
│   │   ├── AUTHENTICATION.md    # [FROZEN] JWT Access/Refresh Token Rotation & 401/403 Contract
│   │   ├── AI_API_CONTRACT.md   # [FROZEN] 3-Tier AI Gateway, LangGraph Workflows & Agent Tools
│   │   ├── ERROR_HANDLING.md    # [FROZEN] Standard Error Envelope & Error Code Catalog
│   │   ├── flutter-api-contract.md
│   │   ├── api-overview.md
│   │   └── ai-integration.md
│   ├── architecture/
│   │   ├── system-overview.md
│   │   ├── backend-architecture.md
│   │   ├── ORDER_WORKFLOW.md    # Order lifecycle, atomic product reservation & concurrency control
│   │   └── PAYMENT_WORKFLOW.md  # Cash, COD & 2-step Bank Transfer verification workflow
│   ├── database/
│   │   └── data-model.md        # MongoDB schemas (Users, Products, Orders, Payments, Notifications, etc.)
│   └── development/
│       ├── ENVIRONMENT.md       # [FROZEN] Complete Environment Configuration Reference
│       ├── environment-variables.md
│       └── local-setup.md
├── infrastructure/
│   └── docker/                  # Docker Compose (MongoDB 7 + NestJS Backend + Python AI Service)
├── docker-compose.yml           # Root convenience Docker Compose file
└── PROJECT_PLAN.md              # Product & UI/UX roadmap
```

---

## Core & Business Capabilities (`apps/backend` & `apps/ai`)

- **Authentication & Wishlist (`/api/v1/auth`)**: Registration, login, `bcrypt` password hashing, short-lived JWT access tokens (`15m`), stateful `bcrypt`-hashed refresh token rotation (`7d`), logout session revocation, `/api/v1/auth/me`, and user wishlist management (`GET /api/v1/auth/wishlist`, `POST /api/v1/auth/wishlist/:productId`, `DELETE /api/v1/auth/wishlist/:productId`).
- **Users (`/api/v1/users`)**: Authenticated profile inspection (`GET /api/v1/users/me`), validated profile updates (`PATCH /api/v1/users/me`), and public seller profiles (`GET /api/v1/users/:id`) with seller statistics (`activeListingsCount`, `soldListingsCount`, `rating`, `transparencyRate`).
- **Categories (`/api/v1/categories`)**: Hierarchical marketplace categories (`parentId` support) with idempotent seeding.
- **Products (`/api/v1/products`)**: Full CRUD with strict seller ownership enforcement (`403 Forbidden`), status state machine (`PATCH /api/v1/products/:id/status`), seller inventory view (`GET /api/v1/products/me/listings`), pagination, category/condition/price filtering, sorting (`sortBy`: `createdAt`, `price`, `viewsCount`; `sortOrder`: `asc`, `desc`), and keyword search.
- **Upload (`/api/v1/upload`)**: Multer multi-image upload (`POST /api/v1/upload/images` & `POST /api/v1/products/:id/images`) enforcing MIME + magic-bytes verification (`image/jpeg`, `image/png`, `image/webp`), `5MB` per-file size limit, and max `10` images per listing.
- **Messaging (`/api/v1/messages`)**: Buyer-seller conversations and messages with strict participant authorization, duplicate conversation prevention, read status tracking, and integrated `ORDER` event messages.
- **Orders, Payments & Notifications (`/api/v1/orders`, `/api/v1/notifications`)**: Complete Buyer–Seller order lifecycle (`PENDING` -> `CONFIRMED` -> `SHIPPING` -> `DELIVERED` -> `COMPLETED` / `CANCELLED` / `REJECTED`), atomic standalone-MongoDB-safe product reservation (`ACTIVE` -> `RESERVED` -> `SOLD`), partial unique active order index, 3 payment methods (`CASH`, `COD`, 2-step `BANK_TRANSFER` verification via `POST /orders/:id/payment-confirmation` and `PATCH /orders/:id/payment/confirm`), privacy-protected seller bank account exposure, and real-time in-app notifications.
- **Reports (`/api/v1/reports`)**: Listing violation reporting with anti-spam protection (`409 Conflict` on duplicate reports, `400 Bad Request` on self-reporting), optional multipart `evidence` images, and reporter privacy (`GET /api/v1/reports/me`).
- **AI Gateway (`/api/v1/ai`)**: JWT-protected gateway (`POST /api/v1/ai/generate-listing`, `POST /api/v1/ai/estimate-price`, `POST /api/v1/ai/buyer-checklist`, `POST /api/v1/ai/chat`, `GET /api/v1/ai/conversations/:conversationId`, `DELETE /api/v1/ai/conversations/:conversationId`) integrated with the Python FastAPI + LangGraph Multi-Agent Service (`apps/ai`).
- **Health & Observability (`/api/v1/health`)**: Service uptime and MongoDB connection readiness check.
- **OpenAPI / Swagger (`/api/docs`)**: Interactive API documentation with Bearer JWT support at `http://localhost:3000/api/docs`.

---

## Quick Start

### 1. Local Development
```powershell
# 1. Start MongoDB
docker compose -f infrastructure/docker/docker-compose.yml up -d mongodb

# 2. Start Python AI Service (:8000)
cd apps/ai
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 3. Seed & Start NestJS Backend (:3000)
cd apps/backend
npm install
npm run seed
npm run start:dev
```
- **API Base URL**: `http://localhost:3000/api/v1`
- **Swagger UI**: `http://localhost:3000/api/docs`
- **Health Endpoint**: `http://localhost:3000/api/v1/health`

### 2. Testing & Quality Verification
```powershell
# 1. Run Python AI Service Test Suite (54 tests)
cd apps/ai
pytest -q

# 2. Run NestJS Unit & E2E Test Suites (43 unit + 33 e2e tests)
cd apps/backend
npm test
npm run test:e2e
npm run build

# 3. Run Flutter Static Analysis & Widget/Unit Test Suite (41 tests)
cd apps/fe
flutter analyze
flutter test
```
