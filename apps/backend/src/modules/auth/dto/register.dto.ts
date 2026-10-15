import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @ApiProperty({
    example: 'khoa.nguyen@remarket.vn',
    description: 'User email address',
  })
  @IsEmail({}, { message: 'Please provide a valid email address' })
  @MaxLength(255)
  email!: string;

  @ApiProperty({
    example: 'StrongPass123!',
    description:
      'Password (min 8 chars, must include at least 1 letter and 1 number)',
    minLength: 8,
    maxLength: 72,
  })
  @IsString()
  @MinLength(8, { message: 'Password must be at least 8 characters long' })
  @MaxLength(72, { message: 'Password cannot exceed 72 characters' })
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/, {
    message: 'Password must contain at least one letter and one number',
  })
  password!: string;

  @ApiProperty({
    example: 'Khoa Nguyen',
    description: 'Public display name',
    minLength: 2,
    maxLength: 80,
  })
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  displayName!: string;

  @ApiPropertyOptional({
    example: '+84901234567',
    description: 'Optional phone number',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[+\d\s\-()]{7,20}$/, {
    message: 'phoneNumber must be a valid phone number format',
  })
  phoneNumber?: string;

  @ApiPropertyOptional({
    example: 'District 10, Ho Chi Minh City',
    description: 'Optional city or district location',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @ApiPropertyOptional({
    example: 'ĐH Khoa học Tự nhiên - ĐHQG TP.HCM',
    description: 'Optional student university or campus',
  })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  university?: string;
}
