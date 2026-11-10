# ReMarket — Backend Architecture

## 1. Directory & Module Organization

The backend lives in `apps/backend` and follows a strict feature-modular structure:

```text
apps/backend/src/
├── common/
│   ├── decorators/       # @CurrentUser() parameter decorator
│   ├── dto/              # Shared PaginationMetaDto & ApiErrorResponseDto for Swagger
│   ├── filters/          # GlobalExceptionFilter (standardized error envelope)
│   ├── guards/           # Shared guards
│   ├── interceptors/     # TransformInterceptor (standardized success envelope)
│   ├── interfaces/       # ApiResponse, JwtPayload, IStorageProvider interfaces
│   ├── pipes/            # ParseObjectIdPipe for MongoDB ObjectId validation
│   └── utils/            # Duration parser & regex escape helpers
├── config/
│   └── configuration.ts  # Centralized typed environment configuration
├── database/
│   ├── database.module.ts# Mongoose async connection setup
│   └── seed.ts           # Idempotent CLI seed script for demo data
├── modules/
│   ├── auth/             # Registration, login, JWT strategy, refresh rotation, logout, wishlist
│   ├── users/            # Authenticated profile management, public seller profiles, wishlist storage
│   ├── categories/       # Marketplace categories & automatic startup seeding
│   ├── products/         # Product CRUD, status state machine, weighted text search & filtering
│   ├── messages/         # Buyer-seller conversations & messages with participant authorization
│   ├── reports/          # Product violation reports with anti-spam & evidence upload support
│   ├── upload/           # Multer multi-image upload & LocalStorageProvider abstraction
│   └── health/           # Service & MongoDB connection health check
├── app.module.ts         # Root NestJS module
└── main.ts               # Application bootstrap, Helmet, CORS, ValidationPipe, Swagger
```

---

## 2. Request Processing Pipeline

Every incoming HTTP request passes through a predictable, defense-in-depth pipeline:

1. **Security Middleware (`helmet`, `cors`)**: Sets HTTP security headers and configures cross-origin access for Flutter/web clients.
2. **Rate Limiting (`ThrottlerGuard`)**: Protects all endpoints globally and applies stricter limits (`10 req/min`) on `/api/v1/auth/register` and `/api/v1/auth/login`.
3. **Authentication Guard (`JwtAuthGuard`)**: Extracts Bearer JWTs on protected routes, verifies signature and expiration, confirms the user exists and is `ACTIVE`, and attaches `req.user` (`{ userId, email }`).
4. **Validation Pipe (`ValidationPipe` & `ParseObjectIdPipe`)**:
   - Strips unknown properties (`whitelist: true`).
   - Rejects unexpected payload fields (`forbidNonWhitelisted: true`).
   - Transforms query parameters into typed DTO instances (`transform: true`).
   - Validates path `:id` parameters as valid 24-character hex MongoDB ObjectIds.
5. **Controller & Domain Service**: Executes business logic and Mongoose queries using sanitized inputs.
6. **Response Interceptor (`TransformInterceptor`)**: Wraps all successful controller responses into the standard envelope:
   ```json
   {
     "success": true,
     "message": "Success",
     "data": {},
     "meta": {
       "page": 1,
       "limit": 12,
       "total": 42,
       "totalPages": 4
     }
   }
   ```
7. **Exception Filter (`GlobalExceptionFilter`)**: Catches all `HttpException`, Multer upload errors, duplicate key errors, and unexpected runtime errors and formats them into:
   ```json
   {
     "success": false,
     "statusCode": 400,
     "message": "Validation failed",
     "error": {
       "code": "VALIDATION_ERROR",
       "details": ["price must not be less than 0"]
     }
   }
   ```

---

## 3. Authentication & Refresh Token Rotation

- **Access Tokens**: Short-lived JWTs (default `15m`) signed with `JWT_ACCESS_SECRET` containing `{ sub, email, type: 'access' }`.
- **Refresh Tokens**: Long-lived JWTs (default `7d`) signed with `JWT_REFRESH_SECRET` containing `{ sub, email, jti, type: 'refresh' }`.
- **Stateful Refresh Revocation**: Each issued refresh token creates a `RefreshSession` document in MongoDB storing `jti`, `userId`, `expiresAt`, `isRevoked`, and a `bcrypt` hash (`tokenHash`) of the refresh token.
- **Token Rotation**: Calling `POST /api/v1/auth/refresh` verifies the refresh JWT, validates the hash against `RefreshSession`, marks the old session `isRevoked = true`, and issues a brand-new access + refresh token pair. Attempting to reuse a rotated or logged-out refresh token immediately fails with `401 Unauthorized`.

---

## 4. Cloud Media Storage Extensibility

Product images are stored as structured subdocuments (`{ url, publicId, sortOrder, altText }`), and `src/common/interfaces/storage-provider.interface.ts` defines the `IStorageProvider` contract (`uploadFile`, `deleteFile`, `getSignedUploadUrl`). When S3 or Cloudinary credentials are added in Phase 2, a concrete storage provider can be injected without breaking the `Product` schema or existing mobile API contracts.
