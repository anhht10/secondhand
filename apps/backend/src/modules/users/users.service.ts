import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  Product,
  ProductDocument,
  ProductStatus,
} from '../products/schemas/product.schema';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  SellerBankInfo,
  User,
  UserDocument,
  UserStatus,
} from './schemas/user.schema';

export interface CreateUserInput {
  email: string;
  passwordHash: string;
  displayName: string;
  phoneNumber?: string | null;
  location?: string | null;
  university?: string | null;
  bio?: string | null;
  avatarUrl?: string | null;
  isEmailVerified?: boolean;
  bankInfo?: SellerBankInfo | null;
}

export interface UserStatsSummary {
  activeListingsCount: number;
  soldListingsCount: number;
  completedOrdersCount: number;
  rating: number;
  totalReviews: number;
  reputationScore: number;
  transparencyRate: number;
}

export interface PublicSellerProfile {
  _id: string;
  id: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  location: string | null;
  university: string | null;
  isEmailVerified: boolean;
  status: UserStatus;
  stats: UserStatsSummary;
  createdAt?: Date;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
  ) {}

  async create(input: CreateUserInput): Promise<UserDocument> {
    const normalizedEmail = input.email.trim().toLowerCase();
    const existing = await this.userModel
      .findOne({ email: normalizedEmail })
      .lean()
      .exec();

    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const created = new this.userModel({
      email: normalizedEmail,
      passwordHash: input.passwordHash,
      displayName: input.displayName.trim(),
      phoneNumber: input.phoneNumber ?? null,
      location: input.location ?? null,
      university: input.university ?? null,
      bio: input.bio ?? null,
      avatarUrl: input.avatarUrl ?? null,
      isEmailVerified: input.isEmailVerified ?? false,
      status: UserStatus.ACTIVE,
      wishlist: [],
      bankInfo: input.bankInfo ?? null,
    });

    return created.save();
  }

  async findByEmailWithPassword(email: string): Promise<UserDocument | null> {
    return this.userModel
      .findOne({ email: email.trim().toLowerCase() })
      .select('+passwordHash')
      .exec();
  }

  async findById(id: string): Promise<UserDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('User not found');
    }

    const user = await this.userModel.findById(id).exec();
    if (!user || user.status === UserStatus.DELETED) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async computeUserStats(
    userId: string,
    existingUser?: UserDocument | null,
  ): Promise<UserStatsSummary> {
    if (!Types.ObjectId.isValid(userId)) {
      return {
        activeListingsCount: 0,
        soldListingsCount: 0,
        completedOrdersCount: 0,
        rating: 0,
        totalReviews: 0,
        reputationScore: 66,
        transparencyRate: 100,
      };
    }

    const sellerObjectId = new Types.ObjectId(userId);
    const [activeListingsCount, soldListingsCount, fetchedUser] =
      await Promise.all([
        this.productModel
          .countDocuments({
            sellerId: sellerObjectId,
            status: { $in: [ProductStatus.ACTIVE, ProductStatus.RESERVED] },
          })
          .exec(),
        this.productModel
          .countDocuments({
            sellerId: sellerObjectId,
            status: ProductStatus.SOLD,
          })
          .exec(),
        existingUser
          ? Promise.resolve(existingUser)
          : this.userModel.findById(sellerObjectId).exec(),
      ]);

    const rep = (fetchedUser as UserDocument | null)?.reputationCache;
    const completedOrdersCount = Math.max(
      soldListingsCount,
      rep?.completedOrdersCount ?? 0,
    );

    return {
      activeListingsCount,
      soldListingsCount,
      completedOrdersCount,
      rating: rep?.averageRating ?? 0,
      totalReviews: rep?.totalReviews ?? 0,
      reputationScore: rep?.reputationScore ?? 66,
      transparencyRate: 100,
    };
  }

  async findPublicProfileById(id: string): Promise<PublicSellerProfile> {
    const user = await this.findById(id);
    const stats = await this.computeUserStats(id, user);

    return {
      _id: String(user._id),
      id: String(user._id),
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      location: user.location,
      university: user.university ?? null,
      isEmailVerified: user.isEmailVerified,
      status: user.status,
      stats,
      createdAt: user.createdAt,
    };
  }

  async updateProfile(
    userId: string,
    updateDto: UpdateUserDto,
  ): Promise<UserDocument> {
    const allowedUpdates: Partial<User> = {};

    if (updateDto.displayName !== undefined) {
      allowedUpdates.displayName = updateDto.displayName.trim();
    }
    if (updateDto.avatarUrl !== undefined) {
      allowedUpdates.avatarUrl = updateDto.avatarUrl;
    }
    if (updateDto.phoneNumber !== undefined) {
      allowedUpdates.phoneNumber = updateDto.phoneNumber.trim();
    }
    if (updateDto.bio !== undefined) {
      allowedUpdates.bio = updateDto.bio.trim();
    }
    if (updateDto.location !== undefined) {
      allowedUpdates.location = updateDto.location.trim();
    }
    if (updateDto.university !== undefined) {
      allowedUpdates.university = updateDto.university.trim();
    }
    if (updateDto.bankInfo !== undefined) {
      allowedUpdates.bankInfo = updateDto.bankInfo
        ? {
            bankName: updateDto.bankInfo.bankName.trim(),
            accountNumber: updateDto.bankInfo.accountNumber.trim(),
            accountHolder: updateDto.bankInfo.accountHolder.trim().toUpperCase(),
            branch: updateDto.bankInfo.branch?.trim() ?? null,
          }
        : null;
    }

    const updated = await this.userModel
      .findByIdAndUpdate(
        userId,
        { $set: allowedUpdates },
        { new: true, runValidators: true },
      )
      .exec();

    if (!updated || updated.status === UserStatus.DELETED) {
      throw new NotFoundException('User not found');
    }

    return updated;
  }

  async addToWishlist(
    userId: string,
    productId: string,
  ): Promise<ProductDocument[]> {
    if (!Types.ObjectId.isValid(productId)) {
      throw new NotFoundException('Product not found');
    }

    const product = await this.productModel
      .findOne({
        _id: new Types.ObjectId(productId),
        status: ProductStatus.ACTIVE,
      })
      .lean()
      .exec();

    if (!product) {
      throw new NotFoundException(
        'Product not found or is not active for wishlisting',
      );
    }

    const updatedUser = await this.userModel
      .findByIdAndUpdate(
        userId,
        { $addToSet: { wishlist: new Types.ObjectId(productId) } },
        { new: true },
      )
      .exec();

    if (!updatedUser || updatedUser.status === UserStatus.DELETED) {
      throw new NotFoundException('User not found');
    }

    return this.getWishlist(userId);
  }

  async removeFromWishlist(
    userId: string,
    productId: string,
  ): Promise<ProductDocument[]> {
    if (!Types.ObjectId.isValid(productId)) {
      throw new NotFoundException('Product not found');
    }

    const updatedUser = await this.userModel
      .findByIdAndUpdate(
        userId,
        { $pull: { wishlist: new Types.ObjectId(productId) } },
        { new: true },
      )
      .exec();

    if (!updatedUser || updatedUser.status === UserStatus.DELETED) {
      throw new NotFoundException('User not found');
    }

    return this.getWishlist(userId);
  }

  async getWishlist(userId: string): Promise<ProductDocument[]> {
    const user = await this.findById(userId);
    const wishlistIds = (user.wishlist ?? []).filter((id) =>
      Types.ObjectId.isValid(id),
    );

    if (wishlistIds.length === 0) {
      return [];
    }

    return this.productModel
      .find({
        _id: { $in: wishlistIds },
        status: ProductStatus.ACTIVE,
      })
      .populate(
        'sellerId',
        'displayName avatarUrl location isEmailVerified status',
      )
      .populate('categoryId', 'name slug icon')
      .exec();
  }

  sanitizeUser(
    user: UserDocument,
    stats?: UserStatsSummary,
  ): Record<string, unknown> {
    const obj = user.toJSON() as Record<string, unknown>;
    delete obj.passwordHash;
    if (stats) {
      obj.stats = stats;
    }
    return obj;
  }

  async getMeWithStats(userId: string): Promise<Record<string, unknown>> {
    const user = await this.findById(userId);
    const stats = await this.computeUserStats(userId, user);
    return this.sanitizeUser(user, stats);
  }
}
