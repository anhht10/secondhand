import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { ParseObjectIdPipe } from '../../common/pipes/parse-object-id.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { imageMulterOptions } from '../upload/upload.controller';
import { MAX_IMAGE_COUNT } from '../upload/upload.service';
import { CreateProductDto } from './dto/create-product.dto';
import {
  DeleteProductResponseDto,
  PaginatedProductsResponseDto,
  ProductResponseDto,
} from './dto/product-response.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { UpdateProductStatusDto } from './dto/update-product-status.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductsService } from './products.service';

@ApiTags('Products')
@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new product listing' })
  @ApiResponse({
    status: 201,
    description: 'Product listing created',
    type: ProductResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Validation error',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() createProductDto: CreateProductDto,
  ) {
    return this.productsService.create(currentUser.userId, createProductDto);
  }

  @Get()
  @ApiOperation({
    summary:
      'List public ACTIVE product listings with pagination, filtering, sorting, and weighted text search',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of active product listings',
    type: PaginatedProductsResponseDto,
  })
  async findAllPublic(@Query() queryDto: QueryProductDto) {
    return this.productsService.findAllPublic(queryDto);
  }

  @Get('me/listings')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'List all product listings owned by the authenticated seller (includes DRAFT, ACTIVE, SOLD, ARCHIVED)',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of seller listings',
    type: PaginatedProductsResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async findMeListings(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() queryDto: QueryProductDto,
  ) {
    return this.productsService.findMyListings(currentUser.userId, queryDto);
  }

  @Get('my-listings')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Alias for /products/me/listings: list all product listings owned by the authenticated seller',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of seller listings',
    type: PaginatedProductsResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async findMyListings(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() queryDto: QueryProductDto,
  ) {
    return this.productsService.findMyListings(currentUser.userId, queryDto);
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({
    summary:
      'Get product listing details by ID (hides DRAFT and ARCHIVED from non-owners)',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product details returned',
    type: ProductResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product listing not found',
    type: ApiErrorResponseDto,
  })
  async findOne(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser?: AuthenticatedUser | null,
  ) {
    return this.productsService.findById(id, true, currentUser?.userId);
  }

  @Patch(':id/status')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Transition product listing status (DRAFT, ACTIVE, SOLD, ARCHIVED) — owner only',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product status updated',
    type: ProductResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — not listing owner',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product listing not found',
    type: ApiErrorResponseDto,
  })
  async updateStatus(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() statusDto: UpdateProductStatusDto,
  ) {
    return this.productsService.updateStatus(id, currentUser.userId, statusDto);
  }

  @Post(':id/images')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(
    FilesInterceptor('images', MAX_IMAGE_COUNT, imageMulterOptions),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary:
      'Upload and attach images to an existing product listing (owner only)',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        images: {
          type: 'array',
          items: { type: 'string', format: 'binary' },
        },
        altTexts: {
          type: 'array',
          items: { type: 'string' },
        },
      },
      required: ['images'],
    },
  })
  @ApiResponse({
    status: 201,
    description: 'Images uploaded and attached to product',
    type: ProductResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — not listing owner',
    type: ApiErrorResponseDto,
  })
  async uploadProductImages(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @UploadedFiles() files: MulterUploadedFile[],
    @Body('altTexts') altTexts?: string | string[],
  ) {
    const normalizedAltTexts = Array.isArray(altTexts)
      ? altTexts
      : typeof altTexts === 'string'
        ? [altTexts]
        : [];

    return this.productsService.addUploadedImages(
      id,
      currentUser.userId,
      files,
      normalizedAltTexts,
    );
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Update or archive a product listing (owner only)',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product listing updated',
    type: ProductResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — not listing owner',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product listing not found',
    type: ApiErrorResponseDto,
  })
  async update(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() updateProductDto: UpdateProductDto,
  ) {
    return this.productsService.update(
      id,
      currentUser.userId,
      updateProductDto,
    );
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Update a product listing via PUT (alias for PATCH /products/:id)',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product listing updated',
    type: ProductResponseDto,
  })
  async updatePut(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() updateProductDto: UpdateProductDto,
  ) {
    return this.productsService.update(
      id,
      currentUser.userId,
      updateProductDto,
    );
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Delete a product listing and remove associated uploaded images (owner only)',
  })
  @ApiParam({ name: 'id', description: 'Product MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Product listing deleted',
    type: DeleteProductResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 403,
    description: 'Forbidden — not listing owner',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Product listing not found',
    type: ApiErrorResponseDto,
  })
  async remove(
    @Param('id', ParseObjectIdPipe) id: string,
    @CurrentUser() currentUser: AuthenticatedUser,
  ) {
    return this.productsService.remove(id, currentUser.userId);
  }
}
