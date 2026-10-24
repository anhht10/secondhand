# ReMarket — Standardized Error Handling Contract (Frozen v1.0)

> **Status**: Frozen (Phase 7 — API Contract Freeze)  
> **Source of Truth**:
> - [`http-exception.filter.ts`](file:///d:/cross-ck/apps/backend/src/common/filters/http-exception.filter.ts)
> - [`transform.interceptor.ts`](file:///d:/cross-ck/apps/backend/src/common/interceptors/transform.interceptor.ts)
> - [`api-response.interface.ts`](file:///d:/cross-ck/apps/backend/src/common/interfaces/api-response.interface.ts)
> - [`ai-http.client.ts`](file:///d:/cross-ck/apps/backend/src/modules/ai/ai-http.client.ts)

---

## 1. Cấu trúc Response Chuẩn (Success vs Error Envelope)

Mọi phản hồi từ NestJS Backend (`http://localhost:3000/api/v1/*`) đều đi qua `TransformInterceptor` (khi thành công) hoặc `GlobalExceptionFilter` (khi có lỗi).

### 1.1. Success Response Envelope (`200 OK`, `201 Created`)

```json
{
  "success": true,
  "message": "Success",
  "data": { ... },
  "meta": {}
}
```

Khi endpoint có phân trang (`GET /products`, `GET /products/me/listings`, `GET /messages/conversations`, `GET /messages/conversations/:id/messages`, `GET /reports/me`), `data` là mảng `T[]` và `meta` chứa thông tin phân trang:

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

> **Lưu ý quan trọng cho Flutter Parser**:
> - Response thành công (`success: true`) **không có** trường `statusCode` ở top-level, và **luôn có** trường `meta` (`{}` hoặc `PaginationMeta`).
> - Response lỗi (`success: false`) **luôn có** `statusCode` ở top-level và đối tượng `error: { code, details, requestId? }`.

---

### 1.2. Error Response Envelope (`4xx`, `5xx`)

Mọi lỗi từ NestJS Backend và các lỗi được ánh xạ từ Python AI Service đều trả về đúng một cấu trúc duy nhất:

```json
{
  "success": false,
  "statusCode": 400,
  "message": "price must not be less than 0",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": [
      "price must not be less than 0",
      "condition must be one of the following values: NEW, LIKE_NEW, GOOD, FAIR"
    ],
    "requestId": "req-7b9d2a10"
  }
}
```

| Trường | Kiểu dữ liệu | Bắt buộc | Mô tả |
|---|---|---|---|
| `success` | `boolean` | Có | Luôn là `false` khi có lỗi |
| `statusCode` | `number` | Có | Mã HTTP status (`400`, `401`, `403`, `404`, `409`, `413`, `429`, `500`, `502`, `503`, `504`) |
| `message` | `string` | Có | Thông báo lỗi chính (nếu `details` có nhiều phần tử, `message` lấy phần tử đầu tiên `details[0]`) |
| `error.code` | `string` | Có | Mã lỗi chuẩn hóa dạng `UPPER_SNAKE_CASE` để Flutter xử lý theo logic |
| `error.details` | `string[]` | Có | Danh sách chi tiết các lỗi (luôn là mảng chuỗi có ít nhất 1 phần tử) |
| `error.requestId` | `string` | Tùy chọn | Xuất hiện khi request có truyền header `X-Request-ID` hoặc khi lỗi phát sinh từ AI Service |

---

## 2. Bảng Mã Lỗi Chuẩn Hóa (Error Code Catalog)

### 2.1. Nhóm Lỗi Nghiệp Vụ & Validation (NestJS Core)

| HTTP Status | `error.code` | Khi nào xảy ra | Ví dụ `message` thực tế từ Source Code |
|---|---|---|---|
| `400` | `VALIDATION_ERROR` | 1. Dữ liệu body/query vi phạm `class-validator` (`ValidationPipe`).<br>2. Lỗi upload file Multer (`LIMIT_FILE_SIZE`, `LIMIT_FILE_COUNT`, sai định dạng ảnh).<br>3. Payload gửi sang AI Service thiếu trường bắt buộc (`422` từ FastAPI được ánh xạ về `400 VALIDATION_ERROR`). | - `"title must be longer than or equal to 5 characters"`<br>- `"Only JPEG, PNG, and WEBP image files are allowed"`<br>- `"At least one image file is required"` |
| `400` | `BAD_REQUEST` | Vi phạm quy tắc nghiệp vụ (Business Rule):<br>- Chuyển trạng thái sản phẩm không hợp lệ.<br>- Chỉnh sửa hoặc xóa sản phẩm đã `SOLD`.<br>- Tự tạo hội thoại hoặc tự báo cáo sản phẩm của chính mình.<br>- Nhắn tin vào sản phẩm `DRAFT` hoặc `ARCHIVED`.<br>- Đính kèm quá 5 ảnh bằng chứng báo cáo. | - `"Invalid status transition from SOLD to ACTIVE"`<br>- `"Cannot edit details of a sold product listing"`<br>- `"Seller cannot start a conversation with themselves on their own product"`<br>- `"You cannot report your own product listing"` |
| `401` | `UNAUTHORIZED` | - Thiếu hoặc sai `Authorization: Bearer <token>`.<br>- Token hết hạn.<br>- Sai email hoặc mật khẩu khi đăng nhập.<br>- Refresh token không hợp lệ hoặc đã bị thu hồi. | - `"Unauthorized"`<br>- `"Invalid email or password"`<br>- `"Invalid or expired refresh token"`<br>- `"Refresh token is no longer valid"` |
| `403` | `FORBIDDEN` | - Tài khoản bị khóa (`status !== "ACTIVE"`).<br>- Thao tác trên sản phẩm/tin nhắn/cuộc hội thoại AI của người dùng khác.<br>- Xem sản phẩm `DRAFT` hoặc `ARCHIVED` của người khác. | - `"Account has been suspended"`<br>- `"You do not have permission to modify this product listing"`<br>- `"You do not have permission to access this conversation"`<br>- `"Conversation belongs to another user."` |
| `404` | `NOT_FOUND` | Không tìm thấy tài nguyên (`User`, `Category`, `Product`, `Conversation`, `Message`) hoặc `ObjectId` không hợp lệ. | - `"Product listing not found"`<br>- `"Category not found"`<br>- `"Conversation not found"`<br>- `"User not found"` |
| `404` | `PRODUCT_NOT_FOUND` | Gọi `POST /api/v1/ai/buyer-checklist` với `productId` không tồn tại trong MongoDB hoặc không phải ObjectId hợp lệ. | - `"Product not found for buyer checklist generation"` |
| `409` | `CONFLICT` | - Đăng ký email đã tồn tại.<br>- Báo cáo trùng lặp cùng 1 sản phẩm (`reporterId + productId` unique index).<br>- Vi phạm unique constraint MongoDB (`code: 11000`). | - `"An account with this email already exists"`<br>- `"You have already submitted a report for this product listing"` |
| `413` | `PAYLOAD_TOO_LARGE` | Body JSON vượt quá giới hạn (`10mb`) hoặc payload quá lớn. | - `"Request entity too large"` |
| `429` | `TOO_MANY_REQUESTS` | Vượt quá giới hạn Rate Limit của `ThrottlerGuard` (toàn cục `60 req/phút`, login/register `10 req/phút`, report `5 req/phút`). | - `"ThrottlerException: Too Many Requests"` |
| `500` | `INTERNAL_SERVER_ERROR` | Lỗi không xác định phía server. | - `"Internal server error"` |

---

### 2.2. Nhóm Lỗi AI Service (`AiHttpClient` Gateway Mapping)

Khi Flutter gọi `/api/v1/ai/*`, `AiHttpClient` trong NestJS chịu trách nhiệm gọi sang Python FastAPI (`AI_SERVICE_URL`) và chuyển đổi mọi lỗi mạng/timeout/upstream thành mã lỗi chuẩn hóa kèm `requestId`:

| HTTP Status | `error.code` | Khi nào xảy ra | Ví dụ Response `error` |
|---|---|---|---|
| `400` | `VALIDATION_ERROR` | FastAPI trả về `400` hoặc `422 Unprocessable Entity` (ví dụ thiếu cả `productId` và `title` khi gọi `buyer-checklist`). | `{ "code": "VALIDATION_ERROR", "details": ["Either productId or title/productName must be provided"], "requestId": "..." }` |
| `403` | `FORBIDDEN` | FastAPI phát hiện `thread_id` / `conversation_id` thuộc về `user_id` khác với người đang đăng nhập. | `{ "code": "FORBIDDEN", "details": ["Conversation belongs to another user."], "requestId": "..." }` |
| `404` | `PRODUCT_NOT_FOUND` | `productId` truyền vào `POST /api/v1/ai/buyer-checklist` không tồn tại trong MongoDB. | `{ "code": "PRODUCT_NOT_FOUND", "details": ["Product not found for buyer checklist generation"] }` |
| `429` | `AI_RATE_LIMITED` | Gemini API hoặc FastAPI trả về `429 Too Many Requests` (vượt quota). *(Lưu ý: `listing_graph` và `pricing_graph` đã có cơ chế deterministic fallback nên hiếm khi trả lỗi này, trừ khi bị chặn trực tiếp)*. | `{ "code": "AI_RATE_LIMITED", "details": ["AI Service rate limit exceeded. Please try again shortly."], "requestId": "..." }` |
| `502` | `AI_INVALID_RESPONSE` | Python AI Service trả về dữ liệu không đúng cấu trúc JSON mong đợi hoặc lỗi `500` từ upstream AI. | `{ "code": "AI_INVALID_RESPONSE", "details": ["AI Service returned an unexpected response"], "requestId": "..." }` |
| `503` | `AI_SERVICE_UNAVAILABLE` | Không thể kết nối tới Python AI Service (`ECONNREFUSED`, container AI chưa chạy, hoặc lỗi mạng). | `{ "code": "AI_SERVICE_UNAVAILABLE", "details": ["AI Service is currently unavailable"], "requestId": "..." }` |
| `504` | `AI_REQUEST_TIMEOUT` | Yêu cầu xử lý AI vượt quá `AI_SERVICE_TIMEOUT_MS` (mặc định `30000` ms = 30 giây). | `{ "code": "AI_REQUEST_TIMEOUT", "details": ["AI Service timed out after 30000ms"], "requestId": "..." }` |

---

## 3. Ví dụ Thực tế các Phản hồi Lỗi

### 3.1. Lỗi Validation nhiều trường (`400 VALIDATION_ERROR`)
```json
{
  "success": false,
  "statusCode": 400,
  "message": "title must be longer than or equal to 5 characters",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": [
      "title must be longer than or equal to 5 characters",
      "price must not be less than 0"
    ]
  }
}
```

### 3.2. Lỗi Không có quyền sở hữu (`403 FORBIDDEN`)
```json
{
  "success": false,
  "statusCode": 403,
  "message": "You do not have permission to modify this product listing",
  "error": {
    "code": "FORBIDDEN",
    "details": [
      "You do not have permission to modify this product listing"
    ]
  }
}
```

### 3.3. Lỗi Không tìm thấy sản phẩm khi tạo Checklist (`404 PRODUCT_NOT_FOUND`)
```json
{
  "success": false,
  "statusCode": 404,
  "message": "Product not found for buyer checklist generation",
  "error": {
    "code": "PRODUCT_NOT_FOUND",
    "details": [
      "Product not found for buyer checklist generation"
    ]
  }
}
```

### 3.4. Lỗi AI Service chưa bật hoặc mất kết nối (`503 AI_SERVICE_UNAVAILABLE`)
```json
{
  "success": false,
  "statusCode": 503,
  "message": "AI Service is currently unavailable",
  "error": {
    "code": "AI_SERVICE_UNAVAILABLE",
    "details": [
      "AI Service is currently unavailable"
    ],
    "requestId": "4f8c9b12-3d5a-4e89-9a1b-2c3d4e5f6a7b"
  }
}
```
