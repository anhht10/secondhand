import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  BuyerPaymentConfirmationDto,
  CreateOrderDto,
  OrderActionNoteDto,
  QueryOrdersDto,
  SellerPaymentConfirmationDto,
} from './dto/order.dto';
import { OrdersService } from './orders.service';

@ApiTags('Orders & Payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Create a new purchase order and atomically reserve the product listing',
  })
  async createOrder(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateOrderDto,
  ) {
    return this.ordersService.createOrder(user.userId, dto);
  }

  @Get()
  @ApiOperation({
    summary: 'List orders for the current authenticated user (buyer or seller)',
  })
  async findOrders(
    @CurrentUser() user: AuthenticatedUser,
    @Query() queryDto: QueryOrdersDto,
  ) {
    const result = await this.ordersService.findOrdersForUser(
      user.userId,
      queryDto,
    );
    return {
      __paginated: true,
      items: result.items,
      meta: result.meta,
    };
  }

  @Get('buyer')
  @ApiOperation({
    summary: 'List all orders placed by the current authenticated buyer',
  })
  async findBuyerOrders(
    @CurrentUser() user: AuthenticatedUser,
    @Query() queryDto: QueryOrdersDto,
  ) {
    const result = await this.ordersService.findOrdersForUser(
      user.userId,
      queryDto,
      'buyer',
    );
    return {
      __paginated: true,
      items: result.items,
      meta: result.meta,
    };
  }

  @Get('seller')
  @ApiOperation({
    summary: 'List all orders received by the current authenticated seller',
  })
  async findSellerOrders(
    @CurrentUser() user: AuthenticatedUser,
    @Query() queryDto: QueryOrdersDto,
  ) {
    const result = await this.ordersService.findOrdersForUser(
      user.userId,
      queryDto,
      'seller',
    );
    return {
      __paginated: true,
      items: result.items,
      meta: result.meta,
    };
  }

  @Get('by-product/:productId')
  @ApiOperation({
    summary:
      'Get the latest order between the current user and a specific product (for Chat & Product Detail integration)',
  })
  @ApiParam({ name: 'productId', description: 'Product MongoDB ObjectId' })
  async findLatestOrderByProduct(
    @Param('productId') productId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.ordersService.findLatestOrderForProductAndUser(
      productId,
      user.userId,
    );
  }

  @Get(':id')
  @ApiOperation({
    summary:
      'Get order detail, timeline, payment record, and authorized seller bank info',
  })
  @ApiParam({ name: 'id', description: 'Order MongoDB ObjectId' })
  async findOrderById(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.ordersService.findOrderById(id, user.userId);
  }

  @Patch(':id/confirm')
  @ApiOperation({
    summary: 'Seller confirms a PENDING order (PENDING -> CONFIRMED)',
  })
  async confirmOrder(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: OrderActionNoteDto,
  ) {
    return this.ordersService.confirmOrder(id, user.userId, dto);
  }

  @Patch(':id/reject')
  @ApiOperation({
    summary:
      'Seller rejects a PENDING order (PENDING -> REJECTED) and restores product availability',
  })
  async rejectOrder(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: OrderActionNoteDto,
  ) {
    return this.ordersService.rejectOrder(id, user.userId, dto);
  }

  @Patch(':id/cancel')
  @ApiOperation({
    summary:
      'Buyer or Seller cancels a PENDING/CONFIRMED order and restores product availability',
  })
  async cancelOrder(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: OrderActionNoteDto,
  ) {
    return this.ordersService.cancelOrder(id, user.userId, dto);
  }

  @Patch(':id/delivery')
  @ApiOperation({
    summary:
      'Seller updates shipping or handover status (CONFIRMED -> SHIPPING -> DELIVERED)',
  })
  async updateDeliveryStatus(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: OrderActionNoteDto,
  ) {
    return this.ordersService.updateDeliveryStatus(id, user.userId, dto);
  }

  @Patch(':id/complete')
  @ApiOperation({
    summary:
      'Buyer confirms receipt of product and completes the order (Product -> SOLD)',
  })
  async completeOrder(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: OrderActionNoteDto,
  ) {
    return this.ordersService.completeOrder(id, user.userId, dto);
  }

  @Post(':id/payment-confirmation')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Buyer submits manual bank transfer confirmation (UNPAID -> BUYER_CONFIRMED)',
  })
  async confirmBuyerPayment(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: BuyerPaymentConfirmationDto,
  ) {
    return this.ordersService.confirmBuyerPayment(id, user.userId, dto);
  }

  @Patch(':id/payment/confirm')
  @ApiOperation({
    summary:
      'Seller confirms receiving bank transfer payment (BUYER_CONFIRMED -> PAID)',
  })
  async confirmSellerPayment(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto?: SellerPaymentConfirmationDto,
  ) {
    return this.ordersService.confirmSellerPayment(id, user.userId, dto);
  }
}
