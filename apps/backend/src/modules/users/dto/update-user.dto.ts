import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  Matches,
  ValidateNested,
} from 'class-validator';

export class SellerBankInfoDto {
  @ApiProperty({
    example: 'Vietcombank (VCB)',
    description: 'Bank name for direct bank transfer',
  })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  bankName!: string;

  @ApiProperty({
    example: '1029384756',
    description: 'Bank account number (digits/alphanumeric only)',
  })
  @IsString()
  @MinLength(4)
  @MaxLength(40)
  @Matches(/^[A-Za-z0-9\s-]+$/, {
    message: 'accountNumber must contain valid account digits/characters only',
  })
  accountNumber!: string;

  @ApiProperty({
    example: 'NGUYEN MINH KHOA',
    description: 'Account holder full name (uppercase recommended)',
  })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  accountHolder!: string;

  @ApiPropertyOptional({
    example: 'CN TP.HCM',
    description: 'Optional bank branch',
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  branch?: string;
}

export class UpdateUserDto {
  @ApiPropertyOptional({
    example: 'Khoa Nguyen',
    description: 'Public display name of the user',
    minLength: 2,
    maxLength: 80,
  })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  displayName?: string;

  @ApiPropertyOptional({
    example: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
    description: 'Avatar image URL or local /uploads/... path',
  })
  @IsOptional()
  @IsString()
  @Matches(/^(https?:\/\/|\/uploads\/)/, {
    message: 'avatarUrl must be a valid HTTP(S) URL or /uploads/... path',
  })
  @MaxLength(500)
  avatarUrl?: string;

  @ApiPropertyOptional({
    example: '+84901234567',
    description: 'Contact phone number',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[+\d\s\-()]{7,20}$/, {
    message: 'phoneNumber must be a valid phone number format',
  })
  phoneNumber?: string;

  @ApiPropertyOptional({
    example:
      'Final-year CS student selling well-maintained tech gear in District 10.',
    description: 'Short seller biography',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional({
    example: 'District 10, Ho Chi Minh City',
    description: 'User city or district location',
    maxLength: 120,
  })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @ApiPropertyOptional({
    example: 'ĐH Bách Khoa - ĐHQG TP.HCM',
    description: 'University or campus for student marketplace transactions',
    maxLength: 150,
  })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  university?: string;

  @ApiPropertyOptional({
    type: SellerBankInfoDto,
    description:
      'Seller bank account configuration for receiving direct transfers (never store passwords/OTP/CVV)',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => SellerBankInfoDto)
  bankInfo?: SellerBankInfoDto | null;
}
