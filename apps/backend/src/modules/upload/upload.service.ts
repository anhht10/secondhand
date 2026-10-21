import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import {
  IStorageProvider,
  MulterUploadedFile,
  STORAGE_PROVIDER_TOKEN,
  UploadedImageMetadata,
} from '../../common/interfaces/storage-provider.interface';

export const ALLOWED_IMAGE_MIME_TYPES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];
export const MAX_IMAGE_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
export const MAX_IMAGE_COUNT = 10;

@Injectable()
export class UploadService {
  constructor(
    @Inject(STORAGE_PROVIDER_TOKEN)
    private readonly storageProvider: IStorageProvider,
  ) {}

  async uploadProductImages(
    files: MulterUploadedFile[],
    altTexts?: string[],
    startOrder = 0,
  ): Promise<UploadedImageMetadata[]> {
    if (!files || files.length === 0) {
      throw new BadRequestException('At least one image file is required');
    }

    if (files.length > MAX_IMAGE_COUNT) {
      throw new BadRequestException(
        `Cannot upload more than ${MAX_IMAGE_COUNT} images at once`,
      );
    }

    for (const file of files) {
      if (!ALLOWED_IMAGE_MIME_TYPES.includes(file.mimetype.toLowerCase())) {
        throw new BadRequestException(
          `Unsupported image MIME type "${file.mimetype}". Allowed types: ${ALLOWED_IMAGE_MIME_TYPES.join(', ')}`,
        );
      }

      if (file.size > MAX_IMAGE_FILE_SIZE_BYTES) {
        throw new BadRequestException(
          `File "${file.originalname}" exceeds maximum size of 5MB`,
        );
      }
    }

    return this.storageProvider.saveUploadedFiles(files, altTexts, startOrder);
  }

  async deleteAsset(publicId: string | null | undefined): Promise<void> {
    if (!publicId) return;
    await this.storageProvider.deleteAsset(publicId);
  }

  async deleteManyAssets(
    publicIds: Array<string | null | undefined>,
  ): Promise<void> {
    const validIds = publicIds.filter((id): id is string => Boolean(id));
    await Promise.all(
      validIds.map((publicId) => this.storageProvider.deleteAsset(publicId)),
    );
  }
}
