import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateReportDto {
  @ApiProperty({
    example: '672b3a9f8e1b2c0012345679',
    description: 'Target product MongoDB ObjectId being reported',
  })
  @IsMongoId({ message: 'productId must be a valid MongoDB ObjectId' })
  productId!: string;

  @ApiProperty({
    example: 'COUNTERFEIT_OR_FAKE',
    description:
      'Reason for reporting the product listing (3 to 150 characters)',
    minLength: 3,
    maxLength: 150,
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty({ message: 'reason is required' })
  @MinLength(3, { message: 'reason must be at least 3 characters long' })
  @MaxLength(150)
  reason!: string;

  @ApiPropertyOptional({
    example:
      'Serial number shown in the listing photos does not match authentic Sony WH-1000XM4 units.',
    description: 'Detailed explanation of the issue',
    maxLength: 2000,
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({
    type: [String],
    example: ['/uploads/products/evidence-1.png'],
    description:
      'Optional array of evidence image URLs (HTTP/HTTPS or /uploads/ paths, max 5)',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (typeof value === 'string') {
      return [value];
    }
    return value;
  })
  @IsArray()
  @ArrayMaxSize(5, { message: 'Cannot attach more than 5 evidence URLs' })
  @IsString({ each: true })
  @Matches(/^(https?:\/\/|\/uploads\/)/, {
    each: true,
    message:
      'Each evidenceUrl must be a valid HTTP/HTTPS URL or an uploaded /uploads/ path',
  })
  evidenceUrls?: string[];
}
