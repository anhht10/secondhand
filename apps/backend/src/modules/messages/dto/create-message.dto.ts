import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MessageType } from '../schemas/message.schema';

export class CreateMessageDto {
  @ApiProperty({
    example: 'Mình có thể xem hàng trực tiếp ở Quận 10 chiều nay không?',
    description: 'Message content (non-empty, max 2000 characters)',
    minLength: 1,
    maxLength: 2000,
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty({ message: 'Message content cannot be empty' })
  @MinLength(1, { message: 'Message content cannot be empty' })
  @MaxLength(2000)
  content!: string;

  @ApiPropertyOptional({
    enum: MessageType,
    default: MessageType.TEXT,
    description: 'Type of message (TEXT, IMAGE, SYSTEM)',
  })
  @IsOptional()
  @IsEnum(MessageType)
  messageType?: MessageType;
}
