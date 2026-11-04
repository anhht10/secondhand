import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PaginationQueryDto } from '../messages/dto/query-messages.dto';
import { imageMulterOptions } from '../upload/upload.controller';
import { CreateReportDto } from './dto/create-report.dto';
import { MAX_REPORT_EVIDENCE_COUNT, ReportsService } from './reports.service';

@ApiTags('Reports')
@Controller('reports')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Post()
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @UseInterceptors(
    FilesInterceptor('evidence', MAX_REPORT_EVIDENCE_COUNT, imageMulterOptions),
  )
  @ApiOperation({
    summary:
      'Submit a report against a product listing (supports JSON evidenceUrls or multipart evidence files)',
  })
  @ApiResponse({ status: 201, description: 'Report submitted successfully' })
  @ApiResponse({
    status: 400,
    description: 'Validation error or attempting to report own listing',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Target product not found',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 409,
    description: 'Duplicate report — user already reported this product',
    type: ApiErrorResponseDto,
  })
  async createReport(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() createDto: CreateReportDto,
    @UploadedFiles() evidenceFiles?: MulterUploadedFile[],
  ) {
    return this.reportsService.create(
      currentUser.userId,
      createDto,
      evidenceFiles,
    );
  }

  @Get('me')
  @ApiOperation({
    summary: 'List reports submitted by the currently authenticated user',
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of user reports',
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async getMyReports(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() queryDto: PaginationQueryDto,
  ) {
    return this.reportsService.findMyReports(currentUser.userId, queryDto);
  }
}
