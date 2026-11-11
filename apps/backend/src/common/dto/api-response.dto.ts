import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class PaginationMetaDto {
  @ApiProperty({ example: 1, description: 'Current page number (1-indexed)' })
  page!: number;

  @ApiProperty({ example: 12, description: 'Number of items per page' })
  limit!: number;

  @ApiProperty({ example: 24, description: 'Total matching items' })
  total!: number;

  @ApiProperty({ example: 2, description: 'Total number of pages' })
  totalPages!: number;

  @ApiPropertyOptional({
    example: true,
    description: 'Whether a next page exists',
  })
  hasNextPage?: boolean;

  @ApiPropertyOptional({
    example: false,
    description: 'Whether a previous page exists',
  })
  hasPrevPage?: boolean;
}

export class ApiErrorDetailDto {
  @ApiProperty({
    example: 'VALIDATION_ERROR',
    description: 'Machine-readable error code',
  })
  code!: string;

  @ApiProperty({
    type: [String],
    example: ['email must be an email'],
    description: 'Detailed validation or business error messages',
  })
  details!: string[];
}

export class ApiErrorResponseDto {
  @ApiProperty({ example: false })
  success!: false;

  @ApiProperty({ example: 400 })
  statusCode!: number;

  @ApiProperty({ example: 'Validation failed' })
  message!: string;

  @ApiProperty({ type: ApiErrorDetailDto })
  error!: ApiErrorDetailDto;
}
