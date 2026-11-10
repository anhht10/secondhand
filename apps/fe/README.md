# ReMarket — Flutter Frontend (`fe/`)

Ứng dụng di động & đa nền tảng **ReMarket** (Chợ đồ cũ sinh viên thông minh & minh bạch hỗ trợ bởi Gemini AI), xây dựng trên nền tảng **Flutter + Dart + Riverpod 2 + Dio + GoRouter**.

> **Tài liệu API Contract (Phase 7 Frozen)**:
> - [`../docs/api/API_CONTRACT.md`](../docs/api/API_CONTRACT.md) — 39 REST API Endpoints của NestJS Backend (`/api/v1`).
> - [`../docs/api/AUTHENTICATION.md`](../docs/api/AUTHENTICATION.md) — Cơ chế JWT Access/Refresh Token Rotation & `401` vs `403`.
> - [`../docs/api/AI_API_CONTRACT.md`](../docs/api/AI_API_CONTRACT.md) — 4 Tính năng AI LangGraph + Gemini.
> - [`../docs/api/ERROR_HANDLING.md`](../docs/api/ERROR_HANDLING.md) — Chuẩn hóa Error Envelope & Mã lỗi.

---

## 1. Cài đặt Dependencies

Yêu cầu hệ thống:
- **Flutter SDK**: `>= 3.44.0` (Dart `^3.12.1`)

```powershell
cd D:\cross-ck\fe
flutter pub get
```

---

## 2. Cấu hình Môi trường & Base URL (`AppConfig`)

Ứng dụng không hardcode rải rác địa chỉ máy chủ. Mọi cấu hình nằm tại [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart) và tự động nhận diện nền tảng nếu không truyền `--dart-define`:

| Nền tảng / Môi trường | Giá trị `API_BASE_URL` mặc định | Lệnh chạy tùy chỉnh (`--dart-define`) |
|---|---|---|
| **Web / iOS Simulator / Desktop** | `http://localhost:3000/api/v1` | `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1` |
| **Android Emulator (AVD)** | `http://10.0.2.2:3000/api/v1` | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1` |
| **Thiết bị thật (Physical Device cùng LAN)** | Truyền IP LAN của máy chạy Backend | `flutter run --dart-define=API_BASE_URL=http://192.168.1.15:3000/api/v1` |
| **Production** | Truyền domain thật & `APP_ENV=production` | `flutter build apk --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.remarket.vn/api/v1` |

> **Lưu ý quan trọng**: `localhost` trên Android Emulator hoặc điện thoại thật trỏ tới chính thiết bị đó chứ không phải máy tính đang chạy NestJS Backend. Với Android Emulator, `AppConfig.resolveDefaultBaseUrl()` tự động dùng `http://10.0.2.2:3000/api/v1`, đồng thời cung cấp hàm `config.resolveMediaUrl(url)` để chuyển đổi URL ảnh `localhost:3000` sang `10.0.2.2:3000`.

---

## 3. Cách chạy Ứng dụng & Kiểm thử

### 3.1. Khởi chạy Backend trước khi chạy App
```powershell
# 1. Đảm bảo MongoDB và NestJS Backend (:3000) đang chạy
cd D:\cross-ck\apps\backend
npm run seed
npm run start:dev
```

### 3.2. Chạy ứng dụng Flutter
```powershell
cd D:\cross-ck\fe
flutter run -d chrome
# Hoặc trên Android Emulator:
flutter run
```

### 3.3. Chạy Static Analysis & Unit/Widget Tests
```powershell
cd D:\cross-ck\fe
flutter analyze
flutter test
```

---

## 4. Cấu trúc Thư mục (Feature-First Layered Architecture)

```text
fe/
├── lib/
│   ├── main.dart                     # Điểm vào ứng dụng
│   ├── bootstrap.dart                # Khởi tạo WidgetsBinding, SharedPreferences & ProviderScope
│   │
│   ├── app/
│   │   ├── app.dart                  # ReMarketApp (MaterialApp.router + AppTheme)
│   │   ├── router/
│   │   │   ├── app_router.dart       # Cấu hình GoRouter + computeAuthRedirect
│   │   │   └── route_names.dart      # Tập trung toàn bộ tên & đường dẫn route
│   │   └── theme/
│   │       ├── app_colors.dart       # Bảng màu Modern White & Royal Blue (#2563EB)
│   │       ├── app_spacing.dart      # Spacing 4pt grid, BorderRadius & Shadows
│   │       ├── app_typography.dart   # Hệ thống phân cấp chữ (Display, Headline, Body, Price)
│   │       └── app_theme.dart        # Cấu hình Material 3 ThemeData
│   │
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart       # Quản lý môi trường dev/prod & API_BASE_URL
│   │   ├── constants/
│   │   │   └── app_constants.dart    # Hằng số & storage keys
│   │   ├── errors/
│   │   │   └── api_exception.dart    # Parse chuẩn Error Envelope từ GlobalExceptionFilter
│   │   ├── network/
│   │   │   ├── api_endpoints.dart    # Tập trung 39 đường dẫn API của NestJS
│   │   │   ├── dio_client.dart       # ApiClient duy nhất, tự bóc tách TransformInterceptor
│   │   │   ├── network_result.dart   # Sealed class NetworkResult (NetworkSuccess / NetworkFailure)
│   │   │   └── interceptors/
│   │   │       ├── auth_interceptor.dart    # Gắn Bearer JWT & Single-flight Refresh Token Rotation
│   │   │       └── logging_interceptor.dart # Log HTTP ở dev mode, tự che mật khẩu & token
│   │   ├── storage/
│   │   │   ├── token_storage.dart    # Lưu trữ Access/Refresh Token qua FlutterSecureStorage
│   │   │   └── local_preferences.dart# Lưu trữ User snapshot qua SharedPreferences
│   │   ├── utils/
│   │   │   ├── validators.dart       # Validate form khớp 1:1 với DTO của NestJS
│   │   │   └── formatters.dart       # Định dạng tiền tệ VNĐ (intl)
│   │   └── widgets/                  # Bộ Design System Widgets dùng chung
│   │       ├── rm_button.dart
│   │       ├── rm_text_field.dart
│   │       ├── rm_card.dart
│   │       ├── rm_loading_indicator.dart
│   │       ├── rm_empty_state.dart
│   │       └── rm_error_state.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/                 # AuthRemoteDataSource, AuthRepositoryImpl, DTO Models
│   │   │   ├── domain/               # AuthRepository interface, AuthState & AuthStatus
│   │   │   └── presentation/         # AuthController (Riverpod) + Splash/Login/Register Screens
│   │   ├── home/
│   │   │   └── presentation/screens/ # Home screen nền tảng
│   │   └── profile/
│   │       └── presentation/screens/ # Profile screen nền tảng + thống kê người bán & Logout
│   │
│   └── shared/
│       ├── models/
│       │   └── user_model.dart       # UserModel & SellerStatsModel
│       └── widgets/
│           └── main_shell_scaffold.dart # Bottom Navigation Shell
│
└── test/                             # Bộ kiểm thử tự động (API Client, Auth, Storage, Validators, Router)
```

---

## 5. Hướng dẫn Tạo Feature Mới (Phase 9+)

Khi phát triển các tính năng mới ở Phase 9 (`products`, `wishlist`, `messages`, `reports`, `ai_assistant`), tuân thủ quy trình 4 bước:

1. **Bước 1 — Data Layer (`lib/features/<feature>/data/`)**:
   - Tạo model có `fromJson` / `toJson`.
   - Tạo `<Feature>RemoteDataSource` nhận `ApiClient` từ `apiClientProvider` (**không bao giờ tự khởi tạo `Dio()` riêng**).
   - Tạo `<Feature>RepositoryImpl` thực thi interface trong `domain/`.
2. **Bước 2 — Domain Layer (`lib/features/<feature>/domain/`)**:
   - Khai báo interface `<Feature>Repository` và immutable `<Feature>State`.
3. **Bước 3 — Application / Riverpod (`lib/features/<feature>/presentation/controllers/`)**:
   - Khai báo `Provider` cho DataSource/Repository và `StateNotifierProvider` (hoặc `FutureProvider` / `AsyncNotifierProvider`) cho Controller.
4. **Bước 4 — Presentation (`lib/features/<feature>/presentation/screens/`)**:
   - Xây dựng UI bằng `ConsumerWidget` / `ConsumerStatefulWidget`, sử dụng các thành phần từ `lib/core/widgets/` (`RmButton`, `RmTextField`, `RmCard`, `RmLoadingIndicator`, `RmEmptyState`, `RmErrorState`) và `AppColors` / `AppTypography` / `AppSpacing`.

---

## 6. Cách Gọi API chuẩn với `ApiClient` & `NetworkResult<T>`

`ApiClient` tự động bóc lớp vỏ `{ "success": true, "message": "...", "data": ..., "meta": ... }` của NestJS `TransformInterceptor` và trả về `NetworkResult<T>`:

```dart
final result = await _apiClient.get<List<ProductModel>>(
  ApiEndpoints.products,
  queryParameters: {'page': 1, 'limit': 20, 'sortBy': 'createdAt', 'sortOrder': 'desc'},
  parser: (rawData) => (rawData as List<dynamic>)
      .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
      .toList(),
);

result.when(
  success: (products, message, paginationMeta) {
    // Xử lý danh sách sản phẩm và phân trang (paginationMeta?.hasNextPage)
  },
  failure: (apiException) {
    // Hiển thị apiException.message hoặc kiểm tra apiException.code
  },
);
```

---

## 7. Luồng Xác thực (Authentication & Session Lifecycle)

1. **Khởi động ứng dụng (`Restore Session`)**:
   - `AuthController` khởi tạo ở trạng thái `AuthStatus.initial` -> chuyển sang `AuthStatus.restoring`.
   - `GoRouter` giữ ứng dụng tại `SplashScreen` (`/splash`).
   - `AuthRepositoryImpl.restoreSession()` kiểm tra `TokenStorage`:
     - Nếu có token hợp lệ -> gọi `GET /api/v1/auth/me` để lấy thông tin mới nhất và chuyển sang `AuthStatus.authenticated` -> `GoRouter` tự động điều hướng tới `/home`.
     - Nếu không có token hoặc token hết hạn không thể refresh -> xóa phiên cục bộ và chuyển sang `AuthStatus.unauthenticated` -> `GoRouter` tự động điều hướng tới `/login`.
2. **Single-Flight Refresh Token Rotation**:
   - Khi `accessToken` hết hạn (sau 15 phút) và một hoặc nhiều request nhận `401 Unauthorized` cùng lúc, `AuthInterceptor` khóa hàng đợi bằng `Completer<bool>` để **chỉ gửi duy nhất 1 request** `POST /api/v1/auth/refresh`.
   - Khi nhận cặp `accessToken` và `refreshToken` mới từ Backend, `AuthInterceptor` lưu cả hai vào `TokenStorage` và tự động thực thi lại toàn bộ các request vừa bị `401`.
   - Nếu `/api/v1/auth/refresh` thất bại (`401`/`403`), `AuthInterceptor` xóa token và gọi `onSessionExpired` để đưa người dùng về màn hình Đăng nhập.
