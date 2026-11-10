import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { BlogCategory } from '../schemas/blog-post.schema';

export class CreateBlogPostDto {
  @ApiProperty({ example: 'Kinh nghiệm kiểm tra MacBook Pro M1 cũ cho sinh viên IT' })
  @IsString()
  @IsNotEmpty()
  @MinLength(5)
  @MaxLength(200)
  title: string;

  @ApiProperty({ example: 'Mình vừa mua một chiếc MacBook cũ trên ReMarket và muốn chia sẻ...' })
  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  @MaxLength(10000)
  content: string;

  @ApiPropertyOptional({ enum: BlogCategory, default: BlogCategory.EXPERIENCE })
  @IsOptional()
  @IsEnum(BlogCategory)
  category?: BlogCategory;

  @ApiPropertyOptional({ type: [String], example: ['macbook', 'kinh-nghiem', 'sinh-vien'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  tags?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  images?: string[];

  @ApiPropertyOptional({ description: 'Optional ReMarket product ID attached to this post' })
  @IsOptional()
  @IsString()
  attachedProductId?: string | null;
}

export class UpdateBlogPostDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(10)
  @MaxLength(10000)
  content?: string;

  @ApiPropertyOptional({ enum: BlogCategory })
  @IsOptional()
  @IsEnum(BlogCategory)
  category?: BlogCategory;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  tags?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  images?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  attachedProductId?: string | null;
}

export class QueryBlogPostsDto {
  @ApiPropertyOptional({ enum: BlogCategory })
  @IsOptional()
  @IsEnum(BlogCategory)
  category?: BlogCategory;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  keyword?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  tag?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  authorId?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}

export class CreateBlogCommentDto {
  @ApiPropertyOptional({ example: 'Cảm ơn bài chia sẻ rất hữu ích của bạn!' })
  @IsOptional()
  @IsString()
  @MaxLength(1500)
  content?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @IsString({ each: true })
  images?: string[];
}

export class GenerateAiBlogDraftDto {
  @ApiProperty({ example: 'Kinh nghiệm test màn hình và bàn phím cơ cũ trước khi xuống tiền' })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(300)
  topic: string;

  @ApiPropertyOptional({ enum: BlogCategory, default: BlogCategory.EXPERIENCE })
  @IsOptional()
  @IsEnum(BlogCategory)
  category?: BlogCategory;

  @ApiPropertyOptional({ example: 'Kiểm tra hở sáng, điểm chết, test switch bàn phím' })
  @IsOptional()
  @IsString()
  @MaxLength(600)
  keyPoints?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  attachedProductTitle?: string;

  @ApiPropertyOptional()
  @IsOptional()
  attachedProductPrice?: number;
}
