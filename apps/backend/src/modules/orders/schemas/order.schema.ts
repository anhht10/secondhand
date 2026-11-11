import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
import { PaymentMethod, PaymentStatus } from './payment.schema';

export type OrderDocument = HydratedDocument<Order>;

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPING = 'SHIPPING',
  DELIVERED = 'DELIVERED',
  COMPLETED = 'COMPLETED',
  REJECTED = 'REJECTED',
  CANCELLED = 'CANCELLED',
}

export enum DeliveryMethod {
  MEETUP = 'MEETUP',
  DELIVERY = 'DELIVERY',
}

export const ACTIVE_RESERVATION_ORDER_STATUSES: OrderStatus[] = [
  OrderStatus.PENDING,
  OrderStatus.CONFIRMED,
  OrderStatus.SHIPPING,
  OrderStatus.DELIVERED,
];

@Schema({ _id: false })
export class OrderProductSnapshot {
  @Prop({ type: String, required: true, trim: true })
  title!: string;

  @Prop({ type: Number, required: true, min: 0 })
  price!: number;

  @Prop({ type: String, required: true })
  condition!: string;

  @Prop({ type: String, default: null })
  imageUrl!: string | null;

  @Prop({ type: String, default: null })
  location!: string | null;
}

export const OrderProductSnapshotSchema =
  SchemaFactory.createForClass(OrderProductSnapshot);

@Schema({ _id: false })
export class OrderTimelineEntry {
  @Prop({ type: String, required: true })
  status!: string;

  @Prop({ type: Types.ObjectId, ref: 'User', default: null })
  actorId!: Types.ObjectId | null;

  @Prop({
    type: String,
    enum: ['BUYER', 'SELLER', 'SYSTEM'],
    default: 'SYSTEM',
  })
  actorRole!: 'BUYER' | 'SELLER' | 'SYSTEM';

  @Prop({ type: String, trim: true, maxlength: 500, default: null })
  note!: string | null;

  @Prop({ type: Date, default: () => new Date() })
  timestamp!: Date;
}

export const OrderTimelineEntrySchema =
  SchemaFactory.createForClass(OrderTimelineEntry);

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
export class Order {
  @Prop({
    type: String,
    required: true,
    unique: true,
    index: true,
    trim: true,
  })
  orderCode!: string;

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
    type: Types.ObjectId,
    ref: 'Conversation',
    default: null,
  })
  conversationId!: Types.ObjectId | null;

  @Prop({
    type: OrderProductSnapshotSchema,
    required: true,
  })
  productSnapshot!: OrderProductSnapshot;

  @Prop({
    type: Number,
    required: true,
    min: 0,
  })
  itemPrice!: number;

  @Prop({
    type: Number,
    default: 0,
    min: 0,
  })
  shippingFee!: number;

  @Prop({
    type: Number,
    required: true,
    min: 0,
  })
  totalAmount!: number;

  @Prop({
    type: String,
    enum: DeliveryMethod,
    required: true,
  })
  deliveryMethod!: DeliveryMethod;

  @Prop({
    type: String,
    trim: true,
    maxlength: 300,
    default: null,
  })
  shippingAddress!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 100,
    default: null,
  })
  recipientName!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 30,
    default: null,
  })
  recipientPhone!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 300,
    default: null,
  })
  meetupLocation!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  buyerNote!: string | null;

  @Prop({
    type: String,
    enum: PaymentMethod,
    required: true,
  })
  paymentMethod!: PaymentMethod;

  @Prop({
    type: String,
    enum: PaymentStatus,
    default: PaymentStatus.UNPAID,
    index: true,
  })
  paymentStatus!: PaymentStatus;

  @Prop({
    type: String,
    enum: OrderStatus,
    default: OrderStatus.PENDING,
    index: true,
  })
  status!: OrderStatus;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  cancelReason!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  rejectReason!: string | null;

  @Prop({
    type: [OrderTimelineEntrySchema],
    default: [],
  })
  timeline!: OrderTimelineEntry[];

  @Prop({ type: Date, default: null })
  confirmedAt!: Date | null;

  @Prop({ type: Date, default: null })
  shippedAt!: Date | null;

  @Prop({ type: Date, default: null })
  deliveredAt!: Date | null;

  @Prop({ type: Date, default: null })
  completedAt!: Date | null;

  @Prop({ type: Date, default: null })
  cancelledAt!: Date | null;

  @Prop({ type: Date, default: null })
  rejectedAt!: Date | null;

  @Prop({
    type: Types.ObjectId,
    ref: 'Review',
    default: null,
  })
  reviewId!: Types.ObjectId | null;

  createdAt?: Date;
  updatedAt?: Date;
}

export const OrderSchema = SchemaFactory.createForClass(Order);

OrderSchema.index({ buyerId: 1, createdAt: -1 });
OrderSchema.index({ sellerId: 1, createdAt: -1 });
OrderSchema.index({ productId: 1, status: 1 });
// Partial unique index guaranteeing at the DB level that at most ONE active order can exist per productId
OrderSchema.index(
  { productId: 1 },
  {
    unique: true,
    partialFilterExpression: {
      status: {
        $in: ['PENDING', 'CONFIRMED', 'SHIPPING', 'DELIVERED'],
      },
    },
    name: 'unique_active_order_per_product_idx',
  },
);
