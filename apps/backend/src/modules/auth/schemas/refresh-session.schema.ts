import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type RefreshSessionDocument = HydratedDocument<RefreshSession>;

@Schema({ timestamps: true })
export class RefreshSession {
  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
  })
  userId!: Types.ObjectId;

  @Prop({
    required: true,
    unique: true,
  })
  jti!: string;

  @Prop({
    required: true,
    select: false,
  })
  tokenHash!: string;

  @Prop({
    type: Date,
    required: true,
    index: { expires: 0 },
  })
  expiresAt!: Date;

  @Prop({
    type: Boolean,
    default: false,
  })
  isRevoked!: boolean;

  @Prop({
    type: Date,
    default: null,
  })
  revokedAt!: Date | null;

  createdAt?: Date;
  updatedAt?: Date;
}

export const RefreshSessionSchema =
  SchemaFactory.createForClass(RefreshSession);

RefreshSessionSchema.index({ userId: 1, isRevoked: 1 });
