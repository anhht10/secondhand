import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsMongoId,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ProductCondition, ProductStatus } from '../schemas/product.schema';

export enum ProductSortBy {
  NEWEST = 'newest',
  PRICE_ASC = 'price_asc',
  PRICE_DESC = 'price_desc',
  POPULAR = 'popular',
}

export class QueryProductDto {
  @ApiPropertyOptional({
    example: 1,
    default: 1,
    description: 'Page number (1-indexed)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({
    example: 12,
    default: 12,
    description: 'Items per page (max 100)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 12;

  @ApiPropertyOptional({
    example: 'Sony WH-1000XM4',
    description: 'Keyword search query matching title and description',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  keyword?: string;

  @ApiPropertyOptional({
    example: 'Sony WH-1000XM4',
    description:
      'Alias for keyword: text search query matching title and description',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012345678',
    description: 'Filter by category ID or category slug',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  categoryId?: string;

  @ApiPropertyOptional({
    example: 'electronics',
    description: 'Alias for categoryId (accepts category ObjectId or slug)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @ApiPropertyOptional({
    enum: ProductCondition,
    description: 'Filter by item condition',
  })
  @IsOptional()
  @IsEnum(ProductCondition)
  condition?: ProductCondition;

  @ApiPropertyOptional({
    example: 500000,
    description: 'Minimum price filter',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  minPrice?: number;

  @ApiPropertyOptional({
    example: 5000000,
    description: 'Maximum price filter',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @ApiPropertyOptional({
    example: 'District 10',
    description: 'Case-insensitive partial match on location',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @ApiPropertyOptional({
    enum: ProductSortBy,
    default: ProductSortBy.NEWEST,
    description: 'Sort order: newest, price_asc, or price_desc',
  })
  @IsOptional()
  @IsEnum(ProductSortBy)
  sort?: ProductSortBy;

  @ApiPropertyOptional({
    enum: ProductSortBy,
    description: 'Alias for sort: newest, price_asc, or price_desc',
  })
  @IsOptional()
  @IsEnum(ProductSortBy)
  sortBy?: ProductSortBy;

  @ApiPropertyOptional({
    enum: ProductStatus,
    description:
      'Status filter (used on /products/me/listings; public /products always returns ACTIVE only)',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012345678',
    description: 'Filter public ACTIVE products by seller MongoDB ObjectId',
  })
  @IsOptional()
  @IsMongoId()
  sellerId?: string;
}
