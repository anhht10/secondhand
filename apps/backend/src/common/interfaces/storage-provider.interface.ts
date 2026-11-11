export interface UploadedImageMetadata {
  url: string;
  publicId: string;
  sortOrder: number;
  altText: string | null;
}

export interface MulterUploadedFile {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination?: string;
  filename?: string;
  path?: string;
  buffer?: Buffer;
}

/**
 * Clean abstraction for local disk or cloud (Cloudinary / AWS S3) image storage.
 * Binary image data is never stored in MongoDB.
 */
export interface IStorageProvider {
  saveUploadedFiles(
    files: MulterUploadedFile[],
    altTexts?: string[],
    startOrder?: number,
  ): Promise<UploadedImageMetadata[]>;
  getSignedUploadParams(folder: string): Promise<{
    uploadUrl: string;
    publicId: string;
    signature?: string;
  }>;
  deleteAsset(publicId: string): Promise<void>;
}

export const STORAGE_PROVIDER_TOKEN = 'STORAGE_PROVIDER_TOKEN';
