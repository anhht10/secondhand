import { ConflictException, NotFoundException } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { Product, ProductStatus } from '../products/schemas/product.schema';
import { User, UserStatus } from './schemas/user.schema';
import { UsersService } from './users.service';

describe('UsersService', () => {
  let service: UsersService;

  const mockUserId = new Types.ObjectId();
  const mockProductId = new Types.ObjectId();

  const mockUserDoc = {
    _id: mockUserId,
    id: String(mockUserId),
    email: 'khoa@remarket.vn',
    passwordHash: 'hashed-secret',
    displayName: 'Khoa Nguyen',
    avatarUrl: null,
    phoneNumber: '+84901234567',
    bio: 'CS Student',
    location: 'District 10, HCMC',
    isEmailVerified: false,
    status: UserStatus.ACTIVE,
    wishlist: [mockProductId],
    createdAt: new Date(),
    save: jest.fn(),
    toJSON: jest.fn().mockReturnValue({
      _id: mockUserId,
      id: String(mockUserId),
      email: 'khoa@remarket.vn',
      displayName: 'Khoa Nguyen',
      avatarUrl: null,
      phoneNumber: '+84901234567',
      bio: 'CS Student',
      location: 'District 10, HCMC',
      isEmailVerified: false,
      status: UserStatus.ACTIVE,
      wishlist: [mockProductId],
    }),
  };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const MockUserModel: any = jest.fn().mockImplementation((dto) => ({
    ...mockUserDoc,
    ...dto,
    save: jest.fn().mockResolvedValue({
      ...mockUserDoc,
      ...dto,
    }),
  }));

  MockUserModel.findOne = jest.fn();
  MockUserModel.findById = jest.fn();
  MockUserModel.findByIdAndUpdate = jest.fn();

  const mockProductModel = {
    findOne: jest.fn(),
    find: jest.fn(),
    countDocuments: jest.fn().mockReturnValue({
      exec: jest.fn().mockResolvedValue(2),
    }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getModelToken(User.name),
          useValue: MockUserModel,
        },
        {
          provide: getModelToken(Product.name),
          useValue: mockProductModel,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('creates a new user when email is unique', async () => {
    MockUserModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(null) }),
    });

    const result = await service.create({
      email: 'Khoa@ReMarket.vn',
      passwordHash: 'hashed-pw',
      displayName: 'Khoa Nguyen',
    });

    expect(result.email).toBe('khoa@remarket.vn');
    expect(result.displayName).toBe('Khoa Nguyen');
  });

  it('throws ConflictException when registering duplicate email', async () => {
    MockUserModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(mockUserDoc) }),
    });

    await expect(
      service.create({
        email: 'khoa@remarket.vn',
        passwordHash: 'hashed-pw',
        displayName: 'Khoa Nguyen',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('finds a user by valid ObjectId and throws NotFoundException on invalid ID', async () => {
    MockUserModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockUserDoc),
    });

    const user = await service.findById(String(mockUserId));
    expect(user.email).toBe('khoa@remarket.vn');

    await expect(service.findById('invalid-id')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('updates allowed user profile fields and strips passwordHash on sanitize', async () => {
    const updatedDoc = {
      ...mockUserDoc,
      displayName: 'Khoa Updated',
      bio: 'Updated bio',
    };
    MockUserModel.findByIdAndUpdate.mockReturnValue({
      exec: jest.fn().mockResolvedValue(updatedDoc),
    });

    const res = await service.updateProfile(String(mockUserId), {
      displayName: 'Khoa Updated',
      bio: 'Updated bio',
    });
    expect(res.displayName).toBe('Khoa Updated');

    const sanitized = service.sanitizeUser(res as never);
    expect(sanitized.passwordHash).toBeUndefined();
  });

  it('adds and removes valid ACTIVE products in user wishlist without duplicates', async () => {
    const mockActiveProduct = {
      _id: mockProductId,
      title: 'Sony WH-1000XM4',
      status: ProductStatus.ACTIVE,
    };

    mockProductModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(mockActiveProduct) }),
    });
    MockUserModel.findByIdAndUpdate.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockUserDoc),
    });
    MockUserModel.findById.mockReturnValue({
      exec: jest.fn().mockResolvedValue(mockUserDoc),
    });
    mockProductModel.find.mockReturnValue({
      populate: () => ({
        populate: () => ({
          exec: jest.fn().mockResolvedValue([mockActiveProduct]),
        }),
      }),
    });

    const wishlistAfterAdd = await service.addToWishlist(
      String(mockUserId),
      String(mockProductId),
    );
    expect(wishlistAfterAdd).toHaveLength(1);
    expect(MockUserModel.findByIdAndUpdate).toHaveBeenCalledWith(
      String(mockUserId),
      { $addToSet: { wishlist: mockProductId } },
      { new: true },
    );

    const wishlistAfterRemove = await service.removeFromWishlist(
      String(mockUserId),
      String(mockProductId),
    );
    expect(wishlistAfterRemove).toBeDefined();
    expect(MockUserModel.findByIdAndUpdate).toHaveBeenCalledWith(
      String(mockUserId),
      { $pull: { wishlist: mockProductId } },
      { new: true },
    );
  });
});
