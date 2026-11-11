import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsMongoId,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { MAX_REVIEW_IMAGES, ReviewStatus } from '../schemas/review.schema';

export class CreateReviewDto {
  @ApiProperty({
    description: 'Completed Order ID to review',
    example: '672b3a9f8e1b2c0012345678',
  })
  @IsMongoId()
  orderId!: string;

  @ApiProperty({
    description: 'Integer star rating from 1 to 5',
    minimum: 1,
    maximum: 5,
    example: 5,
  })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @ApiProperty({
    description: 'Buyer written review of transaction and item condition',
    minLength: 3,
    maxLength: 1500,
    example: 'Người bán rất nhiệt tình, tai nghe đúng mô tả, pin trâu.',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(1500)
  comment!: string;

  @ApiPropertyOptional({
    description: 'Up to 5 uploaded image URLs from actual received item',
    type: [String],
    maxItems: MAX_REVIEW_IMAGES,
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_REVIEW_IMAGES)
  @IsString({ each: true })
  images?: string[];
}

export class UpdateReviewDto {
  @ApiPropertyOptional({
    description: 'Updated integer star rating from 1 to 5',
    minimum: 1,
    maximum: 5,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;

  @ApiPropertyOptional({
    description: 'Updated review comment (within 7 days of creation)',
    minLength: 3,
    maxLength: 1500,
  })
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(1500)
  comment?: string;

  @ApiPropertyOptional({
    description: 'Updated review image URLs (max 5)',
    type: [String],
    maxItems: MAX_REVIEW_IMAGES,
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_REVIEW_IMAGES)
  @IsString({ each: true })
  images?: string[];
}

export class SellerReplyReviewDto {
  @ApiProperty({
    description: 'Seller response to the buyer review',
    minLength: 2,
    maxLength: 1000,
    example: 'Cảm ơn bạn đã tin tưởng ủng hộ shop nhé!',
  })
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  reply!: string;
}

export class ReportReviewDto {
  @ApiProperty({
    description: 'Reason for reporting the review',
    minLength: 3,
    maxLength: 200,
    example: 'Chứa thông tin cá nhân nhạy cảm / ngôn từ không phù hợp',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  reason!: string;

  @ApiPropertyOptional({
    description: 'Additional context for moderators',
    maxLength: 1000,
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}

export class ModerateReviewDto {
  @ApiProperty({
    description: 'Moderation status (VISIBLE, HIDDEN, DELETED)',
    enum: ReviewStatus,
  })
  @IsEnum(ReviewStatus)
  status!: ReviewStatus;

  @ApiPropertyOptional({
    description: 'Reason for moderation action',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  moderationNote?: string;
}

export enum ReviewSortBy {
  NEWEST = 'newest',
  OLDEST = 'oldest',
  HIGHEST = 'highest',
  LOWEST = 'lowest',
}

export class QueryReviewsDto {
  @ApiPropertyOptional({
    description: 'Filter by exact star rating (1..5)',
    minimum: 1,
    maximum: 5,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;

  @ApiPropertyOptional({
    description: 'Sort order (newest, oldest, highest, lowest)',
    enum: ReviewSortBy,
    default: ReviewSortBy.NEWEST,
  })
  @IsOptional()
  @IsEnum(ReviewSortBy)
  sort?: ReviewSortBy;

  @ApiPropertyOptional({
    description: 'Page number (1-indexed)',
    default: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({
    description: 'Items per page (1..50)',
    default: 10,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 10;
}
