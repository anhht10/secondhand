# ReMarket — REST API Overview

> **Canonical Reference**: See **[`docs/api/API_CONTRACT.md`](file:///d:/cross-ck/docs/api/API_CONTRACT.md)** for the full Phase 7 Frozen API Contract.

## 1. Base URL & Conventions

- **Base URL**: `http://localhost:3000/api/v1` (Android Emulator: `http://10.0.2.2:3000/api/v1`)
- **Interactive Swagger UI**: `http://localhost:3000/api/docs`
- **Authentication**: Bearer JWT in the `Authorization` header:
  ```http
  Authorization: Bearer <accessToken>
  ```

### Standard Success Response (`TransformInterceptor`)
```json
{
  "success": true,
  "message": "Success",
  "data": { ... },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 2,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPrevPage": false
  }
}
```

### Standard Error Response (`GlobalExceptionFilter`)
```json
{
  "success": false,
  "statusCode": 400,
  "message": "price must not be less than 0",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": ["price must not be less than 0"]
  }
}
```

---

## 2. Detailed Documentation Index

- **[API_CONTRACT.md](file:///d:/cross-ck/docs/api/API_CONTRACT.md)**: Complete specification of all 39 NestJS endpoints, DTO validation constraints, status transitions, and sample payloads.
- **[AUTHENTICATION.md](file:///d:/cross-ck/docs/api/AUTHENTICATION.md)**: JWT access/refresh token lifecycle, rotation flow, and `401` vs `403` handling.
- **[AI_API_CONTRACT.md](file:///d:/cross-ck/docs/api/AI_API_CONTRACT.md)**: 3-tier AI architecture (`Flutter -> NestJS -> FastAPI -> LangGraph Tools`), caching, and anti-hallucination guarantees.
- **[ERROR_HANDLING.md](file:///d:/cross-ck/docs/api/ERROR_HANDLING.md)**: Standardized error envelope and complete error code catalog.
