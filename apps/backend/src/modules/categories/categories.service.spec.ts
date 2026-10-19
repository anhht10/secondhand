import { NotFoundException } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { CategoriesService } from './categories.service';
import { Category } from './schemas/category.schema';

describe('CategoriesService', () => {
  let service: CategoriesService;

  const rootCategoryId = new Types.ObjectId();
  const childCategoryId = new Types.ObjectId();

  const mockCategories = [
    {
      _id: rootCategoryId,
      name: 'Electronics',
      slug: 'electronics',
      parentId: null,
      isActive: true,
      sortOrder: 1,
    },
    {
      _id: childCategoryId,
      name: 'Computers & Accessories',
      slug: 'computers-accessories',
      parentId: rootCategoryId,
      isActive: true,
      sortOrder: 2,
    },
  ];

  const mockCategoryModel = {
    find: jest.fn(),
    findById: jest.fn(),
    findOne: jest.fn(),
    findOneAndUpdate: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoriesService,
        {
          provide: getModelToken(Category.name),
          useValue: mockCategoryModel,
        },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
  });

  it('seeds initial categories idempotently using $setOnInsert', async () => {
    mockCategoryModel.findOneAndUpdate.mockReturnValue({
      exec: jest.fn().mockResolvedValue({ _id: rootCategoryId }),
    });

    await service.seedInitialCategories();
    expect(mockCategoryModel.findOneAndUpdate).toHaveBeenCalled();
  });

  it('returns active categories sorted by sortOrder and supports parent-child filtering', async () => {
    mockCategoryModel.find.mockReturnValue({
      sort: () => ({
        exec: jest.fn().mockResolvedValue(mockCategories),
      }),
    });

    const all = await service.findAll();
    expect(all).toHaveLength(2);
    expect(String(all[1].parentId)).toBe(String(all[0]._id));

    await service.findAll('root');
    expect(mockCategoryModel.find).toHaveBeenLastCalledWith({
      isActive: true,
      parentId: null,
    });
  });

  it('finds category by valid ObjectId and throws NotFoundException for invalid or inactive category', async () => {
    mockCategoryModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockCategories[0]),
    });

    const found = await service.findById(String(rootCategoryId));
    expect(found.slug).toBe('electronics');

    await expect(service.findById('invalid-id')).rejects.toThrow(
      NotFoundException,
    );
  });
});
