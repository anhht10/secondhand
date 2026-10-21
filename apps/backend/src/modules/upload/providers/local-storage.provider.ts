import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import {
  IStorageProvider,
  MulterUploadedFile,
  UploadedImageMetadata,
} from '../../../common/interfaces/storage-provider.interface';

@Injectable()
export class LocalStorageProvider implements IStorageProvider {
  private readonly logger = new Logger(LocalStorageProvider.name);
  private readonly uploadRootDir = path.join(process.cwd(), 'uploads');
  private readonly productsSubDir = 'products';

  constructor() {
    this.ensureUploadDirectories();
  }

  private ensureUploadDirectories(): void {
    const productDir = path.join(this.uploadRootDir, this.productsSubDir);
    if (!fs.existsSync(productDir)) {
      fs.mkdirSync(productDir, { recursive: true });
    }
  }

  async saveUploadedFiles(
    files: MulterUploadedFile[],
    altTexts: string[] = [],
    startOrder = 0,
  ): Promise<UploadedImageMetadata[]> {
    this.ensureUploadDirectories();

    const results: UploadedImageMetadata[] = [];

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ext = this.resolveSafeExtension(file.originalname, file.mimetype);
      const filename = file.filename || `${Date.now()}-${randomUUID()}${ext}`;
      const relativePublicId = `${this.productsSubDir}/${filename}`;
      const targetPath = path.join(
        this.uploadRootDir,
        this.productsSubDir,
        filename,
      );

      if (file.buffer && !file.path) {
        await fs.promises.writeFile(targetPath, file.buffer);
      }

      const providedAlt = altTexts[i]?.trim();
      const defaultAlt = path
        .basename(file.originalname, path.extname(file.originalname))
        .replace(/[^a-zA-Z0-9\s\-_().]/g, '')
        .trim()
        .slice(0, 120);

      results.push({
        url: `/uploads/${relativePublicId}`,
        publicId: relativePublicId,
        sortOrder: startOrder + i,
        altText: providedAlt || defaultAlt || null,
      });
    }

    return results;
  }

  async getSignedUploadParams(folder: string): Promise<{
    uploadUrl: string;
    publicId: string;
    signature?: string;
  }> {
    const publicId = `${folder}/${Date.now()}-${randomUUID()}`;
    return {
      uploadUrl: '/api/v1/upload/images',
      publicId,
    };
  }

  async deleteAsset(publicId: string): Promise<void> {
    if (!publicId) return;

    // Prevent path traversal outside uploads root
    const normalized = path
      .normalize(publicId)
      .replace(/^(\.\.(\/|\\|$))+/, '');
    const fullPath = path.join(this.uploadRootDir, normalized);

    if (!fullPath.startsWith(this.uploadRootDir)) {
      this.logger.warn(`Blocked unsafe deleteAsset path: ${publicId}`);
      return;
    }

    try {
      if (fs.existsSync(fullPath)) {
        await fs.promises.unlink(fullPath);
      }
    } catch (error) {
      this.logger.warn(
        `Failed to delete local asset ${publicId}: ${(error as Error).message}`,
      );
    }
  }

  private resolveSafeExtension(
    _originalname: string,
    mimetype: string,
  ): string {
    const mimeToExt: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
    };
    return mimeToExt[mimetype.toLowerCase()] || '.jpg';
  }
}
