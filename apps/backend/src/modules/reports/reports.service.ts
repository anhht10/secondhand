import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { PaginationQueryDto } from '../messages/dto/query-messages.dto';
import { Product, ProductDocument } from '../products/schemas/product.schema';
import { UploadService } from '../upload/upload.service';
import { CreateReportDto } from './dto/create-report.dto';
import { Report, ReportDocument, ReportStatus } from './schemas/report.schema';

export interface PaginatedReportsResult {
  items: ReportDocument[];
  meta: PaginationMeta;
}

export const MAX_REPORT_EVIDENCE_COUNT = 5;

@Injectable()
export class ReportsService {
  constructor(
    @InjectModel(Report.name)
    private readonly reportModel: Model<ReportDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    @Optional() private readonly uploadService?: UploadService,
  ) {}

  async create(
    reporterId: string,
    createDto: CreateReportDto,
    evidenceFiles?: MulterUploadedFile[],
  ): Promise<ReportDocument> {
    if (!Types.ObjectId.isValid(createDto.productId)) {
      throw new NotFoundException('Product listing not found');
    }

    const product = await this.productModel
      .findById(createDto.productId)
      .lean()
      .exec();

    if (!product) {
      throw new NotFoundException('Product listing not found');
    }

    if (String(product.sellerId) === String(reporterId)) {
      throw new BadRequestException(
        'You cannot report your own product listing',
      );
    }

    const reporterObjId = new Types.ObjectId(reporterId);
    const productObjId = new Types.ObjectId(createDto.productId);

    const existingReport = await this.reportModel
      .findOne({
        reporterId: reporterObjId,
        productId: productObjId,
      })
      .lean()
      .exec();

    if (existingReport) {
      throw new ConflictException(
        'You have already submitted a report for this product listing',
      );
    }

    const evidenceUrls: string[] = [...(createDto.evidenceUrls ?? [])];

    if (evidenceFiles && evidenceFiles.length > 0) {
      if (!this.uploadService) {
        throw new BadRequestException('Upload service is not available');
      }
      if (
        evidenceUrls.length + evidenceFiles.length >
        MAX_REPORT_EVIDENCE_COUNT
      ) {
        throw new BadRequestException(
          `Cannot attach more than ${MAX_REPORT_EVIDENCE_COUNT} evidence images to a report`,
        );
      }
      const uploaded =
        await this.uploadService.uploadProductImages(evidenceFiles);
      evidenceUrls.push(...uploaded.map((u) => u.url));
    }

    if (evidenceUrls.length > MAX_REPORT_EVIDENCE_COUNT) {
      throw new BadRequestException(
        `Cannot attach more than ${MAX_REPORT_EVIDENCE_COUNT} evidence images to a report`,
      );
    }

    try {
      const created = await this.reportModel.create({
        reporterId: reporterObjId,
        productId: productObjId,
        reason: createDto.reason.trim(),
        description: createDto.description?.trim() ?? null,
        evidenceUrls,
        status: ReportStatus.PENDING,
      });

      const populated = await this.reportModel
        .findById(created._id)
        .populate('productId', 'title price condition status images location')
        .exec();

      return populated ?? created;
    } catch (err) {
      if ((err as { code?: number })?.code === 11000) {
        throw new ConflictException(
          'You have already submitted a report for this product listing',
        );
      }
      throw err;
    }
  }

  async findMyReports(
    reporterId: string,
    queryDto: PaginationQueryDto,
  ): Promise<PaginatedReportsResult> {
    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(100, Math.max(1, queryDto.limit ?? 20));
    const skip = (page - 1) * limit;

    const filter: FilterQuery<ReportDocument> = {
      reporterId: new Types.ObjectId(reporterId),
    };

    const [items, total] = await Promise.all([
      this.reportModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('productId', 'title price condition status images location')
        .exec(),
      this.reportModel.countDocuments(filter).exec(),
    ]);

    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items,
      meta: {
        total,
        page,
        limit,
        totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  async deleteReportsByProductId(productId: string): Promise<void> {
    if (!Types.ObjectId.isValid(productId)) return;
    await this.reportModel
      .deleteMany({ productId: new Types.ObjectId(productId) })
      .exec();
  }
}
