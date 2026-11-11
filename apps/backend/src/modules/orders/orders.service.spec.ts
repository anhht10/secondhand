import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { MessagesService } from '../messages/messages.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  Product,
  ProductCondition,
  ProductStatus,
} from '../products/schemas/product.schema';
import { User, UserStatus } from '../users/schemas/user.schema';
import { OrdersService } from './orders.service';
import {
  DeliveryMethod,
  Order,
  OrderStatus,
} from './schemas/order.schema';
import {
  Payment,
  PaymentMethod,
  PaymentStatus,
} from './schemas/payment.schema';

describe('OrdersService (Unit Tests — Reservation, Concurrency & State Machine)', () => {
  let service: OrdersService;

  const sellerId = new Types.ObjectId().toHexString();
  const buyerAId = new Types.ObjectId().toHexString();
  const buyerBId = new Types.ObjectId().toHexString();
  const strangerId = new Types.ObjectId().toHexString();
  const productId = new Types.ObjectId().toHexString();

  // In-memory stateful stores for realistic atomic simulation
  let productStore: Record<string, any>;
  let userStore: Record<string, any>;
  let orderStore: Map<string, any>;
  let paymentStore: Map<string, any>;

  const makeChain = (val: any) => ({
    lean: () => ({ exec: jest.fn().mockResolvedValue(val) }),
    populate: function () {
      return this;
    },
    sort: function () {
      return this;
    },
    skip: function () {
      return this;
    },
    limit: function () {
      return this;
    },
    exec: jest.fn().mockResolvedValue(val),
  });

  beforeEach(async () => {
    productStore = {
      [productId]: {
        _id: new Types.ObjectId(productId),
        id: productId,
        sellerId: new Types.ObjectId(sellerId),
        title: 'Tai nghe Sony WH-1000XM4',
        price: 3950000,
        condition: ProductCondition.LIKE_NEW,
        status: ProductStatus.ACTIVE,
        location: 'Quận 10, TP.HCM',
        images: [{ url: 'https://images.unsplash.com/photo-1' }],
      },
    };

    userStore = {
      [sellerId]: {
        _id: new Types.ObjectId(sellerId),
        id: sellerId,
        displayName: 'Nguyễn Minh Khoa',
        phoneNumber: '+84901234567',
        status: UserStatus.ACTIVE,
        bankInfo: {
          bankName: 'Vietcombank',
          accountNumber: '1029384756',
          accountHolder: 'NGUYEN MINH KHOA',
          branch: 'CN Thủ Đức',
        },
      },
      [buyerAId]: {
        _id: new Types.ObjectId(buyerAId),
        id: buyerAId,
        displayName: 'Trần Hoàng Minh',
        phoneNumber: '+84912345678',
        status: UserStatus.ACTIVE,
      },
      [buyerBId]: {
        _id: new Types.ObjectId(buyerBId),
        id: buyerBId,
        displayName: 'Lê Thu Hà',
        phoneNumber: '+84988887777',
        status: UserStatus.ACTIVE,
      },
      [strangerId]: {
        _id: new Types.ObjectId(strangerId),
        id: strangerId,
        displayName: 'Người Lạ',
        status: UserStatus.ACTIVE,
      },
    };

    orderStore = new Map();
    paymentStore = new Map();

    const hydrateOrderDoc = (raw: any) => {
      if (!raw) return null;
      const populated = {
        ...raw,
        buyerId: userStore[String(raw.buyerId)] || raw.buyerId,
        sellerId: userStore[String(raw.sellerId)] || raw.sellerId,
        productId: productStore[String(raw.productId)] || raw.productId,
        save: jest.fn().mockImplementation(async function (this: any) {
          orderStore.set(String(raw._id), {
            ...raw,
            conversationId: this.conversationId ?? raw.conversationId,
          });
          return this;
        }),
        toJSON: function () {
          return {
            ...this,
            id: String(raw._id),
          };
        },
      };
      return populated;
    };

    const hydratePaymentDoc = (raw: any) => {
      if (!raw) return null;
      return {
        ...raw,
        toJSON: () => ({
          ...raw,
          id: String(raw._id),
          paymentId: String(raw._id),
        }),
      };
    };

    const mockProductModel = {
      findById: jest.fn((id: any) => makeChain(productStore[String(id)] ?? null)),
      findOneAndUpdate: jest.fn((filter: any, update: any) => {
        const pid = String(filter._id);
        const prod = productStore[pid];
        if (!prod || prod.status !== filter.status) {
          return makeChain(null);
        }
        if (update.$set) {
          Object.assign(prod, update.$set);
        }
        return makeChain(prod);
      }),
      findByIdAndUpdate: jest.fn((id: any, update: any) => {
        const prod = productStore[String(id)];
        if (prod && update.$set) {
          Object.assign(prod, update.$set);
        }
        return makeChain(prod);
      }),
    };

    const mockUserModel = {
      findById: jest.fn((id: any) => makeChain(userStore[String(id)] ?? null)),
    };

    const mockOrderModel = {
      findOne: jest.fn((filter: any) => {
        for (const o of orderStore.values()) {
          if (
            filter.productId &&
            String(o.productId) === String(filter.productId)
          ) {
            const allowedStatuses: string[] = filter.status?.$in ?? [];
            if (
              allowedStatuses.length === 0 ||
              allowedStatuses.includes(o.status)
            ) {
              return makeChain(hydrateOrderDoc(o));
            }
          }
        }
        return makeChain(null);
      }),
      create: jest.fn(async (doc: any) => {
        const newId = new Types.ObjectId();
        const stored = {
          ...doc,
          _id: newId,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        orderStore.set(newId.toHexString(), stored);
        return hydrateOrderDoc(stored);
      }),
      findById: jest.fn((id: any) => {
        const raw = orderStore.get(String(id));
        return makeChain(hydrateOrderDoc(raw));
      }),
      findOneAndUpdate: jest.fn((filter: any, update: any) => {
        const raw = orderStore.get(String(filter._id));
        if (!raw) return makeChain(null);
        if (typeof filter.status === 'string' && raw.status !== filter.status) {
          return makeChain(null);
        }
        if (
          filter.status?.$in &&
          !filter.status.$in.includes(raw.status)
        ) {
          return makeChain(null);
        }
        if (update.$set) Object.assign(raw, update.$set);
        if (update.$push?.timeline) {
          raw.timeline = [...(raw.timeline || []), update.$push.timeline];
        }
        return makeChain(hydrateOrderDoc(raw));
      }),
      findByIdAndUpdate: jest.fn((id: any, update: any) => {
        const raw = orderStore.get(String(id));
        if (!raw) return makeChain(null);
        if (update.$set) Object.assign(raw, update.$set);
        if (update.$push?.timeline) {
          raw.timeline = [...(raw.timeline || []), update.$push.timeline];
        }
        return makeChain(hydrateOrderDoc(raw));
      }),
      countDocuments: jest.fn((filter: any) => {
        let count = 0;
        for (const o of orderStore.values()) {
          if (
            filter.productId &&
            String(o.productId) !== String(filter.productId)
          ) {
            continue;
          }
          if (filter._id?.$ne && String(o._id) === String(filter._id.$ne)) {
            continue;
          }
          if (
            filter.status?.$in &&
            !filter.status.$in.includes(o.status)
          ) {
            continue;
          }
          count++;
        }
        return makeChain(count);
      }),
    };

    const mockPaymentModel = {
      create: jest.fn(async (doc: any) => {
        const newId = new Types.ObjectId();
        const stored = {
          ...doc,
          _id: newId,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        paymentStore.set(String(doc.orderId), stored);
        return hydratePaymentDoc(stored);
      }),
      findOne: jest.fn((filter: any) => {
        const raw = paymentStore.get(String(filter.orderId));
        return makeChain(hydratePaymentDoc(raw));
      }),
      findOneAndUpdate: jest.fn((filter: any, update: any) => {
        const raw = paymentStore.get(String(filter.orderId));
        if (raw && update.$set) {
          Object.assign(raw, update.$set);
        }
        return makeChain(hydratePaymentDoc(raw));
      }),
      updateOne: jest.fn((filter: any, update: any) => {
        const raw = paymentStore.get(String(filter.orderId));
        if (raw && update.$set) {
          Object.assign(raw, update.$set);
        }
        return makeChain({ modifiedCount: 1 });
      }),
      find: jest.fn(() => makeChain([])),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: getModelToken(Order.name), useValue: mockOrderModel },
        { provide: getModelToken(Payment.name), useValue: mockPaymentModel },
        { provide: getModelToken(Product.name), useValue: mockProductModel },
        { provide: getModelToken(User.name), useValue: mockUserModel },
        {
          provide: MessagesService,
          useValue: {
            postOrderEventMessage: jest
              .fn()
              .mockResolvedValue(new Types.ObjectId().toHexString()),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            createNotification: jest.fn().mockResolvedValue({}),
          },
        },
      ],
    }).compile();

    service = module.get<OrdersService>(OrdersService);
  });

  it('1. creates an order, atomically reserves the product, and exposes sellerBankInfo to buyer', async () => {
    const order = await service.createOrder(buyerAId, {
      productId,
      deliveryMethod: DeliveryMethod.MEETUP,
      paymentMethod: PaymentMethod.BANK_TRANSFER,
      meetupLocation: 'ĐH Bách Khoa Q10',
    });

    expect(order.status).toBe(OrderStatus.PENDING);
    expect(order.paymentStatus).toBe(PaymentStatus.UNPAID);
    expect(productStore[productId].status).toBe(ProductStatus.RESERVED);
    expect(order.sellerBankInfo).toBeDefined();
    expect((order.sellerBankInfo as any).accountNumber).toBe('1029384756');
  });

  it('2. prevents duplicate/concurrent purchase of the same product by two buyers', async () => {
    const results = await Promise.allSettled([
      service.createOrder(buyerAId, {
        productId,
        deliveryMethod: DeliveryMethod.MEETUP,
        paymentMethod: PaymentMethod.CASH,
      }),
      service.createOrder(buyerBId, {
        productId,
        deliveryMethod: DeliveryMethod.MEETUP,
        paymentMethod: DeliveryMethod.MEETUP ? PaymentMethod.CASH : PaymentMethod.CASH,
      }),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason).toBeInstanceOf(
      ConflictException,
    );
  });

  it('3. enforces ownership authorization and blocks non-participants or wrong roles', async () => {
    const order = await service.createOrder(buyerAId, {
      productId,
      deliveryMethod: DeliveryMethod.MEETUP,
      paymentMethod: PaymentMethod.BANK_TRANSFER,
    });
    const orderId = String(order.id);

    // Stranger cannot view order
    await expect(service.findOrderById(orderId, strangerId)).rejects.toThrow(
      ForbiddenException,
    );

    // Buyer cannot confirm order (Seller only)
    await expect(service.confirmOrder(orderId, buyerAId)).rejects.toThrow(
      ForbiddenException,
    );

    // Seller cannot submit buyer payment confirmation on buyer's behalf
    await expect(
      service.confirmBuyerPayment(orderId, sellerId, {
        transactionReference: 'FAKE123',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('4. blocks invalid state transitions and premature seller payment confirmation', async () => {
    const order = await service.createOrder(buyerAId, {
      productId,
      deliveryMethod: DeliveryMethod.DELIVERY,
      shippingAddress: 'KTX Khu B ĐHQG TP.HCM',
      paymentMethod: PaymentMethod.BANK_TRANSFER,
    });
    const orderId = String(order.id);

    // Seller cannot confirm bank transfer receipt before buyer submits payment-confirmation
    await expect(
      service.confirmSellerPayment(orderId, sellerId),
    ).rejects.toThrow(BadRequestException);

    // Buyer cannot complete a PENDING unpaid order
    await expect(service.completeOrder(orderId, buyerAId)).rejects.toThrow(
      BadRequestException,
    );
  });

  it('5. restores product to ACTIVE on cancellation/rejection ONLY if no other active order exists', async () => {
    const order = await service.createOrder(buyerAId, {
      productId,
      deliveryMethod: DeliveryMethod.MEETUP,
      paymentMethod: PaymentMethod.CASH,
    });
    const orderId = String(order.id);
    expect(productStore[productId].status).toBe(ProductStatus.RESERVED);

    const cancelled = await service.cancelOrder(orderId, buyerAId, {
      reason: 'Đổi lịch học',
    });
    expect(cancelled.status).toBe(OrderStatus.CANCELLED);
    expect(productStore[productId].status).toBe(ProductStatus.ACTIVE);
  });

  it('6. completes full BANK_TRANSFER lifecycle and marks Product as SOLD', async () => {
    const created = await service.createOrder(buyerAId, {
      productId,
      deliveryMethod: DeliveryMethod.DELIVERY,
      shippingAddress: 'KTX Khu A ĐHQG Thủ Đức',
      paymentMethod: PaymentMethod.BANK_TRANSFER,
    });
    const orderId = String(created.id);

    // Step 1: Seller confirms order
    const confirmed = await service.confirmOrder(orderId, sellerId);
    expect(confirmed.status).toBe(OrderStatus.CONFIRMED);

    // Step 2: Buyer confirms bank transfer
    const buyerPaid = await service.confirmBuyerPayment(orderId, buyerAId, {
      transactionReference: 'VCB99887766',
    });
    expect(buyerPaid.paymentStatus).toBe(PaymentStatus.BUYER_CONFIRMED);

    // Step 3: Seller confirms receiving money
    const sellerPaid = await service.confirmSellerPayment(orderId, sellerId);
    expect(sellerPaid.paymentStatus).toBe(PaymentStatus.PAID);

    // Step 4: Seller updates delivery status
    const shipped = await service.updateDeliveryStatus(orderId, sellerId, {
      deliveryStatus: 'SHIPPING',
    });
    expect(shipped.status).toBe(OrderStatus.SHIPPING);

    // Step 5: Buyer confirms receipt -> Order COMPLETED & Product SOLD
    const completed = await service.completeOrder(orderId, buyerAId);
    expect(completed.status).toBe(OrderStatus.COMPLETED);
    expect(productStore[productId].status).toBe(ProductStatus.SOLD);
  });
});
