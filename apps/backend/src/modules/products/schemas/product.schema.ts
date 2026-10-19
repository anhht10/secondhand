import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ProductDocument = HydratedDocument<Product>;

export enum ProductCondition {
  NEW = 'NEW',
  LIKE_NEW = 'LIKE_NEW',
  GOOD = 'GOOD',
  FAIR = 'FAIR',
}

export enum ProductStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  RESERVED = 'RESERVED',
  SOLD = 'SOLD',
  ARCHIVED = 'ARCHIVED',
}

@Schema({ _id: false })
export class AiChecklistCache {
  @Prop({ type: [String], default: [] })
  inspectionPoints!: string[];

  @Prop({ type: [String], default: [] })
  suggestedQuestions!: string[];

  @Prop({ type: String, default: null })
  safetyTip!: string | null;

  @Prop({ type: Date, default: () => new Date() })
  generatedAt!: Date;
}

export const AiChecklistCacheSchema =
  SchemaFactory.createForClass(AiChecklistCache);

@Schema({ _id: false })
export class ProductImage {
  @Prop({ required: true, trim: true })
  url!: string;

  @Prop({ type: String, default: null })
  publicId!: string | null;

  @Prop({ type: Number, default: 0 })
  sortOrder!: number;

  @Prop({ type: String, default: null })
  altText!: string | null;
}

export const ProductImageSchema = SchemaFactory.createForClass(ProductImage);

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
export class Product {
  @Prop({
    type: Types.ObjectId,
    ref: 'User',
    required: true,
  })
  sellerId!: Types.ObjectId;

  @Prop({
    type: Types.ObjectId,
    ref: 'Category',
    required: true,
    index: true,
  })
  categoryId!: Types.ObjectId;

  @Prop({
    required: true,
    trim: true,
    minlength: 3,
    maxlength: 140,
  })
  title!: string;

  @Prop({
    required: true,
    trim: true,
    minlength: 10,
    maxlength: 4000,
  })
  description!: string;

  @Prop({
    required: true,
    type: Number,
    min: 0,
    index: true,
  })
  price!: number;

  @Prop({
    required: true,
    type: String,
    enum: ProductCondition,
    index: true,
  })
  condition!: ProductCondition;

  @Prop({
    type: [ProductImageSchema],
    default: [],
  })
  images!: ProductImage[];

  @Prop({
    required: true,
    trim: true,
    maxlength: 120,
    index: true,
  })
  location!: string;

  @Prop({
    type: String,
    enum: ProductStatus,
    default: ProductStatus.ACTIVE,
  })
  status!: ProductStatus;

  @Prop({
    type: String,
    trim: true,
    maxlength: 100,
    default: null,
  })
  brand!: string | null;

  @Prop({
    type: Number,
    min: 0,
    default: null,
  })
  originalPrice!: number | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 1000,
    default: null,
  })
  defectDisclosure!: string | null;

  @Prop({
    type: String,
    trim: true,
    maxlength: 1000,
    default: null,
  })
  transparencyNote!: string | null;

  @Prop({
    type: Number,
    min: 0,
    max: 100,
    default: null,
  })
  transparencyScore!: number | null;

  @Prop({
    type: [String],
    default: [],
  })
  tags!: string[];

  @Prop({
    type: AiChecklistCacheSchema,
    default: null,
  })
  aiChecklistCache!: AiChecklistCache | null;

  @Prop({
    type: Number,
    default: 0,
    min: 0,
  })
  viewCount!: number;

  createdAt?: Date;
  updatedAt?: Date;
}

export const ProductSchema = SchemaFactory.createForClass(Product);

ProductSchema.index({ createdAt: -1 });
ProductSchema.index({ sellerId: 1, status: 1, createdAt: -1 });
ProductSchema.index({ status: 1, categoryId: 1, price: 1, createdAt: -1 });
ProductSchema.index(
  { title: 'text', description: 'text' },
  { weights: { title: 10, description: 5 }, name: 'product_text_search_idx' },
);
