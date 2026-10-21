import { ApiProperty } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { ProductStatus } from '../schemas/product.schema';

export class UpdateProductStatusDto {
  @ApiProperty({
    enum: ProductStatus,
    example: ProductStatus.SOLD,
    description:
      'Target product status (DRAFT, ACTIVE, SOLD, or ARCHIVED). Only the listing owner can transition status.',
  })
  @IsEnum(ProductStatus, {
    message: `status must be one of: ${Object.values(ProductStatus).join(', ')}`,
  })
  status!: ProductStatus;
}
