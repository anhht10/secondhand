import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { CategoriesService } from '../categories/categories.service';
import { UploadService } from '../upload/upload.service';
import { ProductsService } from './products.service';
import {
  Product,
  ProductCondition,
  ProductStatus,
} from './schemas/product.schema';

describe('ProductsService', () => {
  let service: ProductsService;

  const ownerId = new Types.ObjectId();
  const otherUserId = new Types.ObjectId();
  const categoryId = new Types.ObjectId();
  const productId = new Types.ObjectId();

  const mockProductDoc = {
    _id: productId,
    sellerId: ownerId,
    categoryId,
    title: 'Sony WH-1000XM4',
    description: 'Excellent noise cancelling headphones in black.',
    price: 4200000,
    condition: ProductCondition.LIKE_NEW,
    images: [
      {
        url: '/uploads/products/test.png',
        publicId: 'products/test.png',
        sortOrder: 0,
        altText: 'Sony',
      },
    ],
    location: 'District 10',
    status: ProductStatus.ACTIVE,
    viewCount: 0,
    save: jest.fn().mockResolvedValue(true),
  };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const MockProductModel: any = jest.fn().mockImplementation((dto) => ({
    ...mockProductDoc,
    ...dto,
    _id: productId,
    save: jest
      .fn()
      .mockResolvedValue({ ...mockProductDoc, ...dto, _id: productId }),
  }));

  MockProductModel.find = jest.fn();
  MockProductModel.findById = jest.fn();
  MockProductModel.findByIdAndUpdate = jest.fn();
  MockProductModel.countDocuments = jest.fn();
  MockProductModel.deleteOne = jest.fn();

  const mockCategoriesService = {
    findById: jest
      .fn()
      .mockResolvedValue({ _id: categoryId, slug: 'electronics' }),
    findBySlugOrId: jest
      .fn()
      .mockResolvedValue({ _id: categoryId, slug: 'electronics' }),
  };

  const mockUploadService = {
    deleteManyAssets: jest.fn().mockResolvedValue(undefined),
    uploadProductImages: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProductsService,
        {
          provide: getModelToken(Product.name),
          useValue: MockProductModel,
        },
        {
          provide: CategoriesService,
          useValue: mockCategoriesService,
        },
        {
          provide: UploadService,
          useValue: mockUploadService,
        },
      ],
    }).compile();

    service = module.get<ProductsService>(ProductsService);
  });

  it('creates a product and assigns sellerId from authenticated user', async () => {
    MockProductModel.findById.mockReturnValue({
      populate: () => ({
        populate: () => ({
          exec: jest.fn().mockResolvedValue(mockProductDoc),
        }),
      }),
    });

    const created = await service.create(String(ownerId), {
      categoryId: String(categoryId),
      title: 'Sony WH-1000XM4',
      description: 'Excellent noise cancelling headphones in black.',
      price: 4200000,
      condition: ProductCondition.LIKE_NEW,
      location: 'District 10',
    });

    expect(mockCategoriesService.findById).toHaveBeenCalledWith(
      String(categoryId),
    );
    expect(String(created.sellerId)).toBe(String(ownerId));
  });

  it('enforces product update ownership and throws ForbiddenException for non-owners', async () => {
    MockProductModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue({ ...mockProductDoc }),
    });

    await expect(
      service.update(String(productId), String(otherUserId), {
        price: 3900000,
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('hides DRAFT and ARCHIVED products from non-owners on findById', async () => {
    MockProductModel.findById.mockReturnValue({
      populate: () => ({
        populate: () => ({
          exec: jest.fn().mockResolvedValue({
            ...mockProductDoc,
            status: ProductStatus.DRAFT,
          }),
        }),
      }),
    });

    await expect(
      service.findById(String(productId), true, String(otherUserId)),
    ).rejects.toThrow(NotFoundException);

    const ownerView = await service.findById(
      String(productId),
      true,
      String(ownerId),
    );
    expect(ownerView.status).toBe(ProductStatus.DRAFT);
  });

  it('enforces product delete ownership and cleans up associated storage assets', async () => {
    MockProductModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue({ ...mockProductDoc }),
    });
    MockProductModel.deleteOne.mockReturnValue({
      exec: jest.fn().mockResolvedValue({ deletedCount: 1 }),
    });

    await expect(
      service.remove(String(productId), String(otherUserId)),
    ).rejects.toThrow(ForbiddenException);

    const deleted = await service.remove(String(productId), String(ownerId));
    expect(deleted).toEqual({ deleted: true, id: String(productId) });
    expect(mockUploadService.deleteManyAssets).toHaveBeenCalledWith([
      'products/test.png',
    ]);
  });

  it('throws NotFoundException when product ID is invalid', async () => {
    await expect(service.findById('not-an-object-id')).rejects.toThrow(
      NotFoundException,
    );
  });
});
