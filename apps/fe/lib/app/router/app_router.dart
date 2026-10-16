import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/presentation/screens/ai_shopping_chat_screen.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/blogs/presentation/screens/blog_detail_screen.dart';
import '../../features/blogs/presentation/screens/blog_feed_screen.dart';
import '../../features/blogs/presentation/screens/create_blog_post_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/listings/presentation/screens/my_listings_screen.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/conversations_screen.dart';
import '../../features/orders/presentation/screens/bank_transfer_screen.dart';
import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/my_orders_screen.dart';
import '../../features/orders/presentation/screens/notifications_screen.dart';
import '../../features/orders/presentation/screens/order_confirmation_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/seller_orders_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/seller_public_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/reports/presentation/screens/my_reports_screen.dart';
import '../../features/reports/presentation/screens/report_product_screen.dart';
import '../../features/reviews/data/models/review_models.dart';
import '../../features/reviews/presentation/screens/review_detail_screen.dart';
import '../../features/reviews/presentation/screens/seller_reviews_screen.dart';
import '../../features/reviews/presentation/screens/write_review_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';
import '../../shared/widgets/main_shell_scaffold.dart';
import 'route_names.dart';

/// Pure function that computes the redirect target for a given [AuthState]
/// and current route path. Extracted for deterministic unit testing.
String? computeAuthRedirect({
  required AuthState authState,
  required String matchedLocation,
}) {
  final isSplash = matchedLocation == RouteNames.splashPath;
  final isAuthRoute = matchedLocation == RouteNames.loginPath ||
      matchedLocation == RouteNames.registerPath;

  // 1. While restoring session on startup, stay on SplashScreen
  if (authState.isRestoring) {
    return isSplash ? null : RouteNames.splashPath;
  }

  // 2. When unauthenticated, only allow Login and Register routes
  if (!authState.isAuthenticated) {
    return isAuthRoute ? null : RouteNames.loginPath;
  }

  // 3. When authenticated, redirect away from Splash / Login / Register to Home
  if (isSplash || isAuthRoute) {
    return RouteNames.homePath;
  }

  return null;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// Provides the single [GoRouter] instance wired to [authControllerProvider].
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      if (previous?.status != next.status ||
          previous?.isAuthenticated != next.isAuthenticated) {
        refreshNotifier.trigger();
      }
    },
  );

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      return computeAuthRedirect(
        authState: authState,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),

      // 5-Tab Bottom Navigation Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Tab 0: Home Discovery Feed
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.homePath,
                name: RouteNames.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Community Blog Feed
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.blogFeedPath,
                name: RouteNames.blogFeedName,
                builder: (context, state) => const BlogFeedScreen(),
              ),
            ],
          ),
          // Tab 2: Create Listing + AI 1 & AI 2
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.createListingPath,
                name: RouteNames.createListingName,
                builder: (context, state) => const CreateListingScreen(),
              ),
            ],
          ),
          // Tab 3: Buyer-Seller Conversations
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.messagesPath,
                name: RouteNames.messagesName,
                builder: (context, state) => const ConversationsScreen(),
              ),
            ],
          ),
          // Tab 4: My Profile & Store Dashboard
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profilePath,
                name: RouteNames.profileName,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Standalone Feature Routes
      GoRoute(
        path: RouteNames.aiChatPath,
        name: RouteNames.aiChatName,
        builder: (context, state) => const AiShoppingChatScreen(),
      ),
      GoRoute(
        path: RouteNames.createBlogPath,
        name: RouteNames.createBlogName,
        builder: (context, state) => const CreateBlogPostScreen(),
      ),
      GoRoute(
        path: RouteNames.blogDetailPath,
        name: RouteNames.blogDetailName,
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return BlogDetailScreen(postId: postId);
        },
      ),
      GoRoute(
        path: RouteNames.productDetailPath,
        name: RouteNames.productDetailName,
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: RouteNames.editListingPath,
        name: RouteNames.editListingName,
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          return CreateListingScreen(editProductId: productId);
        },
      ),
      GoRoute(
        path: RouteNames.reportProductPath,
        name: RouteNames.reportProductName,
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          final productTitle = state.extra is String ? state.extra as String : null;
          return ReportProductScreen(
            productId: productId,
            productTitle: productTitle,
          );
        },
      ),
      GoRoute(
        path: RouteNames.sellerProfilePath,
        name: RouteNames.sellerProfileName,
        builder: (context, state) {
          final sellerId = state.pathParameters['sellerId'] ?? '';
          return SellerPublicProfileScreen(sellerId: sellerId);
        },
      ),
      GoRoute(
        path: RouteNames.chatDetailPath,
        name: RouteNames.chatDetailName,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: RouteNames.myListingsPath,
        name: RouteNames.myListingsName,
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: RouteNames.wishlistPath,
        name: RouteNames.wishlistName,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: RouteNames.editProfilePath,
        name: RouteNames.editProfileName,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.myReportsPath,
        name: RouteNames.myReportsName,
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: RouteNames.settingsPath,
        name: RouteNames.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.checkoutPath,
        name: RouteNames.checkoutName,
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          final conversationId =
              state.uri.queryParameters['conversationId'] ??
              (state.extra is String ? state.extra as String : null);
          return CheckoutScreen(
            productId: productId,
            conversationId: conversationId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.orderConfirmationPath,
        name: RouteNames.orderConfirmationName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderConfirmationScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RouteNames.bankTransferPath,
        name: RouteNames.bankTransferName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return BankTransferScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RouteNames.orderDetailPath,
        name: RouteNames.orderDetailName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RouteNames.myOrdersPath,
        name: RouteNames.myOrdersName,
        builder: (context, state) => const MyOrdersScreen(),
      ),
      GoRoute(
        path: RouteNames.sellerOrdersPath,
        name: RouteNames.sellerOrdersName,
        builder: (context, state) => const SellerOrdersScreen(),
      ),
      GoRoute(
        path: RouteNames.notificationsPath,
        name: RouteNames.notificationsName,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.writeReviewPath,
        name: RouteNames.writeReviewName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          final initialReview =
              state.extra is ReviewModel ? state.extra as ReviewModel : null;
          return WriteReviewScreen(
            orderId: orderId,
            initialReview: initialReview,
          );
        },
      ),
      GoRoute(
        path: RouteNames.reviewDetailPath,
        name: RouteNames.reviewDetailName,
        builder: (context, state) {
          final reviewId = state.pathParameters['reviewId'] ?? '';
          return ReviewDetailScreen(reviewId: reviewId);
        },
      ),
      GoRoute(
        path: RouteNames.sellerReviewsPath,
        name: RouteNames.sellerReviewsName,
        builder: (context, state) {
          final sellerId = state.pathParameters['sellerId'] ?? '';
          final sellerName =
              state.extra is String ? state.extra as String : null;
          return SellerReviewsScreen(
            sellerId: sellerId,
            sellerName: sellerName,
          );
        },
      ),
    ],
  );
});
