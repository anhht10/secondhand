import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_network_image.dart';
import '../../../../shared/widgets/location_map_picker_sheet.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/models/order_model.dart';
import '../../data/models/payment_model.dart';
import '../providers/order_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.productId,
    this.conversationId,
  });

  final String productId;
  final String? conversationId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _meetupLocationController = TextEditingController();
  final _noteController = TextEditingController();
  bool _prefilledUser = false;

  @override
  void dispose() {
    _addressController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _meetupLocationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker({required bool isMeetup}) async {
    final targetController =
        isMeetup ? _meetupLocationController : _addressController;
    final picked = await LocationMapPickerSheet.show(
      context,
      initialAddress: targetController.text,
      isMeetup: isMeetup,
    );
    if (picked != null && mounted) {
      setState(() {
        targetController.text = picked.formattedAddress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final checkoutState = ref.watch(checkoutControllerProvider);
    final currentUser = ref.watch(authControllerProvider).user;

    if (!_prefilledUser && currentUser != null) {
      _prefilledUser = true;
      _recipientNameController.text = currentUser.displayName;
      _recipientPhoneController.text = currentUser.phone ?? '';
      if (currentUser.location != null && currentUser.location!.isNotEmpty) {
        _addressController.text = currentUser.location!;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đặt mua'),
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Không thể tải thông tin sản phẩm: $err'),
          ),
        ),
        data: (product) {
          if (_meetupLocationController.text.isEmpty &&
              product.location != null &&
              product.location!.isNotEmpty) {
            _meetupLocationController.text = product.location!;
          }

          final isDelivery =
              checkoutState.deliveryMethod == DeliveryMethod.delivery;
          final availablePaymentMethods = isDelivery
              ? const <PaymentMethod>[
                  PaymentMethod.cod,
                  PaymentMethod.bankTransfer,
                ]
              : const <PaymentMethod>[
                  PaymentMethod.cash,
                  PaymentMethod.bankTransfer,
                ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: <Widget>[
              // 1. Product summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: RmNetworkImage(imageUrl: product.primaryImageUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Người bán: ${product.seller.displayName}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppFormatters.formatVnd(product.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Delivery Method selection
              const Text(
                'Phương thức nhận hàng',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...DeliveryMethod.values.map((method) {
                final selected = checkoutState.deliveryMethod == method;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ref
                        .read(checkoutControllerProvider.notifier)
                        .setDeliveryMethod(method),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            method == DeliveryMethod.meetup
                                ? Icons.handshake_outlined
                                : Icons.local_shipping_outlined,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  method.labelVi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  method.subtitleVi,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 10),
              if (isDelivery) ...<Widget>[
                TextField(
                  controller: _recipientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên người nhận',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipientPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại liên hệ',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ giao hàng chi tiết *',
                    hintText: 'Ví dụ: Tòa B4 KTX Khu B ĐHQG, Dĩ An...',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton.icon(
                        onPressed: () => _openMapPicker(isMeetup: false),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Bản đồ'),
                      ),
                    ),
                  ),
                ),
              ] else ...<Widget>[
                TextField(
                  controller: _meetupLocationController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Địa điểm hẹn gặp trực tiếp',
                    hintText: 'Ví dụ: Thư viện ĐH Bách Khoa / Cổng KTX...',
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton.icon(
                        onPressed: () => _openMapPicker(isMeetup: true),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Bản đồ'),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 3. Payment Method selection
              const Text(
                'Phương thức thanh toán',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...availablePaymentMethods.map((method) {
                final selected = checkoutState.paymentMethod == method;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ref
                        .read(checkoutControllerProvider.notifier)
                        .setPaymentMethod(method),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            method == PaymentMethod.bankTransfer
                                ? Icons.account_balance_outlined
                                : Icons.payments_outlined,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  method.labelVi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  method.subtitleVi,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Lời nhắn cho người bán (tùy chọn)',
                  hintText: 'Thời gian thuận tiện nhận hàng hoặc câu hỏi thêm...',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Total breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text('Giá sản phẩm'),
                        Text(
                          AppFormatters.formatVnd(product.price),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Phí nền tảng / giữ chỗ'),
                        Text(
                          'Miễn phí (0 ₫)',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Tổng thanh toán',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          AppFormatters.formatVnd(product.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (checkoutState.error != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    checkoutState.error!.message,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: RmButton(
            label: 'Gửi yêu cầu mua',
            icon: Icons.shopping_bag_outlined,
            isLoading: checkoutState.isSubmitting,
            onPressed: () async {
              final created = await ref
                  .read(checkoutControllerProvider.notifier)
                  .submitOrder(
                    productId: widget.productId,
                    shippingAddress: _addressController.text,
                    recipientName: _recipientNameController.text,
                    recipientPhone: _recipientPhoneController.text,
                    meetupLocation: _meetupLocationController.text,
                    buyerNote: _noteController.text,
                    conversationId: widget.conversationId,
                  );
              if (created != null && context.mounted) {
                context.pushReplacement(
                  RouteNames.orderConfirmation(created.id),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
