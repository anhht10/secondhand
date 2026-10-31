import {
  BadGatewayException,
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Types } from 'mongoose';
import { ProductsService } from '../products/products.service';
import {
  ProductCondition,
  ProductDocument,
  ProductStatus,
} from '../products/schemas/product.schema';
import { AiHttpClient, AiRequestContext } from './ai-http.client';
import {
  AiChatDto,
  BuyerChecklistDto,
  EstimatePriceDto,
  GenerateListingDto,
} from './dto/ai.dto';

export interface ListingDescriptionSections {
  overview: string;
  condition: string;
  defects: string;
}

export interface GeneratedListingResult {
  suggestedTitle: string;
  suggestedDescription: ListingDescriptionSections;
  suggestedDescriptionText: string;
  suggestedCategory: string;
  suggestedTags: string[];
  transparencyNote: string;
  transparencyScore: number;
  needsMoreInfo: boolean;
  clarificationQuestions: string[];
  requiresSellerApproval: boolean;
  aiProvider: string;
  requestId?: string;
}

export interface EstimatedPriceResult {
  quickSellPrice: number;
  recommendedPrice: number;
  maxFairPrice: number;
  currency: string;
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  comparableCount: number;
  factors: string[];
  dataSourceNote: string;
  warnings: string[];
  depreciationPercent: number;
  marketDemand: 'HIGH' | 'MEDIUM' | 'LOW';
  reasoning: string;
  requiresSellerDecision: boolean;
  aiProvider: string;
  requestId?: string;
}

export interface InspectionPointItem {
  title: string;
  description: string;
  importance: 'HIGH' | 'MEDIUM' | 'LOW';
}

export interface BuyerChecklistResult {
  productId?: string | null;
  inspectionPoints: InspectionPointItem[];
  suggestedQuestions: string[];
  safetyTips: string[];
  safetyTip: string;
  advisoryOnly: boolean;
  generatedAt: Date;
  cached: boolean;
  aiProvider: string;
  requestId?: string;
}

export interface SerializedProductCard {
  _id: string;
  id: string;
  sellerId: string | null;
  categoryId: string | null;
  title: string;
  description: string;
  price: number;
  originalPrice?: number | null;
  condition: string;
  images: Array<{
    url: string;
    publicId?: string | null;
    sortOrder?: number;
    altText?: string | null;
  }>;
  location: string;
  status: string;
  brand?: string | null;
  defectDisclosure?: string | null;
  transparencyScore?: number | null;
  category?: string | null;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  constructor(
    private readonly aiHttpClient: AiHttpClient,
    private readonly productsService: ProductsService,
  ) {}

  private assertNoClientSuppliedUserId(payload: unknown): void {
    if (!payload || typeof payload !== 'object') return;
    const record = payload as Record<string, unknown>;
    const forbiddenKeys = [
      'user_id',
      'userId',
      'current_user_id',
      'authenticated_user_id',
      'owner_user_id',
    ];
    for (const key of forbiddenKeys) {
      if (key in record && record[key] !== undefined) {
        throw new BadRequestException({
          code: 'VALIDATION_ERROR',
          message: `Client-supplied '${key}' is forbidden. User identity is extracted exclusively from the verified JWT.`,
        });
      }
    }
  }

  /**
   * AI 1: AI-Assisted Listing Generator (`POST /api/v1/ai/generate-listing`)
   */
  async generateListing(
    dto: GenerateListingDto,
    context?: AiRequestContext,
  ): Promise<GeneratedListingResult> {
    this.assertNoClientSuppliedUserId(dto);

    const resolvedName = (dto.productName || dto.title || '').trim();
    if (!resolvedName || resolvedName.length < 2) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'productName or title is required (minimum 2 characters)',
      });
    }

    const resolvedDefects = (dto.defects ?? dto.defectDisclosure ?? '').trim();
    const resolvedPrice = dto.sellingPrice ?? dto.price;
    const resolvedImages = dto.images ?? dto.imageUrls ?? [];

    const requestPayload = {
      productName: resolvedName,
      title: resolvedName,
      brand: dto.brand?.trim() || undefined,
      category: dto.category?.trim() || undefined,
      condition: (dto.condition || ProductCondition.GOOD).trim().toUpperCase(),
      defects: resolvedDefects || undefined,
      defectDisclosure: resolvedDefects || undefined,
      originalPrice: dto.originalPrice,
      sellingPrice: resolvedPrice,
      price: resolvedPrice,
      images: resolvedImages,
      imageUrls: resolvedImages,
      imageBase64: dto.imageBase64,
      imageMimeType: dto.imageMimeType,
    };

    const rawResponse = await this.aiHttpClient.post<Record<string, unknown>>(
      '/ai/generate-listing',
      requestPayload,
      context,
    );

    if (
      !rawResponse ||
      typeof rawResponse.suggestedTitle !== 'string' ||
      !rawResponse.suggestedTitle.trim()
    ) {
      throw new BadGatewayException({
        code: 'AI_INVALID_RESPONSE',
        message:
          'AI Service returned an invalid generate-listing response schema',
      });
    }

    const rawDesc = rawResponse.suggestedDescription;
    let structuredDesc: ListingDescriptionSections;
    if (rawDesc && typeof rawDesc === 'object') {
      const descObj = rawDesc as Record<string, unknown>;
      structuredDesc = {
        overview: String(descObj.overview || resolvedName).trim(),
        condition: String(
          descObj.condition || requestPayload.condition,
        ).trim(),
        defects: String(
          descObj.defects ||
            resolvedDefects ||
            'Người bán chưa khai báo khuyết điểm cụ thể.',
        ).trim(),
      };
    } else if (typeof rawDesc === 'string' && rawDesc.trim()) {
      structuredDesc = {
        overview: rawDesc.trim(),
        condition: requestPayload.condition,
        defects:
          resolvedDefects || 'Người bán chưa khai báo khuyết điểm cụ thể.',
      };
    } else {
      throw new BadGatewayException({
        code: 'AI_INVALID_RESPONSE',
        message:
          'AI Service response is missing structured suggestedDescription',
      });
    }

    const flattenedText =
      typeof rawResponse.suggestedDescriptionText === 'string' &&
      rawResponse.suggestedDescriptionText.trim()
        ? rawResponse.suggestedDescriptionText.trim()
        : `1. Tổng quan: ${structuredDesc.overview}\n2. Tình trạng: ${structuredDesc.condition}\n3. Khuyết điểm khai báo: ${structuredDesc.defects}`;

    return {
      suggestedTitle: rawResponse.suggestedTitle.trim(),
      suggestedDescription: structuredDesc,
      suggestedDescriptionText: flattenedText,
      suggestedCategory: String(
        rawResponse.suggestedCategory || dto.category || 'Phụ kiện & Khác',
      ).trim(),
      suggestedTags: Array.isArray(rawResponse.suggestedTags)
        ? rawResponse.suggestedTags.map((t) => String(t))
        : [],
      transparencyNote: String(rawResponse.transparencyNote || '').trim(),
      transparencyScore:
        typeof rawResponse.transparencyScore === 'number'
          ? rawResponse.transparencyScore
          : 90,
      needsMoreInfo: Boolean(rawResponse.needsMoreInfo),
      clarificationQuestions: Array.isArray(
        rawResponse.clarificationQuestions,
      )
        ? rawResponse.clarificationQuestions.map((q) => String(q))
        : [],
      requiresSellerApproval: true,
      aiProvider: String(rawResponse.aiProvider || 'gemini-3.8-flash'),
      requestId:
        typeof rawResponse.requestId === 'string'
          ? rawResponse.requestId
          : this.aiHttpClient.resolveRequestId(context),
    };
  }

  /**
   * AI 2: AI Smart Price Estimator (`POST /api/v1/ai/estimate-price`)
   */
  async estimatePrice(
    dto: EstimatePriceDto,
    context?: AiRequestContext,
  ): Promise<EstimatedPriceResult> {
    this.assertNoClientSuppliedUserId(dto);

    const resolvedName = (dto.productName || dto.title || '').trim();
    if (!resolvedName || resolvedName.length < 2) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'productName or title is required (minimum 2 characters)',
      });
    }

    const resolvedDefects = (dto.defects ?? dto.defectDisclosure ?? '').trim();

    const requestPayload = {
      productName: resolvedName,
      title: resolvedName,
      brand: dto.brand?.trim() || undefined,
      category: dto.category?.trim() || undefined,
      condition: (dto.condition || ProductCondition.GOOD).trim().toUpperCase(),
      defects: resolvedDefects || undefined,
      defectDisclosure: resolvedDefects || undefined,
      originalPrice: dto.originalPrice,
    };

    const rawResponse = await this.aiHttpClient.post<Record<string, unknown>>(
      '/ai/estimate-price',
      requestPayload,
      context,
    );

    const quickSellPrice = Number(rawResponse?.quickSellPrice);
    const recommendedPrice = Number(rawResponse?.recommendedPrice);
    const maxFairPrice = Number(rawResponse?.maxFairPrice);

    if (
      !Number.isFinite(quickSellPrice) ||
      !Number.isFinite(recommendedPrice) ||
      !Number.isFinite(maxFairPrice) ||
      quickSellPrice <= 0 ||
      quickSellPrice > recommendedPrice ||
      recommendedPrice > maxFairPrice
    ) {
      throw new BadGatewayException({
        code: 'AI_INVALID_RESPONSE',
        message:
          'AI Service returned invalid price tiers (expected 0 < quickSellPrice <= recommendedPrice <= maxFairPrice)',
      });
    }

    const confidenceRaw = String(rawResponse.confidence || 'MEDIUM')
      .trim()
      .toUpperCase();
    const confidence: 'HIGH' | 'MEDIUM' | 'LOW' =
      confidenceRaw === 'HIGH' ||
      confidenceRaw === 'MEDIUM' ||
      confidenceRaw === 'LOW'
        ? confidenceRaw
        : 'MEDIUM';

    const marketDemandRaw = String(
      rawResponse.marketDemand || confidence,
    ).toUpperCase();
    const marketDemand: 'HIGH' | 'MEDIUM' | 'LOW' =
      marketDemandRaw === 'HIGH' ||
      marketDemandRaw === 'MEDIUM' ||
      marketDemandRaw === 'LOW'
        ? marketDemandRaw
        : 'MEDIUM';

    return {
      quickSellPrice,
      recommendedPrice,
      maxFairPrice,
      currency: String(rawResponse.currency || 'VND'),
      confidence,
      comparableCount:
        typeof rawResponse.comparableCount === 'number'
          ? rawResponse.comparableCount
          : 0,
      factors: Array.isArray(rawResponse.factors)
        ? rawResponse.factors.map((f) => String(f))
        : [],
      dataSourceNote: String(rawResponse.dataSourceNote || ''),
      warnings: Array.isArray(rawResponse.warnings)
        ? rawResponse.warnings.map((w) => String(w))
        : [],
      depreciationPercent:
        typeof rawResponse.depreciationPercent === 'number'
          ? rawResponse.depreciationPercent
          : 30,
      marketDemand,
      reasoning: String(rawResponse.reasoning || rawResponse.dataSourceNote || ''),
      requiresSellerDecision: true,
      aiProvider: String(rawResponse.aiProvider || 'gemini-3.8-flash'),
      requestId:
        typeof rawResponse.requestId === 'string'
          ? rawResponse.requestId
          : this.aiHttpClient.resolveRequestId(context),
    };
  }

  /**
   * AI 3: AI Buyer Inspection Checklist (`POST /api/v1/ai/buyer-checklist`)
   */
  async buyerChecklist(
    dto: BuyerChecklistDto,
    context?: AiRequestContext,
  ): Promise<BuyerChecklistResult> {
    this.assertNoClientSuppliedUserId(dto);

    const resolvedProductId = (dto.productId || dto.product_id || '').trim();
    let productTitle = (dto.title || dto.productName || '').trim();
    let productBrand = (dto.brand || '').trim();
    let productCategory = (dto.category || '').trim();
    let productCondition = (
      dto.condition || ProductCondition.GOOD
    ).toUpperCase();
    let productPrice = dto.price;
    let productDefect = (dto.defects ?? dto.defectDisclosure ?? '').trim();
    let productDescription = (dto.description || '').trim();
    let productImages = dto.images ?? dto.imageUrls ?? [];

    if (resolvedProductId) {
      if (!Types.ObjectId.isValid(resolvedProductId)) {
        throw new NotFoundException({
          code: 'PRODUCT_NOT_FOUND',
          message: `Product listing '${resolvedProductId}' was not found`,
        });
      }

      let product: ProductDocument;
      try {
        product = await this.productsService.findById(
          resolvedProductId,
          false,
          context?.userId,
        );
      } catch (error) {
        if (error instanceof ForbiddenException) {
          throw new ForbiddenException({
            code: 'FORBIDDEN',
            message: error.message || 'Access to this product is forbidden',
          });
        }
        throw new NotFoundException({
          code: 'PRODUCT_NOT_FOUND',
          message: `Product listing '${resolvedProductId}' was not found`,
        });
      }

      if (
        product.aiChecklistCache &&
        Array.isArray(product.aiChecklistCache.inspectionPoints) &&
        product.aiChecklistCache.inspectionPoints.length >= 3 &&
        !dto.forceRefresh
      ) {
        const cachedPoints = product.aiChecklistCache.inspectionPoints.map(
          (rawPoint) => this.deserializeCachedInspectionPoint(rawPoint),
        );
        const safetyTip =
          product.aiChecklistCache.safetyTip ||
          'Ưu tiên giao dịch trực tiếp tại khuôn viên trường hoặc nơi công cộng, kiểm tra kỹ sản phẩm trước khi thanh toán.';
        return {
          productId: String(product._id),
          inspectionPoints: cachedPoints,
          suggestedQuestions:
            product.aiChecklistCache.suggestedQuestions ?? [],
          safetyTips: [safetyTip],
          safetyTip,
          advisoryOnly: true,
          generatedAt: product.aiChecklistCache.generatedAt ?? new Date(),
          cached: true,
          aiProvider: 'mongodb-cache',
          requestId: this.aiHttpClient.resolveRequestId(context),
        };
      }

      productTitle = product.title;
      productBrand = product.brand ?? productBrand;
      const catPopulated = product.categoryId as unknown as {
        name?: string;
        slug?: string;
      };
      productCategory =
        catPopulated?.name || catPopulated?.slug || productCategory;
      productCondition = product.condition;
      productPrice = product.price;
      productDefect = product.defectDisclosure ?? productDefect;
      productDescription = product.description ?? productDescription;
      if (Array.isArray(product.images) && product.images.length > 0) {
        productImages = product.images
          .map((img) => img?.url)
          .filter((u): u is string => Boolean(u));
      }
    } else if (!productTitle || productTitle.length < 2) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message:
          'Either a valid productId or title/productName (minimum 2 characters) is required',
      });
    }

    const requestPayload = {
      productId: resolvedProductId || undefined,
      title: productTitle,
      productName: productTitle,
      brand: productBrand || undefined,
      category: productCategory || undefined,
      condition: productCondition,
      price: productPrice,
      defects: productDefect || undefined,
      defectDisclosure: productDefect || undefined,
      description: productDescription || undefined,
      images: productImages,
    };

    const rawResponse = await this.aiHttpClient.post<Record<string, unknown>>(
      '/ai/buyer-checklist',
      requestPayload,
      context,
    );

    if (
      !rawResponse ||
      !Array.isArray(rawResponse.inspectionPoints) ||
      rawResponse.inspectionPoints.length < 3 ||
      !Array.isArray(rawResponse.suggestedQuestions) ||
      rawResponse.suggestedQuestions.length < 3
    ) {
      throw new BadGatewayException({
        code: 'AI_INVALID_RESPONSE',
        message:
          'AI Service returned an invalid buyer-checklist response schema',
      });
    }

    const normalizedPoints: InspectionPointItem[] =
      rawResponse.inspectionPoints.slice(0, 4).map((p) => {
        if (p && typeof p === 'object') {
          const obj = p as Record<string, unknown>;
          const impRaw = String(obj.importance || 'HIGH').toUpperCase();
          const importance: 'HIGH' | 'MEDIUM' | 'LOW' =
            impRaw === 'HIGH' || impRaw === 'MEDIUM' || impRaw === 'LOW'
              ? impRaw
              : 'HIGH';
          return {
            title: String(obj.title || 'Điểm kiểm tra thực tế').trim(),
            description: String(
              obj.description ||
                'Kiểm tra kỹ tình trạng thực tế của sản phẩm.',
            ).trim(),
            importance,
          };
        }
        return this.deserializeCachedInspectionPoint(String(p));
      });

    const suggestedQuestions = rawResponse.suggestedQuestions
      .slice(0, 3)
      .map((q) => String(q).trim());

    const safetyTips = Array.isArray(rawResponse.safetyTips)
      ? rawResponse.safetyTips.map((s) => String(s).trim()).filter(Boolean)
      : [];
    const primarySafetyTip =
      typeof rawResponse.safetyTip === 'string' && rawResponse.safetyTip.trim()
        ? rawResponse.safetyTip.trim()
        : safetyTips[0] ||
          'Luôn kiểm tra trực tiếp sản phẩm ở nơi công cộng và không chuyển khoản đặt cọc trước.';
    if (safetyTips.length === 0) {
      safetyTips.push(primarySafetyTip);
    }

    const generatedAt = new Date();
    if (resolvedProductId) {
      await this.productsService.saveAiChecklistCache(resolvedProductId, {
        inspectionPoints: normalizedPoints.map((pt) => JSON.stringify(pt)),
        suggestedQuestions,
        safetyTip: primarySafetyTip,
        generatedAt,
      });
    }

    return {
      productId: resolvedProductId || null,
      inspectionPoints: normalizedPoints,
      suggestedQuestions,
      safetyTips,
      safetyTip: primarySafetyTip,
      advisoryOnly: true,
      generatedAt,
      cached: false,
      aiProvider: String(rawResponse.aiProvider || 'gemini-3.8-flash'),
      requestId:
        typeof rawResponse.requestId === 'string'
          ? rawResponse.requestId
          : this.aiHttpClient.resolveRequestId(context),
    };
  }

  /**
   * AI 4: AI Secondhand Shopping Assistant (`POST /api/v1/ai/chat`)
   */
  async chat(dto: AiChatDto, context?: AiRequestContext) {
    this.assertNoClientSuppliedUserId(dto);

    const threadId = (
      dto.thread_id ||
      dto.conversation_id ||
      dto.previousInteractionId ||
      ''
    ).trim();

    const requestPayload = {
      message: dto.message.trim(),
      thread_id: threadId || undefined,
      conversation_id: threadId || undefined,
      previousInteractionId: threadId || undefined,
      maxBudget: dto.maxBudget,
      category: dto.category?.trim() || undefined,
    };

    const rawResponse = await this.aiHttpClient.post<Record<string, unknown>>(
      '/ai/chat',
      requestPayload,
      context,
    );

    const messageText = String(
      rawResponse?.message || rawResponse?.reply || '',
    ).trim();
    if (!messageText) {
      throw new BadGatewayException({
        code: 'AI_INVALID_RESPONSE',
        message: 'AI Service returned an empty chat response message',
      });
    }

    const resolvedThreadId = String(
      rawResponse.thread_id ||
        rawResponse.conversation_id ||
        rawResponse.interactionId ||
        threadId ||
        `conv-${Date.now()}`,
    );

    // Extract candidate product IDs from AI response and verify against MongoDB ACTIVE products
    const candidateIds: string[] = [];
    if (Array.isArray(rawResponse.matchedProductIds)) {
      for (const id of rawResponse.matchedProductIds) {
        const strId = String(id || '').trim();
        if (strId && !candidateIds.includes(strId)) {
          candidateIds.push(strId);
        }
      }
    }
    if (Array.isArray(rawResponse.matchedProducts)) {
      for (const item of rawResponse.matchedProducts) {
        if (item && typeof item === 'object') {
          const obj = item as Record<string, unknown>;
          const strId = String(obj._id || obj.id || '').trim();
          if (strId && !candidateIds.includes(strId)) {
            candidateIds.push(strId);
          }
        }
      }
    }

    // Strictly verify against MongoDB with onlyActive = true so deleted/SOLD/DRAFT/ARCHIVED products are NEVER returned
    const activeDocs = await this.productsService.findManyByIds(
      candidateIds,
      true,
    );
    const verifiedProducts = activeDocs
      .filter((doc) => doc.status === ProductStatus.ACTIVE)
      .map((doc) => this.serializeProductCard(doc));
    const verifiedProductIds = verifiedProducts.map((p) => p.id);

    const suggestedActions = Array.isArray(rawResponse.suggestedActions)
      ? rawResponse.suggestedActions.map((a) => String(a))
      : Array.isArray(rawResponse.suggestedFollowUps)
        ? rawResponse.suggestedFollowUps.map((a) => String(a))
        : [];

    const sources = Array.isArray(rawResponse.sources)
      ? rawResponse.sources.map((s) => String(s))
      : [];

    return {
      thread_id: resolvedThreadId,
      conversation_id: resolvedThreadId,
      interactionId: resolvedThreadId,
      intent: String(rawResponse.intent || 'PRODUCT_DISCOVERY'),
      message: messageText,
      reply: messageText,
      matchedProductIds: verifiedProductIds,
      matchedProducts: verifiedProducts,
      suggestedActions,
      suggestedFollowUps: suggestedActions,
      sources,
      aiProvider: String(rawResponse.aiProvider || 'gemini-3.8-flash'),
      requestId:
        typeof rawResponse.requestId === 'string'
          ? rawResponse.requestId
          : this.aiHttpClient.resolveRequestId(context),
    };
  }

  /**
   * Retrieve multi-turn conversation history (`GET /api/v1/ai/conversations/:conversationId`)
   */
  async getConversation(
    conversationId: string,
    context?: AiRequestContext,
  ): Promise<Record<string, unknown>> {
    const cleanedId = (conversationId || '').trim();
    if (!cleanedId) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'conversationId is required',
      });
    }
    return this.aiHttpClient.get<Record<string, unknown>>(
      `/ai/conversations/${encodeURIComponent(cleanedId)}`,
      context,
    );
  }

  /**
   * Delete multi-turn conversation history (`DELETE /api/v1/ai/conversations/:conversationId`)
   */
  async deleteConversation(
    conversationId: string,
    context?: AiRequestContext,
  ): Promise<Record<string, unknown>> {
    const cleanedId = (conversationId || '').trim();
    if (!cleanedId) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'conversationId is required',
      });
    }
    return this.aiHttpClient.delete<Record<string, unknown>>(
      `/ai/conversations/${encodeURIComponent(cleanedId)}`,
      context,
    );
  }

  private deserializeCachedInspectionPoint(
    rawPoint: string,
  ): InspectionPointItem {
    const trimmed = (rawPoint || '').trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        const parsed = JSON.parse(trimmed) as Record<string, unknown>;
        if (parsed && typeof parsed.title === 'string') {
          const imp = String(parsed.importance || 'HIGH').toUpperCase();
          return {
            title: parsed.title,
            description: String(parsed.description || parsed.title),
            importance:
              imp === 'HIGH' || imp === 'MEDIUM' || imp === 'LOW'
                ? imp
                : 'HIGH',
          };
        }
      } catch {
        // Fallback to plain string parsing below
      }
    }
    return {
      title: 'Điểm kiểm tra thực tế',
      description: trimmed || 'Kiểm tra trực tiếp tình trạng sản phẩm.',
      importance: 'HIGH',
    };
  }

  private serializeProductCard(doc: ProductDocument): SerializedProductCard {
    const idStr = String(doc._id);
    const sellerRef = doc.sellerId as unknown as {
      _id?: Types.ObjectId;
    } | null;
    const sellerIdStr = sellerRef?._id
      ? String(sellerRef._id)
      : doc.sellerId
        ? String(doc.sellerId)
        : null;

    const categoryRef = doc.categoryId as unknown as {
      _id?: Types.ObjectId;
      name?: string;
      slug?: string;
    } | null;
    const categoryIdStr = categoryRef?._id
      ? String(categoryRef._id)
      : doc.categoryId
        ? String(doc.categoryId)
        : null;

    return {
      _id: idStr,
      id: idStr,
      sellerId: sellerIdStr,
      categoryId: categoryIdStr,
      title: doc.title,
      description: doc.description ?? '',
      price: doc.price,
      originalPrice: doc.originalPrice ?? null,
      condition: doc.condition,
      images: (doc.images ?? []).map((img, idx) => ({
        url: img.url,
        publicId: img.publicId ?? null,
        sortOrder: img.sortOrder ?? idx,
        altText: img.altText ?? null,
      })),
      location: doc.location ?? '',
      status: doc.status ?? ProductStatus.ACTIVE,
      brand: doc.brand ?? null,
      defectDisclosure: doc.defectDisclosure ?? null,
      transparencyScore: doc.transparencyScore ?? null,
      category: categoryRef?.name ?? categoryRef?.slug ?? null,
    };
  }
}
