import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/app/theme/app_theme.dart';
import 'package:remarket_fe/core/network/network_result.dart';
import 'package:remarket_fe/features/auth/domain/auth_repository.dart';
import 'package:remarket_fe/features/auth/domain/auth_state.dart';
import 'package:remarket_fe/features/auth/presentation/controllers/auth_controller.dart';
import 'package:remarket_fe/features/orders/data/models/order_model.dart';
import 'package:remarket_fe/features/orders/data/models/payment_model.dart';
import 'package:remarket_fe/features/orders/data/repositories/order_repository.dart';
import 'package:remarket_fe/features/orders/data/repositories/payment_repository.dart';
import 'package:remarket_fe/features/orders/presentation/providers/order_providers.dart';
import 'package:remarket_fe/features/orders/presentation/screens/bank_transfer_screen.dart';
import 'package:remarket_fe/features/orders/presentation/screens/checkout_screen.dart';
import 'package:remarket_fe/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:remarket_fe/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:remarket_fe/features/orders/presentation/screens/seller_orders_screen.dart';
import 'package:remarket_fe/features/products/data/models/product_model.dart';
import 'package:remarket_fe/features/products/presentation/providers/product_providers.dart';
import 'package:remarket_fe/shared/models/user_model.dart';

class _FakeOrderRepository implements OrderRepository {
  int createOrderCalls = 0;
  int confirmOrderCalls = 0;
  List<OrderModel> buyerOrders = <OrderModel>[];
  List<OrderModel> sellerOrders = <OrderModel>[];
  OrderModel? orderToReturn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<OrderModel>> createOrder({
    required String productId,
    required DeliveryMethod deliveryMethod,
    required PaymentMethod paymentMethod,
    String? shippingAddress,
    String? recipientName,
    String? recipientPhone,
    String? meetupLocation,
    String? buyerNote,
    String? conversationId,
  }) async {
    createOrderCalls += 1;
    final created = orderToReturn ?? _samplePendingBankOrder;
    return NetworkSuccess<OrderModel>(data: created);
  }

  @override
  Future<NetworkResult<List<OrderModel>>> getBuyerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return NetworkSuccess<List<OrderModel>>(data: buyerOrders);
  }

  @override
  Future<NetworkResult<List<OrderModel>>> getSellerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return NetworkSuccess<List<OrderModel>>(data: sellerOrders);
  }

  @override
  Future<NetworkResult<OrderModel>> confirmOrder(
    String orderId, {
    String? note,
  }) async {
    confirmOrderCalls += 1;
    return NetworkSuccess<OrderModel>(data: _sampleConfirmedBankOrder);
  }
}

class _FakePaymentRepository implements PaymentRepository {
  int confirmBuyerPaymentCalls = 0;
  int confirmSellerPaymentCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<OrderModel>> confirmBuyerPayment(
    String orderId, {
    String? transactionReference,
    String? transferNote,
  }) async {
    confirmBuyerPaymentCalls += 1;
    return NetworkSuccess<OrderModel>(data: _sampleConfirmedBankOrder);
  }

  @override
  Future<NetworkResult<OrderModel>> confirmSellerPayment(
    String orderId, {
    String? note,
  }) async {
    confirmSellerPaymentCalls += 1;
    return NetworkSuccess<OrderModel>(data: _sampleCompletedOrder);
  }
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.user);
  final UserModel user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<UserModel?>> restoreSession() async {
    return NetworkSuccess<UserModel?>(data: user);
  }
}

class _StubAuthController extends AuthController {
  _StubAuthController(UserModel user)
      : super(
          repository: _FakeAuthRepository(user),
          autoRestore: false,
        ) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }
}

const _buyerUser = UserModel(
  id: 'buyer-001',
  email: 'buyer@remarket.vn',
  displayName: 'Trần Thị Minh Anh',
  phone: '0912345678',
  location: 'Quận Cầu Giấy, Hà Nội',
);

const _sellerUser = UserModel(
  id: 'seller-001',
  email: 'khoa.nguyen@remarket.vn',
  displayName: 'Nguyễn Minh Khoa',
  phone: '0987654321',
  location: 'Quận 10, TP.HCM',
);

const ProductModel _demoProduct = ProductModel(
  id: 'prod-101',
  title: 'Tai nghe Sony WH-1000XM4 chống ồn chủ động',
  description: 'Tai nghe nguyên bản, đệm tai êm, pin nghe liên tục 26 giờ.',
  price: 3200000,
  originalPrice: 4500000,
  condition: ProductCondition.likeNew,
  defectDisclosure: 'Hộp giấy hơi móp nhẹ ở góc, tai nghe không vết xước.',
  images: <String>[],
  status: ProductStatus.active,
  location: 'Quận 10, TP.HCM',
  seller: ProductSellerSummary(
    id: 'seller-001',
    displayName: 'Nguyễn Minh Khoa',
    location: 'Quận 10, TP.HCM',
    isEmailVerified: true,
  ),
  category: ProductCategorySummary(
    id: 'cat-audio',
    name: 'Âm thanh & Tai nghe',
  ),
  viewsCount: 18,
);

final _samplePendingBankOrder = OrderModel(
  id: 'ord-001',
  orderCode: 'RM261108ABCD',
  productId: _demoProduct.id,
  buyerId: _buyerUser.id,
  sellerId: _sellerUser.id,
  productSnapshot: const OrderProductSnapshotModel(
    title: 'Tai nghe Sony WH-1000XM4 chống ồn chủ động',
    price: 3200000,
    condition: 'LIKE_NEW',
  ),
  itemPrice: 3200000,
  shippingFee: 0,
  totalAmount: 3200000,
  deliveryMethod: DeliveryMethod.delivery,
  shippingAddress: 'Tòa B4 KTX Khu B ĐHQG, Dĩ An, Bình Dương',
  recipientName: 'Trần Thị Minh Anh',
  recipientPhone: '0912345678',
  paymentMethod: PaymentMethod.bankTransfer,
  paymentStatus: PaymentStatus.unpaid,
  status: OrderStatus.pending,
  buyer: const OrderPartySummaryModel(
    id: 'buyer-001',
    displayName: 'Trần Thị Minh Anh',
    phoneNumber: '0912345678',
  ),
  seller: const OrderPartySummaryModel(
    id: 'seller-001',
    displayName: 'Nguyễn Minh Khoa',
    phoneNumber: '0987654321',
  ),
  sellerBankInfo: const SellerBankInfoModel(
    bankName: 'Vietcombank',
    accountNumber: '1029384756',
    accountHolder: 'NGUYEN MINH KHOA',
    branch: 'CN TP.HCM',
    amount: 3200000,
    transferContent: 'RM261108ABCD',
  ),
  timeline: <OrderTimelineEntryModel>[
    OrderTimelineEntryModel(
      status: 'PENDING',
      actorRole: 'BUYER',
      note: 'Tạo yêu cầu mua hàng mới',
      timestamp: DateTime(2026, 11, 8, 9, 0),
    ),
  ],
  createdAt: DateTime(2026, 11, 8, 9, 0),
);

final _sampleConfirmedBankOrder = OrderModel(
  id: 'ord-001',
  orderCode: 'RM261108ABCD',
  productId: _demoProduct.id,
  buyerId: _buyerUser.id,
  sellerId: _sellerUser.id,
  productSnapshot: _samplePendingBankOrder.productSnapshot,
  itemPrice: 3200000,
  shippingFee: 0,
  totalAmount: 3200000,
  deliveryMethod: DeliveryMethod.delivery,
  shippingAddress: 'Tòa B4 KTX Khu B ĐHQG, Dĩ An, Bình Dương',
  recipientName: 'Trần Thị Minh Anh',
  recipientPhone: '0912345678',
  paymentMethod: PaymentMethod.bankTransfer,
  paymentStatus: PaymentStatus.buyerConfirmed,
  status: OrderStatus.confirmed,
  buyer: _samplePendingBankOrder.buyer,
  seller: _samplePendingBankOrder.seller,
  sellerBankInfo: _samplePendingBankOrder.sellerBankInfo,
  payment: PaymentModel(
    paymentId: 'pay-001',
    orderId: 'ord-001',
    payerId: 'buyer-001',
    receiverId: 'seller-001',
    method: PaymentMethod.bankTransfer,
    amount: 3200000,
    status: PaymentStatus.buyerConfirmed,
    transactionReference: 'VCB99887766',
    buyerConfirmationAt: DateTime(2026, 11, 8, 9, 15),
  ),
  timeline: <OrderTimelineEntryModel>[
    ..._samplePendingBankOrder.timeline,
    OrderTimelineEntryModel(
      status: 'CONFIRMED',
      actorRole: 'SELLER',
      note: 'Người bán đã xác nhận đơn hàng',
      timestamp: DateTime(2026, 11, 8, 9, 10),
    ),
  ],
  createdAt: DateTime(2026, 11, 8, 9, 0),
  confirmedAt: DateTime(2026, 11, 8, 9, 10),
);

final _sampleConfirmedCodOrder = OrderModel(
  id: 'ord-004',
  orderCode: 'RM261108COD1',
  productId: _demoProduct.id,
  buyerId: _buyerUser.id,
  sellerId: _sellerUser.id,
  productSnapshot: _samplePendingBankOrder.productSnapshot,
  itemPrice: 3200000,
  shippingFee: 0,
  totalAmount: 3200000,
  deliveryMethod: DeliveryMethod.delivery,
  shippingAddress: 'Tòa B4 KTX Khu B ĐHQG, Dĩ An, Bình Dương',
  recipientName: 'Trần Thị Minh Anh',
  recipientPhone: '0912345678',
  paymentMethod: PaymentMethod.cod,
  paymentStatus: PaymentStatus.unpaid,
  status: OrderStatus.confirmed,
  buyer: _samplePendingBankOrder.buyer,
  seller: _samplePendingBankOrder.seller,
  timeline: _samplePendingBankOrder.timeline,
  createdAt: DateTime(2026, 11, 8, 9, 0),
);

final _sampleCompletedOrder = OrderModel(
  id: 'ord-002',
  orderCode: 'RM261108DONE',
  productId: 'prod-202',
  buyerId: _buyerUser.id,
  sellerId: _sellerUser.id,
  productSnapshot: const OrderProductSnapshotModel(
    title: 'Chuột Logitech MX Master 3S',
    price: 1650000,
    condition: 'GOOD',
  ),
  itemPrice: 1650000,
  shippingFee: 0,
  totalAmount: 1650000,
  deliveryMethod: DeliveryMethod.meetup,
  meetupLocation: 'Thư viện ĐH Bách Khoa',
  paymentMethod: PaymentMethod.cash,
  paymentStatus: PaymentStatus.paid,
  status: OrderStatus.completed,
  timeline: const <OrderTimelineEntryModel>[],
  createdAt: DateTime(2026, 11, 8, 8, 0),
);

final _sampleCancelledOrder = OrderModel(
  id: 'ord-003',
  orderCode: 'RM261108CANC',
  productId: 'prod-303',
  buyerId: _buyerUser.id,
  sellerId: _sellerUser.id,
  productSnapshot: const OrderProductSnapshotModel(
    title: 'Màn hình LG UltraGear 24 inch',
    price: 2400000,
    condition: 'GOOD',
  ),
  itemPrice: 2400000,
  shippingFee: 0,
  totalAmount: 2400000,
  deliveryMethod: DeliveryMethod.delivery,
  paymentMethod: PaymentMethod.cod,
  paymentStatus: PaymentStatus.unpaid,
  status: OrderStatus.cancelled,
  timeline: const <OrderTimelineEntryModel>[],
  createdAt: DateTime(2026, 11, 8, 7, 0),
);

void main() {
  group('Section 13 — Order, Payment & Checkout Unit Tests', () {
    test(
      'CheckoutController enforces delivery/payment compatibility and validates shippingAddress on DELIVERY',
      () async {
        final fakeRepo = _FakeOrderRepository();
        final container = ProviderContainer(
          overrides: <Override>[
            orderRepositoryProvider.overrideWithValue(fakeRepo),
            productDetailProvider('prod-101').overrideWith(
              (ref) async => _demoProduct,
            ),
            productOrderSummaryProvider('prod-101').overrideWith(
              (ref) async => null,
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(checkoutControllerProvider.notifier);

        // Initial state: MEETUP + CASH
        var state = container.read(checkoutControllerProvider);
        expect(state.deliveryMethod, equals(DeliveryMethod.meetup));
        expect(state.paymentMethod, equals(PaymentMethod.cash));

        // Switching to DELIVERY automatically switches CASH -> COD
        notifier.setDeliveryMethod(DeliveryMethod.delivery);
        state = container.read(checkoutControllerProvider);
        expect(state.deliveryMethod, equals(DeliveryMethod.delivery));
        expect(state.paymentMethod, equals(PaymentMethod.cod));

        // Switching to BANK_TRANSFER and then back to MEETUP preserves BANK_TRANSFER
        notifier.setPaymentMethod(PaymentMethod.bankTransfer);
        notifier.setDeliveryMethod(DeliveryMethod.meetup);
        state = container.read(checkoutControllerProvider);
        expect(state.deliveryMethod, equals(DeliveryMethod.meetup));
        expect(state.paymentMethod, equals(PaymentMethod.bankTransfer));

        // Switching to DELIVERY without valid shippingAddress fails validation
        notifier.setDeliveryMethod(DeliveryMethod.delivery);
        final invalidResult = await notifier.submitOrder(
          productId: 'prod-101',
          shippingAddress: '123', // too short (< 5 chars)
        );
        expect(invalidResult, isNull);
        expect(fakeRepo.createOrderCalls, equals(0));
        expect(
          container.read(checkoutControllerProvider).error?.code,
          equals('VALIDATION_ERROR'),
        );

        // Valid submission creates order via repository
        final validResult = await notifier.submitOrder(
          productId: 'prod-101',
          shippingAddress: 'Tòa B4 KTX Khu B ĐHQG, Dĩ An, Bình Dương',
          recipientName: 'Trần Thị Minh Anh',
          recipientPhone: '0912345678',
        );
        expect(validResult, isNotNull);
        expect(validResult!.orderCode, equals('RM261108ABCD'));
        expect(fakeRepo.createOrderCalls, equals(1));
      },
    );

    test(
      'OrdersListState.filterByTab filters orders accurately across ALL, PENDING, PROCESSING, COMPLETED, and CANCELLED tabs',
      () {
        final listState = OrdersListState(
          orders: <OrderModel>[
            _samplePendingBankOrder,
            _sampleConfirmedBankOrder,
            _sampleCompletedOrder,
            _sampleCancelledOrder,
          ],
        );

        expect(listState.filterByTab('ALL').length, equals(4));
        expect(
          listState.filterByTab('PENDING').map((o) => o.id).toList(),
          equals(<String>['ord-001']),
        );
        expect(
          listState.filterByTab('PROCESSING').map((o) => o.id).toList(),
          equals(<String>['ord-001']),
        );
        expect(
          listState.filterByTab('COMPLETED').map((o) => o.id).toList(),
          equals(<String>['ord-002']),
        );
        expect(
          listState.filterByTab('CANCELLED').map((o) => o.id).toList(),
          equals(<String>['ord-003']),
        );
      },
    );

    test(
      'OrderModel role-based action guards enforce state transition and payment confirmation rules',
      () {
        // 1. PENDING + UNPAID order
        expect(_samplePendingBankOrder.canBuyerCancel, isTrue);
        expect(_samplePendingBankOrder.canBuyerComplete, isFalse);
        expect(_samplePendingBankOrder.canSellerConfirm, isTrue);
        expect(_samplePendingBankOrder.canSellerReject, isTrue);
        expect(
          _samplePendingBankOrder.canSellerConfirmPayment,
          isFalse,
          reason:
              'Seller cannot confirm bank transfer before buyer marks BUYER_CONFIRMED',
        );

        // 2. CONFIRMED + BUYER_CONFIRMED bank transfer order:
        // Seller can confirm payment, but cannot ship/complete until payment is PAID
        expect(_sampleConfirmedBankOrder.canSellerConfirm, isFalse);
        expect(_sampleConfirmedBankOrder.canSellerConfirmPayment, isTrue);
        expect(_sampleConfirmedBankOrder.canSellerUpdateShipping, isFalse);
        expect(_sampleConfirmedBankOrder.canBuyerComplete, isFalse);

        // 3. CONFIRMED COD order: Seller can ship and Buyer can complete
        expect(_sampleConfirmedCodOrder.canSellerUpdateShipping, isTrue);
        expect(_sampleConfirmedCodOrder.canBuyerComplete, isTrue);

        // 4. COMPLETED order
        expect(_sampleCompletedOrder.canBuyerCancel, isFalse);
        expect(_sampleCompletedOrder.canBuyerComplete, isFalse);
        expect(_sampleCompletedOrder.canSellerConfirm, isFalse);
        expect(_sampleCompletedOrder.canSellerReject, isFalse);
      },
    );
  });

  group('Section 13 — Order, Payment & Checkout Widget Tests', () {
    testWidgets(
      'CheckoutScreen displays product summary, payment options, and validates shipping address',
      (WidgetTester tester) async {
        final fakeOrderRepo = _FakeOrderRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authControllerProvider.overrideWith(
                (ref) => _StubAuthController(_buyerUser),
              ),
              productDetailProvider('prod-101').overrideWith(
                (ref) async => _demoProduct,
              ),
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CheckoutScreen(productId: 'prod-101'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Product summary and price are visible
        expect(
          find.text('Tai nghe Sony WH-1000XM4 chống ồn chủ động'),
          findsOneWidget,
        );
        expect(find.text('Phương thức nhận hàng'), findsOneWidget);
        expect(find.text('Phương thức thanh toán'), findsOneWidget);

        // Select DELIVERY method
        await tester.tap(find.text('Giao hàng tận nơi'));
        await tester.pumpAndSettle();

        // Scroll ListView so the shipping address TextField is built & visible
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();

        // Clear prefilled address and tap submit -> shows validation error
        final addressField = find.widgetWithText(
          TextField,
          'Địa chỉ giao hàng chi tiết *',
        );
        await tester.enterText(addressField, '');
        await tester.tap(find.text('Gửi yêu cầu mua'));
        await tester.pumpAndSettle();

        // Scroll to bottom of ListView where error banner is rendered
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Vui lòng nhập địa chỉ nhận hàng cụ thể (tối thiểu 5 ký tự).',
          ),
          findsOneWidget,
        );
        expect(fakeOrderRepo.createOrderCalls, equals(0));
      },
    );

    testWidgets(
      'BankTransferScreen displays seller bank details, copy buttons, and seller confirmation disclaimer for valid orders',
      (WidgetTester tester) async {
        final fakePaymentRepo = _FakePaymentRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              orderDetailProvider('ord-001').overrideWith(
                (ref) async => _samplePendingBankOrder,
              ),
              paymentRepositoryProvider.overrideWithValue(fakePaymentRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BankTransferScreen(orderId: 'ord-001'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Vietcombank'), findsOneWidget);
        expect(find.text('1029384756'), findsOneWidget);
        expect(find.text('NGUYEN MINH KHOA'), findsOneWidget);
        expect(find.text('RM261108ABCD'), findsOneWidget);
        expect(
          find.textContaining('người bán vẫn cần kiểm tra tài khoản và xác nhận'),
          findsOneWidget,
        );

        // Scroll ListView to reveal the buyer confirmation button at the bottom
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(find.text('Tôi đã chuyển khoản'), findsOneWidget);
      },
    );

    testWidgets(
      'MyOrdersScreen and SellerOrdersScreen display tabs and filtered order cards',
      (WidgetTester tester) async {
        final fakeOrderRepo = _FakeOrderRepository()
          ..buyerOrders = <OrderModel>[
            _samplePendingBankOrder,
            _sampleCompletedOrder,
          ]
          ..sellerOrders = <OrderModel>[
            _samplePendingBankOrder,
          ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MyOrdersScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đơn mua của tôi'), findsOneWidget);
        expect(find.text('Tất cả'), findsOneWidget);
        expect(find.text('Chờ xác nhận'), findsAtLeastNWidgets(1));
        expect(find.text('RM261108ABCD'), findsOneWidget);
        expect(find.text('RM261108DONE'), findsOneWidget);

        // Now pump SellerOrdersScreen
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SellerOrdersScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Quản lý đơn bán hàng'), findsOneWidget);
        expect(find.text('Đơn mới'), findsOneWidget);
        expect(find.text('RM261108ABCD'), findsOneWidget);
      },
    );

    testWidgets(
      'OrderDetailScreen renders timeline, payment status, and Seller confirmation actions when viewed by Seller',
      (WidgetTester tester) async {
        final fakeOrderRepo = _FakeOrderRepository();
        final fakePaymentRepo = _FakePaymentRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authControllerProvider.overrideWith(
                (ref) => _StubAuthController(_sellerUser),
              ),
              orderDetailProvider('ord-001').overrideWith(
                (ref) async => _sampleConfirmedBankOrder,
              ),
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
              paymentRepositoryProvider.overrideWithValue(fakePaymentRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const OrderDetailScreen(orderId: 'ord-001'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Mã đơn: RM261108ABCD'), findsOneWidget);
        expect(
          find.textContaining('Chờ người bán xác nhận tiền'),
          findsOneWidget,
        );
        expect(find.text('Mã GD chuyển khoản: VCB99887766'), findsOneWidget);
        expect(
          find.text('Xác nhận đã nhận tiền chuyển khoản'),
          findsOneWidget,
        );
      },
    );
  });
}
