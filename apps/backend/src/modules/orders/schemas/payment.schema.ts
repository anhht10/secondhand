import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type PaymentDocument = HydratedDocument<Payment>;

export enum PaymentMethod {
  CASH = 'CASH',
  COD = 'COD',
  BANK_TRANSFER = 'BANK_TRANSFER',
}

export enum PaymentStatus {
  UNPAID = 'UNPAID',
  BUYER_CONFIRMED = 'BUYER_CONFIRMED',
  PAID = 'PAID',
  CANCELLED = 'CANCELLED',
}

@Schema({
  timestamps: true,
  toJSON: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      ret.paymentId = String(ret._id);
      delete ret.__v;
      return ret;
    },
  },
  toObject: {
    virtuals: true,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      ret.paymentId = String(ret._id);
      delete ret.__v;
      return ret;
    },
  },
})
export class Payment {
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
    ref: 'User',
    required: true,
    index: true,
  })
  payerId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  })
  receiverId!: Types.ObjectId;

  @Prop({
    type: String,
    enum: PaymentMethod,
    required: true,
  })
  method!: PaymentMethod;

  @Prop({
    type: Number,
    required: true,
    min: 0,
  })
  amount!: number;

  @Prop({
    type: String,
    enum: PaymentStatus,
    default: PaymentStatus.UNPAID,
    index: true,
  })
  status!: PaymentStatus;

  @Prop({
    type: String,
    trim: true,
    maxlength: 160,
    default: null,
  })
  transactionReference!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 500,
    default: null,
  })
  transferNote!: string | null;

  @Prop({
    type: Date,
    default: null,
  })
  buyerConfirmationAt!: Date | null;

  @Prop({
    type: Date,
    default: null,
  })
  sellerConfirmationAt!: Date | null;

  @Prop({
    type: Date,
    default: null,
  })
  paidAt!: Date | null;

  createdAt?: Date;
  updatedAt?: Date;
}

export const PaymentSchema = SchemaFactory.createForClass(Payment);
