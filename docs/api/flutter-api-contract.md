# ReMarket — Complete Flutter API Contract (`v1` — Synchronized with Frozen `API_CONTRACT.md`)

> **Canonical Reference**: See **[`docs/api/API_CONTRACT.md`](file:///d:/cross-ck/docs/api/API_CONTRACT.md)**, **[`docs/api/AUTHENTICATION.md`](file:///d:/cross-ck/docs/api/AUTHENTICATION.md)**, **[`docs/api/AI_API_CONTRACT.md`](file:///d:/cross-ck/docs/api/AI_API_CONTRACT.md)**, and **[`docs/api/ERROR_HANDLING.md`](file:///d:/cross-ck/docs/api/ERROR_HANDLING.md)** for the full Phase 7 Frozen API Contract.

---

## 1. Base Configuration & Security Rules

- **Base URL (Web / Desktop / iOS Simulator)**: `http://localhost:3000/api/v1`
- **Base URL (Android Emulator AVD)**: `http://10.0.2.2:3000/api/v1`
- **Swagger UI**: `http://localhost:3000/api/docs`
- **Content-Type**: `application/json` (except image uploads which use `multipart/form-data`)
- **Authentication Header**:
  ```http
  Authorization: Bearer <accessToken>
  ```
- **Correlation Header (Optional)**:
  ```http
  X-Request-ID: <client-generated-uuid>
  ```
- **Strict Security Rules for Flutter**:
  1. Flutter **NEVER** calls the Python AI Service (`:8000`) directly and **NEVER** embeds `GEMINI_API_KEY`.
  2. Flutter **NEVER** sends `userId` or `user_id` in request bodies; user identity is extracted exclusively from the Bearer JWT on the server (`ValidationPipe` is configured with `whitelist: true, forbidNonWhitelisted: true`).

---

## 2. Standard Response & Error Envelopes

### 2.1 Success Envelope (`TransformInterceptor` — `200 OK` / `201 Created`)
- **Single Resource / Action**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": { ... },
    "meta": {}
  }
  ```
- **Paginated List**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": [ ... ],
    "meta": {
      "total": 42,
      "page": 1,
      "limit": 20,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPrevPage": false
    }
  }
  ```

### 2.2 Error Envelope (`GlobalExceptionFilter` — `4xx` / `5xx`)
```json
{
  "success": false,
  "statusCode": 400,
  "message": "price must not be less than 0",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": ["price must not be less than 0"],
    "requestId": "req-9a8b7c6d5e4f3a2b"
  }
}
```

---

## 3. Quick Endpoint Summary (39 Endpoints across 9 Controllers)

| Group | Method | Endpoint | Auth | Success Status |
|---|---|---|---|---|
| **Auth** | `POST` | `/api/v1/auth/register` | Public | `201 Created` |
| **Auth** | `POST` | `/api/v1/auth/login` | Public | `200 OK` |
| **Auth** | `POST` | `/api/v1/auth/refresh` | Public | `200 OK` |
| **Auth** | `POST` | `/api/v1/auth/logout` | Bearer JWT | `200 OK` |
| **Auth** | `GET` | `/api/v1/auth/me` | Bearer JWT | `200 OK` |
| **Wishlist** | `GET` | `/api/v1/auth/wishlist` | Bearer JWT | `200 OK` |
| **Wishlist** | `POST` | `/api/v1/auth/wishlist/:productId` | Bearer JWT | `201 Created` |
| **Wishlist** | `DELETE` | `/api/v1/auth/wishlist/:productId` | Bearer JWT | `200 OK` |
| **Users** | `GET` | `/api/v1/users/me` | Bearer JWT | `200 OK` |
| **Users** | `PATCH` | `/api/v1/users/me` | Bearer JWT | `200 OK` |
| **Users** | `GET` | `/api/v1/users/:id` | Public | `200 OK` |
| **Categories** | `GET` | `/api/v1/categories` | Public | `200 OK` |
| **Categories** | `GET` | `/api/v1/categories/:id` | Public | `200 OK` |
| **Products** | `POST` | `/api/v1/products` | Bearer JWT | `201 Created` |
| **Products** | `GET` | `/api/v1/products` | Public | `200 OK` |
| **Products** | `GET` | `/api/v1/products/me/listings` | Bearer JWT | `200 OK` |
| **Products** | `GET` | `/api/v1/products/my-listings` | Bearer JWT | `200 OK` |
| **Products** | `GET` | `/api/v1/products/:id` | Optional JWT | `200 OK` |
| **Products** | `PATCH` | `/api/v1/products/:id/status` | Bearer JWT (Owner) | `200 OK` |
| **Products** | `POST` | `/api/v1/products/:id/images` | Bearer JWT (Owner) | `201 Created` |
| **Products** | `PATCH` | `/api/v1/products/:id` | Bearer JWT (Owner) | `200 OK` |
| **Products** | `PUT` | `/api/v1/products/:id` | Bearer JWT (Owner) | `200 OK` |
| **Products** | `DELETE` | `/api/v1/products/:id` | Bearer JWT (Owner) | `200 OK` |
| **Upload** | `POST` | `/api/v1/upload/images` | Bearer JWT | `201 Created` |
| **Messages** | `POST` | `/api/v1/messages/conversations` | Bearer JWT | `201 Created` |
| **Messages** | `GET` | `/api/v1/messages/conversations` | Bearer JWT | `200 OK` |
| **Messages** | `GET` | `/api/v1/messages/conversations/:id` | Bearer JWT (Participant) | `200 OK` |
| **Messages** | `GET` | `/api/v1/messages/conversations/:id/messages` | Bearer JWT (Participant) | `200 OK` |
| **Messages** | `POST` | `/api/v1/messages/conversations/:id/messages` | Bearer JWT (Participant) | `201 Created` |
| **Messages** | `PATCH` | `/api/v1/messages/:id/read` | Bearer JWT (Participant) | `200 OK` |
| **Reports** | `POST` | `/api/v1/reports` | Bearer JWT | `201 Created` |
| **Reports** | `GET` | `/api/v1/reports/me` | Bearer JWT | `200 OK` |
| **AI** | `POST` | `/api/v1/ai/generate-listing` | Bearer JWT | `200 OK` |
| **AI** | `POST` | `/api/v1/ai/estimate-price` | Bearer JWT | `200 OK` |
| **AI** | `POST` | `/api/v1/ai/buyer-checklist` | Bearer JWT | `200 OK` |
| **AI** | `POST` | `/api/v1/ai/chat` | Bearer JWT | `200 OK` |
| **AI** | `GET` | `/api/v1/ai/conversations/:conversationId` | Bearer JWT (Owner) | `200 OK` |
| **AI** | `DELETE` | `/api/v1/ai/conversations/:conversationId` | Bearer JWT (Owner) | `200 OK` |
| **Health** | `GET` | `/api/v1/health` | Public | `200 OK` |

For complete request/response JSON payloads and validation constraints for every endpoint above, refer to **[`docs/api/API_CONTRACT.md`](file:///d:/cross-ck/docs/api/API_CONTRACT.md)**.
