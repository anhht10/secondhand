import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ReviewDocument = HydratedDocument<Review>;

export enum ReviewStatus {
  VISIBLE = 'VISIBLE',
  HIDDEN = 'HIDDEN',
  DELETED = 'DELETED',
}

export const MAX_REVIEW_IMAGES = 5;
export const REVIEW_EDIT_WINDOW_DAYS = 7;

@Schema({ _id: false })
export class ReviewReportEntry {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  reporterId!: Types.ObjectId;

  @Prop({ type: String, required: true, trim: true, maxlength: 200 })
  reason!: string;

  @Prop({ type: String, trim: true, maxlength: 1000, default: null })
  description!: string | null;

  @Prop({ type: Date, default: () => new Date() })
  createdAt!: Date;
}

export const ReviewReportEntrySchema =
  SchemaFactory.createForClass(ReviewReportEntry);

@Schema({
  timestamps: true,
  toJSON: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.__v;
      delete ret.reports;
      return ret;
    },
  },
  toObject: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.__v;
      delete ret.reports;
      return ret;
    },
  },
})
export class Review {
  @Prop({
    type: Types.ObjectId,
    ref: 'Order',
    required: true,
    unique: true,
    index: true,
  })
  orderId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'Product',
    required: true,
    index: true,
  })
  productId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  })
  buyerId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  })
  sellerId!: Types.ObjectId;

  @Prop({
    type: Number,
    required: true,
    min: 1,
    max: 5,
    index: true,
  })
  rating!: number;

  @Prop({
    type: String,
    required: true,
    trim: true,
    minlength: 3,
    maxlength: 1500,
  })
  comment!: string;

  @Prop({
    type: [String],
    default: [],
  })
  images!: string[];

  @Prop({
    type: String,
    enum: ReviewStatus,
    default: ReviewStatus.VISIBLE,
    index: true,
  })
  status!: ReviewStatus;

  @Prop({
    type: String,
    trim: true,
    maxlength: 1000,
    default: null,
  })
  sellerReply!: string | null;

  @Prop({
    type: Date,
    default: null,
  })
  sellerRepliedAt!: Date | null;

  @Prop({
    type: [ReviewReportEntrySchema],
    default: [],
  })
  reports!: ReviewReportEntry[];

  @Prop({
    type: Number,
    default: 0,
    min: 0,
  })
  reportCount!: number;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  moderationNote!: string | null;

  createdAt?: Date;
  updatedAt?: Date;
}

export const ReviewSchema = SchemaFactory.createForClass(Review);

// Unique index preventing multiple reviews for the same order
ReviewSchema.index(
  { orderId: 1 },
  { unique: true, name: 'unique_review_per_order_idx' },
);
// Compound index for fast seller review pagination, rating filtering & aggregation
ReviewSchema.index({ sellerId: 1, status: 1, rating: 1, createdAt: -1 });
ReviewSchema.index({ buyerId: 1, createdAt: -1 });
