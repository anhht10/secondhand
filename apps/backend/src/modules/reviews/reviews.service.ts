import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, SortOrder, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/schemas/notification.schema';
import { Order, OrderDocument, OrderStatus } from '../orders/schemas/order.schema';
import {
  Product,
  ProductDocument,
  ProductStatus,
} from '../products/schemas/product.schema';
import { UploadService } from '../upload/upload.service';
import { User, UserDocument, UserStatus } from '../users/schemas/user.schema';
import {
  CreateReviewDto,
  ModerateReviewDto,
  QueryReviewsDto,
  ReportReviewDto,
  ReviewSortBy,
  SellerReplyReviewDto,
  UpdateReviewDto,
} from './dto/review.dto';
import {
  MAX_REVIEW_IMAGES,
  REVIEW_EDIT_WINDOW_DAYS,
  Review,
  ReviewDocument,
  ReviewStatus,
} from './schemas/review.schema';

export interface RatingSummaryResponse {
  averageRating: number;
  totalReviews: number;
  star5Count: number;
  star4Count: number;
  star3Count: number;
  star2Count: number;
  star1Count: number;
  starCounts: Record<'1' | '2' | '3' | '4' | '5', number>;
  ratingDistribution: Record<'1' | '2' | '3' | '4' | '5', number>;
}

export interface TransactionStatisticsResponse {
  completedOrdersCount: number;
  buyerCancelledOrdersCount: number;
  sellerRejectedOrdersCount: number;
  pendingOrdersCount: number;
  successfulTransactionCount: number;
  successfulTransactionRate: number;
  activeListingsCount: number;
  soldListingsCount: number;
  repliedReviewsCount: number;
  sellerReplyRate: number;
}

export interface ReputationBreakdownResponse {
  bayesianRatingScore: number;
  transactionExperienceScore: number;
  fulfillmentReliabilityScore: number;
  priorConfidenceWeight: number;
  priorMeanRating: number;
  formulaDescription: string;
}

export interface SellerReputationResponse {
  sellerId: string;
  averageRating: number;
  reputationScore: number;
  ratingSummary: RatingSummaryResponse;
  transactionStats: TransactionStatisticsResponse;
  reputationBreakdown: ReputationBreakdownResponse;
  updatedAt: string;
}

export interface PaginatedSellerReviewsResponse {
  items: Record<string, unknown>[];
  ratingSummary: RatingSummaryResponse;
  meta: PaginationMeta;
}

@Injectable()
export class ReviewsService {
  // Bayesian smoothing constants so 1 review of 5 stars does not immediately yield a 100/100 score
  private static readonly BAYESIAN_PRIOR_WEIGHT = 5;
  private static readonly BAYESIAN_PRIOR_MEAN = 4.0;

  constructor(
    @InjectModel(Review.name)
    private readonly reviewModel: Model<ReviewDocument>,
    @InjectModel(Order.name)
    private readonly orderModel: Model<OrderDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @Optional() private readonly uploadService?: UploadService,
    @Optional() private readonly notificationsService?: NotificationsService,
  ) {}

  private validateCommentContent(comment: string): string {
    const trimmed = comment.trim();
    if (trimmed.length < 3 || trimmed.length > 1500) {
      throw new BadRequestException(
        'Nội dung đánh giá phải từ 3 đến 1500 ký tự',
      );
    }

    // Prevent accidental or malicious posting of sensitive credentials / PII
    const sensitivePattern =
      /\b(mật\s*khẩu\s*ngân\s*hàng|mã\s*otp|cvv\s*[:=]?\s*\d{3,4})\b/i;
    if (sensitivePattern.test(trimmed)) {
      throw new BadRequestException(
        'Nội dung đánh giá không được chứa mật khẩu ngân hàng, mã OTP hoặc thông tin bảo mật nhạy cảm',
      );
    }

    return trimmed;
  }

  async uploadReviewImages(files: MulterUploadedFile[]): Promise<string[]> {
    if (!files || files.length === 0) {
      throw new BadRequestException('Vui lòng chọn ít nhất 1 hình ảnh');
    }
    if (files.length > MAX_REVIEW_IMAGES) {
      throw new BadRequestException(
        `Mỗi đánh giá chỉ được tải lên tối đa ${MAX_REVIEW_IMAGES} hình ảnh`,
      );
    }
    if (!this.uploadService) {
      throw new BadRequestException('Dịch vụ tải ảnh hiện không khả dụng');
    }

    const uploaded = await this.uploadService.uploadProductImages(files);
    return uploaded.map((item) => item.url);
  }

  async createReview(
    buyerId: string,
    dto: CreateReviewDto,
    uploadedFiles?: MulterUploadedFile[],
  ): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(dto.orderId)) {
      throw new BadRequestException('Mã đơn hàng không hợp lệ');
    }

    const order = await this.orderModel.findById(dto.orderId).exec();
    if (!order) {
      throw new NotFoundException('Không tìm thấy đơn hàng');
    }

    // 1. Verify buyer ownership from JWT
    if (String(order.buyerId) !== String(buyerId)) {
      throw new ForbiddenException(
        'Chỉ người mua thực tế của đơn hàng này mới có quyền gửi đánh giá',
      );
    }

    // 2. Prevent self-review
    if (String(order.sellerId) === String(buyerId)) {
      throw new BadRequestException(
        'Người bán không thể tự đánh giá chính mình',
      );
    }

    // 3. Require order status === COMPLETED
    if (order.status !== OrderStatus.COMPLETED) {
      throw new BadRequestException(
        'Chỉ có thể đánh giá người bán sau khi đơn hàng đã hoàn thành (COMPLETED)',
      );
    }

    // 4. Check duplicate review for this order
    const existingReview = await this.reviewModel
      .findOne({ orderId: order._id })
      .lean()
      .exec();
    if (existingReview) {
      throw new ConflictException(
        'Đơn hàng này đã được đánh giá. Mỗi đơn hàng chỉ được tạo một đánh giá duy nhất',
      );
    }

    // 5. Validate comment & images (max 5)
    const sanitizedComment = this.validateCommentContent(dto.comment);
    const imageUrls: string[] = [...(dto.images ?? [])]
      .map((u) => u.trim())
      .filter((u) => u.length > 0);

    if (uploadedFiles && uploadedFiles.length > 0) {
      if (imageUrls.length + uploadedFiles.length > MAX_REVIEW_IMAGES) {
        throw new BadRequestException(
          `Mỗi đánh giá chỉ được đính kèm tối đa ${MAX_REVIEW_IMAGES} hình ảnh`,
        );
      }
      const newlyUploaded = await this.uploadReviewImages(uploadedFiles);
      imageUrls.push(...newlyUploaded);
    }

    if (imageUrls.length > MAX_REVIEW_IMAGES) {
      throw new BadRequestException(
        `Mỗi đánh giá chỉ được đính kèm tối đa ${MAX_REVIEW_IMAGES} hình ảnh`,
      );
    }

    try {
      const created = await this.reviewModel.create({
        orderId: order._id,
        productId: order.productId,
        buyerId: new Types.ObjectId(buyerId),
        sellerId: order.sellerId,
        rating: dto.rating,
        comment: sanitizedComment,
        images: imageUrls,
        status: ReviewStatus.VISIBLE,
      });

      await this.orderModel
        .findByIdAndUpdate(order._id, {
          $set: { reviewId: created._id },
        })
        .exec();

      await this.recalculateSellerReputation(String(order.sellerId));

      await this.notificationsService?.createNotification({
        recipientId: String(order.sellerId),
        actorId: buyerId,
        type: NotificationType.REVIEW_RECEIVED,
        title: `Bạn nhận được đánh giá ${dto.rating} sao mới`,
        body: `Người mua đơn hàng ${order.orderCode} vừa gửi đánh giá ${dto.rating}/5 sao cho sản phẩm "${order.productSnapshot.title}".`,
        orderId: String(order._id),
        productId: String(order.productId),
      });

      return this.getReviewById(String(created._id));
    } catch (err) {
      if ((err as { code?: number })?.code === 11000) {
        throw new ConflictException(
          'Đơn hàng này đã được đánh giá. Mỗi đơn hàng chỉ được tạo một đánh giá duy nhất',
        );
      }
      throw err;
    }
  }

  async getReviewById(reviewId: string): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel
      .findById(reviewId)
      .populate('buyerId', 'displayName avatarUrl location isEmailVerified')
      .populate('sellerId', 'displayName avatarUrl location isEmailVerified')
      .populate('productId', 'title price condition images status location')
      .exec();

    if (!review || review.status !== ReviewStatus.VISIBLE) {
      throw new NotFoundException('Không tìm thấy đánh giá hoặc đánh giá đã bị ẩn');
    }

    return this.formatReviewResponse(review);
  }

  async getReviewByOrderId(
    orderId: string,
    requesterUserId: string,
  ): Promise<Record<string, unknown> | null> {
    if (!Types.ObjectId.isValid(orderId)) {
      throw new BadRequestException('Mã đơn hàng không hợp lệ');
    }

    const order = await this.orderModel.findById(orderId).lean().exec();
    if (!order) {
      throw new NotFoundException('Không tìm thấy đơn hàng');
    }

    const isParticipant =
      String(order.buyerId) === String(requesterUserId) ||
      String(order.sellerId) === String(requesterUserId);
    if (!isParticipant) {
      throw new ForbiddenException(
        'Bạn không có quyền truy cập thông tin đánh giá của đơn hàng này',
      );
    }

    const review = await this.reviewModel
      .findOne({
        orderId: new Types.ObjectId(orderId),
        status: ReviewStatus.VISIBLE,
      })
      .populate('buyerId', 'displayName avatarUrl location isEmailVerified')
      .populate('sellerId', 'displayName avatarUrl location isEmailVerified')
      .populate('productId', 'title price condition images status location')
      .exec();

    if (!review) {
      return null;
    }

    return this.formatReviewResponse(review);
  }

  async updateReview(
    reviewId: string,
    buyerId: string,
    dto: UpdateReviewDto,
  ): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel.findById(reviewId).exec();
    if (!review || review.status !== ReviewStatus.VISIBLE) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    if (String(review.buyerId) !== String(buyerId)) {
      throw new ForbiddenException(
        'Chỉ người mua đã tạo đánh giá này mới có quyền chỉnh sửa',
      );
    }

    const createdAtMs = review.createdAt
      ? new Date(review.createdAt).getTime()
      : Date.now();
    const editWindowMs = REVIEW_EDIT_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    if (Date.now() - createdAtMs > editWindowMs) {
      throw new BadRequestException(
        `Chỉ được phép chỉnh sửa đánh giá trong vòng ${REVIEW_EDIT_WINDOW_DAYS} ngày kể từ khi tạo`,
      );
    }

    if (dto.rating !== undefined) {
      review.rating = dto.rating;
    }
    if (dto.comment !== undefined) {
      review.comment = this.validateCommentContent(dto.comment);
    }
    if (dto.images !== undefined) {
      const cleaned = dto.images.map((u) => u.trim()).filter((u) => u.length > 0);
      if (cleaned.length > MAX_REVIEW_IMAGES) {
        throw new BadRequestException(
          `Mỗi đánh giá chỉ được đính kèm tối đa ${MAX_REVIEW_IMAGES} hình ảnh`,
        );
      }
      review.images = cleaned;
    }

    await review.save();
    await this.recalculateSellerReputation(String(review.sellerId));

    return this.getReviewById(String(review._id));
  }

  async deleteReviewControlled(
    reviewId: string,
    _requesterUserId: string,
  ): Promise< never > {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel.findById(reviewId).lean().exec();
    if (!review) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    // Policy: Prevent arbitrary deletion of reviews to protect reputation integrity.
    throw new ForbiddenException(
      'Để đảm bảo tính minh bạch của điểm uy tín, hệ thống không cho phép tự ý xóa đánh giá đã gửi. Người mua có thể chỉnh sửa trong 7 ngày đầu hoặc gửi báo cáo vi phạm để kiểm duyệt.',
    );
  }

  async moderateReview(
    reviewId: string,
    dto: ModerateReviewDto,
  ): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel.findById(reviewId).exec();
    if (!review) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    review.status = dto.status;
    review.moderationNote = dto.moderationNote?.trim() ?? null;
    await review.save();

    await this.orderModel
      .findByIdAndUpdate(review.orderId, {
        $set: {
          reviewId:
              dto.status === ReviewStatus.VISIBLE ? review._id : null,
        },
      })
      .exec();

    // Immediately recalculate seller reputation excluding HIDDEN / DELETED reviews
    await this.recalculateSellerReputation(String(review.sellerId));

    return {
      id: String(review._id),
      orderId: String(review.orderId),
      sellerId: String(review.sellerId),
      status: review.status,
      moderationNote: review.moderationNote,
    };
  }

  async replyToReview(
    reviewId: string,
    sellerId: string,
    dto: SellerReplyReviewDto,
  ): Promise<Record<string, unknown>> {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel.findById(reviewId).exec();
    if (!review || review.status !== ReviewStatus.VISIBLE) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    if (String(review.sellerId) !== String(sellerId)) {
      throw new ForbiddenException(
        'Chỉ người bán của đơn hàng trong đánh giá này mới được quyền phản hồi',
      );
    }

    if (review.sellerReply && review.sellerReply.trim().length > 0) {
      throw new ConflictException(
        'Đánh giá này đã có phản hồi từ người bán. Mỗi đánh giá chỉ có một phản hồi hiện hành',
      );
    }

    const sanitizedReply = this.validateCommentContent(dto.reply);
    review.sellerReply = sanitizedReply;
    review.sellerRepliedAt = new Date();
    await review.save();

    await this.notificationsService?.createNotification({
      recipientId: String(review.buyerId),
      actorId: sellerId,
      type: NotificationType.REVIEW_REPLIED,
      title: 'Người bán đã phản hồi đánh giá của bạn',
      body: `Người bán vừa phản hồi nhận xét của bạn: "${sanitizedReply}"`,
      orderId: String(review.orderId),
      productId: String(review.productId),
    });

    return this.getReviewById(String(review._id));
  }

  async reportReview(
    reviewId: string,
    reporterId: string,
    dto: ReportReviewDto,
  ): Promise<{ id: string; reportCount: number; message: string }> {
    if (!Types.ObjectId.isValid(reviewId)) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    const review = await this.reviewModel.findById(reviewId).exec();
    if (!review || review.status !== ReviewStatus.VISIBLE) {
      throw new NotFoundException('Không tìm thấy đánh giá');
    }

    if (String(review.buyerId) === String(reporterId)) {
      throw new BadRequestException(
        'Bạn không thể tự báo cáo đánh giá của chính mình',
      );
    }

    const alreadyReported = (review.reports ?? []).some(
      (entry) => String(entry.reporterId) === String(reporterId),
    );
    if (alreadyReported) {
      throw new ConflictException(
        'Bạn đã gửi báo cáo cho đánh giá này trước đó',
      );
    }

    review.reports.push({
      reporterId: new Types.ObjectId(reporterId),
      reason: dto.reason.trim(),
      description: dto.description?.trim() ?? null,
      createdAt: new Date(),
    });
    review.reportCount = review.reports.length;
    await review.save();

    return {
      id: String(review._id),
      reportCount: review.reportCount,
      message:
        'Báo cáo đã được ghi nhận để đội ngũ kiểm duyệt xem xét. Hệ thống không tự động xóa đánh giá có số sao thấp nếu không vi phạm chính sách.',
    };
  }

  async getSellerReviews(
    sellerId: string,
    queryDto: QueryReviewsDto,
  ): Promise<PaginatedSellerReviewsResponse> {
    if (!Types.ObjectId.isValid(sellerId)) {
      throw new NotFoundException('Không tìm thấy người bán');
    }

    const sellerObjId = new Types.ObjectId(sellerId);
    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(50, Math.max(1, queryDto.limit ?? 10));
    const skip = (page - 1) * limit;

    const filter: FilterQuery<ReviewDocument> = {
      sellerId: sellerObjId,
      status: ReviewStatus.VISIBLE,
    };

    if (queryDto.rating !== undefined) {
      filter.rating = queryDto.rating;
    }

    let sortSpec: Record<string, SortOrder> = { createdAt: -1 };
    switch (queryDto.sort) {
      case ReviewSortBy.OLDEST:
        sortSpec = { createdAt: 1 };
        break;
      case ReviewSortBy.HIGHEST:
        sortSpec = { rating: -1, createdAt: -1 };
        break;
      case ReviewSortBy.LOWEST:
        sortSpec = { rating: 1, createdAt: -1 };
        break;
      case ReviewSortBy.NEWEST:
      default:
        sortSpec = { createdAt: -1 };
        break;
    }

    const [items, total, reputation] = await Promise.all([
      this.reviewModel
        .find(filter)
        .sort(sortSpec)
        .skip(skip)
        .limit(limit)
        .populate('buyerId', 'displayName avatarUrl location isEmailVerified')
        .populate('sellerId', 'displayName avatarUrl location isEmailVerified')
        .populate('productId', 'title price condition images status location')
        .exec(),
      this.reviewModel.countDocuments(filter).exec(),
      this.recalculateSellerReputation(sellerId),
    ]);

    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items: items.map((doc) => this.formatReviewResponse(doc)),
      ratingSummary: reputation.ratingSummary,
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

  async getSellerReputation(
    sellerId: string,
  ): Promise<SellerReputationResponse> {
    if (!Types.ObjectId.isValid(sellerId)) {
      throw new NotFoundException('Không tìm thấy người bán');
    }

    const seller = await this.userModel.findById(sellerId).lean().exec();
    if (!seller || seller.status === UserStatus.DELETED) {
      throw new NotFoundException('Không tìm thấy người bán');
    }

    return this.recalculateSellerReputation(sellerId);
  }

  async recalculateSellerReputation(
    sellerId: string,
  ): Promise<SellerReputationResponse> {
    const sellerObjId = new Types.ObjectId(sellerId);

    // 1. Aggregate VISIBLE reviews by rating & reply count
    const [reviewStats, orderStats, activeListingsCount, soldListingsCount] =
      await Promise.all([
        this.reviewModel
          .aggregate<{
            _id: number;
            count: number;
            repliedCount: number;
          }>([
            {
              $match: {
                sellerId: sellerObjId,
                status: ReviewStatus.VISIBLE,
              },
            },
            {
              $group: {
                _id: '$rating',
                count: { $sum: 1 },
                repliedCount: {
                  $sum: {
                    $cond: [
                      {
                        $and: [
                          { $ne: ['$sellerReply', null] },
                          { $ne: ['$sellerReply', ''] },
                        ],
                      },
                      1,
                      0,
                    ],
                  },
                },
              },
            },
          ])
          .exec(),
        this.orderModel
          .aggregate<{
            _id: OrderStatus;
            count: number;
          }>([
            {
              $match: {
                sellerId: sellerObjId,
              },
            },
            {
              $group: {
                _id: '$status',
                count: { $sum: 1 },
              },
            },
          ])
          .exec(),
        this.productModel
          .countDocuments({
            sellerId: sellerObjId,
            status: { $in: [ProductStatus.ACTIVE, ProductStatus.RESERVED] },
          })
          .exec(),
        this.productModel
          .countDocuments({
            sellerId: sellerObjId,
            status: ProductStatus.SOLD,
          })
          .exec(),
      ]);

    const starCounts: Record<'1' | '2' | '3' | '4' | '5', number> = {
      '1': 0,
      '2': 0,
      '3': 0,
      '4': 0,
      '5': 0,
    };
    let totalReviews = 0;
    let sumRatings = 0;
    let repliedReviewsCount = 0;

    for (const row of reviewStats) {
      const star = row._id;
      const count = row.count ?? 0;
      if (star >= 1 && star <= 5) {
        starCounts[String(star) as '1' | '2' | '3' | '4' | '5'] = count;
        totalReviews += count;
        sumRatings += star * count;
        repliedReviewsCount += row.repliedCount ?? 0;
      }
    }

    const averageRating =
      totalReviews > 0
        ? Math.round((sumRatings / totalReviews) * 100) / 100
        : 0;

    const ratingDistribution: Record<'1' | '2' | '3' | '4' | '5', number> = {
      '1':
        totalReviews > 0
          ? Math.round((starCounts['1'] / totalReviews) * 100)
          : 0,
      '2':
        totalReviews > 0
          ? Math.round((starCounts['2'] / totalReviews) * 100)
          : 0,
      '3':
        totalReviews > 0
          ? Math.round((starCounts['3'] / totalReviews) * 100)
          : 0,
      '4':
        totalReviews > 0
          ? Math.round((starCounts['4'] / totalReviews) * 100)
          : 0,
      '5':
        totalReviews > 0
          ? Math.round((starCounts['5'] / totalReviews) * 100)
          : 0,
    };

    // 2. Aggregate Order statistics (distinguishing buyer-cancelled from seller-rejected)
    let completedOrdersCount = 0;
    let buyerCancelledOrdersCount = 0;
    let sellerRejectedOrdersCount = 0;
    let pendingOrdersCount = 0;

    for (const row of orderStats) {
      const count = row.count ?? 0;
      switch (row._id) {
        case OrderStatus.COMPLETED:
          completedOrdersCount += count;
          break;
        case OrderStatus.CANCELLED:
          buyerCancelledOrdersCount += count;
          break;
        case OrderStatus.REJECTED:
          sellerRejectedOrdersCount += count;
          break;
        case OrderStatus.PENDING:
        case OrderStatus.CONFIRMED:
        case OrderStatus.SHIPPING:
        case OrderStatus.DELIVERED:
          pendingOrdersCount += count;
          break;
      }
    }

    const effectiveCompletedTransactions = Math.max(
      completedOrdersCount,
      soldListingsCount,
    );
    const totalSellerDecidedOrders =
      effectiveCompletedTransactions + sellerRejectedOrdersCount;
    const successfulTransactionRate =
      totalSellerDecidedOrders > 0
        ? Math.round(
            (effectiveCompletedTransactions / totalSellerDecidedOrders) * 100,
          )
        : 100;
    const sellerReplyRate =
      totalReviews > 0
        ? Math.round((repliedReviewsCount / totalReviews) * 100)
        : 100;

    // 3. Transparent Reputation Score (0..100)
    // - Bayesian Rating Score (max 70 pts): shrinks small review counts toward prior mean 4.0 (C = 5)
    //   so 1 review of 5 stars yields BayesianAvg = (20 + 5)/6 = 4.17 -> 58.33/70 (not 70/70)
    const C = ReviewsService.BAYESIAN_PRIOR_WEIGHT;
    const m = ReviewsService.BAYESIAN_PRIOR_MEAN;
    const bayesianAvg = (C * m + sumRatings) / (C + totalReviews);
    const bayesianRatingScore =
      Math.round(((bayesianAvg / 5.0) * 70) * 100) / 100;

    // - Completed Transaction Experience Score (max 20 pts, 2.5 pts per completed order up to 8 orders)
    const transactionExperienceScore =
      Math.round(Math.min(20, effectiveCompletedTransactions * 2.5) * 100) /
      100;

    // - Seller Fulfillment Reliability Score (max 10 pts)
    //   Only seller rejections reduce reliability; buyer cancellations are NOT penalized against seller
    const sellerFaultRate =
      totalSellerDecidedOrders > 0
        ? sellerRejectedOrdersCount / totalSellerDecidedOrders
        : 0;
    const fulfillmentReliabilityScore =
      Math.round(10 * (1 - sellerFaultRate) * 100) / 100;

    const rawScore =
      bayesianRatingScore +
      transactionExperienceScore +
      fulfillmentReliabilityScore;
    const reputationScore = Math.max(0, Math.min(100, Math.round(rawScore)));

    // 4. Persist lightweight cache on User document so Profile & Product Detail reads are O(1)
    const now = new Date();
    await this.userModel
      .findByIdAndUpdate(sellerObjId, {
        $set: {
          reputationCache: {
            averageRating,
            totalReviews,
            reputationScore,
            completedOrdersCount: effectiveCompletedTransactions,
            updatedAt: now,
          },
        },
      })
      .exec();

    return {
      sellerId,
      averageRating,
      reputationScore,
      ratingSummary: {
        averageRating,
        totalReviews,
        star5Count: starCounts['5'],
        star4Count: starCounts['4'],
        star3Count: starCounts['3'],
        star2Count: starCounts['2'],
        star1Count: starCounts['1'],
        starCounts,
        ratingDistribution,
      },
      transactionStats: {
        completedOrdersCount,
        buyerCancelledOrdersCount,
        sellerRejectedOrdersCount,
        pendingOrdersCount,
        successfulTransactionCount: effectiveCompletedTransactions,
        successfulTransactionRate,
        activeListingsCount,
        soldListingsCount,
        repliedReviewsCount,
        sellerReplyRate,
      },
      reputationBreakdown: {
        bayesianRatingScore,
        transactionExperienceScore,
        fulfillmentReliabilityScore,
        priorConfidenceWeight: C,
        priorMeanRating: m,
        formulaDescription:
          'ReputationScore (0..100) = BayesianRatingScore (tối đa 70đ, C=5, m=4.0) + CompletedTransactionScore (tối đa 20đ, 2.5đ/giao dịch hoàn tất) + FulfillmentReliabilityScore (tối đa 10đ, chỉ trừ khi người bán từ chối đơn, không phạt khi người mua tự hủy).',
      },
      updatedAt: now.toISOString(),
    };
  }

  private formatReviewResponse(review: ReviewDocument): Record<string, unknown> {
    const rawBuyer = review.buyerId as unknown as Record<string, unknown>;
    const rawSeller = review.sellerId as unknown as Record<string, unknown>;
    const rawProduct = review.productId as unknown as Record<string, unknown>;

    const buyerIdStr = String(rawBuyer?._id ?? rawBuyer?.id ?? review.buyerId);
    const sellerIdStr = String(
      rawSeller?._id ?? rawSeller?.id ?? review.sellerId,
    );
    const productIdStr = String(
      rawProduct?._id ?? rawProduct?.id ?? review.productId,
    );

    const createdAtMs = review.createdAt
      ? new Date(review.createdAt).getTime()
      : Date.now();
    const canBuyerEdit =
      Date.now() - createdAtMs <=
      REVIEW_EDIT_WINDOW_DAYS * 24 * 60 * 60 * 1000;

    return {
      _id: String(review._id),
      id: String(review._id),
      orderId: String(review.orderId),
      productId: productIdStr,
      buyerId: buyerIdStr,
      sellerId: sellerIdStr,
      rating: review.rating,
      comment: review.comment,
      images: review.images ?? [],
      status: review.status,
      sellerReply: review.sellerReply ?? null,
      sellerRepliedAt: review.sellerRepliedAt ?? null,
      canBuyerEdit,
      buyer:
        rawBuyer && typeof rawBuyer === 'object' && 'displayName' in rawBuyer
          ? {
              id: buyerIdStr,
              displayName: rawBuyer.displayName,
              avatarUrl: rawBuyer.avatarUrl ?? null,
              location: rawBuyer.location ?? null,
              isEmailVerified: rawBuyer.isEmailVerified ?? false,
            }
          : null,
      seller:
        rawSeller && typeof rawSeller === 'object' && 'displayName' in rawSeller
          ? {
              id: sellerIdStr,
              displayName: rawSeller.displayName,
              avatarUrl: rawSeller.avatarUrl ?? null,
              location: rawSeller.location ?? null,
              isEmailVerified: rawSeller.isEmailVerified ?? false,
            }
          : null,
      product:
        rawProduct && typeof rawProduct === 'object' && 'title' in rawProduct
          ? {
              id: productIdStr,
              title: rawProduct.title,
              price: rawProduct.price,
              condition: rawProduct.condition,
              status: rawProduct.status,
              images: rawProduct.images ?? [],
              location: rawProduct.location ?? null,
            }
          : null,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    };
  }
}
