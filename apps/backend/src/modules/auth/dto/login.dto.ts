import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({
    example: 'khoa.nguyen@remarket.vn',
    description: 'Registered email address',
  })
  @IsEmail({}, { message: 'Please provide a valid email address' })
  @MaxLength(255)
  email!: string;

  @ApiProperty({
    example: 'StrongPass123!',
    description: 'Account password',
  })
  @IsString()
  @MinLength(1, { message: 'Password is required' })
  @MaxLength(72)
  password!: string;
}
