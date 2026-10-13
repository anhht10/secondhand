# ReMarket — Environment Configuration Reference (Frozen v1.0)

> **Status**: Frozen (Phase 7 — API Contract Freeze)  
> **Source of Truth**:
> - [`apps/backend/src/config/env.validation.ts`](file:///d:/cross-ck/apps/backend/src/config/env.validation.ts)
> - [`apps/backend/src/config/configuration.ts`](file:///d:/cross-ck/apps/backend/src/config/configuration.ts)
> - [`apps/ai/app/core/config.py`](file:///d:/cross-ck/apps/ai/app/core/config.py)
> - [`infrastructure/docker/docker-compose.yml`](file:///d:/cross-ck/infrastructure/docker/docker-compose.yml)

---

## 1. Kiến trúc Cổng Dịch vụ (Service Ports & Topology)

| Thành phần | Thư mục | Cổng mặc định | Base URL (Host Machine) | Ghi chú |
|---|---|---|---|---|
| **MongoDB 7** | `infrastructure/docker` | `27017` | `mongodb://localhost:27017/remarket` | Lưu trữ toàn bộ dữ liệu ứng dụng |
| **NestJS Backend** | `apps/backend` | `3000` | `http://localhost:3000/api/v1` | API Gateway duy nhất cho Flutter (`Swagger`: `/api/docs`) |
| **Python AI Service** | `apps/ai` (`ai`) | `8000` | `http://localhost:8000` | Dịch vụ nội bộ LangGraph + Gemini (gọi bởi NestJS) |
| **Flutter App** | `fe` (Phase 8) | N/A | Kết nối tới `API_BASE_URL` (`:3000/api/v1`) | **Chỉ gọi NestJS Backend**, không gọi trực tiếp `:8000` |

---

## 2. Biến Môi Trường — NestJS Backend (`apps/backend/.env`)

Được kiểm tra nghiêm ngặt khi khởi động qua `validateEnv` trong [`env.validation.ts`](file:///d:/cross-ck/apps/backend/src/config/env.validation.ts).

| Biến môi trường | Bắt buộc | Mặc định | Ví dụ | Mô tả |
|---|---|---|---|---|
| `NODE_ENV` | Không | `development` | `development` \| `production` \| `test` | Môi trường thực thi |
| `PORT` | Không | `3000` | `3000` | Cổng lắng nghe HTTP của NestJS |
| `API_PREFIX` | Không | `api/v1` | `api/v1` | Tiền tố route toàn cục (`/api/v1`) |
| `MONGODB_URI` | **Có** (Prod) | `mongodb://localhost:27017/remarket` | `mongodb://localhost:27017/remarket` | Chuỗi kết nối MongoDB |
| `JWT_SECRET` | **Có** (Prod) | `dev-jwt-secret-change-in-production` | `remarket-super-secret-jwt-key` | Khóa ký Access Token |
| `JWT_EXPIRES_IN` | Không | `15m` | `15m` | Thời hạn của Access Token |
| `JWT_REFRESH_SECRET` | **Có** (Prod) | `dev-jwt-refresh-secret-change-in-production` | `remarket-super-secret-refresh-key` | Khóa ký Refresh Token |
| `JWT_REFRESH_EXPIRES_IN` | Không | `7d` | `7d` | Thời hạn của Refresh Token |
| `AI_SERVICE_URL` | Không | `http://localhost:8000` | `http://localhost:8000` | URL của Python FastAPI AI Service |
| `AI_SERVICE_TIMEOUT_MS` | Không | `30000` | `30000` | Thời gian chờ tối đa (ms) khi NestJS gọi sang AI Service |
| `STORAGE_DRIVER` | Không | `local` | `local` \| `s3` | Cơ chế lưu trữ file ảnh (`local` lưu vào `/uploads`, `s3` lưu lên S3/R2/MinIO) |
| `UPLOAD_DIR` | Không | `uploads` | `uploads` | Thư mục lưu ảnh trên ổ đĩa khi `STORAGE_DRIVER=local` |
| `PUBLIC_BASE_URL` | Không | `http://localhost:3000` | `http://localhost:3000` | Domain gốc để tạo URL ảnh trả về cho client |
| `S3_ENDPOINT` | Khi `s3` | `""` | `https://s3.ap-southeast-1.amazonaws.com` | Endpoint S3 / Cloudflare R2 / MinIO |
| `S3_REGION` | Khi `s3` | `ap-southeast-1` | `ap-southeast-1` | Region của S3 bucket |
| `S3_BUCKET` | Khi `s3` | `""` | `remarket-uploads` | Tên bucket lưu trữ |
| `S3_ACCESS_KEY_ID` | Khi `s3` | `""` | `AKIA...` | Access Key S3 |
| `S3_SECRET_ACCESS_KEY` | Khi `s3` | `""` | `...` | Secret Key S3 |
| `S3_PUBLIC_BASE_URL` | Khi `s3` | `""` | `https://cdn.remarket.vn` | URL CDN công khai cho ảnh trên S3 |
| `CORS_ORIGIN` | Không | `*` | `*` | Cấu hình CORS origin |

---

## 3. Biến Môi Trường — Python AI Service (`apps/ai/.env`)

Được cấu hình qua `pydantic-settings` trong [`config.py`](file:///d:/cross-ck/apps/ai/app/core/config.py).

| Biến môi trường | Bắt buộc | Mặc định | Ví dụ | Mô tả |
|---|---|---|---|---|
| `APP_NAME` | Không | `ReMarket AI Service` | `ReMarket AI Service` | Tên ứng dụng FastAPI |
| `APP_ENV` | Không | `development` | `development` \| `production` \| `test` | Môi trường thực thi |
| `PORT` | Không | `8000` | `8000` | Cổng lắng nghe của Uvicorn/FastAPI |
| `LOG_LEVEL` | Không | `INFO` | `INFO` \| `DEBUG` | Mức log hệ thống |
| `GEMINI_API_KEY` | **Khuyến nghị** | `""` | `AIzaSy...` | API Key của Google Gemini (nếu để trống hoặc hết quota, hệ thống tự động chuyển sang chế độ deterministic fallback an toàn) |
| `GEMINI_MODEL` | Không | `gemini-3.8-flash` | `gemini-3.8-flash` | Model Gemini sử dụng cho 4 đồ thị LangGraph |
| `GEMINI_TEMPERATURE` | Không | `0.3` | `0.3` | Độ sáng tạo mặc định của model (`0.0` - `2.0`) |
| `GEMINI_MAX_OUTPUT_TOKENS` | Không | `2048` | `2048` | Số token đầu ra tối đa |
| `GEMINI_TIMEOUT_SECONDS` | Không | `25` | `25` | Timeout (giây) cho mỗi lời gọi Gemini API |
| `GEMINI_MAX_RETRIES` | Không | `1` | `1` | Số lần thử lại khi Gemini gặp lỗi tạm thời |
| `BACKEND_API_URL` | Không | `http://localhost:3000/api/v1` | `http://localhost:3000/api/v1` | Base URL của NestJS Backend để các **LangGraph Agent Tools** (`search_products`, `filter_products`, v.v.) gọi lấy dữ liệu thật |
| `BACKEND_API_TIMEOUT_SECONDS` | Không | `10.0` | `10.0` | Timeout (giây) khi Agent Tools gọi NestJS Backend |
| `BACKEND_API_MAX_RETRIES` | Không | `2` | `2` | Số lần retry khi Agent Tools gọi NestJS Backend |
| `CHECKPOINTER_TYPE` | Không | `memory` | `memory` \| `sqlite` | Loại bộ nhớ lưu trạng thái hội thoại LangGraph |
| `SQLITE_DB_PATH` | Không | `./data/langgraph_checkpoints.sqlite` | `./data/langgraph_checkpoints.sqlite` | Đường dẫn file SQLite khi `CHECKPOINTER_TYPE=sqlite` |
| `RAG_ENABLED` | Không | `true` | `true` | Bật/tắt truy xuất tri thức RAG |
| `RAG_VECTOR_STORE_DIR` | Không | `./data/vector_store` | `./data/vector_store` | Thư mục lưu chỉ mục Vector Store |
| `RAG_KNOWLEDGE_DIR` | Không | `./app/rag/knowledge` | `./app/rag/knowledge` | Thư mục chứa 5 tài liệu Markdown tri thức chợ đồ cũ |
| `RAG_TOP_K` | Không | `3` | `3` | Số đoạn tài liệu RAG lấy ra mỗi lần truy vấn (`1` - `10`) |
| `CORS_ORIGINS` | Không | `*` | `*` | Danh sách origin được phép gọi FastAPI |

---

## 4. Cấu hình Môi Trường cho Flutter (`fe`)

Khi triển khai ứng dụng Flutter ở Phase 8, truyền cấu hình qua `--dart-define`:

| Biến `--dart-define` | Giá trị theo nền tảng | Mô tả |
|---|---|---|
| `API_BASE_URL` (Web / Desktop / iOS Simulator) | `http://localhost:3000/api/v1` | Kết nối tới NestJS chạy trên cùng máy host |
| `API_BASE_URL` (Android Emulator - AVD) | `http://10.0.2.2:3000/api/v1` | Địa chỉ loopback đặc biệt của Android Emulator trỏ về `localhost` của máy host |
| `API_BASE_URL` (Thiết bị thật cùng mạng LAN) | `http://<LAN_IP>:3000/api/v1` | Địa chỉ IPv4 LAN của máy tính chạy Backend |

> **Lưu ý khi hiển thị ảnh (`PUBLIC_BASE_URL`) trên Android Emulator**:
> Khi chạy local (`STORAGE_DRIVER=local`), Backend trả về URL ảnh dạng `http://localhost:3000/uploads/products/...`. Trên Android Emulator, nếu bạn đặt `PUBLIC_BASE_URL=http://10.0.2.2:3000` trong `apps/backend/.env` hoặc normalize `localhost` -> `10.0.2.2` trong helper hiển thị ảnh của Flutter, ảnh sẽ tải mượt mà trên cả Web và Android Emulator.

---

## 5. Hướng dẫn Khởi chạy Toàn Hệ thống (Local & Docker)

### Cách 1: Chạy toàn bộ bằng Docker Compose
```bash
docker compose -f infrastructure/docker/docker-compose.yml up -d --build
```

### Cách 2: Chạy Local phục vụ phát triển (Development)
1. **Khởi động MongoDB**:
   ```bash
   docker compose -f infrastructure/docker/docker-compose.yml up -d mongodb
   ```
2. **Khởi động Python AI Service (`:8000`)**:
   ```bash
   cd apps/ai
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
3. **Seed dữ liệu mẫu & Khởi động NestJS Backend (`:3000`)**:
   ```bash
   cd apps/backend
   npm run seed
   npm run start:dev
   ```
4. **Kiểm tra trạng thái hoạt động**:
   - NestJS Health: `GET http://localhost:3000/api/v1/health`
   - Swagger UI: `http://localhost:3000/api/docs`
   - AI Service Health: `GET http://localhost:8000/health`
