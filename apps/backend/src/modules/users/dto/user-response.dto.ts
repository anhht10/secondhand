import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserStatus } from '../schemas/user.schema';

export class UserStatsDto {
  @ApiProperty({ example: 6 })
  activeListingsCount!: number;

  @ApiProperty({ example: 4 })
  soldListingsCount!: number;

  @ApiProperty({ example: 4.9 })
  rating!: number;

  @ApiProperty({ example: 100 })
  transparencyRate!: number;
}

export class UserResponseDto {
  @ApiProperty({ example: '672b3a9f8e1b2c0012345678' })
  id!: string;

  @ApiProperty({ example: 'khoa.nguyen@remarket.vn' })
  email!: string;

  @ApiProperty({ example: 'Khoa Nguyen' })
  displayName!: string;

  @ApiPropertyOptional({
    example: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
    nullable: true,
  })
  avatarUrl!: string | null;

  @ApiPropertyOptional({ example: '+84901234567', nullable: true })
  phoneNumber!: string | null;

  @ApiPropertyOptional({
    example: 'Final-year CS student selling well-maintained tech gear.',
    nullable: true,
  })
  bio!: string | null;

  @ApiPropertyOptional({
    example: 'District 10, Ho Chi Minh City',
    nullable: true,
  })
  location!: string | null;

  @ApiPropertyOptional({
    example: 'ĐH Bách Khoa - ĐHQG TP.HCM',
    nullable: true,
  })
  university?: string | null;

  @ApiPropertyOptional({ type: UserStatsDto })
  stats?: UserStatsDto;

  @ApiProperty({ example: false })
  isEmailVerified!: boolean;

  @ApiProperty({ enum: UserStatus, example: UserStatus.ACTIVE })
  status!: UserStatus;

  @ApiPropertyOptional({ example: '2026-11-06T08:00:00.000Z' })
  createdAt?: Date;

  @ApiPropertyOptional({ example: '2026-11-06T08:00:00.000Z' })
  updatedAt?: Date;
}

export class PublicSellerProfileResponseDto {
  @ApiProperty({ example: '672b3a9f8e1b2c0012345678' })
  id!: string;

  @ApiProperty({ example: 'Khoa Nguyen' })
  displayName!: string;

  @ApiPropertyOptional({
    example: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
    nullable: true,
  })
  avatarUrl!: string | null;

  @ApiPropertyOptional({
    example: 'Final-year CS student selling well-maintained tech gear.',
    nullable: true,
  })
  bio!: string | null;

  @ApiPropertyOptional({
    example: 'District 10, Ho Chi Minh City',
    nullable: true,
  })
  location!: string | null;

  @ApiPropertyOptional({
    example: 'ĐH Bách Khoa - ĐHQG TP.HCM',
    nullable: true,
  })
  university?: string | null;

  @ApiPropertyOptional({ type: UserStatsDto })
  stats?: UserStatsDto;

  @ApiProperty({ example: false })
  isEmailVerified!: boolean;

  @ApiProperty({ enum: UserStatus, example: UserStatus.ACTIVE })
  status!: UserStatus;

  @ApiPropertyOptional({ example: '2026-11-06T08:00:00.000Z' })
  createdAt?: Date;
}
