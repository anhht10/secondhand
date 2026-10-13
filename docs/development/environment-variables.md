# ReMarket — Environment Variables Reference

> **Canonical Reference**: See **[`docs/development/ENVIRONMENT.md`](file:///d:/cross-ck/docs/development/ENVIRONMENT.md)** for the complete Phase 7 Frozen Environment Reference.

## 1. NestJS Backend (`apps/backend/.env`)

| Variable | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `NODE_ENV` | No | `development` | Execution environment (`development`, `test`, `production`). |
| `PORT` | No | `3000` | HTTP port the NestJS server listens on. |
| `API_PREFIX` | No | `api/v1` | Global REST route prefix. |
| `CORS_ORIGIN` | No | `*` | Allowed CORS origins. |
| `MONGODB_URI` | Yes (Prod) | `mongodb://localhost:27017/remarket` | Primary MongoDB connection URI. |
| `JWT_SECRET` | Yes (Prod) | `dev-jwt-secret-change-in-production` | Secret key used to sign short-lived JWT access tokens. |
| `JWT_EXPIRES_IN` | No | `15m` | Access token lifetime. |
| `JWT_REFRESH_SECRET` | Yes (Prod) | `dev-jwt-refresh-secret-change-in-production` | Secret key used to sign JWT refresh tokens. |
| `JWT_REFRESH_EXPIRES_IN` | No | `7d` | Refresh token lifetime. |
| `AI_SERVICE_URL` | No | `http://localhost:8000` | Base URL of the Python FastAPI + LangGraph AI Service. |
| `AI_SERVICE_TIMEOUT_MS` | No | `30000` | Timeout in milliseconds for NestJS -> Python AI HTTP calls. |
| `STORAGE_DRIVER` | No | `local` | File storage backend (`local` or `s3`). |
| `UPLOAD_DIR` | No | `uploads` | Local directory for Multer image uploads. |
| `PUBLIC_BASE_URL` | No | `http://localhost:3000` | Public base URL used to construct uploaded image URLs. |

---

## 2. Python AI Service (`apps/ai/.env`)

| Variable | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `PORT` | No | `8000` | Port on which the FastAPI AI service listens. |
| `GEMINI_API_KEY` | Recommended | `""` | Google Gemini API Key (falls back to deterministic output if omitted/quota exceeded). |
| `GEMINI_MODEL` | No | `gemini-3.8-flash` | Configured Gemini generation model. |
| `GEMINI_TIMEOUT_SECONDS` | No | `25` | Timeout in seconds per Gemini API request. |
| `BACKEND_API_URL` | No | `http://localhost:3000/api/v1` | Base URL of the NestJS Backend API used by LangGraph Agent Tools. |
| `CHECKPOINTER_TYPE` | No | `memory` | LangGraph checkpointer backend (`memory` or `sqlite`). |
| `RAG_ENABLED` | No | `true` | Enable RAG knowledge retrieval. |
| `RAG_TOP_K` | No | `3` | Number of knowledge chunks retrieved per query. |
