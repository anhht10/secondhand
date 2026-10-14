import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { ParseObjectIdPipe } from '../../common/pipes/parse-object-id.pipe';
import { ProductResponseDto } from '../products/dto/product-response.dto';
import { UserResponseDto } from '../users/dto/user-response.dto';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';
import { AuthResponseDto, LogoutResponseDto } from './dto/auth-response.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly usersService: UsersService,
  ) {}

  @Post('register')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @ApiOperation({ summary: 'Register a new user account' })
  @ApiResponse({
    status: 201,
    description: 'User registered and tokens issued',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 409,
    description: 'Email already exists',
    type: ApiErrorResponseDto,
  })
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @ApiOperation({ summary: 'Authenticate user with email and password' })
  @ApiResponse({
    status: 200,
    description: 'User authenticated and tokens issued',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Invalid credentials',
    type: ApiErrorResponseDto,
  })
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  @ApiOperation({ summary: 'Rotate refresh token and issue new access token' })
  @ApiResponse({
    status: 200,
    description: 'New token pair issued',
    type: AuthResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Invalid or revoked refresh token',
    type: ApiErrorResponseDto,
  })
  async refresh(@Body() refreshTokenDto: RefreshTokenDto) {
    return this.authService.refresh(refreshTokenDto);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Logout and revoke refresh session(s)' })
  @ApiBody({
    required: false,
    schema: {
      type: 'object',
      properties: {
        refreshToken: {
          type: 'string',
          description: 'Optional specific refresh token to revoke',
        },
      },
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Refresh session revoked',
    type: LogoutResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async logout(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body('refreshToken') refreshToken?: string,
  ) {
    return this.authService.logout(currentUser.userId, refreshToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get currently authenticated user profile' })
  @ApiResponse({
    status: 200,
    description: 'Authenticated user returned',
    type: UserResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async getMe(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.authService.getMe(currentUser.userId);
  }

  @Get('wishlist')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Get authenticated user wishlist (valid ACTIVE products only)',
  })
  @ApiResponse({
    status: 200,
    description: 'List of wishlisted active products',
    type: [ProductResponseDto],
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async getWishlist(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.usersService.getWishlist(currentUser.userId);
  }

  @Post('wishlist/:productId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Add a valid ACTIVE product to the authenticated user wishlist (idempotent, no duplicates)',
  })
  @ApiParam({ name: 'productId', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 201,
    description: 'Product added to wishlist',
    type: [ProductResponseDto],
  })
  @ApiResponse({
    status: 404,
    description: 'Product not found or inactive',
    type: ApiErrorResponseDto,
  })
  async addToWishlist(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('productId', ParseObjectIdPipe) productId: string,
  ) {
    return this.usersService.addToWishlist(currentUser.userId, productId);
  }

  @Delete('wishlist/:productId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Remove a product from the authenticated user wishlist',
  })
  @ApiParam({ name: 'productId', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product removed from wishlist',
    type: [ProductResponseDto],
  })
  async removeFromWishlist(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('productId', ParseObjectIdPipe) productId: string,
  ) {
    return this.usersService.removeFromWishlist(currentUser.userId, productId);
  }
}
