import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type CategoryDocument = HydratedDocument<Category>;

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
export class Category {
  @Prop({
    required: true,
    trim: true,
    maxlength: 100,
  })
  name!: string;

  @Prop({
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  })
  slug!: string;

  @Prop({
    type: String,
    trim: true,
    maxlength: 300,
    default: null,
  })
  description!: string | null;

  @Prop({
    type: String,
    trim: true,
    default: null,
  })
  icon!: string | null;

  @Prop({
    type: Types.ObjectId,
    ref: 'Category',
    default: null,
    index: true,
  })
  parentId!: Types.ObjectId | null;

  @Prop({
    type: Boolean,
    default: true,
  })
  isActive!: boolean;

  @Prop({
    type: Number,
    default: 0,
  })
  sortOrder!: number;

  createdAt?: Date;
  updatedAt?: Date;
}

export const CategorySchema = SchemaFactory.createForClass(Category);

CategorySchema.index({ isActive: 1, sortOrder: 1, name: 1 });
