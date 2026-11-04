import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ReportDocument = HydratedDocument<Report>;

export enum ReportStatus {
  PENDING = 'PENDING',
  REVIEWING = 'REVIEWING',
  RESOLVED = 'RESOLVED',
  REJECTED = 'REJECTED',
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
export class Report {
  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
  })
  reporterId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'Product',
    required: true,
    index: true,
  })
  productId!: Types.ObjectId;

  @Prop({
    type: String,
    required: true,
    trim: true,
    minlength: 3,
    maxlength: 150,
  })
  reason!: string;

  @Prop({
    type: String,
    trim: true,
    maxlength: 2000,
    default: null,
  })
  description!: string | null;

  @Prop({
    type: [String],
    default: [],
  })
  evidenceUrls!: string[];

  @Prop({
    type: String,
    enum: ReportStatus,
    default: ReportStatus.PENDING,
    index: true,
  })
  status!: ReportStatus;

  createdAt?: Date;
  updatedAt?: Date;
}

export const ReportSchema = SchemaFactory.createForClass(Report);

// Prevent duplicate report spam by the same reporter on the same product
ReportSchema.index(
  { reporterId: 1, productId: 1 },
  { unique: true, name: 'unique_reporter_product_report_idx' },
);
ReportSchema.index({ reporterId: 1, createdAt: -1 });
