import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type BlogCommentDocument = HydratedDocument<BlogComment>;

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
export class BlogComment {
  @Prop({ type: Types.ObjectId, ref: 'BlogPost', required: true, index: true })
  postId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  authorId: Types.ObjectId;

  @Prop({
    default: '',
    trim: true,
    maxlength: 1500,
  })
  content: string;

  @Prop({ type: [String], default: [] })
  images: string[];

  createdAt?: Date;
  updatedAt?: Date;
}

export const BlogCommentSchema = SchemaFactory.createForClass(BlogComment);

BlogCommentSchema.index({ postId: 1, createdAt: 1 });
