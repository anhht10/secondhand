import {
  BadGatewayException,
  BadRequestException,
  ForbiddenException,
  GatewayTimeoutException,
  HttpException,
  HttpStatus,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Types } from 'mongoose';
import { ProductsService } from '../products/products.service';
import {
  ProductCondition,
  ProductStatus,
} from '../products/schemas/product.schema';
import { AiHttpClient } from './ai-http.client';
import { AiService } from './ai.service';

describe('AiService (Phase 4 Integration)', () => {
  let service: AiService;

  const userAId = '65f1a2b3c4d5e6f7a8b9c0d1';
  const userBId = '65f1a2b3c4d5e6f7a8b9c0d2';
  const mockProductId = new Types.ObjectId('65f000000000000000000101');
  const mockSellerId = new Types.ObjectId(userAId);
  const mockCategoryId = new Types.ObjectId('65f000000000000000000010');

  const mockProduct = {
    _id: mockProductId,
    sellerId: { _id: mockSellerId, displayName: 'Seller A' },
    categoryId: {
      _id: mockCategoryId,
      name: 'Máy tính & Phụ kiện',
      slug: 'computers-accessories',
    },
    title: 'Keychron K6 Wireless Mechanical Keyboard',
    brand: 'Keychron',
    price: 1350000,
    originalPrice: 2450000,
    condition: ProductCondition.LIKE_NEW,
    defectDisclosure: 'Xước nhẹ 1mm cạnh khung nhôm',
    description: 'Bàn phím cơ không dây 65% Gateron Brown switch.',
    images: [{ url: 'https://cdn.remarket.vn/k6.jpg', sortOrder: 0 }],
    location: 'Thủ Đức, TP.HCM',
    status: ProductStatus.ACTIVE,
    aiChecklistCache: null,
  };

  const mockProductsService = {
    findById: jest.fn(),
    saveAiChecklistCache: jest.fn().mockResolvedValue(undefined),
    findActiveForAiCatalog: jest.fn().mockResolvedValue([mockProduct]),
    findManyByIds: jest.fn().mockResolvedValue([mockProduct]),
  };

  const mockAiHttpClient = {
    post: jest.fn(),
    get: jest.fn(),
    delete: jest.fn(),
    resolveRequestId: jest.fn().mockReturnValue('req-test-123456'),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockProductsService.findById.mockResolvedValue(mockProduct);
    mockProductsService.findManyByIds.mockResolvedValue([mockProduct]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AiService,
        { provide: AiHttpClient, useValue: mockAiHttpClient },
        { provide: ProductsService, useValue: mockProductsService },
      ],
    }).compile();

    service = module.get<AiService>(AiService);
  });

  it('AI 1: generates structured 3-part listing with transparency note via Python AI Service', async () => {
    mockAiHttpClient.post.mockResolvedValueOnce({
      suggestedTitle: '[Pass Nhanh] Keychron Bàn phím cơ Keychron K6 - Như mới',
      suggestedDescription: {
        overview: 'Bàn phím cơ Keychron K6 chính hãng.',
        condition: 'Tình trạng LIKE_NEW (99%).',
        defects: 'Xước nhẹ 1mm cạnh nhôm.',
      },
      suggestedCategory: 'Máy tính & Phụ kiện',
      suggestedTags: ['keychron', 'maytinhphukien', 'remarket'],
      transparencyNote:
        'Người bán đã khai báo: Xước nhẹ 1mm cạnh nhôm. Chỉ đăng sau khi duyệt.',
      transparencyScore: 95,
      needsMoreInfo: false,
      clarificationQuestions: [],
      requiresSellerApproval: true,
      aiProvider: 'gemini-3.8-flash',
      requestId: 'req-gen-01',
    });

    const res = await service.generateListing(
      {
        title: 'Bàn phím cơ Keychron K6',
        brand: 'Keychron',
        condition: 'LIKE_NEW',
        defectDisclosure: 'Xước nhẹ 1mm cạnh nhôm',
      },
      { userId: userAId, requestId: 'req-gen-01' },
    );

    expect(mockAiHttpClient.post).toHaveBeenCalledWith(
      '/ai/generate-listing',
      expect.objectContaining({
        productName: 'Bàn phím cơ Keychron K6',
        defects: 'Xước nhẹ 1mm cạnh nhôm',
      }),
      { userId: userAId, requestId: 'req-gen-01' },
    );
    expect(res.suggestedTitle).toContain('Keychron');
    expect(res.suggestedDescription.overview).toContain('Keychron K6');
    expect(res.suggestedDescription.defects).toContain('Xước nhẹ 1mm');
    expect(res.requiresSellerApproval).toBe(true);
  });

  it('AI 2: estimates 3-tier pricing (quickSellPrice <= recommendedPrice <= maxFairPrice)', async () => {
    mockAiHttpClient.post.mockResolvedValueOnce({
      quickSellPrice: 1300000,
      recommendedPrice: 1500000,
      maxFairPrice: 1700000,
      currency: 'VND',
      confidence: 'HIGH',
      comparableCount: 2,
      factors: ['Giá gốc: 2,450,000 VND', 'Tình trạng: LIKE_NEW'],
      dataSourceNote: 'Định giá dựa trên 2 sản phẩm tương đồng từ Backend ReMarket.',
      warnings: [],
      depreciationPercent: 39,
      marketDemand: 'HIGH',
      reasoning: 'Định giá dựa trên 2 sản phẩm tương đồng.',
      aiProvider: 'gemini-3.8-flash',
    });

    const res = await service.estimatePrice(
      {
        title: 'Bàn phím cơ Keychron K6',
        brand: 'Keychron',
        condition: 'LIKE_NEW',
        originalPrice: 2450000,
      },
      { userId: userAId },
    );

    expect(res.quickSellPrice).toBeLessThanOrEqual(res.recommendedPrice);
    expect(res.recommendedPrice).toBeLessThanOrEqual(res.maxFairPrice);
    expect(res.comparableCount).toBe(2);
    expect(res.confidence).toBe('HIGH');
  });

  it('AI 3: generates buyer checklist for real productId and persists cache to MongoDB Product', async () => {
    mockAiHttpClient.post.mockResolvedValueOnce({
      productId: String(mockProductId),
      inspectionPoints: [
        {
          title: 'Kiểm tra vết xước 1mm cạnh khung nhôm',
          description: 'Xác minh vị trí xước đã khai báo.',
          importance: 'HIGH',
        },
        {
          title: 'Kiểm tra switch và kết nối Bluetooth',
          description: 'Gõ thử toàn bộ các phím.',
          importance: 'HIGH',
        },
        {
          title: 'Kiểm tra dung lượng pin',
          description: 'Theo dõi pin khi bật LED.',
          importance: 'MEDIUM',
        },
      ],
      suggestedQuestions: [
        'Bàn phím đã từng sửa mạch chưa?',
        'Bạn có thể gửi video gõ phím thực tế không?',
        'Phụ kiện keycap puller và cáp USB-C còn đủ không?',
      ],
      safetyTips: [
        'Giao dịch trực tiếp tại nơi công cộng, không đặt cọc trước.',
      ],
      safetyTip: 'Giao dịch trực tiếp tại nơi công cộng, không đặt cọc trước.',
      advisoryOnly: true,
      aiProvider: 'gemini-3.8-flash',
    });

    const res = await service.buyerChecklist(
      { productId: String(mockProductId) },
      { userId: userAId },
    );

    expect(res.productId).toBe(String(mockProductId));
    expect(res.inspectionPoints).toHaveLength(3);
    expect(res.inspectionPoints[0].importance).toBe('HIGH');
    expect(res.suggestedQuestions).toHaveLength(3);
    expect(res.cached).toBe(false);
    expect(mockProductsService.saveAiChecklistCache).toHaveBeenCalledTimes(1);
  });

  it('AI 3: throws PRODUCT_NOT_FOUND (404) when productId does not exist', async () => {
    mockProductsService.findById.mockRejectedValueOnce(
      new NotFoundException('Product listing not found'),
    );

    await expect(
      service.buyerChecklist(
        { productId: '65f000000000000000000999' },
        { userId: userAId },
      ),
    ).rejects.toThrow(NotFoundException);
  });

  it('AI 4: answers shopping assistant chat with verified ACTIVE matchedProducts (all 10 schema fields)', async () => {
    mockAiHttpClient.post.mockResolvedValueOnce({
      thread_id: 'conv-session-01',
      intent: 'PRODUCT_DISCOVERY',
      message: 'Tìm thấy 1 bàn phím cơ Keychron K6 phù hợp dưới 1.5 triệu.',
      matchedProductIds: [String(mockProductId)],
      matchedProducts: [{ id: String(mockProductId) }],
      suggestedActions: ['So sánh các sản phẩm vừa tìm được'],
      sources: [],
      aiProvider: 'gemini-3.8-flash',
    });

    const res = await service.chat(
      {
        message: 'Tìm bàn phím cơ Keychron ở Thủ Đức',
        thread_id: 'conv-session-01',
        maxBudget: 1500000,
      },
      { userId: userAId },
    );

    expect(res.thread_id).toBe('conv-session-01');
    expect(res.matchedProducts).toHaveLength(1);
    const card = res.matchedProducts[0];
    expect(card._id).toBe(String(mockProductId));
    expect(card.sellerId).toBe(userAId);
    expect(card.categoryId).toBe(String(mockCategoryId));
    expect(card.title).toBe(mockProduct.title);
    expect(card.description).toBe(mockProduct.description);
    expect(card.price).toBe(mockProduct.price);
    expect(card.condition).toBe(mockProduct.condition);
    expect(Array.isArray(card.images)).toBe(true);
    expect(card.location).toBe(mockProduct.location);
    expect(card.status).toBe(ProductStatus.ACTIVE);
  });

  it('AI 4: filters out deleted or non-ACTIVE products from matchedProducts', async () => {
    mockAiHttpClient.post.mockResolvedValueOnce({
      thread_id: 'conv-session-02',
      intent: 'PRODUCT_DISCOVERY',
      message: 'Kết quả tìm kiếm',
      matchedProductIds: ['65f000000000000000000888'],
      matchedProducts: [{ id: '65f000000000000000000888' }],
    });
    // Product was deleted or marked SOLD in MongoDB
    mockProductsService.findManyByIds.mockResolvedValueOnce([]);

    const res = await service.chat(
      { message: 'Tìm laptop cũ' },
      { userId: userAId },
    );

    expect(mockProductsService.findManyByIds).toHaveBeenCalledWith(
      ['65f000000000000000000888'],
      true,
    );
    expect(res.matchedProducts).toEqual([]);
    expect(res.matchedProductIds).toEqual([]);
  });

  it('propagates standardized error codes (AI_SERVICE_UNAVAILABLE, AI_REQUEST_TIMEOUT, AI_RATE_LIMITED, AI_INVALID_RESPONSE, FORBIDDEN)', async () => {
    // 1. AI_SERVICE_UNAVAILABLE
    mockAiHttpClient.post.mockRejectedValueOnce(
      new ServiceUnavailableException({
        code: 'AI_SERVICE_UNAVAILABLE',
        message: 'AI Service is currently unavailable',
      }),
    );
    await expect(
      service.generateListing({ title: 'Laptop Dell' }, { userId: userAId }),
    ).rejects.toThrow(ServiceUnavailableException);

    // 2. AI_REQUEST_TIMEOUT
    mockAiHttpClient.post.mockRejectedValueOnce(
      new GatewayTimeoutException({
        code: 'AI_REQUEST_TIMEOUT',
        message: 'AI Service request timed out',
      }),
    );
    await expect(
      service.estimatePrice(
        { title: 'Laptop Dell', condition: 'GOOD' },
        { userId: userAId },
      ),
    ).rejects.toThrow(GatewayTimeoutException);

    // 3. AI_RATE_LIMITED
    mockAiHttpClient.post.mockRejectedValueOnce(
      new HttpException(
        { code: 'AI_RATE_LIMITED', message: 'Rate limit exceeded' },
        HttpStatus.TOO_MANY_REQUESTS,
      ),
    );
    await expect(
      service.chat({ message: 'Xin chào' }, { userId: userAId }),
    ).rejects.toThrow(HttpException);

    // 4. AI_INVALID_RESPONSE (malformed payload from Python AI)
    mockAiHttpClient.post.mockResolvedValueOnce({ invalidField: true });
    await expect(
      service.generateListing({ title: 'Laptop Dell' }, { userId: userAId }),
    ).rejects.toThrow(BadGatewayException);

    // 5. FORBIDDEN when User B tries to read User A's thread_id
    mockAiHttpClient.get.mockRejectedValueOnce(
      new ForbiddenException({
        code: 'FORBIDDEN',
        message: 'Conversation belongs to another user',
      }),
    );
    await expect(
      service.getConversation('conv-user-a', { userId: userBId }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects client-supplied user_id in request payload with VALIDATION_ERROR', async () => {
    await expect(
      service.chat(
        {
          message: 'Tìm laptop',
          ...({ user_id: userAId } as Record<string, unknown>),
        },
        { userId: userBId },
      ),
    ).rejects.toThrow(BadRequestException);
  });
});
