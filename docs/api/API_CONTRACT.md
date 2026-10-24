# ReMarket — Master REST API Contract for Flutter (Frozen v1.0)

> **Status**: Frozen (Phase 7 — API Contract Freeze)  
> **Base URL (Local / Web / iOS Simulator)**: `http://localhost:3000/api/v1`  
> **Base URL (Android Emulator AVD)**: `http://10.0.2.2:3000/api/v1`  
> **Interactive OpenAPI / Swagger UI**: `http://localhost:3000/api/docs`  
> **Related Frozen Specs**:
> - [AUTHENTICATION.md](file:///d:/cross-ck/docs/api/AUTHENTICATION.md) — Chi tiết JWT, Refresh Token Rotation, `401` vs `403`.
> - [AI_API_CONTRACT.md](file:///d:/cross-ck/docs/api/AI_API_CONTRACT.md) — Chi tiết 4 tính năng AI, LangGraph Tools và bộ nhớ hội thoại.
> - [ERROR_HANDLING.md](file:///d:/cross-ck/docs/api/ERROR_HANDLING.md) — Cấu trúc lỗi chuẩn và danh mục mã lỗi.
> - [ENVIRONMENT.md](file:///d:/cross-ck/docs/development/ENVIRONMENT.md) — Cấu hình biến môi trường toàn hệ thống.

---

## Tổng quan 39 Endpoints của NestJS Backend (`/api/v1`)

| Nhóm API | Controller | Số lượng Endpoints | Tiền tố Route |
|---|---|---|---|
| **1. Authentication** | [`AuthController`](file:///d:/cross-ck/apps/backend/src/modules/auth/auth.controller.ts) | 5 | `/api/v1/auth` |
| **2. User / Profile** | [`UsersController`](file:///d:/cross-ck/apps/backend/src/modules/users/users.controller.ts) | 3 | `/api/v1/users` |
| **3. Categories** | [`CategoriesController`](file:///d:/cross-ck/apps/backend/src/modules/categories/categories.controller.ts) | 2 | `/api/v1/categories` |
| **4. Products** | [`ProductsController`](file:///d:/cross-ck/apps/backend/src/modules/products/products.controller.ts) | 10 | `/api/v1/products` |
| **5. Wishlist** | [`AuthController`](file:///d:/cross-ck/apps/backend/src/modules/auth/auth.controller.ts) | 3 | `/api/v1/auth/wishlist` |
| **6. Messaging / Chat** | [`MessagesController`](file:///d:/cross-ck/apps/backend/src/modules/messages/messages.controller.ts) | 6 | `/api/v1/messages` |
| **7. Reports** | [`ReportsController`](file:///d:/cross-ck/apps/backend/src/modules/reports/reports.controller.ts) | 2 | `/api/v1/reports` |
| **8. AI Features** | [`AiController`](file:///d:/cross-ck/apps/backend/src/modules/ai/ai.controller.ts) | 6 | `/api/v1/ai` |
| **9. Upload & Health** | [`UploadController`](file:///d:/cross-ck/apps/backend/src/modules/upload/upload.controller.ts), [`HealthController`](file:///d:/cross-ck/apps/backend/src/modules/health/health.controller.ts) | 2 | `/api/v1/upload`, `/api/v1/health` |
| **Tổng cộng** | **9 Controllers** | **39 Endpoints** | `/api/v1` |

---

## Quy ước Chung (Global Conventions)

1. **Success Envelope (`TransformInterceptor`)**:
   - Không phân trang:
     ```json
     {
       "success": true,
       "message": "Success",
       "data": { ... },
       "meta": {}
     }
     ```
   - Có phân trang:
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
2. **Error Envelope (`GlobalExceptionFilter`)**:
   ```json
   {
     "success": false,
     "statusCode": 400,
     "message": "Mô tả lỗi chính",
     "error": {
       "code": "VALIDATION_ERROR",
       "details": ["Chi tiết lỗi 1"],
       "requestId": "optional-req-id"
     }
   }
   ```
3. **Dual ID (`_id` và `id`)**: Tất cả document Mongoose (`User`, `Category`, `Product`, `Conversation`, `Message`, `Report`) đều bật `toJSON: { virtuals: true }` nên trả về song song cả `"_id"` và `"id"` dạng chuỗi 24 ký tự hex.
4. **Validation Pipe**: Toàn bộ body và query được kiểm tra với `whitelist: true, forbidNonWhitelisted: true, transform: true`. Gửi thêm trường lạ không khai báo trong DTO sẽ bị từ chối với lỗi `400 VALIDATION_ERROR` (`"property <x> should not exist"`).

---

## NHÓM 1 — AUTHENTICATION (`/api/v1/auth`)

### 1.1. Đăng ký tài khoản mới
- **HTTP Method & URL**: `POST /api/v1/auth/register`
- **Authentication**: Public (Rate limit: `10` requests / `60s`)
- **Headers**: `Content-Type: application/json`
- **Path / Query Parameters**: Không có
- **Request Body (`RegisterDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `email` | `string` | **Có** | `@IsEmail()`, tự động `trim()` + `toLowerCase()` |
  | `password` | `string` | **Có** | `8..72` ký tự, ít nhất 1 chữ cái và 1 chữ số (`/^(?=.*[A-Za-z])(?=.*\d).{8,72}$/`) |
  | `displayName` | `string` | **Có** | `2..60` ký tự |
  | `phone` | `string` | Không | Regex `/^[0-9+\-\s()]{8,20}$/` |
  | `location` | `string` | Không | Tối đa `120` ký tự |
- **HTTP Status Codes**:
  - `201 Created`: Đăng ký thành công, trả về `user` và `tokens`.
  - `400 Bad Request` (`VALIDATION_ERROR`): Dữ liệu không hợp lệ.
  - `409 Conflict` (`CONFLICT`): `"An account with this email already exists"`.
  - `429 Too Many Requests` (`TOO_MANY_REQUESTS`): Quá 10 lần/phút.
- **Ví dụ Request**:
  ```json
  {
    "email": "tran.binh@student.edu.vn",
    "password": "Password123",
    "displayName": "Trần Thị Bình",
    "phone": "0912345678",
    "location": "Quận 10, TP.HCM"
  }
  ```
- **Ví dụ Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "user": {
        "_id": "672b3a9f8e1b2c0012345678",
        "id": "672b3a9f8e1b2c0012345678",
        "email": "tran.binh@student.edu.vn",
        "displayName": "Trần Thị Bình",
        "phone": "0912345678",
        "avatarUrl": null,
        "bio": null,
        "location": "Quận 10, TP.HCM",
        "role": "user",
        "isEmailVerified": false,
        "status": "ACTIVE",
        "wishlist": [],
        "createdAt": "2026-11-06T15:00:00.000Z",
        "updatedAt": "2026-11-06T15:00:00.000Z"
      },
      "tokens": {
        "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
      }
    },
    "meta": {}
  }
  ```

---

### 1.2. Đăng nhập
- **HTTP Method & URL**: `POST /api/v1/auth/login`
- **Authentication**: Public (Rate limit: `10` requests / `60s`)
- **Headers**: `Content-Type: application/json`
- **Request Body (`LoginDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `email` | `string` | **Có** | `@IsEmail()` |
  | `password` | `string` | **Có** | `@IsString()`, `@MinLength(1)` |
- **HTTP Status Codes**:
  - `200 OK`: Đăng nhập thành công (trả về `{ user, tokens }` giống hệt `register`).
  - `401 Unauthorized` (`UNAUTHORIZED`): `"Invalid email or password"`.
  - `403 Forbidden` (`FORBIDDEN`): `"Account has been suspended"`.
- **Ví dụ Request**:
  ```json
  {
    "email": "nguyen.an@student.edu.vn",
    "password": "Password123!"
  }
  ```

---

### 1.3. Làm mới cặp JWT (Refresh Token Rotation)
- **HTTP Method & URL**: `POST /api/v1/auth/refresh`
- **Authentication**: Public (Rate limit: `20` requests / `60s`)
- **Headers**: `Content-Type: application/json`
- **Request Body (`RefreshTokenDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `refreshToken` | `string` | **Có** | `@IsString()`, `@MinLength(10)` |
- **HTTP Status Codes**:
  - `200 OK`: Trả về `{ user, tokens: { accessToken, refreshToken } }` mới.
  - `401 Unauthorized` (`UNAUTHORIZED`): `"Invalid or expired refresh token"`, `"Refresh token is no longer valid"`, hoặc `"Invalid refresh token"`.
  - `403 Forbidden` (`FORBIDDEN`): `"Account has been suspended"`.

---

### 1.4. Đăng xuất (Thu hồi Refresh Token)
- **HTTP Method & URL**: `POST /api/v1/auth/logout`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Request Body**: Không cần body
- **HTTP Status Codes**:
  - `200 OK`: Đăng xuất thành công.
  - `401 Unauthorized`: Token thiếu hoặc hết hạn.
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Logged out successfully",
    "data": {
      "message": "Logged out successfully"
    },
    "meta": {}
  }
  ```

---

### 1.5. Lấy thông tin người dùng hiện tại kèm thống kê (`GET /api/v1/auth/me`)
- **HTTP Method & URL**: `GET /api/v1/auth/me`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **HTTP Status Codes**: `200 OK`, `401 Unauthorized`
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "_id": "672b3a9f8e1b2c0012345678",
      "id": "672b3a9f8e1b2c0012345678",
      "email": "nguyen.an@student.edu.vn",
      "displayName": "Nguyễn Văn An",
      "phone": "0901234567",
      "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
      "bio": "Sinh viên năm 4 ĐH Bách Khoa TP.HCM, chuyên nhượng lại đồ công nghệ và giáo trình giữ kỹ.",
      "location": "Khu đô thị ĐHQG TP.HCM, Thủ Đức",
      "role": "user",
      "isEmailVerified": true,
      "status": "ACTIVE",
      "wishlist": ["672b3a9f8e1b2c0012345679"],
      "createdAt": "2026-11-06T15:00:00.000Z",
      "updatedAt": "2026-11-06T15:00:00.000Z",
      "stats": {
        "activeListingsCount": 5,
        "soldListingsCount": 2,
        "rating": 4.9,
        "transparencyRate": 98
      }
    },
    "meta": {}
  }
  ```

---

## NHÓM 2 — USER / PROFILE (`/api/v1/users`)

### 2.1. Lấy hồ sơ cá nhân & thống kê người bán (`GET /api/v1/users/me`)
- **HTTP Method & URL**: `GET /api/v1/users/me`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Mô tả**: Trả về cùng cấu trúc dữ liệu với `GET /api/v1/auth/me` (bao gồm đối tượng `stats`).

---

### 2.2. Cập nhật hồ sơ cá nhân (`PATCH /api/v1/users/me`)
- **HTTP Method & URL**: `PATCH /api/v1/users/me`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Headers**: `Content-Type: application/json`
- **Request Body (`UpdateUserDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `displayName` | `string` | Không | `2..60` ký tự |
  | `phone` | `string` | Không | Regex `/^[0-9+\-\s()]{8,20}$/` |
  | `avatarUrl` | `string` | Không | Tối đa `500` ký tự (URL trả về từ `POST /api/v1/upload/images`) |
  | `bio` | `string` | Không | Tối đa `300` ký tự |
  | `location` | `string` | Không | Tối đa `120` ký tự |
- **HTTP Status Codes**: `200 OK`, `400 VALIDATION_ERROR`, `401 UNAUTHORIZED`
- **Ví dụ Request**:
  ```json
  {
    "displayName": "Nguyễn Văn An (BK)",
    "bio": "Pass lại đồ công nghệ sinh viên rõ nguồn gốc.",
    "location": "Dĩ An, Bình Dương"
  }
  ```
- **Ví dụ Response (`200 OK`)**: Trả về đối tượng `User` đã cập nhật.

---

### 2.3. Xem hồ sơ công khai của người bán (`GET /api/v1/users/:id`)
- **HTTP Method & URL**: `GET /api/v1/users/:id`
- **Authentication**: Public
- **Path Parameters**: `id` (MongoDB ObjectId của người bán)
- **Bảo mật dữ liệu**: Chỉ trả về thông tin công khai (`_id`, `id`, `displayName`, `avatarUrl`, `bio`, `location`, `isEmailVerified`, `status`, `createdAt`, `stats`). **Không bao giờ** trả về `email`, `phone`, hay `wishlist`.
- **HTTP Status Codes**:
  - `200 OK`: Thành công.
  - `404 Not Found` (`NOT_FOUND`): `"User not found"`.
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "_id": "672b3a9f8e1b2c0012345678",
      "id": "672b3a9f8e1b2c0012345678",
      "displayName": "Nguyễn Văn An",
      "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
      "bio": "Sinh viên năm 4 ĐH Bách Khoa TP.HCM",
      "location": "Khu đô thị ĐHQG TP.HCM, Thủ Đức",
      "isEmailVerified": true,
      "status": "ACTIVE",
      "createdAt": "2026-11-06T15:00:00.000Z",
      "stats": {
        "activeListingsCount": 5,
        "soldListingsCount": 2,
        "rating": 4.9,
        "transparencyRate": 98
      }
    },
    "meta": {}
  }
  ```

---

## NHÓM 3 — CATEGORIES (`/api/v1/categories`)

### 3.1. Lấy danh sách danh mục đang hoạt động
- **HTTP Method & URL**: `GET /api/v1/categories`
- **Authentication**: Public
- **Query Parameters**:
  - `parentId` *(optional)*: Truyền `"root"` hoặc `"null"` để chỉ lấy danh mục gốc (`parentId = null`); hoặc truyền `<ObjectId>` để lấy danh mục con. Không truyền sẽ lấy toàn bộ danh mục đang hoạt động (`isActive: true`).
- **HTTP Status Codes**: `200 OK`
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": [
      {
        "_id": "672b3a9f8e1b2c0012345670",
        "id": "672b3a9f8e1b2c0012345670",
        "name": "Đồ điện tử",
        "slug": "electronics",
        "description": "Điện thoại, tai nghe, loa, máy đọc sách, thiết bị thông minh đã qua sử dụng",
        "icon": "devices",
        "parentId": null,
        "isActive": true,
        "createdAt": "2026-11-06T15:00:00.000Z",
        "updatedAt": "2026-11-06T15:00:00.000Z"
      },
      {
        "_id": "672b3a9f8e1b2c0012345671",
        "id": "672b3a9f8e1b2c0012345671",
        "name": "Máy tính & Phụ kiện",
        "slug": "computers-accessories",
        "description": "Laptop, màn hình, bàn phím cơ, chuột, linh kiện máy tính",
        "icon": "laptop_mac",
        "parentId": null,
        "isActive": true,
        "createdAt": "2026-11-06T15:00:00.000Z",
        "updatedAt": "2026-11-06T15:00:00.000Z"
      }
    ],
    "meta": {}
  }
  ```

---

### 3.2. Xem chi tiết một danh mục
- **HTTP Method & URL**: `GET /api/v1/categories/:id`
- **Authentication**: Public
- **Path Parameters**: `id` (MongoDB ObjectId của danh mục)
- **HTTP Status Codes**:
  - `200 OK`: Trả về chi tiết danh mục.
  - `404 Not Found` (`NOT_FOUND`): `"Category not found"`.

---

## NHÓM 4 — PRODUCTS (`/api/v1/products`)

### Các Enum & Quy tắc Trạng thái Sản phẩm

- **`ProductCondition`**:
  - `NEW` — Mới 100% / Chưa qua sử dụng
  - `LIKE_NEW` — Như mới (98–99%)
  - `GOOD` — Tốt (85–95%, xước nhẹ không ảnh hưởng chức năng)
  - `FAIR` — Khá / Trung bình (70–84%, có dấu hiệu hao mòn rõ)
- **`ProductStatus` & State Machine (`ALLOWED_STATUS_TRANSITIONS`)**:
  - `DRAFT` → `ACTIVE`, `ARCHIVED`
  - `ACTIVE` → `RESERVED`, `SOLD`, `ARCHIVED`, `DRAFT`
  - `RESERVED` → `ACTIVE`, `SOLD`, `ARCHIVED`
  - `SOLD` → `ARCHIVED` *(Không thể sửa nội dung hoặc xóa sản phẩm đã `SOLD`)*
  - `ARCHIVED` → `DRAFT`, `ACTIVE`

---

### 4.1. Tạo tin đăng sản phẩm mới
- **HTTP Method & URL**: `POST /api/v1/products`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Headers**: `Content-Type: application/json`
- **Request Body (`CreateProductDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `title` | `string` | **Có** | `5..120` ký tự |
  | `description` | `string` | **Có** | `20..5000` ký tự |
  | `price` | `number` | **Có** | `>= 0` (VNĐ) |
  | `originalPrice` | `number` | Không | `>= 0` (VNĐ) |
  | `categoryId` | `string` | **Có** | `@IsMongoId()`, phải là danh mục đang `isActive: true` |
  | `condition` | `enum` | **Có** | `NEW`, `LIKE_NEW`, `GOOD`, `FAIR` |
  | `defectDisclosure` | `string` | Không | Tối đa `1000` ký tự (nếu không gửi, lưu là `""`) |
  | `images` | `string[]` | Không | Tối đa `10` URL ảnh |
  | `location` | `string` | Không | Tối đa `120` ký tự |
  | `status` | `enum` | Không | Chỉ cho phép `DRAFT` hoặc `ACTIVE` khi tạo mới (mặc định `ACTIVE`) |
  | `aiMetadata` | `object` | Không | `{ suggestedPriceMin, suggestedPriceRecommended, suggestedPriceMax, aiGeneratedDescription, buyerChecklist, questionsForSeller, lastGeneratedAt }` |
- **HTTP Status Codes**:
  - `201 Created`: Tạo thành công (đã populate `sellerId` và `categoryId`).
  - `400 Bad Request` (`VALIDATION_ERROR` / `BAD_REQUEST`): Dữ liệu không hợp lệ hoặc `categoryId` không tồn tại.
  - `401 Unauthorized`: Chưa đăng nhập.

---

### 4.2. Tìm kiếm, lọc và phân trang danh sách sản phẩm
- **HTTP Method & URL**: `GET /api/v1/products`
- **Authentication**: Public
- **Query Parameters (`QueryProductDto`)**:
  | Query Param | Kiểu | Mặc định | Validation Constraints | Mô tả |
  |---|---|---|---|---|
  | `page` | `number` | `1` | `>= 1` | Trang hiện tại |
  | `limit` | `number` | `20` | `1..100` | Số lượng mỗi trang |
  | `search` | `string` | — | Tối đa `120` ký tự | Tìm kiếm theo từ khóa trong `title` và `description` |
  | `categoryId` | `string` | — | `@IsMongoId()` | Lọc theo ID danh mục |
  | `condition` | `enum` | — | `NEW`, `LIKE_NEW`, `GOOD`, `FAIR` | Lọc theo tình trạng |
  | `minPrice` | `number` | — | `>= 0` | Giá tối thiểu (VNĐ) |
  | `maxPrice` | `number` | — | `>= 0` | Giá tối đa (VNĐ) (`minPrice` không được lớn hơn `maxPrice`) |
  | `sellerId` | `string` | — | `@IsMongoId()` | Lọc sản phẩm của một người bán cụ thể |
  | `status` | `enum` | `ACTIVE` | `ACTIVE`, `RESERVED`, `SOLD` | Truyền `DRAFT` hoặc `ARCHIVED` trên endpoint public sẽ trả về mảng rỗng `[]` để bảo vệ quyền riêng tư |
  | `sortBy` | `enum` | `createdAt` | `createdAt`, `price`, `viewsCount` | Trường sắp xếp |
  | `sortOrder` | `enum` | `desc` | `asc`, `desc` | Thứ tự sắp xếp |
- **HTTP Status Codes**: `200 OK`, `400 VALIDATION_ERROR`
- **Ví dụ Request**:
  `GET /api/v1/products?search=keychron&condition=LIKE_NEW&maxPrice=2000000&page=1&limit=10&sortBy=price&sortOrder=asc`
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": [
      {
        "_id": "672b3a9f8e1b2c0012345681",
        "id": "672b3a9f8e1b2c0012345681",
        "sellerId": {
          "_id": "672b3a9f8e1b2c0012345678",
          "id": "672b3a9f8e1b2c0012345678",
          "displayName": "Nguyễn Văn An",
          "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
          "location": "Khu đô thị ĐHQG TP.HCM, Thủ Đức",
          "isEmailVerified": true,
          "status": "ACTIVE"
        },
        "categoryId": {
          "_id": "672b3a9f8e1b2c0012345671",
          "id": "672b3a9f8e1b2c0012345671",
          "name": "Máy tính & Phụ kiện",
          "slug": "computers-accessories",
          "icon": "laptop_mac"
        },
        "title": "Bàn phím cơ Keychron K6 RGB Gateron Brown Switch",
        "description": "📦 [TỔNG QUAN SẢN PHẨM]\nBàn phím cơ không dây Keychron K6 layout 65%...",
        "price": 1350000,
        "originalPrice": 2450000,
        "condition": "LIKE_NEW",
        "defectDisclosure": "Xước nhẹ 1mm ở cạnh phải khung nhôm, toàn bộ switch và LED RGB hoạt động hoàn hảo.",
        "images": [
          "https://images.unsplash.com/photo-1587829741301-dc798b83add3"
        ],
        "status": "ACTIVE",
        "location": "Thủ Đức, TP.HCM",
        "aiMetadata": null,
        "viewsCount": 14,
        "createdAt": "2026-11-06T15:00:00.000Z",
        "updatedAt": "2026-11-06T15:00:00.000Z"
      }
    ],
    "meta": {
      "total": 1,
      "page": 1,
      "limit": 10,
      "totalPages": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
  }
  ```

---

### 4.3. Lấy danh sách tin đăng của chính mình (Bao gồm cả `DRAFT`, `SOLD`, `ARCHIVED`)
- **HTTP Method & URL**:
  - Chính thức: `GET /api/v1/products/me/listings`
  - Bí danh tương thích: `GET /api/v1/products/my-listings`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Query Parameters**: Nhận đầy đủ `QueryProductDto` (`page`, `limit`, `status`, `search`, `categoryId`, `condition`, `sortBy`, `sortOrder`). Nếu không truyền `status`, trả về **tất cả các trạng thái** (`DRAFT`, `ACTIVE`, `RESERVED`, `SOLD`, `ARCHIVED`) của người bán hiện tại.
- **HTTP Status Codes**: `200 OK`, `401 UNAUTHORIZED`

---

### 4.4. Xem chi tiết một sản phẩm
- **HTTP Method & URL**: `GET /api/v1/products/:id`
- **Authentication**: **Optional** (`OptionalJwtAuthGuard` — Public cho `ACTIVE`, `RESERVED`, `SOLD`; **Bắt buộc gửi Bearer token của chủ sở hữu** nếu sản phẩm đang ở trạng thái `DRAFT` hoặc `ARCHIVED`).
- **Tác dụng phụ**: Tự động tăng `viewsCount` thêm `1` khi xem sản phẩm `ACTIVE` / `RESERVED` / `SOLD`.
- **HTTP Status Codes**:
  - `200 OK`: Trả về chi tiết sản phẩm.
  - `403 Forbidden` (`FORBIDDEN`): `"This product listing is not publicly available"` (khi xem sản phẩm `DRAFT` / `ARCHIVED` mà không phải chủ sở hữu).
  - `404 Not Found` (`NOT_FOUND`): `"Product listing not found"`.

---

### 4.5. Cập nhật trạng thái sản phẩm (State Machine)
- **HTTP Method & URL**: `PATCH /api/v1/products/:id/status`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ chủ sở hữu `sellerId`)
- **Request Body (`UpdateProductStatusDto`)**:
  ```json
  {
    "status": "SOLD"
  }
  ```
- **HTTP Status Codes**:
  - `200 OK`: Cập nhật trạng thái thành công.
  - `400 Bad Request` (`BAD_REQUEST`): `"Invalid status transition from <A> to <B>"`.
  - `403 Forbidden` (`FORBIDDEN`): `"You do not have permission to modify this product listing"`.
  - `404 Not Found` (`NOT_FOUND`): `"Product listing not found"`.

---

### 4.6. Upload và gắn thêm ảnh trực tiếp vào sản phẩm
- **HTTP Method & URL**: `POST /api/v1/products/:id/images`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ chủ sở hữu `sellerId`)
- **Headers**: `Content-Type: multipart/form-data`
- **Form Data Field**:
  - `images`: Mảng file ảnh (`1..10` files, mỗi file `<= 5MB`, định dạng `image/jpeg`, `image/png`, `image/webp`). Tổng số ảnh của sản phẩm sau khi thêm không vượt quá `10` ảnh.
- **HTTP Status Codes**:
  - `201 Created`: Trả về đối tượng `Product` đã cập nhật mảng `images`.
  - `400 Bad Request`: Quá 10 ảnh, sai định dạng, hoặc sản phẩm đã `SOLD`.
  - `403 Forbidden`: Không phải chủ sở hữu.

---

### 4.7. Chỉnh sửa thông tin sản phẩm
- **HTTP Method & URL**:
  - Chính thức: `PATCH /api/v1/products/:id`
  - Bí danh tương thích: `PUT /api/v1/products/:id`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ chủ sở hữu `sellerId`)
- **Request Body (`UpdateProductDto`)**: Tất cả các trường của `CreateProductDto` đều là tùy chọn (`PartialType(CreateProductDto)`).
- **Quy tắc nghiệp vụ**: Không cho phép sửa nội dung khi sản phẩm đã ở trạng thái `SOLD` (`400 BAD_REQUEST` `"Cannot edit details of a sold product listing"`).

---

### 4.8. Xóa sản phẩm
- **HTTP Method & URL**: `DELETE /api/v1/products/:id`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ chủ sở hữu `sellerId`)
- **Quy tắc nghiệp vụ**:
  - Không cho phép xóa sản phẩm đã `SOLD` (`400 BAD_REQUEST` `"Cannot delete a sold product listing. You may archive it instead."`).
  - Khi xóa thành công, hệ thống tự động dọn dẹp (`cascade cleanup`): gỡ `productId` khỏi `wishlist` của mọi user, xóa các `conversations`/`messages` và `reports` gắn với sản phẩm đó, đồng thời xóa các file ảnh local.
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Product listing deleted successfully",
    "data": {
      "message": "Product listing deleted successfully"
    },
    "meta": {}
  }
  ```

---

## NHÓM 5 — WISHLIST (`/api/v1/auth/wishlist`)

> Được đặt trong [`AuthController`](file:///d:/cross-ck/apps/backend/src/modules/auth/auth.controller.ts) tại đường dẫn `/api/v1/auth/wishlist`.

### 5.1. Lấy danh sách sản phẩm yêu thích
- **HTTP Method & URL**: `GET /api/v1/auth/wishlist`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **HTTP Status Codes**: `200 OK`, `401 UNAUTHORIZED`
- **Ví dụ Response (`200 OK`)**: Trả về mảng `Product[]` trong `data` (đã populate `sellerId` và `categoryId`).

---

### 5.2. Thêm sản phẩm vào danh sách yêu thích
- **HTTP Method & URL**: `POST /api/v1/auth/wishlist/:productId`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Path Parameters**: `productId` (MongoDB ObjectId của sản phẩm; sản phẩm không được ở trạng thái `DRAFT`)
- **HTTP Status Codes**:
  - `201 Created`: Thêm thành công, trả về mảng `Product[]` wishlist mới nhất.
  - `400 Bad Request`: Sản phẩm đang ở trạng thái `DRAFT`.
  - `404 Not Found`: `"Product listing not found"`.

---

### 5.3. Xóa sản phẩm khỏi danh sách yêu thích
- **HTTP Method & URL**: `DELETE /api/v1/auth/wishlist/:productId`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Path Parameters**: `productId` (MongoDB ObjectId)
- **HTTP Status Codes**:
  - `200 OK`: Xóa thành công, trả về mảng `Product[]` wishlist còn lại.

---

## NHÓM 6 — MESSAGING / CHAT NGƯỜI MUA ↔ NGƯỜI BÁN (`/api/v1/messages`)

### 6.1. Tạo mới hoặc lấy cuộc hội thoại theo sản phẩm
- **HTTP Method & URL**: `POST /api/v1/messages/conversations`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Request Body (`CreateConversationDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints | Mô tả |
  |---|---|---|---|---|
  | `productId` | `string` | **Có** | `@IsMongoId()` | ID sản phẩm người mua quan tâm |
  | `initialMessage` | `string` | Không | `1..2000` ký tự | Tin nhắn mở đầu (nếu truyền, hệ thống tự động tạo bản ghi `Message` đầu tiên) |
- **Quy tắc nghiệp vụ**:
  - Mỗi bộ 3 `(buyerId, sellerId, productId)` chỉ có **duy nhất 1 cuộc hội thoại** (idempotent). Nếu đã tồn tại, trả về cuộc hội thoại hiện có.
  - Người bán **không thể** tự tạo hội thoại với chính mình trên sản phẩm của mình (`400 BAD_REQUEST` `"Seller cannot start a conversation with themselves on their own product"`).
  - Không thể tạo hội thoại trên sản phẩm `DRAFT` hoặc `ARCHIVED` (`400 BAD_REQUEST`).
- **HTTP Status Codes**: `201 Created`, `400 BAD_REQUEST`, `404 NOT_FOUND`
- **Ví dụ Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "_id": "672b3a9f8e1b2c0012345690",
      "id": "672b3a9f8e1b2c0012345690",
      "buyerId": {
        "_id": "672b3a9f8e1b2c0012345679",
        "id": "672b3a9f8e1b2c0012345679",
        "displayName": "Trần Thị Bình",
        "avatarUrl": null,
        "location": "Quận 10, TP.HCM",
        "isEmailVerified": true,
        "status": "ACTIVE"
      },
      "sellerId": {
        "_id": "672b3a9f8e1b2c0012345678",
        "id": "672b3a9f8e1b2c0012345678",
        "displayName": "Nguyễn Văn An",
        "avatarUrl": null,
        "location": "Thủ Đức, TP.HCM",
        "isEmailVerified": true,
        "status": "ACTIVE"
      },
      "productId": {
        "_id": "672b3a9f8e1b2c0012345681",
        "id": "672b3a9f8e1b2c0012345681",
        "title": "Bàn phím cơ Keychron K6 RGB Gateron Brown Switch",
        "price": 1350000,
        "condition": "LIKE_NEW",
        "status": "ACTIVE",
        "images": ["https://images.unsplash.com/photo-1587829741301-dc798b83add3"],
        "location": "Thủ Đức, TP.HCM"
      },
      "lastMessage": "Chào bạn, bàn phím này còn hộp và phụ kiện đầy đủ không ạ?",
      "lastMessageAt": "2026-11-06T15:10:00.000Z",
      "createdAt": "2026-11-06T15:10:00.000Z",
      "updatedAt": "2026-11-06T15:10:00.000Z"
    },
    "meta": {}
  }
  ```

---

### 6.2. Lấy danh sách các cuộc hội thoại của tôi
- **HTTP Method & URL**: `GET /api/v1/messages/conversations`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Query Parameters (`PaginationQueryDto`)**: `page` (mặc định `1`), `limit` (mặc định `20`, tối đa `100`).
- **Sắp xếp**: Mới nhất lên đầu (`lastMessageAt: -1, updatedAt: -1`).
- **HTTP Status Codes**: `200 OK` (Trả về mảng `Conversation[]` trong `data` và `PaginationMeta` trong `meta`).

---

### 6.3. Xem chi tiết một cuộc hội thoại
- **HTTP Method & URL**: `GET /api/v1/messages/conversations/:id`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ `buyerId` hoặc `sellerId` của hội thoại)
- **HTTP Status Codes**:
  - `200 OK`: Trả về chi tiết `Conversation`.
  - `403 Forbidden` (`FORBIDDEN`): `"You do not have permission to access this conversation"`.
  - `404 Not Found` (`NOT_FOUND`): `"Conversation not found"`.

---

### 6.4. Lấy danh sách tin nhắn trong cuộc hội thoại
- **HTTP Method & URL**: `GET /api/v1/messages/conversations/:id/messages`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ `buyerId` hoặc `sellerId`)
- **Query Parameters**: `page` (`1`), `limit` (`20`, tối đa `100`).
- **Sắp xếp**: Theo thứ tự thời gian tăng dần (`createdAt: 1, _id: 1`).
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": [
      {
        "_id": "672b3a9f8e1b2c0012345691",
        "id": "672b3a9f8e1b2c0012345691",
        "conversationId": "672b3a9f8e1b2c0012345690",
        "senderId": {
          "_id": "672b3a9f8e1b2c0012345679",
          "id": "672b3a9f8e1b2c0012345679",
          "displayName": "Trần Thị Bình",
          "avatarUrl": null
        },
        "content": "Chào bạn, bàn phím này còn hộp và phụ kiện đầy đủ không ạ?",
        "messageType": "TEXT",
        "isRead": false,
        "createdAt": "2026-11-06T15:10:00.000Z",
        "updatedAt": "2026-11-06T15:10:00.000Z"
      }
    ],
    "meta": {
      "total": 1,
      "page": 1,
      "limit": 20,
      "totalPages": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
  }
  ```

---

### 6.5. Gửi tin nhắn mới trong cuộc hội thoại
- **HTTP Method & URL**: `POST /api/v1/messages/conversations/:id/messages`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ `buyerId` hoặc `sellerId`)
- **Request Body (`CreateMessageDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `content` | `string` | **Có** | `1..2000` ký tự (không được chỉ chứa khoảng trắng) |
  | `messageType` | `enum` | Không | `TEXT` (mặc định), `IMAGE`, `SYSTEM` |
- **HTTP Status Codes**: `201 Created`, `400 BAD_REQUEST` (nếu sản phẩm đã bị `ARCHIVED`), `403 FORBIDDEN`, `404 NOT_FOUND`.

---

### 6.6. Đánh dấu tin nhắn đã đọc
- **HTTP Method & URL**: `PATCH /api/v1/messages/:id/read`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, chỉ thành viên cuộc hội thoại)
- **Path Parameters**: `id` (MongoDB ObjectId của `Message`)
- **HTTP Status Codes**: `200 OK` (Trả về `Message` với `"isRead": true`), `403 FORBIDDEN`, `404 NOT_FOUND`.

---

## NHÓM 7 — REPORTS (BÁO CÁO VI PHẠM / SAI SỰ THẬT) (`/api/v1/reports`)

### 7.1. Gửi báo cáo sản phẩm vi phạm
- **HTTP Method & URL**: `POST /api/v1/reports`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`, Rate limit: `5` requests / `60s`)
- **Headers**: Hỗ trợ cả `application/json` (nếu gửi `evidenceUrls`) hoặc `multipart/form-data` (nếu đính kèm file trong trường `evidence`, tối đa `5` ảnh, mỗi ảnh `<= 5MB`).
- **Request Body (`CreateReportDto`)**:
  | Trường | Kiểu | Bắt buộc | Validation Constraints |
  |---|---|---|---|
  | `productId` | `string` | **Có** | `@IsMongoId()` |
  | `reason` | `string` | **Có** | `3..150` ký tự |
  | `description` | `string` | Không | Tối đa `1500` ký tự |
  | `evidenceUrls` | `string[]` | Không | Tối đa `5` URL ảnh bằng chứng |
- **Quy tắc nghiệp vụ**:
  - Người bán không thể tự báo cáo sản phẩm của chính mình (`400 BAD_REQUEST` `"You cannot report your own product listing"`).
  - Mỗi người dùng chỉ được gửi 1 báo cáo cho mỗi sản phẩm (`409 CONFLICT` `"You have already submitted a report for this product listing"`).
- **Ví dụ Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "_id": "672b3a9f8e1b2c0012345695",
      "id": "672b3a9f8e1b2c0012345695",
      "reporterId": "672b3a9f8e1b2c0012345679",
      "productId": {
        "_id": "672b3a9f8e1b2c0012345681",
        "id": "672b3a9f8e1b2c0012345681",
        "title": "Bàn phím cơ Keychron K6 RGB Gateron Brown Switch",
        "price": 1350000,
        "condition": "LIKE_NEW",
        "status": "ACTIVE",
        "images": ["https://images.unsplash.com/photo-1587829741301-dc798b83add3"],
        "location": "Thủ Đức, TP.HCM"
      },
      "reason": "Thông tin tình trạng chưa chính xác",
      "description": "Sản phẩm thực tế có vết móp ở góc trái chưa được nêu trong bài đăng.",
      "evidenceUrls": [],
      "status": "PENDING",
      "createdAt": "2026-11-06T15:20:00.000Z",
      "updatedAt": "2026-11-06T15:20:00.000Z"
    },
    "meta": {}
  }
  ```

---

### 7.2. Xem danh sách các báo cáo đã gửi của tôi
- **HTTP Method & URL**: `GET /api/v1/reports/me`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Query Parameters**: `page` (`1`), `limit` (`20`, tối đa `100`).
- **HTTP Status Codes**: `200 OK` (Trả về mảng `Report[]` trong `data` và `PaginationMeta` trong `meta`).

---

## NHÓM 8 — AI FEATURES (`/api/v1/ai`)

> Chi tiết toàn diện về kiến trúc 3 tầng, LangGraph Agent Tools, cơ chế cache và ví dụ đầy đủ được trình bày tại **[AI_API_CONTRACT.md](file:///d:/cross-ck/docs/api/AI_API_CONTRACT.md)**. Dưới đây là bảng tóm tắt nhanh 6 endpoints cho Flutter:

| STT | Chức năng | Method & URL | Auth | HTTP Status |
|---|---|---|---|---|
| 8.1 | **AI 1: Tạo tin đăng bán hàng** | `POST /api/v1/ai/generate-listing` | Bearer JWT | `200 OK` |
| 8.2 | **AI 2: Định giá đồ cũ 3 mức** | `POST /api/v1/ai/estimate-price` | Bearer JWT | `200 OK` |
| 8.3 | **AI 3: Tạo Checklist kiểm tra & Câu hỏi cho người bán** | `POST /api/v1/ai/buyer-checklist` | Bearer JWT | `200 OK` |
| 8.4 | **AI 4: Trợ lý mua sắm đa lượt (Multi-turn Chat)** | `POST /api/v1/ai/chat` | Bearer JWT | `200 OK` |
| 8.5 | **Lấy lịch sử hội thoại AI theo `conversationId`** | `GET /api/v1/ai/conversations/:conversationId` | Bearer JWT (Owner) | `200 OK` |
| 8.6 | **Xóa lịch sử hội thoại AI theo `conversationId`** | `DELETE /api/v1/ai/conversations/:conversationId` | Bearer JWT (Owner) | `200 OK` |

---

## NHÓM 9 — UPLOAD HÌNH ẢNH & HEALTH CHECK (`/api/v1/upload`, `/api/v1/health`)

### 9.1. Upload danh sách ảnh sản phẩm / avatar (`POST /api/v1/upload/images`)
- **HTTP Method & URL**: `POST /api/v1/upload/images`
- **Authentication**: **Required** (`Authorization: Bearer <accessToken>`)
- **Headers**: `Content-Type: multipart/form-data`
- **Form Data Field**:
  - `images`: Từ `1` đến `10` files ảnh.
  - **Giới hạn dung lượng**: Tối đa `5MB` (`5,242,880` bytes) mỗi file.
  - **Định dạng cho phép (Magic-bytes + MIME verified)**: `image/jpeg` (`.jpg`, `.jpeg`), `image/png` (`.png`), `image/webp` (`.webp`).
- **HTTP Status Codes**:
  - `201 Created`: Upload thành công, trả về danh sách URL công khai (`urls: string[]`) và chi tiết từng file (`files`).
  - `400 Bad Request` (`VALIDATION_ERROR`): Không có file, quá 10 files, vượt quá 5MB, hoặc file giả mạo phần mở rộng (không khớp magic bytes JPEG/PNG/WEBP).
- **Ví dụ Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "message": "Images uploaded successfully",
    "data": {
      "urls": [
        "http://localhost:3000/uploads/products/1730905000000-a1b2c3d4.jpg"
      ],
      "files": [
        {
          "url": "http://localhost:3000/uploads/products/1730905000000-a1b2c3d4.jpg",
          "key": "products/1730905000000-a1b2c3d4.jpg",
          "originalName": "keychron-k6.jpg",
          "mimeType": "image/jpeg",
          "size": 245120
        }
      ]
    },
    "meta": {}
  }
  ```

---

### 9.2. Kiểm tra trạng thái hệ thống (`GET /api/v1/health`)
- **HTTP Method & URL**: `GET /api/v1/health`
- **Authentication**: Public
- **HTTP Status Codes**: `200 OK`
- **Ví dụ Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Success",
    "data": {
      "status": "ok",
      "service": "remarket-backend",
      "timestamp": "2026-11-06T15:30:00.000Z",
      "uptime": 3600.45,
      "database": {
        "status": "connected"
      }
    },
    "meta": {}
  }
  ```

---

## 10. ORDERS & PAYMENTS (`/api/v1/orders`)

Tất cả endpoint `/api/v1/orders/*` đều yêu cầu **Bearer JWT Authentication**. Backend luôn lấy `userId` từ JWT payload (`@CurrentUser()`), không bao giờ tin tưởng `buyerId`/`sellerId` từ request body.

### 10.1. Tạo đơn mua hàng & giữ chỗ sản phẩm (`POST /api/v1/orders`)
- **HTTP Method & URL**: `POST /api/v1/orders`
- **Authentication**: Bearer JWT (Buyer)
- **Request Body (`CreateOrderDto`)**:
  ```json
  {
    "productId": "672b3a9f8e1b2c0012345678",
    "deliveryMethod": "DELIVERY",
    "paymentMethod": "BANK_TRANSFER",
    "shippingAddress": "Tòa B4 KTX Khu B ĐHQG, Dĩ An, Bình Dương",
    "recipientName": "Trần Thị Minh Anh",
    "recipientPhone": "0912345678",
    "buyerNote": "Giao giờ hành chính giúp mình",
    "conversationId": "672b3a9f8e1b2c0099887766"
  }
  ```
- **HTTP Status Codes**:
  - `201 Created`: Tạo đơn thành công, chuyển `Product.status` sang `RESERVED` một cách atomic, khởi tạo bản ghi `Payment` (`UNPAID`).
  - `400 Bad Request`: Tự mua sản phẩm của chính mình, phương thức thanh toán không khớp phương thức nhận hàng, hoặc thiếu `shippingAddress` khi chọn `DELIVERY`.
  - `409 Conflict`: Sản phẩm không còn ở trạng thái `ACTIVE` hoặc đã được người mua khác đặt giữ chỗ.

### 10.2. Danh sách đơn hàng (`GET /api/v1/orders`, `GET /api/v1/orders/buyer`, `GET /api/v1/orders/seller`)
- **Query Params**: `status` (tùy chọn: `PENDING`, `CONFIRMED`, `SHIPPING`, `DELIVERED`, `COMPLETED`, `REJECTED`, `CANCELLED`), `page`, `limit`.
- **HTTP Status Codes**: `200 OK`

### 10.3. Tra cứu đơn đang hoạt động theo sản phẩm (`GET /api/v1/orders/by-product/:productId`)
- **HTTP Method & URL**: `GET /api/v1/orders/by-product/:productId`
- **Authentication**: Bearer JWT (Trả về đơn hàng liên quan đến sản phẩm mà user hiện tại là Buyer hoặc Seller, hoặc `null`).

### 10.4. Chi tiết đơn hàng (`GET /api/v1/orders/:id`)
- **HTTP Method & URL**: `GET /api/v1/orders/:id`
- **Authorization**: Chỉ `buyerId` hoặc `sellerId` của đơn hàng mới được phép truy cập (`403 Forbidden` nếu là bên thứ ba).
- **Bảo mật thông tin ngân hàng**: Trường `sellerBankInfo` (`bankName`, `accountNumber`, `accountHolder`, `branch`, `amount`, `transferContent`) chỉ được trả về khi đơn hàng hợp lệ (không phải `CANCELLED`/`REJECTED`) và người bán đã cấu hình.

### 10.5. Người bán xác nhận / từ chối / cập nhật giao hàng
- `PATCH /api/v1/orders/:id/confirm`: Seller xác nhận đơn (`PENDING` $\rightarrow$ `CONFIRMED`).
- `PATCH /api/v1/orders/:id/reject`: Seller từ chối đơn (`PENDING` $\rightarrow$ `REJECTED`) và khôi phục `Product.status` về `ACTIVE` nếu không còn đơn hợp lệ nào khác.
- `PATCH /api/v1/orders/:id/delivery`: Seller cập nhật trạng thái giao hàng (`CONFIRMED` $\rightarrow$ `SHIPPING` $\rightarrow$ `DELIVERED`).

### 10.6. Người mua hủy đơn / xác nhận hoàn tất
- `PATCH /api/v1/orders/:id/cancel`: Buyer hủy đơn (`PENDING`/`CONFIRMED` khi chưa `PAID` $\rightarrow$ `CANCELLED`) và khôi phục `Product.status` về `ACTIVE`.
- `PATCH /api/v1/orders/:id/complete`: Buyer xác nhận đã nhận hàng (`CONFIRMED`/`SHIPPING`/`DELIVERED` $\rightarrow$ `COMPLETED`), chuyển `Product.status` sang `SOLD`.

### 10.7. Xác nhận thanh toán chuyển khoản 2 bước
- `POST /api/v1/orders/:id/payment-confirmation`: **Buyer** xác nhận đã chuyển khoản (`UNPAID` $\rightarrow$ `BUYER_CONFIRMED`), kèm `transactionReference` và `transferNote` tùy chọn.
- `PATCH /api/v1/orders/:id/payment/confirm`: **Seller** xác nhận đã nhận tiền (`BUYER_CONFIRMED` $\rightarrow$ `PAID`). Chỉ hợp lệ sau khi Buyer đã gửi xác nhận chuyển khoản.

---

## 11. NOTIFICATIONS (`/api/v1/notifications`)

- `GET /api/v1/notifications`: Lấy danh sách thông báo đơn hàng, thanh toán & đánh giá của người dùng hiện tại (`ORDER_CREATED`, `ORDER_CONFIRMED`, `ORDER_REJECTED`, `ORDER_CANCELLED`, `PAYMENT_BUYER_CONFIRMED`, `PAYMENT_CONFIRMED_BY_SELLER`, `ORDER_COMPLETED`, `REVIEW_RECEIVED`, `REVIEW_REPLIED`).
- `PATCH /api/v1/notifications/:id/read`: Đánh dấu 1 thông báo là đã đọc.
- `PATCH /api/v1/notifications/read-all`: Đánh dấu tất cả thông báo là đã đọc.

---

## 12. REVIEWS & SELLER REPUTATION (`/api/v1/reviews`, `/api/v1/sellers`)

> Chi tiết quy trình xác thực giao dịch thật và công thức tính Điểm uy tín Bayesian được mô tả tại **[REVIEW_WORKFLOW.md](file:///d:/cross-ck/docs/architecture/REVIEW_WORKFLOW.md)** và **[SELLER_REPUTATION.md](file:///d:/cross-ck/docs/architecture/SELLER_REPUTATION.md)**.

### 12.1. Tạo đánh giá người bán sau giao dịch (`POST /api/v1/reviews`)
- **Authentication**: Bearer JWT (Chỉ `buyerId` của đơn hàng đã `COMPLETED`).
- **Request Body (`CreateReviewDto`)**:
  ```json
  {
    "orderId": "672b3a9f8e1b2c0012349900",
    "rating": 5,
    "comment": "Tai nghe Sony XM4 đúng như mô tả, chống ồn tốt, người bán giao đúng hẹn!",
    "images": [
      "http://localhost:3000/uploads/products/1730905000000-review1.jpg"
    ]
  }
  ```
- **HTTP Status Codes**:
  - `201 Created`: Tạo đánh giá thành công, cập nhật `Order.reviewId` và tính toán lại `User.reputationCache`.
  - `400 Bad Request`: Đơn hàng chưa đạt trạng thái `COMPLETED`, nhận xét quá ngắn (`< 10` ký tự), hoặc vượt quá `5` ảnh.
  - `403 Forbidden`: Người gọi không phải `buyerId` của đơn hàng.
  - `409 Conflict`: Đơn hàng này đã có đánh giá trước đó (`unique_review_per_order_idx`).

### 12.2. Upload hình ảnh thực tế cho đánh giá (`POST /api/v1/reviews/upload-images`)
- **Authentication**: Bearer JWT (`multipart/form-data`, trường `images`, tối đa `5` ảnh, mỗi ảnh `<= 5MB`, định dạng `JPEG/PNG/WEBP`).
- **HTTP Status Codes**: `201 Created` (Trả về `{ urls: string[], files: [...] }`).

### 12.3. Xem / Chỉnh sửa / Kiểm soát xóa đánh giá
- `GET /api/v1/reviews/:id`: Lấy chi tiết một đánh giá (Public).
- `GET /api/v1/orders/:orderId/review`: Lấy đánh giá gắn với một đơn hàng cụ thể (Bearer JWT — Buyer hoặc Seller của đơn hàng).
- `PATCH /api/v1/reviews/:id`: Buyer chỉnh sửa `rating`, `comment`, `images` trong vòng **07 ngày** đầu kể từ `createdAt` (Bearer JWT — Owner).
- `DELETE /api/v1/reviews/:id`: Bị chặn (`403 Forbidden`) để bảo vệ tính minh bạch của lịch sử uy tín; việc ẩn/xóa chỉ thực hiện qua luồng kiểm duyệt (`VISIBLE` $\rightarrow$ `HIDDEN`/`DELETED`).

### 12.4. Người bán phản hồi & Báo cáo vi phạm
- `POST /api/v1/reviews/:id/reply`: Seller phản hồi đánh giá (`{ "reply": "Cảm ơn bạn đã ủng hộ shop!" }`, tối đa **01 phản hồi** cho mỗi đánh giá, không làm thay đổi `rating`/`comment` của Buyer).
- `POST /api/v1/reviews/:id/report`: Báo cáo đánh giá vi phạm tiêu chuẩn cộng đồng (`{ "reason": "...", "description": "..." }`).

### 12.5. Danh sách đánh giá & Điểm uy tín người bán (`GET /api/v1/sellers/:sellerId/reviews`, `GET /api/v1/sellers/:sellerId/reputation`)
- `GET /api/v1/sellers/:sellerId/reviews`:
  - **Query Params**: `page` (`1`), `limit` (`10`), `rating` (`1..5`, tùy chọn), `sort` (`newest` | `oldest` | `highest` | `lowest`).
  - **Response (`200 OK`)**: Trả về `{ items: Review[], ratingSummary, meta }` trong `data`.
- `GET /api/v1/sellers/:sellerId/reputation`:
  - **Response (`200 OK`)**: Trả về `reputationScore` (`0..100`), `reputationTier` (`TRUSTED_SELLER` | `RELIABLE_SELLER` | `NEW_SELLER` | `NEEDS_IMPROVEMENT`), `averageRating`, `ratingSummary` (`totalReviews`, `star5Count`..`star1Count`, `ratingDistribution`), `transactionStats` (`completedOrdersCount`, `buyerCancelledOrdersCount`, `sellerRejectedOrdersCount`, `successfulTransactionRate`, `sellerReplyRate`), và `breakdown` điểm thành phần.


