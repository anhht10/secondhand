# ReMarket — Local Development Setup Guide

## 1. Prerequisites

- **Node.js**: v20.x LTS or newer (verified with Node v20–v26)
- **npm**: v10+
- **MongoDB**: Local MongoDB 7.0+ running on `127.0.0.1:27017` **OR** Docker Desktop (`docker compose`)

---

## 2. Option A: Run Locally with Node.js & Local MongoDB

1. **Configure Environment Variables**:
   Copy `.env.example` to `.env` inside `apps/backend`:
   ```powershell
   Copy-Item apps/backend/.env.example apps/backend/.env
   ```

2. **Install Dependencies**:
   ```powershell
   Set-Location apps/backend
   npm install
   ```

3. **Seed Demo Data (Optional)**:
   Categories are seeded automatically on startup. To also seed a demo seller account (`khoa.nguyen@remarket.vn` / `ReMarket123!`) and sample product listings:
   ```powershell
   npm run seed
   ```

4. **Start the NestJS Backend Server (`:5000`)**:
   ```powershell
   npm run start:dev
   ```
   - API Base URL: `http://localhost:5000/api/v1`
   - Health Check: `http://localhost:5000/api/v1/health`
   - Swagger UI: `http://localhost:5000/api/docs`

5. **Start the Python FastAPI + LangGraph AI Service (`:8000`)**:
   In a second terminal:
   ```powershell
   Set-Location D:\cross-ck\apps\ai
   Copy-Item .env.example .env
   python -m scripts.ingest_knowledge
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   - FastAPI Health Check: `http://localhost:8000/health`
   - FastAPI OpenAPI Docs: `http://localhost:8000/docs`

---

## 3. Option B: Run with Docker Compose

From the repository root (`D:\cross-ck`):

```powershell
docker compose up -d --build
```

Or using the infrastructure compose file directly:

```powershell
docker compose -f infrastructure/docker/docker-compose.yml up -d --build
```

This starts:
- `remarket-mongodb` on port `27017` with persistent volume `remarket_mongodb_data` and healthcheck.
- `remarket-backend` on port `5000` connected to `remarket-mongodb`.

---

## 4. Running Tests & Quality Checks

Inside `apps/backend`:

```powershell
# Run unit tests
npm test

# Run end-to-end (e2e) integration tests against MongoDB test database
npm run test:e2e

# Run ESLint static analysis
npm run lint

# Format code with Prettier
npm run format

# Compile production bundle to dist/
npm run build
```
