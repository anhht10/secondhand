import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { Product, ProductStatus } from '../products/schemas/product.schema';
import { UploadService } from '../upload/upload.service';
import { ReportsService } from './reports.service';
import { Report, ReportStatus } from './schemas/report.schema';

describe('ReportsService', () => {
  let service: ReportsService;

  const reporterId = new Types.ObjectId();
  const sellerId = new Types.ObjectId();
  const productId = new Types.ObjectId();
  const reportId = new Types.ObjectId();

  const mockReportModel = {
    findOne: jest.fn(),
    create: jest.fn(),
    findById: jest.fn(),
    find: jest.fn(),
    countDocuments: jest.fn(),
    deleteMany: jest.fn(),
  };

  const mockProductModel = {
    findById: jest.fn(),
  };

  const mockUploadService = {
    uploadProductImages: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReportsService,
        {
          provide: getModelToken(Report.name),
          useValue: mockReportModel,
        },
        {
          provide: getModelToken(Product.name),
          useValue: mockProductModel,
        },
        {
          provide: UploadService,
          useValue: mockUploadService,
        },
      ],
    }).compile();

    service = module.get<ReportsService>(ReportsService);
  });

  it('creates a report for a valid product and sets status to PENDING', async () => {
    mockProductModel.findById.mockReturnValue({
      lean: () => ({
        exec: jest.fn().mockResolvedValue({
          _id: productId,
          sellerId,
          status: ProductStatus.ACTIVE,
        }),
      }),
    });
    mockReportModel.findOne.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(null) }),
    });
    const createdDoc = {
      _id: reportId,
      reporterId,
      productId,
      reason: 'COUNTERFEIT',
      status: ReportStatus.PENDING,
    };
    mockReportModel.create.mockResolvedValue(createdDoc);
    mockReportModel.findById.mockReturnValue({
      populate: () => ({ exec: jest.fn().mockResolvedValue(createdDoc) }),
    });

    const report = await service.create(String(reporterId), {
      productId: String(productId),
      reason: 'COUNTERFEIT',
      description: 'Fake serial number',
    });

    expect(report.status).toBe(ReportStatus.PENDING);
    expect(report.reason).toBe('COUNTERFEIT');
  });

  it('prevents a seller from reporting their own product and prevents duplicate reports', async () => {
    mockProductModel.findById.mockReturnValue({
      lean: () => ({
        exec: jest.fn().mockResolvedValue({
          _id: productId,
          sellerId,
          status: ProductStatus.ACTIVE,
        }),
      }),
    });

    await expect(
      service.create(String(sellerId), {
        productId: String(productId),
        reason: 'SPAM',
      }),
    ).rejects.toThrow(BadRequestException);

    mockReportModel.findOne.mockReturnValue({
      lean: () => ({
        exec: jest.fn().mockResolvedValue({ _id: reportId }),
      }),
    });

    await expect(
      service.create(String(reporterId), {
        productId: String(productId),
        reason: 'SPAM',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('throws NotFoundException when reporting a non-existent product', async () => {
    mockProductModel.findById.mockReturnValue({
      lean: () => ({ exec: jest.fn().mockResolvedValue(null) }),
    });

    await expect(
      service.create(String(reporterId), {
        productId: String(new Types.ObjectId()),
        reason: 'SCAM',
      }),
    ).rejects.toThrow(NotFoundException);
  });
});
