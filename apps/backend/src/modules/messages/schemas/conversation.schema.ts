import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ConversationDocument = HydratedDocument<Conversation>;

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
export class Conversation {
  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
  })
  buyerId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
  })
  sellerId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'Product',
    required: true,
    index: true,
  })
  productId!: Types.ObjectId;

  @Prop({
    type: String,
    trim: true,
    maxlength: 2000,
    default: null,
  })
  lastMessage!: string | null;

  @Prop({
    type: Date,
    default: null,
    index: true,
  })
  lastMessageAt!: Date | null;

  @Prop({
    type: Types.ObjectId,
    ref: 'Order',
    default: null,
  })
  activeOrderId?: Types.ObjectId | null;

  createdAt?: Date;
  updatedAt?: Date;
}

export const ConversationSchema = SchemaFactory.createForClass(Conversation);

// Ensure one unique conversation per (buyerId, sellerId, productId)
ConversationSchema.index(
  { buyerId: 1, sellerId: 1, productId: 1 },
  { unique: true, name: 'unique_buyer_seller_product_conversation_idx' },
);
ConversationSchema.index({ buyerId: 1, lastMessageAt: -1, updatedAt: -1 });
ConversationSchema.index({ sellerId: 1, lastMessageAt: -1, updatedAt: -1 });
