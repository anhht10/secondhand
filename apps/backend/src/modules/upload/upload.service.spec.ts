import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import {
  IStorageProvider,
  MulterUploadedFile,
  STORAGE_PROVIDER_TOKEN,
} from '../../common/interfaces/storage-provider.interface';
import { UploadService } from './upload.service';

describe('UploadService', () => {
  let service: UploadService;

  const mockStorageProvider: IStorageProvider = {
    saveUploadedFiles: jest
      .fn()
      .mockImplementation(async (files, altTexts = [], startOrder = 0) =>
        files.map((f: MulterUploadedFile, idx: number) => ({
          url: `/uploads/products/${f.originalname}`,
          publicId: `products/${f.originalname}`,
          sortOrder: startOrder + idx,
          altText: altTexts[idx] ?? f.originalname,
        })),
      ),
    getSignedUploadParams: jest.fn(),
    deleteAsset: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UploadService,
        {
          provide: STORAGE_PROVIDER_TOKEN,
          useValue: mockStorageProvider,
        },
      ],
    }).compile();

    service = module.get<UploadService>(UploadService);
  });

  it('uploads valid image files and returns structured metadata', async () => {
    const validFile: MulterUploadedFile = {
      fieldname: 'images',
      originalname: 'sony-xm4.png',
      encoding: '7bit',
      mimetype: 'image/png',
      size: 1024 * 100,
      buffer: Buffer.from('fake-png'),
    };

    const result = await service.uploadProductImages(
      [validFile],
      ['Sony front'],
    );
    expect(result).toHaveLength(1);
    expect(result[0].publicId).toBe('products/sony-xm4.png');
    expect(result[0].altText).toBe('Sony front');
  });

  it('rejects unsupported MIME types or oversized files', async () => {
    const invalidMimeFile: MulterUploadedFile = {
      fieldname: 'images',
      originalname: 'malware.exe',
      encoding: '7bit',
      mimetype: 'application/octet-stream',
      size: 1024,
    };

    await expect(
      service.uploadProductImages([invalidMimeFile]),
    ).rejects.toThrow(BadRequestException);

    const oversizedFile: MulterUploadedFile = {
      fieldname: 'images',
      originalname: 'huge.jpg',
      encoding: '7bit',
      mimetype: 'image/jpeg',
      size: 6 * 1024 * 1024, // 6MB > 5MB limit
    };

    await expect(service.uploadProductImages([oversizedFile])).rejects.toThrow(
      BadRequestException,
    );
  });

  it('deletes multiple assets via storage provider', async () => {
    await service.deleteManyAssets([
      'products/img1.jpg',
      null,
      'products/img2.png',
    ]);
    expect(mockStorageProvider.deleteAsset).toHaveBeenCalledTimes(2);
  });
});
