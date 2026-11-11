import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsMongoId,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { DeliveryMethod } from '../schemas/order.schema';
import { PaymentMethod } from '../schemas/payment.schema';

export class CreateOrderDto {
  @ApiProperty({
    example: '672b3a9f8e1b2c0012345679',
    description: 'Target Product MongoDB ObjectId',
  })
  @IsMongoId()
  productId!: string;

  @ApiProperty({
    enum: DeliveryMethod,
    example: DeliveryMethod.MEETUP,
    description: 'Fulfillment method: MEETUP (direct handover) or DELIVERY (shipping)',
  })
  @IsEnum(DeliveryMethod)
  deliveryMethod!: DeliveryMethod;

  @ApiProperty({
    enum: PaymentMethod,
    example: PaymentMethod.BANK_TRANSFER,
    description: 'Payment method: CASH, COD, or BANK_TRANSFER',
  })
  @IsEnum(PaymentMethod)
  paymentMethod!: PaymentMethod;

  @ApiPropertyOptional({
    example: 'KTX Khu B ĐHQG TP.HCM, Phường Đông Hòa, Dĩ An',
    description: 'Required when deliveryMethod is DELIVERY',
  })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  shippingAddress?: string;

  @ApiPropertyOptional({
    example: 'Trần Hoàng Minh',
    description: 'Recipient full name',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  recipientName?: string;

  @ApiPropertyOptional({
    example: '+84912345678',
    description: 'Recipient contact phone number',
  })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  recipientPhone?: string;

  @ApiPropertyOptional({
    example: 'Thư viện ĐH Bách Khoa Cơ sở 1, Quận 10',
    description: 'Preferred meetup location when deliveryMethod is MEETUP',
  })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  meetupLocation?: string;

  @ApiPropertyOptional({
    example: 'Mình có thể nhận máy vào chiều thứ 5 lúc 15h nhé.',
    description: 'Optional buyer note for the seller',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  buyerNote?: string;

  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012349999',
    description: 'Optional conversation ID when creating an order from Chat',
  })
  @IsOptional()
  @IsMongoId()
  conversationId?: string;
}

export class QueryOrdersDto {
  @ApiPropertyOptional({
    enum: ['buyer', 'seller', 'all'],
    default: 'all',
  })
  @IsOptional()
  @IsString()
  role?: 'buyer' | 'seller' | 'all';

  @ApiPropertyOptional({
    description:
      'Filter by status or tab group: ALL, PENDING, PROCESSING, CONFIRMED, SHIPPING, DELIVERED, COMPLETED, CANCELLED, REJECTED',
  })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  status?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

export class OrderActionNoteDto {
  @ApiPropertyOptional({
    example: 'Đã xác nhận đơn hàng, hẹn gặp bạn chiều mai.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @ApiPropertyOptional({
    example: 'Đổi ý hoặc đã mua được sản phẩm khác',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @ApiPropertyOptional({
    enum: ['SHIPPING', 'DELIVERED'],
    description: 'Optional delivery status when updating shipping progress',
  })
  @IsOptional()
  @IsEnum(['SHIPPING', 'DELIVERED'])
  deliveryStatus?: 'SHIPPING' | 'DELIVERED';
}

export class BuyerPaymentConfirmationDto {
  @ApiPropertyOptional({
    example: 'FT26312998877',
    description: 'Optional bank transfer reference number (never submit OTP/passwords/CVV)',
  })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  transactionReference?: string;

  @ApiPropertyOptional({
    example: 'Mình đã chuyển khoản đủ qua Vietcombank lúc 14:20',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  transferNote?: string;

  @ApiPropertyOptional({
    example: 'Mình đã chuyển khoản đủ qua Vietcombank lúc 14:20',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class SellerPaymentConfirmationDto {
  @ApiPropertyOptional({
    example: 'Đã nhận đủ tiền chuyển khoản từ người mua.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
