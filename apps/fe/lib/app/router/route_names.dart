/// Centralized route paths and names for ReMarket GoRouter configuration.
abstract final class RouteNames {
  // Auth & Bootstrap Route Names
  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';

  // Shell Route Names
  static const String homeName = 'home';
  static const String blogFeedName = 'blogs';
  static const String aiChatName = 'ai-chat';
  static const String createListingName = 'create-listing';
  static const String messagesName = 'messages';
  static const String profileName = 'profile';

  // Feature Route Names
  static const String blogDetailName = 'blog-detail';
  static const String createBlogName = 'create-blog';
  static const String productDetailName = 'product-detail';
  static const String editListingName = 'edit-listing';
  static const String reportProductName = 'report-product';
  static const String sellerProfileName = 'seller-profile';
  static const String chatDetailName = 'chat-detail';
  static const String myListingsName = 'my-listings';
  static const String wishlistName = 'wishlist';
  static const String editProfileName = 'edit-profile';
  static const String myReportsName = 'my-reports';
  static const String settingsName = 'settings';
  static const String checkoutName = 'checkout';
  static const String orderConfirmationName = 'order-confirmation';
  static const String bankTransferName = 'bank-transfer';
  static const String orderDetailName = 'order-detail';
  static const String myOrdersName = 'my-orders';
  static const String sellerOrdersName = 'seller-orders';
  static const String notificationsName = 'notifications';
  static const String writeReviewName = 'write-review';
  static const String reviewDetailName = 'review-detail';
  static const String sellerReviewsName = 'seller-reviews';

  // Auth & Bootstrap Paths
  static const String splashPath = '/splash';
  static const String loginPath = '/login';
  static const String registerPath = '/register';

  // Shell Paths
  static const String homePath = '/home';
  static const String blogFeedPath = '/blogs';
  static const String aiChatPath = '/ai-chat';
  static const String createListingPath = '/create-listing';
  static const String messagesPath = '/messages';
  static const String profilePath = '/profile';

  // Feature Route Paths
  static const String createBlogPath = '/blogs/create';
  static const String blogDetailPath = '/blogs/:postId';
  static const String productDetailPath = '/products/:productId';
  static const String editListingPath = '/products/:productId/edit';
  static const String reportProductPath = '/products/:productId/report';
  static const String checkoutPath = '/products/:productId/checkout';
  static const String sellerProfilePath = '/sellers/:sellerId';
  static const String chatDetailPath = '/messages/:conversationId';
  static const String myListingsPath = '/my-listings';
  static const String wishlistPath = '/wishlist';
  static const String editProfilePath = '/profile/edit';
  static const String myReportsPath = '/my-reports';
  static const String settingsPath = '/settings';
  static const String myOrdersPath = '/my-orders';
  static const String sellerOrdersPath = '/seller-orders';
  static const String notificationsPath = '/notifications';
  static const String orderConfirmationPath = '/orders/:orderId/confirmation';
  static const String bankTransferPath = '/orders/:orderId/bank-transfer';
  static const String orderDetailPath = '/orders/:orderId';
  static const String writeReviewPath = '/orders/:orderId/review/write';
  static const String reviewDetailPath = '/reviews/:reviewId';
  static const String sellerReviewsPath = '/sellers/:sellerId/reviews';

  // Concrete Path Builders
  static String blogDetail(String postId) => '/blogs/$postId';
  static String productDetail(String productId) => '/products/$productId';
  static String editListing(String productId) => '/products/$productId/edit';
  static String reportProduct(String productId) => '/products/$productId/report';
  static String checkout(String productId, {String? conversationId}) {
    if (conversationId != null && conversationId.isNotEmpty) {
      return '/products/$productId/checkout?conversationId=$conversationId';
    }
    return '/products/$productId/checkout';
  }
  static String orderConfirmation(String orderId) =>
      '/orders/$orderId/confirmation';
  static String bankTransfer(String orderId) => '/orders/$orderId/bank-transfer';
  static String orderDetail(String orderId) => '/orders/$orderId';
  static String writeReview(String orderId) => '/orders/$orderId/review/write';
  static String reviewDetail(String reviewId) => '/reviews/$reviewId';
  static String sellerProfile(String sellerId) => '/sellers/$sellerId';
  static String sellerReviews(String sellerId) => '/sellers/$sellerId/reviews';
  static String chatDetail(String conversationId) => '/messages/$conversationId';
}

typedef AppRoutes = RouteNames;
