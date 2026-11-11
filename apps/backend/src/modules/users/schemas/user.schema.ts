import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type UserDocument = HydratedDocument<User>;

export enum UserStatus {
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  DELETED = 'DELETED',
}

@Schema({ _id: false })
export class SellerBankInfo {
  @Prop({ type: String, required: true, trim: true, maxlength: 120 })
  bankName!: string;

  @Prop({ type: String, required: true, trim: true, maxlength: 40 })
  accountNumber!: string;

  @Prop({ type: String, required: true, trim: true, maxlength: 120 })
  accountHolder!: string;

  @Prop({ type: String, trim: true, maxlength: 120, default: null })
  branch?: string | null;
}

export const SellerBankInfoSchema =
  SchemaFactory.createForClass(SellerBankInfo);

@Schema({ _id: false })
export class SellerReputationCache {
  @Prop({ type: Number, default: 0, min: 0, max: 5 })
  averageRating!: number;

  @Prop({ type: Number, default: 0, min: 0 })
  totalReviews!: number;

  @Prop({ type: Number, default: 66, min: 0, max: 100 })
  reputationScore!: number;

  @Prop({ type: Number, default: 0, min: 0 })
  completedOrdersCount!: number;

  @Prop({ type: Date, default: () => new Date() })
  updatedAt!: Date;
}

export const SellerReputationCacheSchema =
  SchemaFactory.createForClass(SellerReputationCache);

@Schema({
  timestamps: true,
  toJSON: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.passwordHash;
      delete ret.__v;
      return ret;
    },
  },
  toObject: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.passwordHash;
      delete ret.__v;
      return ret;
    },
  },
})
export class User {
  @Prop({
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  })
  email!: string;

  @Prop({
    required: true,
    select: false,
  })
  passwordHash!: string;

  @Prop({
    required: true,
    trim: true,
    minlength: 2,
    maxlength: 80,
  })
  displayName!: string;

  @Prop({
    type: String,
    default: null,
  })
  avatarUrl!: string | null;

  @Prop({
    type: String,
    trim: true,
    default: null,
  })
  phoneNumber!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  bio!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 120,
    default: null,
  })
  location!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 150,
    default: null,
  })
  university!: string | null;

  @Prop({
    type: Boolean,
    default: false,
  })
  isEmailVerified!: boolean;

  @Prop({
    type: String,
    enum: UserStatus,
    default: UserStatus.ACTIVE,
    index: true,
  })
  status!: UserStatus;

  @Prop({
    type: [{ type: Types.ObjectId, ref: 'Product' }],
    default: [],
  })
  wishlist!: Types.ObjectId[];

  @Prop({
    type: SellerBankInfoSchema,
    default: null,
  })
  bankInfo!: SellerBankInfo | null;

  @Prop({
    type: SellerReputationCacheSchema,
    default: () => ({
      averageRating: 0,
      totalReviews: 0,
      reputationScore: 66,
      completedOrdersCount: 0,
      updatedAt: new Date(),
    }),
  })
  reputationCache!: SellerReputationCache;

  createdAt?: Date;
  updatedAt?: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);
