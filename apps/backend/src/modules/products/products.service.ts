import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, SortOrder, Types } from 'mongoose';
import { PaginationMeta } from '../../common/interfaces/api-response.interface';
import { MulterUploadedFile } from '../../common/interfaces/storage-provider.interface';
import { CategoriesService } from '../categories/categories.service';
import { MessagesService } from '../messages/messages.service';
import { ReportsService } from '../reports/reports.service';
import { MAX_IMAGE_COUNT, UploadService } from '../upload/upload.service';
import { CreateProductDto } from './dto/create-product.dto';
import { ProductSortBy, QueryProductDto } from './dto/query-product.dto';
import { UpdateProductStatusDto } from './dto/update-product-status.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import {
  AiChecklistCache,
  Product,
  ProductDocument,
  ProductImage,
  ProductStatus,
} from './schemas/product.schema';

export interface PaginatedProductsResult {
  items: ProductDocument[];
  meta: PaginationMeta;
}

@Injectable()
export class ProductsService {
  private static readonly ALLOWED_STATUS_TRANSITIONS: Record<
    ProductStatus,
    ProductStatus[]
  > = {
    [ProductStatus.DRAFT]: [
      ProductStatus.DRAFT,
      ProductStatus.ACTIVE,
      ProductStatus.ARCHIVED,
    ],
    [ProductStatus.ACTIVE]: [
      ProductStatus.ACTIVE,
      ProductStatus.RESERVED,
      ProductStatus.SOLD,
      ProductStatus.ARCHIVED,
      ProductStatus.DRAFT,
    ],
    [ProductStatus.RESERVED]: [
      ProductStatus.RESERVED,
      ProductStatus.ACTIVE,
      ProductStatus.SOLD,
      ProductStatus.ARCHIVED,
    ],
    [ProductStatus.SOLD]: [ProductStatus.SOLD, ProductStatus.ARCHIVED],
    [ProductStatus.ARCHIVED]: [
      ProductStatus.ARCHIVED,
      ProductStatus.ACTIVE,
      ProductStatus.DRAFT,
    ],
  };

  constructor(
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    private readonly categoriesService: CategoriesService,
    @Optional() private readonly uploadService?: UploadService,
    @Optional() private readonly messagesService?: MessagesService,
    @Optional() private readonly reportsService?: ReportsService,
  ) {}

  async create(
    sellerId: string,
    createDto: CreateProductDto,
  ): Promise<ProductDocument> {
    if (createDto.status === ProductStatus.SOLD) {
      throw new BadRequestException(
        'Cannot create a new product listing directly with SOLD status',
      );
    }

    await this.categoriesService.findById(createDto.categoryId);

    const normalizedImages: ProductImage[] = (createDto.images ?? []).map(
      (img, index) => ({
        url: img.url,
        publicId: img.publicId ?? null,
        sortOrder: img.sortOrder ?? index,
        altText: img.altText ?? null,
      }),
    );

    if (normalizedImages.length > MAX_IMAGE_COUNT) {
      throw new BadRequestException(
        `A product cannot have more than ${MAX_IMAGE_COUNT} images`,
      );
    }

    const created = new this.productModel({
      sellerId: new Types.ObjectId(sellerId),
      categoryId: new Types.ObjectId(createDto.categoryId),
      title: createDto.title.trim(),
      description: createDto.description.trim(),
      price: createDto.price,
      condition: createDto.condition,
      images: normalizedImages,
      location: createDto.location.trim(),
      status: createDto.status ?? ProductStatus.ACTIVE,
      brand: createDto.brand?.trim() ?? null,
      originalPrice: createDto.originalPrice ?? null,
      defectDisclosure: createDto.defectDisclosure?.trim() ?? null,
      transparencyNote: createDto.transparencyNote?.trim() ?? null,
      transparencyScore: createDto.transparencyScore ?? null,
      tags: createDto.tags ?? [],
      aiChecklistCache: createDto.aiChecklistCache
        ? {
            inspectionPoints: createDto.aiChecklistCache.inspectionPoints ?? [],
            suggestedQuestions:
              createDto.aiChecklistCache.suggestedQuestions ?? [],
            safetyTip: createDto.aiChecklistCache.safetyTip ?? null,
            generatedAt: createDto.aiChecklistCache.generatedAt ?? new Date(),
          }
        : null,
      viewCount: 0,
    });

    const saved = await created.save();
    return this.findById(String(saved._id), false, sellerId);
  }

  async findAllPublic(
    queryDto: QueryProductDto,
  ): Promise<PaginatedProductsResult> {
    const filter: FilterQuery<ProductDocument> = {
      status: ProductStatus.ACTIVE,
    };

    if (queryDto.sellerId && Types.ObjectId.isValid(queryDto.sellerId)) {
      filter.sellerId = new Types.ObjectId(queryDto.sellerId);
    }

    const categoryIdentifier = queryDto.categoryId ?? queryDto.category;
    if (categoryIdentifier) {
      const category =
        await this.categoriesService.findBySlugOrId(categoryIdentifier);
      if (!category) {
        return this.buildEmptyPage(queryDto.page ?? 1, queryDto.limit ?? 12);
      }
      filter.categoryId = category._id;
    }

    this.applyCommonFilters(filter, queryDto);

    return this.executePaginatedQuery(filter, queryDto);
  }

  async findMyListings(
    sellerId: string,
    queryDto: QueryProductDto,
  ): Promise<PaginatedProductsResult> {
    const filter: FilterQuery<ProductDocument> = {
      sellerId: new Types.ObjectId(sellerId),
    };

    if (queryDto.status) {
      filter.status = queryDto.status;
    }

    const categoryIdentifier = queryDto.categoryId ?? queryDto.category;
    if (categoryIdentifier) {
      const category =
        await this.categoriesService.findBySlugOrId(categoryIdentifier);
      if (!category) {
        return this.buildEmptyPage(queryDto.page ?? 1, queryDto.limit ?? 12);
      }
      filter.categoryId = category._id;
    }

    this.applyCommonFilters(filter, queryDto);

    return this.executePaginatedQuery(filter, queryDto);
  }

  async findById(
    id: string,
    incrementView = true,
    viewerUserId?: string,
  ): Promise<ProductDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Product listing not found');
    }

    const existing = await this.productModel
      .findById(id)
      .populate(
        'sellerId',
        'displayName avatarUrl location isEmailVerified status reputationCache',
      )
      .populate('categoryId', 'name slug icon')
      .exec();

    if (!existing) {
      throw new NotFoundException('Product listing not found');
    }

    const sellerIdStr = String(
      (existing.sellerId as unknown as { _id?: Types.ObjectId })?._id ??
        existing.sellerId,
    );
    const isOwner = Boolean(
      viewerUserId && sellerIdStr === String(viewerUserId),
    );

    // Do not expose DRAFT or ARCHIVED products to non-owners
    if (
      (existing.status === ProductStatus.DRAFT ||
        existing.status === ProductStatus.ARCHIVED) &&
      !isOwner
    ) {
      throw new NotFoundException('Product listing not found');
    }

    if (incrementView && !isOwner) {
      const updated = await this.productModel
        .findByIdAndUpdate(id, { $inc: { viewCount: 1 } }, { new: true })
        .populate(
          'sellerId',
          'displayName avatarUrl location isEmailVerified status',
        )
        .populate('categoryId', 'name slug icon')
        .exec();

      if (updated) {
        return updated;
      }
    }

    return existing;
  }

  async update(
    id: string,
    sellerId: string,
    updateDto: UpdateProductDto,
  ): Promise<ProductDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Product listing not found');
    }

    const existing = await this.productModel.findById(id).exec();
    if (!existing) {
      throw new NotFoundException('Product listing not found');
    }

    if (String(existing.sellerId) !== String(sellerId)) {
      throw new ForbiddenException(
        'You do not have permission to update this product listing',
      );
    }

    if (updateDto.status !== undefined) {
      this.validateStatusTransition(existing.status, updateDto.status);
    }

    if (existing.status === ProductStatus.SOLD) {
      const hasContentModification =
        updateDto.title !== undefined ||
        updateDto.description !== undefined ||
        updateDto.price !== undefined ||
        updateDto.condition !== undefined ||
        updateDto.categoryId !== undefined ||
        updateDto.images !== undefined;

      if (hasContentModification) {
        throw new BadRequestException(
          'Cannot modify product details of a SOLD listing; only archiving is permitted',
        );
      }
    }

    if (updateDto.categoryId !== undefined) {
      await this.categoriesService.findById(updateDto.categoryId);
      existing.categoryId = new Types.ObjectId(updateDto.categoryId);
    }

    if (updateDto.title !== undefined) {
      existing.title = updateDto.title.trim();
    }
    if (updateDto.description !== undefined) {
      existing.description = updateDto.description.trim();
    }
    if (updateDto.price !== undefined) {
      existing.price = updateDto.price;
    }
    if (updateDto.condition !== undefined) {
      existing.condition = updateDto.condition;
    }
    if (updateDto.location !== undefined) {
      existing.location = updateDto.location.trim();
    }
    if (updateDto.status !== undefined) {
      existing.status = updateDto.status;
    }
    if (updateDto.brand !== undefined) {
      existing.brand = updateDto.brand ? updateDto.brand.trim() : null;
    }
    if (updateDto.originalPrice !== undefined) {
      existing.originalPrice = updateDto.originalPrice ?? null;
    }
    if (updateDto.defectDisclosure !== undefined) {
      existing.defectDisclosure = updateDto.defectDisclosure
        ? updateDto.defectDisclosure.trim()
        : null;
    }
    if (updateDto.transparencyNote !== undefined) {
      existing.transparencyNote = updateDto.transparencyNote
        ? updateDto.transparencyNote.trim()
        : null;
    }
    if (updateDto.transparencyScore !== undefined) {
      existing.transparencyScore = updateDto.transparencyScore ?? null;
    }
    if (updateDto.tags !== undefined) {
      existing.tags = updateDto.tags ?? [];
    }
    if (updateDto.aiChecklistCache !== undefined) {
      existing.aiChecklistCache = updateDto.aiChecklistCache
        ? {
            inspectionPoints: updateDto.aiChecklistCache.inspectionPoints ?? [],
            suggestedQuestions:
              updateDto.aiChecklistCache.suggestedQuestions ?? [],
            safetyTip: updateDto.aiChecklistCache.safetyTip ?? null,
            generatedAt: updateDto.aiChecklistCache.generatedAt ?? new Date(),
          }
        : null;
    }
    if (updateDto.images !== undefined) {
      if (updateDto.images.length > MAX_IMAGE_COUNT) {
        throw new BadRequestException(
          `A product cannot have more than ${MAX_IMAGE_COUNT} images`,
        );
      }

      const newPublicIds = new Set(
        updateDto.images
          .map((img) => img.publicId)
          .filter((pid): pid is string => Boolean(pid)),
      );
      const removedPublicIds = (existing.images ?? [])
        .map((img) => img.publicId)
        .filter(
          (pid): pid is string =>
            typeof pid === 'string' && pid.length > 0 && !newPublicIds.has(pid),
        );

      if (removedPublicIds.length > 0 && this.uploadService) {
        await this.uploadService.deleteManyAssets(removedPublicIds);
      }

      existing.images = updateDto.images.map((img, index) => ({
        url: img.url,
        publicId: img.publicId ?? null,
        sortOrder: img.sortOrder ?? index,
        altText: img.altText ?? null,
      }));
    }

    await existing.save();
    return this.findById(String(existing._id), false, sellerId);
  }

  async updateStatus(
    id: string,
    sellerId: string,
    statusDto: UpdateProductStatusDto,
  ): Promise<ProductDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Product listing not found');
    }

    const existing = await this.productModel.findById(id).exec();
    if (!existing) {
      throw new NotFoundException('Product listing not found');
    }

    if (String(existing.sellerId) !== String(sellerId)) {
      throw new ForbiddenException(
        'You do not have permission to change the status of this product listing',
      );
    }

    this.validateStatusTransition(existing.status, statusDto.status);

    existing.status = statusDto.status;
    await existing.save();
    return this.findById(String(existing._id), false, sellerId);
  }

  async addUploadedImages(
    id: string,
    sellerId: string,
    files: MulterUploadedFile[],
    altTexts?: string[],
  ): Promise<ProductDocument> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Product listing not found');
    }

    const existing = await this.productModel.findById(id).exec();
    if (!existing) {
      throw new NotFoundException('Product listing not found');
    }

    if (String(existing.sellerId) !== String(sellerId)) {
      throw new ForbiddenException(
        'You do not have permission to modify images for this product listing',
      );
    }

    if (existing.status === ProductStatus.SOLD) {
      throw new BadRequestException(
        'Cannot add images to a SOLD product listing',
      );
    }

    if (!this.uploadService) {
      throw new BadRequestException('Upload service is not configured');
    }

    const currentImages = existing.images ?? [];
    if (currentImages.length + (files?.length ?? 0) > MAX_IMAGE_COUNT) {
      throw new BadRequestException(
        `Total images per product cannot exceed ${MAX_IMAGE_COUNT}`,
      );
    }

    const uploaded = await this.uploadService.uploadProductImages(
      files,
      altTexts,
      currentImages.length,
    );

    existing.images = [...currentImages, ...uploaded];
    await existing.save();

    return this.findById(String(existing._id), false, sellerId);
  }

  async remove(
    id: string,
    sellerId: string,
  ): Promise<{ deleted: boolean; id: string }> {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Product listing not found');
    }

    const existing = await this.productModel.findById(id).exec();
    if (!existing) {
      throw new NotFoundException('Product listing not found');
    }

    if (String(existing.sellerId) !== String(sellerId)) {
      throw new ForbiddenException(
        'You do not have permission to delete this product listing',
      );
    }

    if (existing.status === ProductStatus.SOLD) {
      throw new BadRequestException(
        'Cannot delete a SOLD product listing; please archive it instead',
      );
    }

    const imagePublicIds = (existing.images ?? [])
      .map((img) => img.publicId)
      .filter((pid): pid is string => Boolean(pid));

    if (imagePublicIds.length > 0 && this.uploadService) {
      await this.uploadService.deleteManyAssets(imagePublicIds);
    }

    const productIdStr = String(existing._id);
    if (this.messagesService) {
      await this.messagesService.deleteConversationsByProductId(productIdStr);
    }
    if (this.reportsService) {
      await this.reportsService.deleteReportsByProductId(productIdStr);
    }

    await this.productModel.deleteOne({ _id: existing._id }).exec();

    return {
      deleted: true,
      id: productIdStr,
    };
  }

  async saveAiChecklistCache(
    productId: string,
    cache: AiChecklistCache,
  ): Promise<void> {
    if (!Types.ObjectId.isValid(productId)) return;
    await this.productModel
      .findByIdAndUpdate(productId, { $set: { aiChecklistCache: cache } })
      .exec();
  }

  async findActiveForAiCatalog(limit = 30): Promise<ProductDocument[]> {
    return this.productModel
      .find({ status: ProductStatus.ACTIVE })
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate(
        'sellerId',
        'displayName avatarUrl location university isEmailVerified status',
      )
      .populate('categoryId', 'name slug icon')
      .exec();
  }

  async findManyByIds(
    ids: string[],
    onlyActive = true,
  ): Promise<ProductDocument[]> {
    const validIds = ids
      .filter((id) => Types.ObjectId.isValid(id))
      .map((id) => new Types.ObjectId(id));
    if (validIds.length === 0) return [];
    const queryFilter: FilterQuery<ProductDocument> = {
      _id: { $in: validIds },
    };
    if (onlyActive) {
      queryFilter.status = ProductStatus.ACTIVE;
    }
    const docs = await this.productModel
      .find(queryFilter)
      .populate(
        'sellerId',
        'displayName avatarUrl location university isEmailVerified status',
      )
      .populate('categoryId', 'name slug icon')
      .exec();
    const docMap = new Map<string, ProductDocument>(
      docs.map((d) => [String(d._id), d as ProductDocument]),
    );
    const ordered: ProductDocument[] = [];
    for (const id of ids) {
      const found = docMap.get(String(id));
      if (found) {
        ordered.push(found);
      }
    }
    return ordered;
  }

  private validateStatusTransition(
    currentStatus: ProductStatus,
    nextStatus: ProductStatus,
  ): void {
    const allowed =
      ProductsService.ALLOWED_STATUS_TRANSITIONS[currentStatus] ?? [];
    if (!allowed.includes(nextStatus)) {
      throw new BadRequestException(
        `Invalid product status transition from ${currentStatus} to ${nextStatus}`,
      );
    }
  }

  private applyCommonFilters(
    filter: FilterQuery<ProductDocument>,
    queryDto: QueryProductDto,
  ): void {
    if (queryDto.condition) {
      filter.condition = queryDto.condition;
    }

    if (queryDto.minPrice !== undefined || queryDto.maxPrice !== undefined) {
      if (
        queryDto.minPrice !== undefined &&
        queryDto.maxPrice !== undefined &&
        queryDto.minPrice > queryDto.maxPrice
      ) {
        throw new BadRequestException(
          'minPrice cannot be greater than maxPrice',
        );
      }

      const priceFilter: Record<string, number> = {};
      if (queryDto.minPrice !== undefined) {
        priceFilter.$gte = queryDto.minPrice;
      }
      if (queryDto.maxPrice !== undefined) {
        priceFilter.$lte = queryDto.maxPrice;
      }
      filter.price = priceFilter;
    }

    if (queryDto.location && queryDto.location.trim().length > 0) {
      const escapedLocation = this.escapeRegex(queryDto.location.trim());
      filter.location = { $regex: escapedLocation, $options: 'i' };
    }
  }

  private async executePaginatedQuery(
    baseFilter: FilterQuery<ProductDocument>,
    queryDto: QueryProductDto,
  ): Promise<PaginatedProductsResult> {
    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(100, Math.max(1, queryDto.limit ?? 12));
    const skip = (page - 1) * limit;

    const sortOption = queryDto.sort ?? queryDto.sortBy ?? ProductSortBy.NEWEST;
    const sortSpec: Record<string, SortOrder | { $meta: string }> =
      sortOption === ProductSortBy.PRICE_ASC
        ? { price: 1, createdAt: -1 }
        : sortOption === ProductSortBy.PRICE_DESC
          ? { price: -1, createdAt: -1 }
          : sortOption === ProductSortBy.POPULAR
            ? { viewCount: -1, createdAt: -1 }
            : { createdAt: -1, _id: -1 };

    const trimmedSearch = (queryDto.keyword ?? queryDto.search)?.trim();

    if (trimmedSearch && trimmedSearch.length > 0) {
      const textFilter: FilterQuery<ProductDocument> = {
        ...baseFilter,
        $text: { $search: trimmedSearch },
      };

      const textSortSpec: Record<string, SortOrder | { $meta: string }> =
        queryDto.sort || queryDto.sortBy
          ? sortSpec
          : { score: { $meta: 'textScore' }, createdAt: -1 };

      const [textItems, textTotal] = await Promise.all([
        this.productModel
          .find(textFilter, { score: { $meta: 'textScore' } })
          .sort(textSortSpec as Record<string, SortOrder>)
          .skip(skip)
          .limit(limit)
          .populate(
            'sellerId',
            'displayName avatarUrl location isEmailVerified status',
          )
          .populate('categoryId', 'name slug icon')
          .exec(),
        this.productModel.countDocuments(textFilter).exec(),
      ]);

      if (textTotal > 0) {
        const totalPages = Math.ceil(textTotal / limit) || 1;
        return {
          items: textItems,
          meta: {
            total: textTotal,
            page,
            limit,
            totalPages,
            hasNextPage: page < totalPages,
            hasPrevPage: page > 1,
          },
        };
      }

      const escapedSearch = this.escapeRegex(trimmedSearch);
      const regexFilter: FilterQuery<ProductDocument> = {
        ...baseFilter,
        $or: [
          { title: { $regex: escapedSearch, $options: 'i' } },
          { description: { $regex: escapedSearch, $options: 'i' } },
          { brand: { $regex: escapedSearch, $options: 'i' } },
        ],
      };

      return this.runStandardFind(
        regexFilter,
        sortSpec as Record<string, SortOrder>,
        page,
        limit,
        skip,
      );
    }

    return this.runStandardFind(
      baseFilter,
      sortSpec as Record<string, SortOrder>,
      page,
      limit,
      skip,
    );
  }

  private async runStandardFind(
    filter: FilterQuery<ProductDocument>,
    sortSpec: Record<string, SortOrder>,
    page: number,
    limit: number,
    skip: number,
  ): Promise<PaginatedProductsResult> {
    const [items, total] = await Promise.all([
      this.productModel
        .find(filter)
        .sort(sortSpec)
        .skip(skip)
        .limit(limit)
        .populate(
          'sellerId',
          'displayName avatarUrl location isEmailVerified status',
        )
        .populate('categoryId', 'name slug icon')
        .exec(),
      this.productModel.countDocuments(filter).exec(),
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

  private buildEmptyPage(page: number, limit: number): PaginatedProductsResult {
    return {
      items: [],
      meta: {
        total: 0,
        page,
        limit,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: page > 1,
      },
    };
  }

  private escapeRegex(input: string): string {
    return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
