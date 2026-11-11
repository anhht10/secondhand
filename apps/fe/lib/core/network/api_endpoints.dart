/// Centralized endpoint paths for the ReMarket NestJS Gateway (`/api/v1`).
///
/// Mirrors `docs/api/API_CONTRACT.md` (Phase 7 Frozen Contract).
/// All paths are relative to `AppConfig.apiBaseUrl` (`http://localhost:3000/api/v1`).
abstract final class ApiEndpoints {
  // 1. Authentication (`/api/v1/auth`)
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';

  // 2. Wishlist (`/api/v1/auth/wishlist`)
  static const String wishlist = '/auth/wishlist';
  static String wishlistItem(String productId) => '/auth/wishlist/$productId';

  // 3. Users / Profile (`/api/v1/users`)
  static const String usersMe = '/users/me';
  static String userPublicProfile(String userId) => '/users/$userId';

  // 4. Categories (`/api/v1/categories`)
  static const String categories = '/categories';
  static String categoryById(String categoryId) => '/categories/$categoryId';

  // 5. Products (`/api/v1/products`)
  static const String products = '/products';
  static const String myListings = '/products/me/listings';
  static String productById(String productId) => '/products/$productId';
  static String productStatus(String productId) => '/products/$productId/status';
  static String productImages(String productId) => '/products/$productId/images';

  // 6. Upload (`/api/v1/upload`)
  static const String uploadImages = '/upload/images';

  // 7. Messaging (`/api/v1/messages`)
  static const String conversations = '/messages/conversations';
  static String conversationById(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String conversationMessages(String conversationId) =>
      '/messages/conversations/$conversationId/messages';
  static String markMessageRead(String messageId) => '/messages/$messageId/read';

  // 8. Reports (`/api/v1/reports`)
  static const String reports = '/reports';
  static const String myReports = '/reports/me';

  // 9. AI Assistant (`/api/v1/ai`)
  static const String aiGenerateListing = '/ai/generate-listing';
  static const String aiEstimatePrice = '/ai/estimate-price';
  static const String aiBuyerChecklist = '/ai/buyer-checklist';
  static const String aiChat = '/ai/chat';
  static String aiConversationById(String conversationId) =>
      '/ai/conversations/$conversationId';

  // 10. Health (`/api/v1/health`)
  static const String health = '/health';

  // 11. Orders & Payments (`/api/v1/orders`)
  static const String orders = '/orders';
  static const String buyerOrders = '/orders/buyer';
  static const String sellerOrders = '/orders/seller';
  static String orderById(String orderId) => '/orders/$orderId';
  static String orderByProduct(String productId) =>
      '/orders/by-product/$productId';
  static String confirmOrder(String orderId) => '/orders/$orderId/confirm';
  static String rejectOrder(String orderId) => '/orders/$orderId/reject';
  static String cancelOrder(String orderId) => '/orders/$orderId/cancel';
  static String updateOrderDelivery(String orderId) =>
      '/orders/$orderId/delivery';
  static String completeOrder(String orderId) => '/orders/$orderId/complete';
  static String confirmBuyerPayment(String orderId) =>
      '/orders/$orderId/payment-confirmation';
  static String confirmSellerPayment(String orderId) =>
      '/orders/$orderId/payment/confirm';

  // 12. Notifications (`/api/v1/notifications`)
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  // 13. Reviews & Seller Reputation (`/api/v1/reviews` & `/api/v1/sellers`)
  static const String reviews = '/reviews';
  static const String reviewsUploadImages = '/reviews/upload-images';
  static String reviewById(String reviewId) => '/reviews/$reviewId';
  static String reviewReply(String reviewId) => '/reviews/$reviewId/reply';
  static String reviewReport(String reviewId) => '/reviews/$reviewId/report';
  static String sellerReviews(String sellerId) => '/sellers/$sellerId/reviews';
  static String sellerReputation(String sellerId) =>
      '/sellers/$sellerId/reputation';
  static String orderReview(String orderId) => '/orders/$orderId/review';
}
