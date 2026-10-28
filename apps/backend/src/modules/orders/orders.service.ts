import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import { MessagesService } from '../messages/messages.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import {
  Product,
  ProductDocument,
  ProductStatus,
} from '../products/schemas/product.schema';
import { User, UserDocument, UserStatus } from '../users/schemas/user.schema';
import {
  BuyerPaymentConfirmationDto,
  CreateOrderDto,
  OrderActionNoteDto,
  QueryOrdersDto,
  SellerPaymentConfirmationDto,
} from './dto/order.dto';
import {
  ACTIVE_RESERVATION_ORDER_STATUSES,
  DeliveryMethod,
  Order,
  OrderDocument,
  OrderStatus,
} from './schemas/order.schema';
import {
  Payment,
  PaymentDocument,
  PaymentMethod,
  PaymentStatus,
} from './schemas/payment.schema';

export interface PaginatedOrdersResult {
  items: Record<string, unknown>[];
  meta: PaginationMeta;
}

@Injectable()
export class OrdersService {
  constructor(
    @InjectModel(Order.name)
    private readonly orderModel: Model<OrderDocument>,
    @InjectModel(Payment.name)
    private readonly paymentModel: Model<PaymentDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @Optional() private readonly messagesService?: MessagesService,
    @Optional() private readonly notificationsService?: NotificationsService,
  ) {}

  private generateOrderCode(): string {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const rand = Math.random().toString(36).substring(2, 7).toUpperCase();
    return `RM-${y}${m}${d}-${rand}`;
  }

  /**
   * Creates a new Order and atomically reserves the Product (`ACTIVE -> RESERVED`).
   * Safe across both standalone MongoDB and replica sets without multi-doc transaction assumptions.
   */
  async createOrder(
    buyerId: string,
    dto: CreateOrderDto,
  ): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(dto.productId)) {
      throw new NotFoundException('Product not found');
    }

    // Validate delivery & payment method compatibility
    if (dto.deliveryMethod === DeliveryMethod.DELIVERY) {
      const addr = dto.shippingAddress?.trim() ?? '';
      if (addr.length < 5) {
        throw new BadRequestException(
          'shippingAddress (minimum 5 characters) is required when deliveryMethod is DELIVERY',
        );
      }
      if (dto.paymentMethod === PaymentMethod.CASH) {
        throw new BadRequestException(
          'Direct CASH payment is only available for MEETUP orders; choose COD or BANK_TRANSFER for DELIVERY',
        );
      }
    } else if (dto.deliveryMethod === DeliveryMethod.MEETUP) {
      if (dto.paymentMethod === PaymentMethod.COD) {
        throw new BadRequestException(
          'COD payment is only available for DELIVERY orders; choose CASH or BANK_TRANSFER for MEETUP',
        );
      }
    }

    const buyer = await this.userModel.findById(buyerId).lean().exec();
    if (!buyer || buyer.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('Buyer account is not active');
    }

    const existingProduct = await this.productModel
      .findById(dto.productId)
      .lean()
      .exec();
    if (!existingProduct) {
      throw new NotFoundException('Product listing not found');
    }

    const sellerIdStr = String(existingProduct.sellerId);
    if (sellerIdStr === String(buyerId)) {
      throw new BadRequestException(
        'You cannot create an order for your own product listing',
      );
    }

    const seller = await this.userModel.findById(sellerIdStr).lean().exec();
    if (!seller || seller.status !== UserStatus.ACTIVE) {
      throw new BadRequestException('Seller account is not available');
    }

    const productObjId = new Types.ObjectId(dto.productId);
    const buyerObjId = new Types.ObjectId(buyerId);
    const sellerObjId = new Types.ObjectId(sellerIdStr);

    // Check if an active order already exists for this product
    const existingActiveOrder = await this.orderModel
      .findOne({
        productId: productObjId,
        status: { $in: ACTIVE_RESERVATION_ORDER_STATUSES },
      })
      .lean()
      .exec();
    if (existingActiveOrder) {
      throw new ConflictException(
        'This product already has an active order and is currently reserved',
      );
    }

    // ATOMIC RESERVATION: Only succeeds if product is currently ACTIVE
    const reservedProduct = await this.productModel
      .findOneAndUpdate(
        {
          _id: productObjId,
          status: ProductStatus.ACTIVE,
          sellerId: { $ne: buyerObjId },
        },
        {
          $set: { status: ProductStatus.RESERVED },
        },
        { new: true },
      )
      .exec();

    if (!reservedProduct) {
      throw new ConflictException(
        'Product is no longer available or has already been reserved by another buyer',
      );
    }

    const itemPrice = Number(reservedProduct.price || 0);
    const shippingFee = 0;
    const totalAmount = itemPrice + shippingFee;
    const primaryImage =
      Array.isArray(reservedProduct.images) && reservedProduct.images.length > 0
        ? reservedProduct.images[0]?.url ?? null
        : null;

    const now = new Date();
    let createdOrder: OrderDocument;
    try {
      createdOrder = await this.orderModel.create({
        orderCode: this.generateOrderCode(),
        productId: productObjId,
        buyerId: buyerObjId,
        sellerId: sellerObjId,
        conversationId:
          dto.conversationId && Types.ObjectId.isValid(dto.conversationId)
            ? new Types.ObjectId(dto.conversationId)
            : null,
        productSnapshot: {
          title: reservedProduct.title,
          price: itemPrice,
          condition: reservedProduct.condition,
          imageUrl: primaryImage,
          location: reservedProduct.location,
        },
        itemPrice,
        shippingFee,
        totalAmount,
        deliveryMethod: dto.deliveryMethod,
        shippingAddress:
          dto.deliveryMethod === DeliveryMethod.DELIVERY
            ? dto.shippingAddress?.trim() ?? null
            : null,
        recipientName:
          dto.recipientName?.trim() || buyer.displayName || null,
        recipientPhone:
          dto.recipientPhone?.trim() || buyer.phoneNumber || null,
        meetupLocation:
          dto.deliveryMethod === DeliveryMethod.MEETUP
            ? dto.meetupLocation?.trim() || reservedProduct.location || null
            : null,
        buyerNote: dto.buyerNote?.trim() ?? null,
        paymentMethod: dto.paymentMethod,
        paymentStatus: PaymentStatus.UNPAID,
        status: OrderStatus.PENDING,
        timeline: [
          {
            status: OrderStatus.PENDING,
            actorId: buyerObjId,
            actorRole: 'BUYER',
            note:
              dto.buyerNote?.trim() ||
              `Tạo đơn mua hàng (${dto.deliveryMethod} - ${dto.paymentMethod})`,
            timestamp: now,
          },
        ],
      });

      await this.paymentModel.create({
        orderId: createdOrder._id,
        payerId: buyerObjId,
        receiverId: sellerObjId,
        method: dto.paymentMethod,
        amount: totalAmount,
        status: PaymentStatus.UNPAID,
        transactionReference: null,
        transferNote: null,
        buyerConfirmationAt: null,
        sellerConfirmationAt: null,
        paidAt: null,
      });
    } catch (error) {
      // Rollback product reservation safely if order creation failed
      await this.restoreProductAvailabilityIfNoActiveOrder(productObjId);
      if ((error as { code?: number })?.code === 11000) {
        throw new ConflictException(
          'This product already has an active order and cannot be purchased twice',
        );
      }
      throw error;
    }

    // Link with Buyer-Seller Conversation & post Order Summary message
    if (this.messagesService) {
      try {
        const linkedConvId = await this.messagesService.postOrderEventMessage({
          buyerId: String(buyerId),
          sellerId: sellerIdStr,
          productId: String(reservedProduct._id),
          orderId: String(createdOrder._id),
          senderId: String(buyerId),
          content: `🛒 [Đơn hàng ${createdOrder.orderCode}] Yêu cầu mua "${reservedProduct.title}" — Giá: ${totalAmount.toLocaleString('vi-VN')} ₫ (${dto.deliveryMethod === DeliveryMethod.MEETUP ? 'Giao dịch trực tiếp' : 'Giao hàng tận nơi'} | ${dto.paymentMethod}). Đang chờ người bán xác nhận.`,
        });
        if (linkedConvId && Types.ObjectId.isValid(linkedConvId)) {
          createdOrder.conversationId = new Types.ObjectId(linkedConvId);
          await createdOrder.save();
        }
      } catch {
        // Non-blocking chat integration
      }
    }

    // Notify Seller
    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: sellerIdStr,
        actorId: buyerId,
        type: NotificationType.ORDER_CREATED,
        title: 'Bạn có đơn đặt mua mới!',
        body: `${buyer.displayName} vừa gửi yêu cầu mua "${reservedProduct.title}" (Mã đơn: ${createdOrder.orderCode}).`,
        orderId: String(createdOrder._id),
        productId: String(reservedProduct._id),
      });
    }

    return this.findOrderById(String(createdOrder._id), buyerId);
  }

  /**
   * Safely restores a RESERVED product back to ACTIVE only when NO other active order exists for it.
   */
  private async restoreProductAvailabilityIfNoActiveOrder(
    productId: Types.ObjectId,
    excludeOrderId?: Types.ObjectId,
  ): Promise<void> {
    const filter: FilterQuery<OrderDocument> = {
      productId,
      status: { $in: ACTIVE_RESERVATION_ORDER_STATUSES },
    };
    if (excludeOrderId) {
      filter._id = { $ne: excludeOrderId };
    }

    const activeCount = await this.orderModel.countDocuments(filter).exec();
    if (activeCount === 0) {
      await this.productModel
        .findOneAndUpdate(
          { _id: productId, status: ProductStatus.RESERVED },
          { $set: { status: ProductStatus.ACTIVE } },
        )
        .exec();
    }
  }

  async findOrdersForUser(
    userId: string,
    queryDto: QueryOrdersDto,
    forcedRole?: 'buyer' | 'seller',
  ): Promise<PaginatedOrdersResult> {
    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(100, Math.max(1, queryDto.limit ?? 20));
    const skip = (page - 1) * limit;

    const userObjId = new Types.ObjectId(userId);
    const role = forcedRole ?? queryDto.role ?? 'all';
    const filter: FilterQuery<OrderDocument> = {};

    if (role === 'buyer') {
      filter.buyerId = userObjId;
    } else if (role === 'seller') {
      filter.sellerId = userObjId;
    } else {
      filter.$or = [{ buyerId: userObjId }, { sellerId: userObjId }];
    }

    const rawStatus = queryDto.status?.trim().toUpperCase();
    if (rawStatus && rawStatus !== 'ALL') {
      if (rawStatus === 'PROCESSING') {
        filter.status = {
          $in: [
            OrderStatus.CONFIRMED,
            OrderStatus.SHIPPING,
            OrderStatus.DELIVERED,
          ],
        };
      } else if (rawStatus === 'CANCELLED_GROUP') {
        filter.status = {
          $in: [OrderStatus.CANCELLED, OrderStatus.REJECTED],
        };
      } else if (
        Object.values(OrderStatus).includes(rawStatus as OrderStatus)
      ) {
        if (rawStatus === OrderStatus.CANCELLED) {
          filter.status = {
            $in: [OrderStatus.CANCELLED, OrderStatus.REJECTED],
          };
        } else {
          filter.status = rawStatus as OrderStatus;
        }
      }
    }

    const [orders, total] = await Promise.all([
      this.orderModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate(
          'buyerId',
          'displayName avatarUrl phoneNumber location university isEmailVerified status',
        )
        .populate(
          'sellerId',
          'displayName avatarUrl phoneNumber location university isEmailVerified status bankInfo',
        )
        .populate('productId', 'title price condition status images location')
        .exec(),
      this.orderModel.countDocuments(filter).exec(),
    ]);

    const orderIds = orders.map((o) => o._id);
    const payments =
      orderIds.length > 0
        ? await this.paymentModel
            .find({ orderId: { $in: orderIds } })
            .exec()
        : [];
    const paymentByOrderId = new Map<string, PaymentDocument>();
    for (const p of payments) {
      paymentByOrderId.set(String(p.orderId), p);
    }

    const formattedItems = orders.map((order) =>
      this.serializeOrder(
        order,
        userId,
        paymentByOrderId.get(String(order._id)) ?? null,
      ),
    );

    const totalPages = Math.ceil(total / limit) || 1;
    return {
      items: formattedItems,
      meta: {
        total,
        page,
        limit,
        totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  async findOrderById(
    orderId: string,
    requesterId: string,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, requesterId);
    const payment = await this.paymentModel
      .findOne({ orderId: order._id })
      .exec();
    return this.serializeOrder(order, requesterId, payment);
  }

  async findLatestOrderForProductAndUser(
    productId: string,
    requesterId: string,
  ): Promise<Record<string, unknown> | null> {
    if (!Types.ObjectId.isValid(productId)) {
      return null;
    }
    const userObjId = new Types.ObjectId(requesterId);
    const order = await this.orderModel
      .findOne({
        productId: new Types.ObjectId(productId),
        $or: [{ buyerId: userObjId }, { sellerId: userObjId }],
      })
      .sort({ createdAt: -1 })
      .populate(
        'buyerId',
        'displayName avatarUrl phoneNumber location university isEmailVerified status',
      )
      .populate(
        'sellerId',
        'displayName avatarUrl phoneNumber location university isEmailVerified status bankInfo',
      )
      .populate('productId', 'title price condition status images location')
      .exec();

    if (!order) {
      return null;
    }

    const payment = await this.paymentModel
      .findOne({ orderId: order._id })
      .exec();
    return this.serializeOrder(order, requesterId, payment);
  }

  /**
   * Seller confirms a PENDING order (`PENDING -> CONFIRMED`).
   */
  async confirmOrder(
    orderId: string,
    sellerId: string,
    dto?: OrderActionNoteDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, sellerId, 'SELLER');

    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException(
        `Cannot confirm order in status '${order.status}'. Only PENDING orders can be confirmed.`,
      );
    }

    const now = new Date();
    const noteText =
      dto?.note?.trim() || 'Người bán đã xác nhận đơn hàng, sẵn sàng giao dịch.';
    const updated = await this.orderModel
      .findOneAndUpdate(
        { _id: order._id, status: OrderStatus.PENDING },
        {
          $set: {
            status: OrderStatus.CONFIRMED,
            confirmedAt: now,
          },
          $push: {
            timeline: {
              status: OrderStatus.CONFIRMED,
              actorId: new Types.ObjectId(sellerId),
              actorRole: 'SELLER',
              note: noteText,
              timestamp: now,
            },
          },
        },
        { new: true },
      )
      .exec();

    if (!updated) {
      throw new ConflictException('Order status was modified concurrently');
    }

    const buyerIdStr = this.extractId(order.buyerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: buyerIdStr,
        sellerId,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: sellerId,
        content: `✅ [Đơn hàng ${order.orderCode}] Người bán đã xác nhận đơn hàng. ${noteText}`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: buyerIdStr,
        actorId: sellerId,
        type: NotificationType.ORDER_CONFIRMED,
        title: 'Đơn hàng đã được xác nhận!',
        body: `Người bán đã xác nhận đơn ${order.orderCode} cho sản phẩm "${order.productSnapshot.title}".`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), sellerId);
  }

  /**
   * Seller rejects a PENDING order (`PENDING -> REJECTED`) and restores product to ACTIVE.
   */
  async rejectOrder(
    orderId: string,
    sellerId: string,
    dto?: OrderActionNoteDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, sellerId, 'SELLER');

    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException(
        `Cannot reject order in status '${order.status}'. Only PENDING orders can be rejected.`,
      );
    }

    const now = new Date();
    const reasonText =
      dto?.reason?.trim() ||
      dto?.note?.trim() ||
      'Người bán từ chối đơn hàng.';

    const updated = await this.orderModel
      .findOneAndUpdate(
        { _id: order._id, status: OrderStatus.PENDING },
        {
          $set: {
            status: OrderStatus.REJECTED,
            paymentStatus: PaymentStatus.CANCELLED,
            rejectReason: reasonText,
            rejectedAt: now,
          },
          $push: {
            timeline: {
              status: OrderStatus.REJECTED,
              actorId: new Types.ObjectId(sellerId),
              actorRole: 'SELLER',
              note: reasonText,
              timestamp: now,
            },
          },
        },
        { new: true },
      )
      .exec();

    if (!updated) {
      throw new ConflictException('Order status was modified concurrently');
    }

    await this.paymentModel
      .updateOne(
        { orderId: order._id },
        { $set: { status: PaymentStatus.CANCELLED } },
      )
      .exec();

    const prodObjId = new Types.ObjectId(this.extractId(order.productId));
    await this.restoreProductAvailabilityIfNoActiveOrder(prodObjId, order._id);

    const buyerIdStr = this.extractId(order.buyerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: buyerIdStr,
        sellerId,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: sellerId,
        content: `❌ [Đơn hàng ${order.orderCode}] Người bán đã từ chối đơn hàng. Lý do: ${reasonText}`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: buyerIdStr,
        actorId: sellerId,
        type: NotificationType.ORDER_REJECTED,
        title: 'Đơn hàng bị từ chối',
        body: `Đơn hàng ${order.orderCode} ("${order.productSnapshot.title}") đã bị từ chối: ${reasonText}`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), sellerId);
  }

  /**
   * Buyer or Seller cancels an order (`PENDING | CONFIRMED -> CANCELLED`) and restores product to ACTIVE.
   */
  async cancelOrder(
    orderId: string,
    userId: string,
    dto?: OrderActionNoteDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, userId);

    const allowedCancelStatuses: OrderStatus[] = [
      OrderStatus.PENDING,
      OrderStatus.CONFIRMED,
    ];
    if (!allowedCancelStatuses.includes(order.status)) {
      throw new BadRequestException(
        `Cannot cancel order in status '${order.status}'. Only PENDING or CONFIRMED orders can be cancelled.`,
      );
    }

    const isBuyer = this.extractId(order.buyerId) === String(userId);
    if (isBuyer && order.paymentStatus === PaymentStatus.PAID) {
      throw new BadRequestException(
        'Cannot cancel order directly after payment has already been confirmed as PAID by seller',
      );
    }

    const now = new Date();
    const actorRole: 'BUYER' | 'SELLER' = isBuyer ? 'BUYER' : 'SELLER';
    const reasonText =
      dto?.reason?.trim() ||
      dto?.note?.trim() ||
      (isBuyer ? 'Người mua đã hủy đơn hàng.' : 'Người bán đã hủy đơn hàng.');

    const updated = await this.orderModel
      .findOneAndUpdate(
        { _id: order._id, status: { $in: allowedCancelStatuses } },
        {
          $set: {
            status: OrderStatus.CANCELLED,
            paymentStatus: PaymentStatus.CANCELLED,
            cancelReason: reasonText,
            cancelledAt: now,
          },
          $push: {
            timeline: {
              status: OrderStatus.CANCELLED,
              actorId: new Types.ObjectId(userId),
              actorRole,
              note: reasonText,
              timestamp: now,
            },
          },
        },
        { new: true },
      )
      .exec();

    if (!updated) {
      throw new ConflictException('Order status was modified concurrently');
    }

    await this.paymentModel
      .updateOne(
        { orderId: order._id },
        { $set: { status: PaymentStatus.CANCELLED } },
      )
      .exec();

    const prodObjId = new Types.ObjectId(this.extractId(order.productId));
    await this.restoreProductAvailabilityIfNoActiveOrder(prodObjId, order._id);

    const buyerIdStr = this.extractId(order.buyerId);
    const sellerIdStr = this.extractId(order.sellerId);
    const productIdStr = this.extractId(order.productId);
    const targetRecipient = isBuyer ? sellerIdStr : buyerIdStr;

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: buyerIdStr,
        sellerId: sellerIdStr,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: userId,
        content: `🚫 [Đơn hàng ${order.orderCode}] ${isBuyer ? 'Người mua' : 'Người bán'} đã hủy đơn hàng. Lý do: ${reasonText}`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: targetRecipient,
        actorId: userId,
        type: NotificationType.ORDER_CANCELLED,
        title: 'Đơn hàng đã bị hủy',
        body: `Đơn hàng ${order.orderCode} ("${order.productSnapshot.title}") đã bị hủy: ${reasonText}`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), userId);
  }

  /**
   * Seller updates shipping / handover progress (`CONFIRMED -> SHIPPING -> DELIVERED`).
   */
  async updateDeliveryStatus(
    orderId: string,
    sellerId: string,
    dto: OrderActionNoteDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, sellerId, 'SELLER');

    const targetStatus =
      dto.deliveryStatus === 'DELIVERED'
        ? OrderStatus.DELIVERED
        : OrderStatus.SHIPPING;

    if (
      targetStatus === OrderStatus.SHIPPING &&
      order.status !== OrderStatus.CONFIRMED
    ) {
      throw new BadRequestException(
        `Order must be CONFIRMED before transitioning to SHIPPING (current: ${order.status})`,
      );
    }

    if (
      targetStatus === OrderStatus.DELIVERED &&
      ![OrderStatus.CONFIRMED, OrderStatus.SHIPPING].includes(order.status)
    ) {
      throw new BadRequestException(
        `Order must be CONFIRMED or SHIPPING before marking DELIVERED (current: ${order.status})`,
      );
    }

    if (
      order.paymentMethod === PaymentMethod.BANK_TRANSFER &&
      order.paymentStatus !== PaymentStatus.PAID
    ) {
      throw new BadRequestException(
        'For BANK_TRANSFER orders, payment must be confirmed as PAID before shipping/delivering',
      );
    }

    const now = new Date();
    const noteText =
      dto.note?.trim() ||
      (targetStatus === OrderStatus.SHIPPING
        ? 'Người bán đang giao sản phẩm / chuẩn bị điểm hẹn.'
        : 'Người bán đã bàn giao sản phẩm cho người mua.');

    const updateSet: Record<string, unknown> = { status: targetStatus };
    if (targetStatus === OrderStatus.SHIPPING) {
      updateSet.shippedAt = now;
    } else {
      updateSet.deliveredAt = now;
    }

    await this.orderModel
      .findByIdAndUpdate(order._id, {
        $set: updateSet,
        $push: {
          timeline: {
            status: targetStatus,
            actorId: new Types.ObjectId(sellerId),
            actorRole: 'SELLER',
            note: noteText,
            timestamp: now,
          },
        },
      })
      .exec();

    const buyerIdStr = this.extractId(order.buyerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: buyerIdStr,
        sellerId,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: sellerId,
        content: `🚚 [Đơn hàng ${order.orderCode}] Cập nhật giao nhận: ${noteText}`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: buyerIdStr,
        actorId: sellerId,
        type:
          targetStatus === OrderStatus.SHIPPING
            ? NotificationType.ORDER_SHIPPING
            : NotificationType.ORDER_DELIVERED,
        title:
          targetStatus === OrderStatus.SHIPPING
            ? 'Đơn hàng đang được giao!'
            : 'Sản phẩm đã được giao tới bạn!',
        body: `${noteText} (Mã đơn: ${order.orderCode})`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), sellerId);
  }

  /**
   * Buyer submits confirmation that they have transferred money (`UNPAID -> BUYER_CONFIRMED`).
   * Seller is strictly forbidden from calling this on behalf of Buyer.
   */
  async confirmBuyerPayment(
    orderId: string,
    buyerId: string,
    dto?: BuyerPaymentConfirmationDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, buyerId, 'BUYER');

    if (
      ![
        OrderStatus.PENDING,
        OrderStatus.CONFIRMED,
        OrderStatus.SHIPPING,
      ].includes(order.status)
    ) {
      throw new BadRequestException(
        `Cannot submit payment confirmation when order status is '${order.status}'`,
      );
    }

    if (order.paymentMethod !== PaymentMethod.BANK_TRANSFER) {
      throw new BadRequestException(
        `Manual transfer confirmation is only applicable to BANK_TRANSFER orders (current method: ${order.paymentMethod})`,
      );
    }

    if (order.paymentStatus === PaymentStatus.PAID) {
      throw new BadRequestException('Payment has already been confirmed as PAID');
    }

    const now = new Date();
    const refText = dto?.transactionReference?.trim() || null;
    const noteText =
      dto?.transferNote?.trim() ||
      dto?.note?.trim() ||
      (refText
        ? `Người mua báo đã chuyển khoản (Mã GD: ${refText})`
        : 'Người mua xác nhận đã chuyển khoản ngân hàng. Chờ người bán kiểm tra và xác nhận.');

    await Promise.all([
      this.paymentModel
        .findOneAndUpdate(
          { orderId: order._id },
          {
            $set: {
              status: PaymentStatus.BUYER_CONFIRMED,
              buyerConfirmationAt: now,
              transactionReference: refText,
              transferNote: noteText,
            },
          },
          { new: true },
        )
        .exec(),
      this.orderModel
        .findByIdAndUpdate(order._id, {
          $set: { paymentStatus: PaymentStatus.BUYER_CONFIRMED },
          $push: {
            timeline: {
              status: 'PAYMENT_BUYER_CONFIRMED',
              actorId: new Types.ObjectId(buyerId),
              actorRole: 'BUYER',
              note: noteText,
              timestamp: now,
            },
          },
        })
        .exec(),
    ]);

    const sellerIdStr = this.extractId(order.sellerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId,
        sellerId: sellerIdStr,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: buyerId,
        content: `💳 [Đơn hàng ${order.orderCode}] Người mua báo đã chuyển khoản (${order.totalAmount.toLocaleString('vi-VN')} ₫)${refText ? ` - Mã GD: ${refText}` : ''}. Vui lòng kiểm tra tài khoản và xác nhận!`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: sellerIdStr,
        actorId: buyerId,
        type: NotificationType.PAYMENT_BUYER_CONFIRMED,
        title: 'Người mua đã gửi xác nhận chuyển khoản!',
        body: `Người mua đơn ${order.orderCode} báo đã chuyển khoản ${order.totalAmount.toLocaleString('vi-VN')} ₫. Hãy kiểm tra tài khoản ngân hàng của bạn.`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), buyerId);
  }

  /**
   * Seller confirms receiving the buyer's payment (`BUYER_CONFIRMED -> PAID`).
   * Seller CANNOT confirm BANK_TRANSFER receipt before Buyer submits `payment-confirmation`.
   */
  async confirmSellerPayment(
    orderId: string,
    sellerId: string,
    dto?: SellerPaymentConfirmationDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, sellerId, 'SELLER');

    if (
      [OrderStatus.CANCELLED, OrderStatus.REJECTED, OrderStatus.COMPLETED].includes(
        order.status,
      )
    ) {
      throw new BadRequestException(
        `Cannot confirm payment when order status is '${order.status}'`,
      );
    }

    if (order.paymentStatus === PaymentStatus.PAID) {
      throw new BadRequestException('Payment is already marked as PAID');
    }

    if (
      order.paymentMethod === PaymentMethod.BANK_TRANSFER &&
      order.paymentStatus !== PaymentStatus.BUYER_CONFIRMED
    ) {
      throw new BadRequestException(
        'Seller cannot confirm bank transfer receipt before the buyer submits transfer confirmation (BUYER_CONFIRMED required)',
      );
    }

    const now = new Date();
    const noteText =
      dto?.note?.trim() || 'Người bán xác nhận đã nhận đủ tiền thanh toán.';

    const orderSet: Record<string, unknown> = {
      paymentStatus: PaymentStatus.PAID,
    };
    if (order.status === OrderStatus.PENDING) {
      orderSet.status = OrderStatus.CONFIRMED;
      orderSet.confirmedAt = now;
    }

    await Promise.all([
      this.paymentModel
        .findOneAndUpdate(
          { orderId: order._id },
          {
            $set: {
              status: PaymentStatus.PAID,
              sellerConfirmationAt: now,
              paidAt: now,
            },
          },
          { new: true },
        )
        .exec(),
      this.orderModel
        .findByIdAndUpdate(order._id, {
          $set: orderSet,
          $push: {
            timeline: {
              status: 'PAYMENT_CONFIRMED_PAID',
              actorId: new Types.ObjectId(sellerId),
              actorRole: 'SELLER',
              note: noteText,
              timestamp: now,
            },
          },
        })
        .exec(),
    ]);

    const buyerIdStr = this.extractId(order.buyerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: buyerIdStr,
        sellerId,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: sellerId,
        content: `💰 [Đơn hàng ${order.orderCode}] Người bán xác nhận đã nhận đủ tiền thanh toán (${order.totalAmount.toLocaleString('vi-VN')} ₫).`,
      });
    }

    if (this.notificationsService) {
      await this.notificationsService.createNotification({
        recipientId: buyerIdStr,
        actorId: sellerId,
        type: NotificationType.PAYMENT_SELLER_CONFIRMED,
        title: 'Người bán đã xác nhận nhận tiền!',
        body: `Người bán đã xác nhận nhận đủ thanh toán cho đơn ${order.orderCode} ("${order.productSnapshot.title}").`,
        orderId: String(order._id),
        productId: productIdStr,
      });
    }

    return this.findOrderById(String(order._id), sellerId);
  }

  /**
   * Buyer confirms receipt of product & completes the order (`CONFIRMED | SHIPPING | DELIVERED -> COMPLETED`).
   * Transitions Product status to `SOLD` and marks CASH/COD payment as `PAID`.
   */
  async completeOrder(
    orderId: string,
    userId: string,
    dto?: OrderActionNoteDto,
  ): Promise<Record<string, unknown>> {
    const order = await this.loadAndAuthorizeOrder(orderId, userId, 'BUYER');

    const completableStatuses: OrderStatus[] = [
      OrderStatus.CONFIRMED,
      OrderStatus.SHIPPING,
      OrderStatus.DELIVERED,
    ];
    if (!completableStatuses.includes(order.status)) {
      throw new BadRequestException(
        `Cannot complete order in status '${order.status}'. Order must be CONFIRMED, SHIPPING, or DELIVERED first.`,
      );
    }

    if (
      order.paymentMethod === PaymentMethod.BANK_TRANSFER &&
      order.paymentStatus !== PaymentStatus.PAID
    ) {
      throw new BadRequestException(
        'Cannot complete BANK_TRANSFER order until seller has confirmed payment receipt (PAID)',
      );
    }

    const now = new Date();
    const noteText =
      dto?.note?.trim() ||
      'Người mua xác nhận đã kiểm tra và nhận sản phẩm thành công. Giao dịch hoàn tất!';

    const updated = await this.orderModel
      .findOneAndUpdate(
        { _id: order._id, status: { $in: completableStatuses } },
        {
          $set: {
            status: OrderStatus.COMPLETED,
            paymentStatus: PaymentStatus.PAID,
            completedAt: now,
            deliveredAt: order.deliveredAt ?? now,
          },
          $push: {
            timeline: {
              status: OrderStatus.COMPLETED,
              actorId: new Types.ObjectId(userId),
              actorRole: 'BUYER',
              note: noteText,
              timestamp: now,
            },
          },
        },
        { new: true },
      )
      .exec();

    if (!updated) {
      throw new ConflictException('Order status was modified concurrently');
    }

    // Ensure Payment record is marked PAID (for CASH / COD or BANK_TRANSFER)
    await this.paymentModel
      .updateOne(
        { orderId: order._id },
        {
          $set: {
            status: PaymentStatus.PAID,
            paidAt: now,
            buyerConfirmationAt: now,
            sellerConfirmationAt: now,
          },
        },
      )
      .exec();

    // Transition Product to SOLD
    const prodObjId = new Types.ObjectId(this.extractId(order.productId));
    await this.productModel
      .findByIdAndUpdate(prodObjId, {
        $set: { status: ProductStatus.SOLD },
      })
      .exec();

    const sellerIdStr = this.extractId(order.sellerId);
    const productIdStr = this.extractId(order.productId);

    if (this.messagesService) {
      await this.messagesService.postOrderEventMessage({
        buyerId: userId,
        sellerId: sellerIdStr,
        productId: productIdStr,
        orderId: String(order._id),
        senderId: userId,
        content: `🎉 [Đơn hàng ${order.orderCode}] Giao dịch hoàn tất! Người mua đã xác nhận nhận hàng thành công.`,
      });
    }

    if (this.notificationsService) {
      await Promise.all([
        this.notificationsService.createNotification({
          recipientId: sellerIdStr,
          actorId: userId,
          type: NotificationType.ORDER_COMPLETED,
          title: 'Giao dịch hoàn tất!',
          body: `Người mua đã xác nhận nhận hàng cho đơn ${order.orderCode} ("${order.productSnapshot.title}"). Sản phẩm đã chuyển sang Đã bán.`,
          orderId: String(order._id),
          productId: productIdStr,
        }),
        this.notificationsService.createNotification({
          recipientId: userId,
          actorId: userId,
          type: NotificationType.ORDER_COMPLETED,
          title: 'Đơn hàng hoàn thành!',
          body: `Cảm ơn bạn đã hoàn tất giao dịch đơn ${order.orderCode} trên ReMarket.`,
          orderId: String(order._id),
          productId: productIdStr,
        }),
      ]);
    }

    return this.findOrderById(String(order._id), userId);
  }

  private async loadAndAuthorizeOrder(
    orderId: string,
    userId: string,
    requiredRole?: 'BUYER' | 'SELLER',
  ): Promise<OrderDocument> {
    if (!Types.ObjectId.isValid(orderId)) {
      throw new NotFoundException('Order not found');
    }

    const order = await this.orderModel
      .findById(orderId)
      .populate(
        'buyerId',
        'displayName avatarUrl phoneNumber location university isEmailVerified status',
      )
      .populate(
        'sellerId',
        'displayName avatarUrl phoneNumber location university isEmailVerified status bankInfo',
      )
      .populate('productId', 'title price condition status images location')
      .exec();

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    const buyerIdStr = this.extractId(order.buyerId);
    const sellerIdStr = this.extractId(order.sellerId);
    const isBuyer = buyerIdStr === String(userId);
    const isSeller = sellerIdStr === String(userId);

    if (!isBuyer && !isSeller) {
      throw new ForbiddenException(
        'You do not have permission to access or modify this order',
      );
    }

    if (requiredRole === 'BUYER' && !isBuyer) {
      throw new ForbiddenException(
        'Only the buyer of this order can perform this action',
      );
    }

    if (requiredRole === 'SELLER' && !isSeller) {
      throw new ForbiddenException(
        'Only the seller of this order can perform this action',
      );
    }

    return order;
  }

  private extractId(ref: unknown): string {
    if (ref && typeof ref === 'object' && '_id' in ref) {
      return String((ref as { _id: unknown })._id);
    }
    return String(ref ?? '');
  }

  private serializeOrder(
    order: OrderDocument,
    requesterId: string,
    payment: PaymentDocument | null,
  ): Record<string, unknown> {
    const raw = order.toJSON() as Record<string, unknown>;
    const buyerIdStr = this.extractId(order.buyerId);
    const sellerIdStr = this.extractId(order.sellerId);
    const isParticipant =
      buyerIdStr === String(requesterId) || sellerIdStr === String(requesterId);
    const isValidOrderForBankDisplay =
      isParticipant &&
      ![OrderStatus.CANCELLED, OrderStatus.REJECTED].includes(order.status);

    // Extract seller bankInfo safely and strip it from raw sellerId object
    let sellerBankInfo: Record<string, unknown> | null = null;
    if (
      raw.sellerId &&
      typeof raw.sellerId === 'object' &&
      raw.sellerId !== null
    ) {
      const sellerObj = { ...(raw.sellerId as Record<string, unknown>) };
      const configuredBank = sellerObj.bankInfo as
        | {
            bankName?: string;
            accountNumber?: string;
            accountHolder?: string;
            branch?: string | null;
          }
        | undefined
        | null;
      delete sellerObj.bankInfo;
      raw.seller = sellerObj;
      raw.sellerId = sellerIdStr;

      if (
        isValidOrderForBankDisplay &&
        configuredBank &&
        configuredBank.bankName &&
        configuredBank.accountNumber &&
        configuredBank.accountHolder
      ) {
        sellerBankInfo = {
          bankName: configuredBank.bankName,
          accountNumber: configuredBank.accountNumber,
          accountHolder: configuredBank.accountHolder,
          branch: configuredBank.branch ?? null,
          amount: order.totalAmount,
          transferContent: `${order.orderCode}`,
        };
      }
    }

    if (
      raw.buyerId &&
      typeof raw.buyerId === 'object' &&
      raw.buyerId !== null
    ) {
      raw.buyer = raw.buyerId;
      raw.buyerId = buyerIdStr;
    }

    if (
      raw.productId &&
      typeof raw.productId === 'object' &&
      raw.productId !== null
    ) {
      raw.product = raw.productId;
      raw.productId = this.extractId(order.productId);
    }

    raw.reviewId = order.reviewId ? String(order.reviewId) : null;
    raw.hasReview = Boolean(order.reviewId);
    raw.sellerBankInfo = sellerBankInfo;
    raw.payment = payment
      ? payment.toJSON()
      : {
          paymentId: null,
          orderId: String(order._id),
          payerId: buyerIdStr,
          receiverId: sellerIdStr,
          method: order.paymentMethod,
          amount: order.totalAmount,
          status: order.paymentStatus,
          transactionReference: null,
          transferNote: null,
          buyerConfirmationAt: null,
          sellerConfirmationAt: null,
          paidAt: null,
        };

    return raw;
  }
}
