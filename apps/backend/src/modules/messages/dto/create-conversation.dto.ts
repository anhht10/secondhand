import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsMongoId,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateConversationDto {
  @ApiProperty({
    example: '672b3a9f8e1b2c0012345679',
    description: 'Target product MongoDB ObjectId to inquire about',
  })
  @IsMongoId({ message: 'productId must be a valid MongoDB ObjectId' })
  productId!: string;

  @ApiPropertyOptional({
    example: 'Chào bạn, tai nghe Sony WH-1000XM4 này còn hàng không ạ?',
    description:
      'Optional initial message to send when opening the conversation',
    maxLength: 2000,
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MinLength(1, { message: 'initialMessage cannot be empty' })
  @MaxLength(2000)
  initialMessage?: string;
}
