# ReMarket — Backend Audit, Hardening & Production Readiness Report (Phase 1–3)

## 1. Cấu trúc dự án (`D:\cross-ck`)

- **Backend chính thức duy nhất**: `D:\cross-ck\apps\backend`
- **Documentation**: `D:\cross-ck\docs`
- **Infrastructure & Docker**: `D:\cross-ck\infrastructure\docker` & `D:\cross-ck\docker-compose.yml`

---

## 2. Full Backend Audit Table (Phase 3)

| Module | Completed | Partial | Missing | Issues |
| :--- | :--- | :--- | :--- | :--- |
| **AuthModule** | `AuthController`, `AuthService`, `JwtStrategy`, `JwtAuthGuard`, `OptionalJwtAuthGuard`, `RefreshSession` schema (`jti`, `tokenHash`, TTL index), `register`, `login`, `refresh`, `logout`, `me`, và Wishlist (`GET/POST/DELETE /api/v1/auth/wishlist`). Unit & E2E tests đầy đủ. | Không có | Không có | Đã loại bỏ khai báo `index: true` dư thừa trên `jti` (đã có `unique: true`) và tối ưu bằng compound index `{ userId: 1, isRevoked: 1 }`. |
| **UsersModule** | `UsersController`, `UsersService`, `User` schema (`passwordHash` ẩn bằng `select: false` & `toJSON`), `GET /api/v1/users/me`, `PATCH /api/v1/users/me`, `GET /api/v1/users/:id` (ẩn `email` & `passwordHash`). Unit & E2E tests đầy đủ. | Không có | Không có | Đã loại bỏ `index: true` dư thừa trên `email` (đã có `unique: true`). |
| **CategoriesModule** | `CategoriesController`, `CategoriesService`, `Category` schema, tự động seed idempotent 7 danh mục gốc/con khi khởi động (`OnModuleInit`), `GET /api/v1/categories`, `GET /api/v1/categories/:id`. Unit & E2E tests đầy đủ. | Không có | Không có | Đã bổ sung compound index `{ isActive: 1, sortOrder: 1, name: 1 }` tối ưu trực tiếp truy vấn danh mục đang hoạt động. |
| **ProductsModule** | `ProductsController`, `ProductsService`, `Product` & `ProductImage` schemas, đầy đủ CRUD, kiểm tra quyền sở hữu (`403 Forbidden`), máy trạng thái (`DRAFT`, `ACTIVE`, `SOLD`, `ARCHIVED`), `GET /api/v1/products/me/listings`, weighted text search (`product_text_search_idx`), lọc & phân trang, tự động dọn ảnh/conversation/report khi xóa sản phẩm. | Không có | Không có | Đã bổ sung compound index `{ sellerId: 1, status: 1, createdAt: -1 }` và loại bỏ single-field index bị trùng prefix. |
| **UploadModule** | `UploadController`, `UploadService`, `LocalStorageProvider` (`IStorageProvider`), Multer memory storage, kiểm tra MIME (`image/jpeg`, `image/png`, `image/webp`), giới hạn `5MB/file`, tối đa `10 files`, chống path traversal và sanitize tên file. | Không có | Không có | Đã tăng cường sanitize `defaultAlt` và cố định phần mở rộng file an toàn tuyệt đối theo MIME type. |
| **MessagesModule** | `MessagesController`, `MessagesService`, `Conversation` & `Message` schemas, tạo/lấy cuộc hội thoại, chống tự nhắn tin với chính mình, chống tạo hội thoại trùng (`unique_buyer_seller_product_conversation_idx`), phân trang tin nhắn, đánh dấu đã đọc (`PATCH /api/v1/messages/:id/read`), chặn người lạ truy cập (`403 Forbidden`). | Không có | Không có | Đã loại bỏ `index: true` đơn lẻ bị trùng prefix với compound index trên `buyerId`, `sellerId`, `conversationId`. |
| **ReportsModule** | `ReportsController`, `ReportsService`, `Report` schema, gửi báo cáo kèm ảnh bằng chứng (`POST /api/v1/reports`), xem báo cáo của bản thân (`GET /api/v1/reports/me`), chặn tự báo cáo sản phẩm của mình (`400`), chặn spam báo cáo trùng (`409 Conflict` & `unique_reporter_product_report_idx`). | Không có | Không có | Đã loại bỏ `index: true` đơn lẻ bị trùng prefix trên `reporterId`. |
| **Common / Core** | `TransformInterceptor`, `GlobalExceptionFilter`, `ParseObjectIdPipe`, `@CurrentUser()`, `Helmet`, `CORS`, `ThrottlerGuard`, `ValidationPipe`, `Swagger` (`/api/docs`), `HealthModule` (`/api/v1/health`). | Không có | Không có | Đã chuẩn hóa hoàn toàn envelope phản hồi thành công (`{ success, message, data, meta }`) và lỗi (`{ success, statusCode, message, error: { code, details } }`), tách biệt database test (`remarket_test`). |
