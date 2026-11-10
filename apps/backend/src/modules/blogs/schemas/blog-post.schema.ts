import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type BlogPostDocument = HydratedDocument<BlogPost>;

export enum BlogCategory {
  EXPERIENCE = 'EXPERIENCE',
  REVIEW = 'REVIEW',
  STUDY_CORNER = 'STUDY_CORNER',
  WANT_TO_BUY = 'WANT_TO_BUY',
  SCAM_ALERT = 'SCAM_ALERT',
  GENERAL = 'GENERAL',
}

export enum BlogPostStatus {
  PUBLISHED = 'PUBLISHED',
  HIDDEN = 'HIDDEN',
}

@Schema({
  timestamps: true,
  toJSON: {
    virtuals: true,
    versionKey: false,
    transform: (_doc: unknown, ret: Record<string, unknown>) => {
      ret.id = String(ret._id);
      return ret;
    },
  },
})
export class BlogPost {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  authorId: Types.ObjectId;

  @Prop({
    required: true,
    trim: true,
    minlength: 5,
    maxlength: 200,
    index: 'text',
  })
  title: string;

  @Prop({
    required: true,
    trim: true,
    minlength: 10,
    maxlength: 10000,
  })
  content: string;

  @Prop({
    type: String,
    enum: BlogCategory,
    default: BlogCategory.EXPERIENCE,
    index: true,
  })
  category: BlogCategory;

  @Prop({ type: [String], default: [] })
  tags: string[];

  @Prop({ type: [String], default: [] })
  images: string[];

  @Prop({ type: Types.ObjectId, ref: 'Product', default: null })
  attachedProductId?: Types.ObjectId | null;

  @Prop({ type: [{ type: Types.ObjectId, ref: 'User' }], default: [] })
  likedBy: Types.ObjectId[];

  @Prop({ type: Number, default: 0, min: 0 })
  likesCount: number;

  @Prop({ type: Number, default: 0, min: 0 })
  commentsCount: number;

  @Prop({ type: Number, default: 0, min: 0 })
  viewsCount: number;

  @Prop({
    type: String,
    enum: BlogPostStatus,
    default: BlogPostStatus.PUBLISHED,
    index: true,
  })
  status: BlogPostStatus;

  createdAt?: Date;
  updatedAt?: Date;
}

export const BlogPostSchema = SchemaFactory.createForClass(BlogPost);

BlogPostSchema.index({ status: 1, category: 1, createdAt: -1 });
BlogPostSchema.index({ authorId: 1, createdAt: -1 });
