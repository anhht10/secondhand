import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { plainToInstance, Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsMongoId,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ProductCondition, ProductStatus } from '../schemas/product.schema';

export class AiChecklistCacheInputDto {
  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  inspectionPoints?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  suggestedQuestions?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  safetyTip?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  generatedAt?: Date;
}

export class ProductImageInputDto {
  @ApiProperty({
    example: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
    description: 'Image URL or local /uploads/... path',
  })
  @IsString()
  @Matches(/^(https?:\/\/|\/uploads\/)/, {
    message: 'url must be a valid HTTP(S) URL or /uploads/... path',
  })
  @MaxLength(1000)
  url!: string;

  @ApiPropertyOptional({
    example: 'products/sony-xm4-main',
    description: 'Cloud storage provider public identifier',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  publicId?: string;

  @ApiPropertyOptional({
    example: 0,
    description: 'Display sort order (0 = primary thumbnail)',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiPropertyOptional({
    example: 'Sony WH-1000XM4 Wireless Headphones front view',
    description: 'Accessible image alt text',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  altText?: string;
}

export class CreateProductDto {
  @ApiProperty({
    example: '672b3a9f8e1b2c0012345678',
    description: 'Category MongoDB ObjectId',
  })
  @IsMongoId({ message: 'categoryId must be a valid MongoDB ObjectId' })
  categoryId!: string;

  @ApiProperty({
    example: 'Sony WH-1000XM4 Wireless Noise Cancelling Headphones',
    description: 'Listing title',
    minLength: 3,
    maxLength: 140,
  })
  @IsString()
  @MinLength(3)
  @MaxLength(140)
  title!: string;

  @ApiProperty({
    example:
      'Purchased 8 months ago, lightly used in office. Includes original carrying case, USB-C cable, and airplane adapter. Battery health is excellent.',
    description: 'Detailed product condition and package description',
    minLength: 10,
    maxLength: 4000,
  })
  @IsString()
  @MinLength(10)
  @MaxLength(4000)
  description!: string;

  @ApiProperty({
    example: 4200000,
    description: 'Listing price (must be >= 0)',
    minimum: 0,
  })
  @Type(() => Number)
  @IsNumber({}, { message: 'price must be a valid number' })
  @Min(0, { message: 'price cannot be negative' })
  price!: number;

  @ApiProperty({
    enum: ProductCondition,
    example: ProductCondition.LIKE_NEW,
    description: 'Physical condition of the item',
  })
  @IsEnum(ProductCondition, {
    message: `condition must be one of: ${Object.values(ProductCondition).join(', ')}`,
  })
  condition!: ProductCondition;

  @ApiPropertyOptional({
    type: [ProductImageInputDto],
    description:
      'Array of product image objects (or string URLs which are automatically normalized)',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (!Array.isArray(value)) return value;
    return value.map((item, index) => {
      if (typeof item === 'string') {
        return plainToInstance(ProductImageInputDto, {
          url: item,
          sortOrder: index,
        });
      }
      if (typeof item === 'object' && item !== null) {
        return plainToInstance(ProductImageInputDto, item);
      }
      return item;
    });
  })
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  images?: ProductImageInputDto[];

  @ApiProperty({
    example: 'District 10, Ho Chi Minh City',
    description: 'Pickup or seller location',
  })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  location!: string;

  @ApiPropertyOptional({
    enum: ProductStatus,
    default: ProductStatus.ACTIVE,
    description: 'Initial listing status (defaults to ACTIVE)',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({
    example: 'Keychron',
    description: 'Product brand or manufacturer',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  brand?: string | null;

  @ApiPropertyOptional({
    example: 2450000,
    description: 'Original retail price for savings comparison',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  originalPrice?: number | null;

  @ApiPropertyOptional({
    example:
      'Xước nhẹ 1mm ở cạnh phải khung nhôm, các phím hoạt động hoàn hảo 100%.',
    description: 'Mandatory defect and wear disclosure note',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defectDisclosure?: string | null;

  @ApiPropertyOptional({
    example: 'Đã vệ sinh switch và keycap, cam kết chưa qua sửa chữa mạch.',
    description: 'AI-assisted or seller transparency note',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  transparencyNote?: string | null;

  @ApiPropertyOptional({
    example: 96,
    description: 'Transparency score (0-100)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  transparencyScore?: number | null;

  @ApiPropertyOptional({
    example: ['#banphimco', '#keychron', '#hotswap'],
    type: [String],
    description: 'Searchable hashtags / tags',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(15)
  @IsString({ each: true })
  tags?: string[];

  @ApiPropertyOptional({
    type: AiChecklistCacheInputDto,
    description: 'Cached AI Buyer Inspection Checklist',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => AiChecklistCacheInputDto)
  aiChecklistCache?: AiChecklistCacheInputDto | null;
}
