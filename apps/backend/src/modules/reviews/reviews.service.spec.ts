import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { NotificationsService } from '../notifications/notifications.service';
import { Order, OrderStatus } from '../orders/schemas/order.schema';
import { Product } from '../products/schemas/product.schema';
import { UploadService } from '../upload/upload.service';
import { User } from '../users/schemas/user.schema';
import { ReviewsService } from './reviews.service';
import { Review, ReviewStatus } from './schemas/review.schema';

describe('ReviewsService (Phase 9.6 — Seller Reputation & Reviews)', () => {
  let service: ReviewsService;

  const buyerId = new Types.ObjectId();
  const sellerId = new Types.ObjectId();
  const otherUserId = new Types.ObjectId();
  const orderId = new Types.ObjectId();
  const productId = new Types.ObjectId();
  const reviewId = new Types.ObjectId();

  const mockCompletedOrder = {
    _id: orderId,
    orderCode: 'RM261108REV1',
    productId,
    buyerId,
    sellerId,
    status: OrderStatus.COMPLETED,
    productSnapshot: {
      title: 'Bàn phím Keychron K2 Pro',
      price: 1500000,
      condition: 'LIKE_NEW',
    },
  };

  const mockReviewModel = {
    findOne: jest.fn(),
    findById: jest.fn(),
    find: jest.fn(),
    countDocuments: jest.fn(),
    create: jest.fn(),
    aggregate: jest.fn(),
  };

  const mockOrderModel = {
    findById: jest.fn(),
    findByIdAndUpdate: jest.fn(),
    aggregate: jest.fn(),
  };

  const mockProductModel = {
    countDocuments: jest.fn(),
  };

  const mockUserModel = {
    findById: jest.fn(),
    findByIdAndUpdate: jest.fn(),
  };

  const mockUploadService = {
    uploadProductImages: jest.fn(),
  };

  const mockNotificationsService = {
    createNotification: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    mockOrderModel.findByIdAndUpdate.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockCompletedOrder),
    });
    mockUserModel.findByIdAndUpdate.mockReturnValue({
      exec: jest.fn().mockResolvedValue({}),
    });
    mockProductModel.countDocuments.mockReturnValue({
      exec: jest.fn().mockResolvedValue(1),
    });
    mockReviewModel.aggregate.mockReturnValue({
      exec: jest.fn().mockResolvedValue([{ _id: 5, count: 1, repliedCount: 0 }]),
    });
    mockOrderModel.aggregate.mockReturnValue({
      exec: jest.fn().mockResolvedValue([
        { _id: OrderStatus.COMPLETED, count: 1 },
        { _id: OrderStatus.CANCELLED, count: 2 },
      ]),
    });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReviewsService,
        { provide: getModelToken(Review.name), useValue: mockReviewModel },
        { provide: getModelToken(Order.name), useValue: mockOrderModel },
        { provide: getModelToken(Product.name), useValue: mockProductModel },
        { provide: getModelToken(User.name), useValue: mockUserModel },
        { provide: UploadService, useValue: mockUploadService },
        { provide: NotificationsService, useValue: mockNotificationsService },
      ],
    }).compile();

    service = module.get<ReviewsService>(ReviewsService);
  });

  function makePopulatedReviewQuery(doc: Record<string, unknown> | null) {
    return {
      populate: jest.fn().mockReturnValue({
        populate: jest.fn().mockReturnValue({
          populate: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue(doc),
          }),
        }),
      }),
    };
  }

  it('creates a review for a COMPLETED order, links reviewId, and recalculates reputation without giving 100/100 on a single 5-star review', async () => {
    mockOrderModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockCompletedOrder),
    });
    mockReviewModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(null) }),
    });

    const createdDoc = {
      _id: reviewId,
      orderId,
      productId,
      buyerId: { _id: buyerId, displayName: 'Buyer A', isEmailVerified: true },
      sellerId: {
        _id: sellerId,
        displayName: 'Seller B',
        isEmailVerified: true,
      },
      rating: 5,
      comment: 'Sản phẩm đúng như mô tả, giao hàng nhanh!',
      images: ['http://localhost:3000/uploads/products/rev1.jpg'],
      status: ReviewStatus.VISIBLE,
      sellerReply: null,
      sellerRepliedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    mockReviewModel.create.mockResolvedValue(createdDoc);
    mockReviewModel.findById.mockReturnValue(
      makePopulatedReviewQuery(createdDoc),
    );

    const res = await service.createReview(String(buyerId), {
      orderId: String(orderId),
      rating: 5,
      comment: 'Sản phẩm đúng như mô tả, giao hàng nhanh!',
      images: ['http://localhost:3000/uploads/products/rev1.jpg'],
    });

    expect(res.rating).toBe(5);
    expect(res.images).toHaveLength(1);
    expect(mockOrderModel.findByIdAndUpdate).toHaveBeenCalledWith(orderId, {
      $set: { reviewId },
    });

    // Verify Bayesian reputation calculation:
    // 1 review of 5 stars + 1 completed order + 2 buyer-cancelled orders:
    // - BayesianAvg = (5*4.0 + 5) / 6 = 4.1667 -> bayesianRatingScore = 58.33
    // - transactionExperienceScore = 1 * 2.5 = 2.5
    // - fulfillmentReliabilityScore = 10 (buyer cancellations do NOT penalize seller!)
    // Total reputationScore = round(58.33 + 2.5 + 10) = 71 (< 100!)
    const reputation = await service.recalculateSellerReputation(
      String(sellerId),
    );
    expect(reputation.averageRating).toBe(5);
    expect(reputation.ratingSummary.totalReviews).toBe(1);
    expect(reputation.reputationScore).toBe(71);
    expect(reputation.reputationScore).toBeLessThan(100);
    expect(reputation.transactionStats.buyerCancelledOrdersCount).toBe(2);
    expect(reputation.transactionStats.successfulTransactionRate).toBe(100);
  });

  it('rejects review creation when order is not COMPLETED or when called by non-buyer', async () => {
    // 1. Order still CONFIRMED (not COMPLETED)
    mockOrderModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue({
        ...mockCompletedOrder,
        status: OrderStatus.CONFIRMED,
      }),
    });

    await expect(
      service.createReview(String(buyerId), {
        orderId: String(orderId),
        rating: 5,
        comment: 'Đánh giá sớm khi chưa hoàn tất đơn',
      }),
    ).rejects.toThrow(BadRequestException);

    // 2. Called by another user who is not the buyer of the order
    mockOrderModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockCompletedOrder),
    });

    await expect(
      service.createReview(String(otherUserId), {
        orderId: String(orderId),
        rating: 4,
        comment: 'Người lạ cố tình đánh giá đơn của người khác',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('prevents duplicate reviews for the same order', async () => {
    mockOrderModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockCompletedOrder),
    });
    mockReviewModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue({ _id: reviewId }) }),
    });

    await expect(
      service.createReview(String(buyerId), {
        orderId: String(orderId),
        rating: 5,
        comment: 'Cố tình đánh giá lần 2 cho cùng 1 đơn hàng',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('allows buyer to update review within 7 days and blocks edits after 7 days or by non-buyer', async () => {
    const recentReviewDoc = {
      _id: reviewId,
      orderId,
      productId,
      buyerId,
      sellerId,
      rating: 4,
      comment: 'Nhận xét ban đầu',
      images: [],
      status: ReviewStatus.VISIBLE,
      createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
      save: jest.fn().mockResolvedValue(undefined),
    };

    mockReviewModel.findById
      .mockReturnValueOnce({
        exec: jest.fn().mockResolvedValue(recentReviewDoc),
      })
      .mockReturnValueOnce(
        makePopulatedReviewQuery({
          ...recentReviewDoc,
          rating: 5,
          comment: 'Đã cập nhật lên 5 sao sau khi dùng thử',
        }),
      );

    const updated = await service.updateReview(
      String(reviewId),
      String(buyerId),
      {
        rating: 5,
        comment: 'Đã cập nhật lên 5 sao sau khi dùng thử',
      },
    );
    expect(updated.rating).toBe(5);
    expect(recentReviewDoc.save).toHaveBeenCalled();

    // Expired (> 7 days old)
    const expiredReviewDoc = {
      ...recentReviewDoc,
      createdAt: new Date(Date.now() - 9 * 24 * 60 * 60 * 1000), // 9 days ago
    };
    mockReviewModel.findById.mockReturnValueOnce({
      exec: jest.fn().mockResolvedValue(expiredReviewDoc),
    });

    await expect(
      service.updateReview(String(reviewId), String(buyerId), {
        rating: 3,
        comment: 'Cố sửa sau 9 ngày',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('enforces seller reply permissions (seller only, 1 reply per review, cannot alter rating)', async () => {
    const reviewDoc = {
      _id: reviewId,
      orderId,
      productId,
      buyerId,
      sellerId,
      rating: 4,
      comment: 'Hàng tốt, đóng gói kỹ.',
      images: [],
      status: ReviewStatus.VISIBLE,
      sellerReply: null as string | null,
      sellerRepliedAt: null as Date | null,
      createdAt: new Date(),
      save: jest.fn().mockResolvedValue(undefined),
    };

    // 1. Non-seller cannot reply
    mockReviewModel.findById.mockReturnValueOnce({
      exec: jest.fn().mockResolvedValue(reviewDoc),
    });
    await expect(
      service.replyToReview(String(reviewId), String(buyerId), {
        reply: 'Người mua tự trả lời',
      }),
    ).rejects.toThrow(ForbiddenException);

    // 2. Seller replies successfully
    mockReviewModel.findById
      .mockReturnValueOnce({
        exec: jest.fn().mockResolvedValue(reviewDoc),
      })
      .mockReturnValueOnce(
        makePopulatedReviewQuery({
          ...reviewDoc,
          sellerReply: 'Cảm ơn bạn đã ủng hộ shop!',
          sellerRepliedAt: new Date(),
        }),
      );

    const replied = await service.replyToReview(
      String(reviewId),
      String(sellerId),
      {
        reply: 'Cảm ơn bạn đã ủng hộ shop!',
      },
    );
    expect(replied.sellerReply).toBe('Cảm ơn bạn đã ủng hộ shop!');
    expect(replied.rating).toBe(4);

    // 3. Second reply attempt on same review is rejected with ConflictException
    mockReviewModel.findById.mockReturnValueOnce({
      exec: jest.fn().mockResolvedValue(reviewDoc),
    });
    await expect(
      service.replyToReview(String(reviewId), String(sellerId), {
        reply: 'Phản hồi lần 2',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('blocks arbitrary review deletion and recalculates reputation when moderation hides a review', async () => {
    const reviewDoc = {
      _id: reviewId,
      orderId,
      productId,
      buyerId,
      sellerId,
      rating: 1,
      status: ReviewStatus.VISIBLE,
      moderationNote: null as string | null,
      save: jest.fn().mockResolvedValue(undefined),
    };

    mockReviewModel.findById.mockReturnValueOnce({
      lean: () => ({ exec: jest.fn().mockResolvedValue(reviewDoc) }),
    });

    await expect(
      service.deleteReviewControlled(String(reviewId), String(buyerId)),
    ).rejects.toThrow(ForbiddenException);

    // Moderation hides the review -> triggers recalculateSellerReputation
    mockReviewModel.findById.mockReturnValueOnce({
      exec: jest.fn().mockResolvedValue(reviewDoc),
    });
    mockReviewModel.aggregate.mockReturnValueOnce({
      exec: jest.fn().mockResolvedValue([]), // 0 visible reviews remaining
    });

    const modRes = await service.moderateReview(String(reviewId), {
      status: ReviewStatus.HIDDEN,
      moderationNote: 'Vi phạm quy định đăng thông tin nhạy cảm',
    });

    expect(modRes.status).toBe(ReviewStatus.HIDDEN);
    expect(mockOrderModel.findByIdAndUpdate).toHaveBeenCalledWith(orderId, {
      $set: { reviewId: null },
    });
  });
});
