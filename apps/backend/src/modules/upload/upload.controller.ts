import {
  BadRequestException,
  Body,
  Controller,
  Post,
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
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { memoryStorage } from 'multer';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ProductImageResponseDto } from '../products/dto/product-response.dto';
import {
  ALLOWED_IMAGE_MIME_TYPES,
  MAX_IMAGE_COUNT,
  MAX_IMAGE_FILE_SIZE_BYTES,
  UploadService,
} from './upload.service';

export const imageMulterOptions = {
  storage: memoryStorage(),
  limits: {
    fileSize: MAX_IMAGE_FILE_SIZE_BYTES,
    files: MAX_IMAGE_COUNT,
  },
  fileFilter: (
    _req: unknown,
    file: { mimetype: string; originalname: string },
    callback: (error: Error | null, acceptFile: boolean) => void,
  ) => {
    if (!ALLOWED_IMAGE_MIME_TYPES.includes(file.mimetype.toLowerCase())) {
      return callback(
        new BadRequestException(
          `Unsupported image format "${file.mimetype}". Allowed: jpeg, jpg, png, webp`,
        ),
        false,
      );
    }
    callback(null, true);
  },
};

@ApiTags('Upload')
@Controller('upload')
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Post('images')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(
    FilesInterceptor('images', MAX_IMAGE_COUNT, imageMulterOptions),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary:
      'Upload multiple product images (max 10 files, 5MB each, jpeg/png/webp)',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        images: {
          type: 'array',
          items: { type: 'string', format: 'binary' },
          description: 'Image files (field name: images)',
        },
        altTexts: {
          type: 'array',
          items: { type: 'string' },
          description:
            'Optional alt text descriptions corresponding to each image',
        },
      },
      required: ['images'],
    },
  })
  @ApiResponse({
    status: 201,
    description: 'Images uploaded and metadata returned',
    type: [ProductImageResponseDto],
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid MIME type, file size exceeded, or missing files',
    type: ApiErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized',
    type: ApiErrorResponseDto,
  })
  async uploadImages(
    @UploadedFiles() files: MulterUploadedFile[],
    @Body('altTexts') altTexts?: string | string[],
  ) {
    const normalizedAltTexts = Array.isArray(altTexts)
      ? altTexts
      : typeof altTexts === 'string'
        ? [altTexts]
        : [];

    return this.uploadService.uploadProductImages(files, normalizedAltTexts, 0);
  }
}
