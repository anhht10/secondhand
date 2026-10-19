import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CategoryResponseDto {
  @ApiProperty({ example: '672b3a9f8e1b2c0012345678' })
  id!: string;

  @ApiProperty({ example: 'Electronics' })
  name!: string;

  @ApiProperty({ example: 'electronics' })
  slug!: string;

  @ApiPropertyOptional({
    example:
      'Headphones, audio gear, cameras, monitors, and consumer electronics.',
    nullable: true,
  })
  description!: string | null;

  @ApiPropertyOptional({ example: 'devices', nullable: true })
  icon!: string | null;

  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012345670',
    nullable: true,
    description: 'Parent category ObjectId (null for top-level categories)',
  })
  parentId!: string | null;

  @ApiProperty({ example: true })
  isActive!: boolean;

  @ApiProperty({ example: 1 })
  sortOrder!: number;
}
