import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/app/app.dart';
import 'package:remarket_fe/app/router/app_router.dart';
import 'package:remarket_fe/app/router/route_names.dart';
import 'package:remarket_fe/core/errors/api_exception.dart';
import 'package:remarket_fe/core/network/network_result.dart';
import 'package:remarket_fe/features/auth/domain/auth_repository.dart';
import 'package:remarket_fe/features/auth/domain/auth_state.dart';
import 'package:remarket_fe/features/auth/presentation/controllers/auth_controller.dart';
import 'package:remarket_fe/features/categories/data/models/category_model.dart';
import 'package:remarket_fe/features/categories/presentation/providers/category_providers.dart';
import 'package:remarket_fe/features/products/data/models/product_model.dart';
import 'package:remarket_fe/features/products/data/repositories/product_repository.dart';
import 'package:remarket_fe/features/products/presentation/providers/product_providers.dart';
import 'package:remarket_fe/features/wishlist/data/repositories/wishlist_repository.dart';
import 'package:remarket_fe/features/wishlist/presentation/providers/wishlist_providers.dart';
import 'package:remarket_fe/shared/models/user_model.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.initialUser});

  UserModel? initialUser;
  bool shouldFailLogin = false;

  static const UserModel demoUser = UserModel(
    id: '672b3a9f8e1b2c0012345678',
    email: 'nguyen.an@student.edu.vn',
    displayName: 'Nguyễn Văn An',
    location: 'Thủ Đức, TP.HCM',
    stats: SellerStatsModel(
      activeListingsCount: 5,
      soldListingsCount: 2,
      rating: 4.9,
      transparencyRate: 98,
    ),
  );

  @override
  Future<NetworkResult<UserModel?>> restoreSession() async {
    return NetworkSuccess<UserModel?>(data: initialUser);
  }

  @override
  Future<NetworkResult<UserModel>> login({
    required String email,
    required String password,
  }) async {
    if (shouldFailLogin) {
      return const NetworkFailure<UserModel>(
        ApiException(
          message: 'Invalid email or password',
          code: ApiErrorCodes.unauthorized,
          statusCode: 401,
        ),
      );
    }
    return const NetworkSuccess<UserModel>(data: demoUser);
  }

  @override
  Future<NetworkResult<UserModel>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? location,
  }) async {
    return NetworkSuccess<UserModel>(
      data: UserModel(
        id: 'new-user-id',
        email: email,
        displayName: displayName,
        phone: phone,
        location: location,
      ),
    );
  }

  @override
  Future<NetworkResult<UserModel>> refreshProfile() async {
    return const NetworkSuccess<UserModel>(data: demoUser);
  }

  @override
  Future<void> logout() async {
    initialUser = null;
  }
}

class _FakeProductRepository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<ProductFeedResponse>> getProducts(
    ProductFilterQuery query,
  ) async {
    return const NetworkSuccess<ProductFeedResponse>(
      data: ProductFeedResponse(items: <ProductModel>[]),
    );
  }
}

class _FakeWishlistRepository implements WishlistRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<List<ProductModel>>> getWishlist() async {
    return const NetworkSuccess<List<ProductModel>>(data: <ProductModel>[]);
  }
}

void main() {
  group('GoRouter computeAuthRedirect', () {
    test('redirects to /splash while restoring session without loops', () {
      const restoringState = AuthState(status: AuthStatus.restoring);
      expect(
        computeAuthRedirect(
          authState: restoringState,
          matchedLocation: RouteNames.homePath,
        ),
        equals(RouteNames.splashPath),
      );
      expect(
        computeAuthRedirect(
          authState: restoringState,
          matchedLocation: RouteNames.splashPath,
        ),
        isNull,
      );
    });

    test('redirects unauthenticated users from protected routes to /login', () {
      const unauthState = AuthState(status: AuthStatus.unauthenticated);
      expect(
        computeAuthRedirect(
          authState: unauthState,
          matchedLocation: RouteNames.homePath,
        ),
        equals(RouteNames.loginPath),
      );
      expect(
        computeAuthRedirect(
          authState: unauthState,
          matchedLocation: RouteNames.profilePath,
        ),
        equals(RouteNames.loginPath),
      );
      expect(
        computeAuthRedirect(
          authState: unauthState,
          matchedLocation: RouteNames.loginPath,
        ),
        isNull,
      );
      expect(
        computeAuthRedirect(
          authState: unauthState,
          matchedLocation: RouteNames.registerPath,
        ),
        isNull,
      );
    });

    test(
      'redirects authenticated users away from /splash, /login, /register to /home',
      () {
        const authState = AuthState(
          status: AuthStatus.authenticated,
          user: _FakeAuthRepository.demoUser,
        );
        expect(
          computeAuthRedirect(
            authState: authState,
            matchedLocation: RouteNames.splashPath,
          ),
          equals(RouteNames.homePath),
        );
        expect(
          computeAuthRedirect(
            authState: authState,
            matchedLocation: RouteNames.loginPath,
          ),
          equals(RouteNames.homePath),
        );
        expect(
          computeAuthRedirect(
            authState: authState,
            matchedLocation: RouteNames.homePath,
          ),
          isNull,
        );
        expect(
          computeAuthRedirect(
            authState: authState,
            matchedLocation: RouteNames.profilePath,
          ),
          isNull,
        );
      },
    );
  });

  group('Auth UI & 5-Tab Shell Routing Flow', () {
    testWidgets(
      'unauthenticated launch redirects to LoginScreen, validates form, logs in to HomeScreen, and logs out from ProfileScreen',
      (WidgetTester tester) async {
        final fakeRepo = _FakeAuthRepository(initialUser: null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authRepositoryProvider.overrideWithValue(fakeRepo),
              productRepositoryProvider
                  .overrideWithValue(_FakeProductRepository()),
              wishlistRepositoryProvider
                  .overrideWithValue(_FakeWishlistRepository()),
              categoriesProvider.overrideWith(
                (ref) async => const <CategoryModel>[],
              ),
            ],
            child: const ReMarketApp(),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Should land on LoginScreen
        expect(find.text('Đăng nhập tài khoản'), findsOneWidget);

        // 2. Submit empty form -> validation errors appear
        final submitBtn = find.byKey(const Key('login_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pump();
        expect(find.text('Vui lòng nhập địa chỉ email.'), findsOneWidget);
        expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);

        // 3. Enter valid credentials and submit
        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          'nguyen.an@student.edu.vn',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'Password123!',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // 4. Redirected to HomeScreen with AI Shopping Assistant banner
        expect(find.text('Trợ lý Mua sắm Gemini AI'), findsOneWidget);

        // 5. Navigate to Profile tab and log out
        await tester.tap(find.text('Hồ sơ'));
        await tester.pumpAndSettle();
        expect(find.text('Hồ sơ & Cửa hàng cá nhân'), findsOneWidget);
        expect(find.text('Nguyễn Văn An'), findsOneWidget);

        final logoutBtn = find.byKey(const Key('logout_button'));
        await tester.ensureVisible(logoutBtn);
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        // 6. Redirected back to LoginScreen
        expect(find.text('Đăng nhập tài khoản'), findsOneWidget);
      },
    );

    testWidgets(
      'RegisterScreen validates password complexity and registers a new user into HomeScreen',
      (WidgetTester tester) async {
        final fakeRepo = _FakeAuthRepository(initialUser: null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authRepositoryProvider.overrideWithValue(fakeRepo),
              productRepositoryProvider
                  .overrideWithValue(_FakeProductRepository()),
              wishlistRepositoryProvider
                  .overrideWithValue(_FakeWishlistRepository()),
              categoriesProvider.overrideWith(
                (ref) async => const <CategoryModel>[],
              ),
            ],
            child: const ReMarketApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate from LoginScreen to RegisterScreen
        final goToRegisterBtn = find.byKey(const Key('go_to_register_button'));
        await tester.ensureVisible(goToRegisterBtn);
        await tester.tap(goToRegisterBtn);
        await tester.pumpAndSettle();

        expect(find.text('Đăng ký thành viên mới'), findsOneWidget);

        // Enter weak password without digits -> validation error
        await tester.enterText(
          find.byKey(const Key('register_display_name_field')),
          'Lê Hoàng Nam',
        );
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'le.nam@student.edu.vn',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'weakpassword',
        );
        await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')),
          'weakpassword',
        );

        final registerSubmitBtn =
            find.byKey(const Key('register_submit_button'));
        await tester.ensureVisible(registerSubmitBtn);
        await tester.tap(registerSubmitBtn);
        await tester.pump();

        expect(
          find.text('Mật khẩu phải bao gồm ít nhất 1 chữ cái và 1 chữ số.'),
          findsOneWidget,
        );

        // Fix password to satisfy NestJS RegisterDto rules and submit
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'Password123',
        );
        await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')),
          'Password123',
        );
        await tester.ensureVisible(registerSubmitBtn);
        await tester.tap(registerSubmitBtn);
        await tester.pumpAndSettle();

        // Redirected to HomeScreen
        expect(find.text('Trợ lý Mua sắm Gemini AI'), findsOneWidget);
      },
    );
  });
}
