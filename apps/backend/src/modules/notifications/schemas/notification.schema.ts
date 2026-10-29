import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type NotificationDocument = HydratedDocument<Notification>;

export enum NotificationType {
  ORDER_CREATED = 'ORDER_CREATED',
  ORDER_CONFIRMED = 'ORDER_CONFIRMED',
  ORDER_REJECTED = 'ORDER_REJECTED',
  ORDER_CANCELLED = 'ORDER_CANCELLED',
  ORDER_SHIPPING = 'ORDER_SHIPPING',
  ORDER_DELIVERED = 'ORDER_DELIVERED',
  ORDER_COMPLETED = 'ORDER_COMPLETED',
  PAYMENT_BUYER_CONFIRMED = 'PAYMENT_BUYER_CONFIRMED',
  PAYMENT_SELLER_CONFIRMED = 'PAYMENT_SELLER_CONFIRMED',
  REVIEW_RECEIVED = 'REVIEW_RECEIVED',
  REVIEW_REPLIED = 'REVIEW_REPLIED',
}

@Schema({
  timestamps: true,
  toJSON: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.__v;
      return ret;
    },
  },
  toObject: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      delete ret.__v;
      return ret;
    },
  },
})
export class Notification {
  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  })
  recipientId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    default: null,
  })
  actorId!: Types.ObjectId | null;

  @Prop({
    type: String,
    enum: NotificationType,
    required: true,
    index: true,
  })
  type!: NotificationType;

  @Prop({
    type: String,
    required: true,
    trim: true,
    maxlength: 200,
  })
  title!: string;

  @Prop({
    type: String,
    required: true,
    trim: true,
    maxlength: 1000,
  })
  body!: string;

  @Prop({
    type: Types.ObjectId,
    ref: 'Order',
    default: null,
    index: true,
  })
  orderId!: Types.ObjectId | null;

  @Prop({
    type: Types.ObjectId,
    ref: 'Product',
    default: null,
  })
  productId!: Types.ObjectId | null;

  @Prop({
    type: Boolean,
    default: false,
    index: true,
  })
  isRead!: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);
NotificationSchema.index({ recipientId: 1, createdAt: -1 });
NotificationSchema.index({ recipientId: 1, isRead: 1 });
