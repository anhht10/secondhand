import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationMetaDto } from '../../../common/dto/api-response.dto';
import { ProductCondition, ProductStatus } from '../schemas/product.schema';

export class ProductImageResponseDto {
  @ApiProperty({
    example: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
  })
  url!: string;

  @ApiPropertyOptional({ example: 'products/sony-xm4-main', nullable: true })
  publicId!: string | null;

  @ApiProperty({ example: 0 })
  sortOrder!: number;

  @ApiPropertyOptional({
    example: 'Sony WH-1000XM4 Wireless Headphones front view',
    nullable: true,
  })
  altText!: string | null;
}

export class ProductResponseDto {
  @ApiProperty({ example: '672b3a9f8e1b2c0012345679' })
  id!: string;

  @ApiProperty({ example: '672b3a9f8e1b2c0012345671' })
  sellerId!: string;

  @ApiProperty({ example: '672b3a9f8e1b2c0012345678' })
  categoryId!: string;

  @ApiProperty({
    example: 'Sony WH-1000XM4 Wireless Noise Cancelling Headphones',
  })
  title!: string;

  @ApiProperty({
    example:
      'Purchased 8 months ago, lightly used in office. Includes carrying case and cables.',
  })
  description!: string;

  @ApiProperty({ example: 4200000 })
  price!: number;

  @ApiProperty({ enum: ProductCondition, example: ProductCondition.LIKE_NEW })
  condition!: ProductCondition;

  @ApiProperty({ type: [ProductImageResponseDto] })
  images!: ProductImageResponseDto[];

  @ApiProperty({ example: 'District 10, Ho Chi Minh City' })
  location!: string;

  @ApiProperty({ enum: ProductStatus, example: ProductStatus.ACTIVE })
  status!: ProductStatus;

  @ApiPropertyOptional({ example: 'Sony', nullable: true })
  brand?: string | null;

  @ApiPropertyOptional({ example: 6990000, nullable: true })
  originalPrice?: number | null;

  @ApiPropertyOptional({
    example: 'Đệm tai còn êm, chỉ xước dăm rất nhẹ trên vỏ hộp đựng.',
    nullable: true,
  })
  defectDisclosure?: string | null;

  @ApiPropertyOptional({
    example: 'Pin thực tế còn hơn 26h bật ANC, đầy đủ phụ kiện zin.',
    nullable: true,
  })
  transparencyNote?: string | null;

  @ApiPropertyOptional({ example: 98, nullable: true })
  transparencyScore?: number | null;

  @ApiPropertyOptional({
    type: [String],
    example: ['#sony', '#wh1000xm4', '#tainghechongon'],
  })
  tags?: string[];

  @ApiProperty({ example: 14 })
  viewCount!: number;

  @ApiPropertyOptional({ example: '2026-11-06T08:00:00.000Z' })
  createdAt?: Date;

  @ApiPropertyOptional({ example: '2026-11-06T08:00:00.000Z' })
  updatedAt?: Date;
}

export class PaginatedProductsResponseDto {
  @ApiProperty({ example: true })
  success!: true;

  @ApiProperty({ type: [ProductResponseDto] })
  data!: ProductResponseDto[];

  @ApiProperty({ type: PaginationMetaDto })
  meta!: PaginationMetaDto;

  @ApiProperty({ example: 'Success' })
  message!: string;
}

export class DeleteProductResponseDto {
  @ApiProperty({ example: true })
  deleted!: boolean;

  @ApiProperty({ example: '672b3a9f8e1b2c0012345679' })
  id!: string;
}
