import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { imageMulterOptions } from '../upload/upload.controller';
import {
  CreateReviewDto,
  QueryReviewsDto,
  ReportReviewDto,
  SellerReplyReviewDto,
  UpdateReviewDto,
} from './dto/review.dto';
import { ReviewsService } from './reviews.service';
import { MAX_REVIEW_IMAGES } from './schemas/review.schema';

@ApiTags('Reviews & Seller Reputation')
@Controller()
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post('reviews/upload-images')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(
    FilesInterceptor('images', MAX_REVIEW_IMAGES, imageMulterOptions),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Upload up to 5 real post-transaction review images (max 5MB each)',
  })
  async uploadReviewImages(@UploadedFiles() files: MulterUploadedFile[]) {
    const urls = await this.reviewsService.uploadReviewImages(files);
    return { urls };
  }

  @Post('reviews')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(
    FilesInterceptor('images', MAX_REVIEW_IMAGES, imageMulterOptions),
  )
  @ApiOperation({
    summary:
      'Create a seller review for a COMPLETED order (1 review per order, buyer only)',
  })
  async createReview(
    @CurrentUser() user: AuthenticatedUser,
    @Body() createDto: CreateReviewDto,
    @UploadedFiles() files?: MulterUploadedFile[],
  ) {
    return this.reviewsService.createReview(user.userId, createDto, files);
  }

  @Get('reviews/:id')
  @ApiOperation({ summary: 'Get review detail by review ID' })
  async getReviewById(@Param('id') id: string) {
    return this.reviewsService.getReviewById(id);
  }

  @Patch('reviews/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Update buyer review within 7 days of creation (buyer only)',
  })
  async updateReview(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() updateDto: UpdateReviewDto,
  ) {
    return this.reviewsService.updateReview(id, user.userId, updateDto);
  }

  @Delete('reviews/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Controlled review deletion endpoint (blocks arbitrary reputation manipulation)',
  })
  async deleteReview(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.reviewsService.deleteReviewControlled(id, user.userId);
  }

  @Post('reviews/:id/reply')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Seller replies to a buyer review (1 reply per review, seller only)',
  })
  async replyToReview(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() replyDto: SellerReplyReviewDto,
  ) {
    return this.reviewsService.replyToReview(id, user.userId, replyDto);
  }

  @Post('reviews/:id/report')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Report a review for policy/PII/spam violation',
  })
  async reportReview(
    @Param('id') id: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() reportDto: ReportReviewDto,
  ) {
    return this.reviewsService.reportReview(id, user.userId, reportDto);
  }

  @Get('sellers/:sellerId/reviews')
  @ApiOperation({
    summary:
      'Get paginated reviews and rating summary for a seller (supports rating filter & sorting)',
  })
  async getSellerReviews(
    @Param('sellerId') sellerId: string,
    @Query() queryDto: QueryReviewsDto,
  ) {
    const result = await this.reviewsService.getSellerReviews(
      sellerId,
      queryDto,
    );
    return {
      success: true,
      message: 'Success',
      data: result,
      meta: result.meta,
    };
  }

  @Get('sellers/:sellerId/reputation')
  @ApiOperation({
    summary:
      'Get seller reputation score, rating distribution, and transaction statistics',
  })
  async getSellerReputation(@Param('sellerId') sellerId: string) {
    return this.reviewsService.getSellerReputation(sellerId);
  }

  @Get('orders/:orderId/review')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Get the review associated with a specific order (if any)',
  })
  async getReviewByOrderId(
    @Param('orderId') orderId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.reviewsService.getReviewByOrderId(orderId, user.userId);
  }
}
