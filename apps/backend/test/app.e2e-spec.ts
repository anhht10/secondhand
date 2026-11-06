import { INestApplication, ValidationPipe } from '@nestjs/common';
import { getConnectionToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import * as http from 'http';
import { AddressInfo } from 'net';
import { Connection, Types } from 'mongoose';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { CategoriesService } from '../src/modules/categories/categories.service';
import {
  ProductCondition,
  ProductStatus,
} from '../src/modules/products/schemas/product.schema';
import { ReportStatus } from '../src/modules/reports/schemas/report.schema';

describe('ReMarket Core & Business API (e2e — Non-Destructive)', () => {
  let app: INestApplication;
  let dbConnection: Connection;

  const testEmailPrefix = 'e2e.suite.';
  const sellerAEmail = `${testEmailPrefix}seller.a@remarket.vn`;
  const buyerBEmail = `${testEmailPrefix}buyer.b@remarket.vn`;
  const outsiderCEmail = `${testEmailPrefix}outsider.c@remarket.vn`;

  let sellerAToken = '';
  let sellerARefreshToken = '';
  let sellerAId = '';

  let buyerBToken = '';
  let buyerBId = '';

  let outsiderCToken = '';

  let electronicsCategoryId = '';
  let computersCategoryId = '';

  let product1Id = '';
  let product2Id = '';
  let draftProductId = '';

  let conversationId = '';
  let firstMessageId = '';
  let mockAiServer: http.Server | null = null;

  // Minimal 1x1 transparent PNG buffer for Multer upload tests
  const samplePngBuffer = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    'base64',
  );

  async function cleanUpScopedTestData(): Promise<void> {
    if (!dbConnection) return;

    const testUsers = await dbConnection
      .collection('users')
      .find({ email: { $regex: `^${testEmailPrefix}` } })
      .project({ _id: 1 })
      .toArray();

    const testUserIds = testUsers.map((u) => u._id as Types.ObjectId);

    if (testUserIds.length > 0) {
      const convs = await dbConnection
        .collection('conversations')
        .find({
          $or: [
            { buyerId: { $in: testUserIds } },
            { sellerId: { $in: testUserIds } },
          ],
        })
        .project({ _id: 1 })
        .toArray();
      const convIds = convs.map((c) => c._id as Types.ObjectId);

      if (convIds.length > 0) {
        await dbConnection
          .collection('messages')
          .deleteMany({ conversationId: { $in: convIds } });
        await dbConnection
          .collection('conversations')
          .deleteMany({ _id: { $in: convIds } });
      }

      await dbConnection
        .collection('reports')
        .deleteMany({ reporterId: { $in: testUserIds } });
      await dbConnection
        .collection('products')
        .deleteMany({ sellerId: { $in: testUserIds } });
      await dbConnection
        .collection('refreshsessions')
        .deleteMany({ userId: { $in: testUserIds } });
      await dbConnection
        .collection('users')
        .deleteMany({ _id: { $in: testUserIds } });
    }
  }

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.MONGODB_TEST_URI =
      process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/remarket_test';
    process.env.THROTTLE_LIMIT = '1000';

    mockAiServer = http.createServer((req, res) => {
      res.setHeader('Content-Type', 'application/json');
      if (req.url?.includes('/ai/generate-listing')) {
        res.end(
          JSON.stringify({
            suggestedTitle:
              '[Pass Nhanh] Keychron Bàn phím cơ Keychron K6 - Như mới',
            suggestedDescription: {
              overview: 'Bàn phím cơ Keychron K6 chính hãng.',
              condition: 'LIKE_NEW (99%)',
              defects: 'Xước nhẹ 1mm cạnh nhôm',
            },
            suggestedCategory: 'Máy tính & Phụ kiện',
            suggestedTags: ['keychron', 'remarket'],
            transparencyNote: 'Đã khai báo minh bạch khuyết điểm.',
            transparencyScore: 95,
            needsMoreInfo: false,
            clarificationQuestions: [],
            requiresSellerApproval: true,
            aiProvider: 'gemini-3.8-flash',
          }),
        );
        return;
      }
      if (req.url?.includes('/ai/estimate-price')) {
        res.end(
          JSON.stringify({
            quickSellPrice: 1300000,
            recommendedPrice: 1500000,
            maxFairPrice: 1700000,
            currency: 'VND',
            confidence: 'HIGH',
            comparableCount: 1,
            factors: ['Giá gốc: 2.450.000đ', 'Tình trạng: LIKE_NEW'],
            dataSourceNote: 'Dựa trên dữ liệu ReMarket.',
            warnings: [],
            depreciationPercent: 39,
            marketDemand: 'HIGH',
            reasoning: 'Định giá hợp lý.',
            aiProvider: 'gemini-3.8-flash',
          }),
        );
        return;
      }
      if (req.url?.includes('/ai/buyer-checklist')) {
        res.end(
          JSON.stringify({
            productId: product1Id,
            inspectionPoints: [
              {
                title: 'Kiểm tra ngoại hình và vết xước',
                description: 'Đối chiếu thực tế.',
                importance: 'HIGH',
              },
              {
                title: 'Kiểm tra kết nối Bluetooth & ANC',
                description: 'Nghe thử chống ồn 10 phút.',
                importance: 'HIGH',
              },
              {
                title: 'Kiểm tra dung lượng pin',
                description: 'Kiểm tra sạc USB-C.',
                importance: 'MEDIUM',
              },
            ],
            suggestedQuestions: [
              'Sản phẩm còn hộp và phụ kiện không?',
              'Có lỗi phát sinh nào khác không?',
              'Mình hẹn test trực tiếp ở trường được chứ?',
            ],
            safetyTips: ['Giao dịch nơi công cộng, không đặt cọc trước.'],
            safetyTip: 'Giao dịch nơi công cộng, không đặt cọc trước.',
            advisoryOnly: true,
            aiProvider: 'gemini-3.8-flash',
          }),
        );
        return;
      }
      if (req.url?.includes('/ai/chat')) {
        res.end(
          JSON.stringify({
            thread_id: 'conv-e2e-01',
            intent: 'PRODUCT_DISCOVERY',
            message: 'Mình tìm thấy tai nghe Sony WH-1000XM4 phù hợp dưới 4.5 triệu.',
            matchedProductIds: product1Id ? [product1Id] : [],
            matchedProducts: product1Id ? [{ id: product1Id }] : [],
            suggestedActions: ['So sánh các sản phẩm'],
            sources: [],
            aiProvider: 'gemini-3.8-flash',
          }),
        );
        return;
      }
      res.statusCode = 404;
      res.end(JSON.stringify({ message: 'Not found' }));
    });
    await new Promise<void>((resolve) =>
      mockAiServer!.listen(0, '127.0.0.1', () => resolve()),
    );
    const aiPort = (mockAiServer.address() as AddressInfo).port;
    process.env.AI_SERVICE_URL = `http://127.0.0.1:${aiPort}`;

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: {
          enableImplicitConversion: false,
        },
      }),
    );

    await app.init();

    dbConnection = app.get<Connection>(getConnectionToken());
    await cleanUpScopedTestData();

    // Ensure categories and indexes are present idempotently without dropping anything
    const categoriesService = app.get(CategoriesService);
    await categoriesService.seedInitialCategories();
  });

  afterAll(async () => {
    await cleanUpScopedTestData();
    if (app) {
      await app.close();
    }
    if (mockAiServer) {
      await new Promise<void>((resolve) => mockAiServer!.close(() => resolve()));
    }
  });

  describe('1. Health Check (/api/v1/health)', () => {
    it('GET /api/v1/health returns service status and connected database state', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/health')
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('ok');
      expect(res.body.data.database.status).toBe('connected');
    });
  });

  describe('2. Authentication & Session Lifecycle (/api/v1/auth)', () => {
    it('POST /api/v1/auth/register registers Seller A, Buyer B, and Outsider C', async () => {
      const resA = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: sellerAEmail,
          password: 'Password123!',
          displayName: 'Khoa Nguyen',
          phoneNumber: '+84901234567',
          location: 'District 10, Ho Chi Minh City',
        })
        .expect(201);

      expect(resA.body.success).toBe(true);
      expect(resA.body.data.user.passwordHash).toBeUndefined();
      sellerAToken = resA.body.data.tokens.accessToken;
      sellerARefreshToken = resA.body.data.tokens.refreshToken;
      sellerAId = resA.body.data.user.id || resA.body.data.user._id;

      const resB = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: buyerBEmail,
          password: 'Password123!',
          displayName: 'Minh Tran',
          location: 'District 1, Ho Chi Minh City',
        })
        .expect(201);

      buyerBToken = resB.body.data.tokens.accessToken;
      buyerBId = resB.body.data.user.id || resB.body.data.user._id;
      expect(buyerBId).toBeDefined();

      const resC = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: outsiderCEmail,
          password: 'Password123!',
          displayName: 'Outsider User',
        })
        .expect(201);

      outsiderCToken = resC.body.data.tokens.accessToken;
    });

    it('POST /api/v1/auth/register rejects duplicate email with 409 Conflict', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({
          email: sellerAEmail,
          password: 'Password123!',
          displayName: 'Duplicate User',
        })
        .expect(409);
    });

    it('POST /api/v1/auth/login authenticates valid credentials and rejects invalid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: sellerAEmail,
          password: 'Password123!',
        })
        .expect(200);

      sellerAToken = res.body.data.tokens.accessToken;
      sellerARefreshToken = res.body.data.tokens.refreshToken;

      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: sellerAEmail,
          password: 'WrongPassword999!',
        })
        .expect(401);
    });

    it('POST /api/v1/auth/refresh and /api/v1/auth/logout manage session rotation and revocation', async () => {
      const oldRefreshToken = sellerARefreshToken;

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRefreshToken })
        .expect(200);

      sellerAToken = res.body.data.tokens.accessToken;
      sellerARefreshToken = res.body.data.tokens.refreshToken;

      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRefreshToken })
        .expect(401);

      await request(app.getHttpServer())
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ refreshToken: sellerARefreshToken })
        .expect(200);

      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: sellerARefreshToken })
        .expect(401);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: sellerAEmail,
          password: 'Password123!',
        })
        .expect(200);

      sellerAToken = loginRes.body.data.tokens.accessToken;
      sellerARefreshToken = loginRes.body.data.tokens.refreshToken;
    });
  });

  describe('3. User Profile & Categories (/api/v1/users & /api/v1/categories)', () => {
    it('PATCH /api/v1/users/me updates profile and GET /api/v1/users/:id hides private fields', async () => {
      const meRes = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(200);
      expect(meRes.body.success).toBe(true);
      expect(meRes.body.data.email).toBe(sellerAEmail);

      const res = await request(app.getHttpServer())
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          displayName: 'Khoa Nguyen (Verified Tech)',
          bio: 'Selling carefully maintained audio & keyboard gear in HCMC.',
        })
        .expect(200);

      expect(res.body.data.displayName).toBe('Khoa Nguyen (Verified Tech)');

      const pubRes = await request(app.getHttpServer())
        .get(`/api/v1/users/${sellerAId}`)
        .expect(200);

      expect(pubRes.body.data.passwordHash).toBeUndefined();
      expect(pubRes.body.data.email).toBeUndefined();
    });

    it('GET /api/v1/categories lists seeded active categories, gets category by ID, and rejects invalid/missing IDs', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/categories')
        .expect(200);

      const electronics = res.body.data.find(
        (c: { slug: string }) => c.slug === 'electronics',
      );
      const computers = res.body.data.find(
        (c: { slug: string }) => c.slug === 'computers-accessories',
      );

      electronicsCategoryId = String(electronics._id);
      computersCategoryId = String(computers._id);
      expect(String(computers.parentId)).toBe(electronicsCategoryId);

      // Get Category by ID
      const catDetail = await request(app.getHttpServer())
        .get(`/api/v1/categories/${electronicsCategoryId}`)
        .expect(200);
      expect(catDetail.body.success).toBe(true);
      expect(catDetail.body.data.slug).toBe('electronics');

      // Invalid Category ID -> 400 Bad Request with standardized error envelope
      const invalidIdRes = await request(app.getHttpServer())
        .get('/api/v1/categories/invalid-object-id')
        .expect(400);
      expect(invalidIdRes.body.success).toBe(false);
      expect(invalidIdRes.body.error.code).toBeDefined();
      expect(Array.isArray(invalidIdRes.body.error.details)).toBe(true);

      // Non-existent Category ObjectId -> 404 Not Found
      await request(app.getHttpServer())
        .get(`/api/v1/categories/${String(new Types.ObjectId())}`)
        .expect(404);
    });
  });

  describe('4. Product Listings, Search, Filtering, Sorting & Status Rules (/api/v1/products)', () => {
    it('POST /api/v1/products creates listings and blocks creating a product directly with SOLD status', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          categoryId: electronicsCategoryId,
          title: 'Invalid Sold Product',
          description: 'Should not allow creating directly as SOLD.',
          price: 1000000,
          condition: ProductCondition.GOOD,
          location: 'District 10',
          status: ProductStatus.SOLD,
        })
        .expect(400);

      const res1 = await request(app.getHttpServer())
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          categoryId: electronicsCategoryId,
          title: 'Sony WH-1000XM4 Wireless Noise Cancelling Headphones',
          description:
            'Purchased 8 months ago, lightly used in office. Includes carrying case and cables.',
          price: 4200000,
          condition: ProductCondition.LIKE_NEW,
          location: 'District 10, Ho Chi Minh City',
          images: [
            {
              url: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
              sortOrder: 0,
              altText: 'Sony WH-1000XM4 front view',
            },
          ],
        })
        .expect(201);

      product1Id = String(res1.body.data._id);

      const res2 = await request(app.getHttpServer())
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          categoryId: computersCategoryId,
          title: 'Keychron K6 Wireless Mechanical Keyboard',
          description:
            'Hot-swappable Gateron Brown switches, aluminum frame, RGB backlight.',
          price: 1450000,
          condition: ProductCondition.GOOD,
          location: 'Thu Duc City, Ho Chi Minh City',
          images: [
            'https://images.unsplash.com/photo-1587829741301-dc798b83add3',
          ],
        })
        .expect(201);

      product2Id = String(res2.body.data._id);

      const resDraft = await request(app.getHttpServer())
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          categoryId: computersCategoryId,
          title: 'Dell UltraSharp U2422H Monitor (Draft)',
          description: 'Draft listing not yet ready for public marketplace.',
          price: 3800000,
          condition: ProductCondition.LIKE_NEW,
          location: 'District 10, Ho Chi Minh City',
          status: ProductStatus.DRAFT,
        })
        .expect(201);

      draftProductId = String(resDraft.body.data._id);
    });

    it('GET /api/v1/products supports keyword search, category/price/condition filtering, sorting, and hides DRAFT from public', async () => {
      // List all public products
      const listRes = await request(app.getHttpServer())
        .get('/api/v1/products?page=1&limit=10')
        .expect(200);
      expect(listRes.body.success).toBe(true);
      expect(listRes.body.meta.page).toBe(1);

      // Search by keyword
      const searchRes = await request(app.getHttpServer())
        .get('/api/v1/products?keyword=Keychron&sort=price_asc')
        .expect(200);

      expect(
        searchRes.body.data.some(
          (p: { _id: string }) => String(p._id) === product2Id,
        ),
      ).toBe(true);

      // Filter by categoryId
      const catFilterRes = await request(app.getHttpServer())
        .get(`/api/v1/products?categoryId=${computersCategoryId}`)
        .expect(200);
      expect(
        catFilterRes.body.data.some(
          (p: { _id: string }) => String(p._id) === product2Id,
        ),
      ).toBe(true);

      // Filter by price range & condition
      const priceCondRes = await request(app.getHttpServer())
        .get(
          `/api/v1/products?minPrice=1000000&maxPrice=2000000&condition=${ProductCondition.GOOD}`,
        )
        .expect(200);
      expect(
        priceCondRes.body.data.some(
          (p: { _id: string }) => String(p._id) === product2Id,
        ),
      ).toBe(true);

      // Filter by sellerId & sort=popular (Phase 10 BUG-01 fix verification)
      const sellerFilterRes = await request(app.getHttpServer())
        .get(`/api/v1/products?sellerId=${sellerAId}&sort=popular`)
        .expect(200);
      expect(sellerFilterRes.body.data.length).toBeGreaterThanOrEqual(2);
      expect(
        sellerFilterRes.body.data.every(
          (p: { sellerId: { _id?: string; id?: string } }) =>
            String(p.sellerId._id || p.sellerId.id) === String(sellerAId),
        ),
      ).toBe(true);

      // Update product with local /uploads/... image URL (Phase 10 BUG-05 fix verification)
      const updateRes = await request(app.getHttpServer())
        .patch(`/api/v1/products/${product1Id}`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          price: 4100000,
          images: ['/uploads/products/sony-xm4-local.jpg'],
        })
        .expect(200);
      expect(updateRes.body.data.price).toBe(4100000);
      expect(updateRes.body.data.images[0].url).toBe(
        '/uploads/products/sony-xm4-local.jpg',
      );

      await request(app.getHttpServer())
        .patch(`/api/v1/products/${product1Id}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ price: 100000 })
        .expect(403);

      // DRAFT hidden from non-owners on GET /products/:id
      await request(app.getHttpServer())
        .get(`/api/v1/products/${draftProductId}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(404);
    });
  });

  describe('5. Conversations & Messaging (/api/v1/messages)', () => {
    it('(Test 1 & 9 & 10) POST /api/v1/messages/conversations creates conversation, prevents self-chat & invalid product, and prevents duplicate conversations', async () => {
      // Seller A cannot start a conversation with themselves on their own product
      await request(app.getHttpServer())
        .post('/api/v1/messages/conversations')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          productId: product1Id,
          initialMessage: 'Self chat attempt',
        })
        .expect(400);

      // Cannot start a conversation on a DRAFT product
      await request(app.getHttpServer())
        .post('/api/v1/messages/conversations')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: draftProductId,
        })
        .expect(400);

      // Non-existent product returns 404
      await request(app.getHttpServer())
        .post('/api/v1/messages/conversations')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: String(new Types.ObjectId()),
        })
        .expect(404);

      // Buyer B starts conversation on Seller A's product1Id with an initial message
      const convRes = await request(app.getHttpServer())
        .post('/api/v1/messages/conversations')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product1Id,
          initialMessage:
            'Chào bạn, tai nghe Sony XM4 này còn đầy đủ phụ kiện không?',
        })
        .expect(201);

      expect(convRes.body.success).toBe(true);
      conversationId = String(convRes.body.data._id);
      expect(convRes.body.data.lastMessage).toContain('Sony XM4');
      expect(convRes.body.data.lastMessageAt).toBeTruthy();

      // Calling POST /api/v1/messages/conversations again for the same buyer/seller/product returns the SAME conversation (no duplicate!)
      const dupRes = await request(app.getHttpServer())
        .post('/api/v1/messages/conversations')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product1Id,
        })
        .expect(201);

      expect(String(dupRes.body.data._id)).toBe(conversationId);
    });

    it('(Test 2 & 3) GET /api/v1/messages/conversations & /conversations/:id return conversation list and details for participants', async () => {
      const listRes = await request(app.getHttpServer())
        .get('/api/v1/messages/conversations?page=1&limit=10')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(200);

      expect(listRes.body.success).toBe(true);
      expect(listRes.body.data.length).toBe(1);
      expect(String(listRes.body.data[0]._id)).toBe(conversationId);
      expect(listRes.body.meta.total).toBe(1);

      const detailRes = await request(app.getHttpServer())
        .get(`/api/v1/messages/conversations/${conversationId}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);

      expect(String(detailRes.body.data._id)).toBe(conversationId);
    });

    it('(Test 4 & 5 & 10) POST & GET /api/v1/messages/conversations/:id/messages send and paginate messages and reject empty content', async () => {
      // Empty / whitespace-only message rejected with 400
      await request(app.getHttpServer())
        .post(`/api/v1/messages/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ content: '   ' })
        .expect(400);

      // Seller A replies in the conversation
      const sendRes = await request(app.getHttpServer())
        .post(`/api/v1/messages/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          content:
            'Chào Minh, tai nghe còn nguyên hộp, cáp USB-C và jack máy bay nhé!',
        })
        .expect(201);

      expect(sendRes.body.success).toBe(true);
      expect(sendRes.body.data.isRead).toBe(false);
      firstMessageId = String(sendRes.body.data._id);

      // Get messages in conversation with pagination
      const msgsRes = await request(app.getHttpServer())
        .get(
          `/api/v1/messages/conversations/${conversationId}/messages?page=1&limit=10`,
        )
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);

      expect(msgsRes.body.success).toBe(true);
      expect(msgsRes.body.data.length).toBe(2);
      expect(msgsRes.body.meta.total).toBe(2);
    });

    it('(Test 6 & 7) PATCH /api/v1/messages/:id/read marks message as read and blocks unauthorized outsider access across all message endpoints', async () => {
      // Outsider C (not buyer or seller) blocked with 403 on conversation detail, message list, send message, and mark read
      await request(app.getHttpServer())
        .get(`/api/v1/messages/conversations/${conversationId}`)
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .expect(403);

      await request(app.getHttpServer())
        .get(`/api/v1/messages/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .expect(403);

      await request(app.getHttpServer())
        .post(`/api/v1/messages/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .send({ content: 'Intruder message' })
        .expect(403);

      await request(app.getHttpServer())
        .patch(`/api/v1/messages/${firstMessageId}/read`)
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .expect(403);

      // Buyer B marks Seller A's message as read -> 200 OK
      const readRes = await request(app.getHttpServer())
        .patch(`/api/v1/messages/${firstMessageId}/read`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);

      expect(readRes.body.success).toBe(true);
      expect(readRes.body.data.isRead).toBe(true);
    });
  });

  describe('6. Report Listing (/api/v1/reports)', () => {
    it('(Test 8 & 10) POST /api/v1/reports & GET /api/v1/reports/me create report, block self-report, duplicate spam, and non-existent products', async () => {
      // Seller A cannot report their own product -> 400
      await request(app.getHttpServer())
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          productId: product1Id,
          reason: 'SPAM',
        })
        .expect(400);

      // Reporting non-existent product -> 404
      await request(app.getHttpServer())
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: String(new Types.ObjectId()),
          reason: 'SCAM_LISTING',
        })
        .expect(404);

      // Invalid short reason -> 400
      await request(app.getHttpServer())
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product2Id,
          reason: 'ab',
        })
        .expect(400);

      // Buyer B submits valid report on product2Id -> 201 Created with status PENDING
      const reportRes = await request(app.getHttpServer())
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product2Id,
          reason: 'MISLEADING_DESCRIPTION',
          description: 'Switch type listed does not match photos.',
          evidenceUrls: [
            'https://images.unsplash.com/photo-1587829741301-dc798b83add3',
          ],
        })
        .expect(201);

      expect(reportRes.body.success).toBe(true);
      expect(reportRes.body.data.status).toBe(ReportStatus.PENDING);
      expect(reportRes.body.data.reason).toBe('MISLEADING_DESCRIPTION');

      // Duplicate report by same user on same product -> 409 Conflict
      await request(app.getHttpServer())
        .post('/api/v1/reports')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product2Id,
          reason: 'DUPLICATE_REPORT',
        })
        .expect(409);

      // GET /api/v1/reports/me returns Buyer B's submitted reports and does not expose them to Outsider C
      const myReportsRes = await request(app.getHttpServer())
        .get('/api/v1/reports/me')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);

      expect(myReportsRes.body.data).toHaveLength(1);

      const outsiderReportsRes = await request(app.getHttpServer())
        .get('/api/v1/reports/me')
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .expect(200);

      expect(outsiderReportsRes.body.data).toHaveLength(0);
    });
  });

  describe('7. Image Upload & Wishlist (/api/v1/upload & /api/v1/auth/wishlist)', () => {
    it('uploads valid images, rejects invalid MIME types, rejects oversized files (>5MB), and enforces max 10 images limit', async () => {
      // 1. Upload Valid Image to product
      const uploadRes = await request(app.getHttpServer())
        .post(`/api/v1/products/${draftProductId}/images`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .attach('images', samplePngBuffer, {
          filename: 'dell-monitor.png',
          contentType: 'image/png',
        })
        .expect(201);

      expect(uploadRes.body.success).toBe(true);
      expect(uploadRes.body.data.images.length).toBe(1);

      // 2. Reject Invalid MIME Type (e.g. text/plain or application/pdf)
      const invalidMimeRes = await request(app.getHttpServer())
        .post('/api/v1/upload/images')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .attach('images', Buffer.from('not-an-image'), {
          filename: 'malicious.txt',
          contentType: 'text/plain',
        });
      expect(invalidMimeRes.status).toBe(400);
      expect(invalidMimeRes.body.success).toBe(false);

      // 3. Reject Oversized File (> 5MB)
      const oversizedBuffer = Buffer.alloc(5 * 1024 * 1024 + 1024, 0x41);
      const oversizedRes = await request(app.getHttpServer())
        .post('/api/v1/upload/images')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .attach('images', oversizedBuffer, {
          filename: 'huge-photo.png',
          contentType: 'image/png',
        });
      expect([400, 413]).toContain(oversizedRes.status);
      expect(oversizedRes.body.success).toBe(false);

      // 4. Validate Image Count (> 10 files)
      let reqChain = request(app.getHttpServer())
        .post('/api/v1/upload/images')
        .set('Authorization', `Bearer ${sellerAToken}`);
      for (let i = 0; i < 11; i++) {
        reqChain = reqChain.attach('images', samplePngBuffer, {
          filename: `img-${i}.png`,
          contentType: 'image/png',
        });
      }
      const tooManyFilesRes = await reqChain;
      expect(tooManyFilesRes.status).toBe(400);
      expect(tooManyFilesRes.body.success).toBe(false);
    });

    it('manages user wishlist (add, prevent duplicate, get wishlist, remove from wishlist)', async () => {
      // 1. Add to Wishlist
      await request(app.getHttpServer())
        .post(`/api/v1/auth/wishlist/${product1Id}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(201);

      // 2. Prevent Duplicate Wishlist
      const secondAdd = await request(app.getHttpServer())
        .post(`/api/v1/auth/wishlist/${product1Id}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(201);

      expect(secondAdd.body.data).toHaveLength(1);

      // 3. Get Wishlist
      const getWishRes = await request(app.getHttpServer())
        .get('/api/v1/auth/wishlist')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);
      expect(getWishRes.body.success).toBe(true);
      expect(getWishRes.body.data).toHaveLength(1);

      // 4. Remove from Wishlist
      const delWishRes = await request(app.getHttpServer())
        .delete(`/api/v1/auth/wishlist/${product1Id}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);
      expect(delWishRes.body.success).toBe(true);
      expect(delWishRes.body.data).toHaveLength(0);
    });
  });

  describe('8. (Test 11) Product Ownership & Status Transition Business Rules (including RESERVED)', () => {
    it('enforces valid status transitions (ACTIVE -> RESERVED -> SOLD, blocks DRAFT -> SOLD and SOLD -> ACTIVE) and owner authorization', async () => {
      // Update via PUT alias with transparency fields
      const putRes = await request(app.getHttpServer())
        .put(`/api/v1/products/${product1Id}`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          brand: 'Sony',
          originalPrice: 6490000,
          defectDisclosure: 'Xước nhẹ ngoài hộp đựng, tai nghe đẹp 99%',
          transparencyScore: 98,
          tags: ['#sony', '#wh1000xm4'],
        })
        .expect(200);
      expect(putRes.body.data.brand).toBe('Sony');
      expect(putRes.body.data.transparencyScore).toBe(98);

      // Buyer B cannot change Seller A's product status -> 403
      await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}/status`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ status: ProductStatus.SOLD })
        .expect(403);

      // Seller A cannot transition DRAFT directly to SOLD -> 400
      await request(app.getHttpServer())
        .patch(`/api/v1/products/${draftProductId}/status`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ status: ProductStatus.SOLD })
        .expect(400);

      // Seller A transitions ACTIVE product2Id to RESERVED ("Đã đặt gạch") -> 200
      const reserveRes = await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}/status`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ status: ProductStatus.RESERVED })
        .expect(200);
      expect(reserveRes.body.data.status).toBe(ProductStatus.RESERVED);

      // Seller A transitions RESERVED product2Id to SOLD -> 200
      await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}/status`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ status: ProductStatus.SOLD })
        .expect(200);

      // Seller A cannot relist a SOLD product directly back to ACTIVE -> 400
      await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}/status`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ status: ProductStatus.ACTIVE })
        .expect(400);

      // Seller A cannot modify price/title of a SOLD product -> 400
      await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ price: 999999 })
        .expect(400);

      // Seller A cannot hard-delete a SOLD product -> 400 (must archive instead)
      await request(app.getHttpServer())
        .delete(`/api/v1/products/${product2Id}`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(400);

      // Seller A CAN archive a SOLD product -> 200
      const archiveRes = await request(app.getHttpServer())
        .patch(`/api/v1/products/${product2Id}/status`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ status: ProductStatus.ARCHIVED })
        .expect(200);

      expect(archiveRes.body.data.status).toBe(ProductStatus.ARCHIVED);

      // Seller A deletes their DRAFT product -> 200 OK
      await request(app.getHttpServer())
        .delete(`/api/v1/products/${draftProductId}`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(200);
    });
  });

  describe('9. AI Assistant Endpoints (/api/v1/ai)', () => {
    it('supports AI 1 (generate-listing), AI 2 (estimate-price), AI 3 (buyer-checklist with MongoDB cache), and AI 4 (chat with matchedProducts)', async () => {
      // AI 1: Generate Listing
      const genRes = await request(app.getHttpServer())
        .post('/api/v1/ai/generate-listing')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          title: 'Bàn phím cơ Keychron K6',
          brand: 'Keychron',
          category: 'Máy tính & Phụ kiện',
          condition: 'LIKE_NEW',
          defectDisclosure: 'Xước nhẹ 1mm cạnh nhôm',
        })
        .expect(200);
      expect(genRes.body.success).toBe(true);
      expect(genRes.body.data.suggestedTitle).toBeDefined();
      expect(genRes.body.data.suggestedDescription).toBeDefined();
      expect(Array.isArray(genRes.body.data.suggestedTags)).toBe(true);

      // AI 2: Estimate Price
      const priceRes = await request(app.getHttpServer())
        .post('/api/v1/ai/estimate-price')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          title: 'Bàn phím cơ Keychron K6',
          brand: 'Keychron',
          condition: 'LIKE_NEW',
          originalPrice: 2450000,
        })
        .expect(200);
      expect(priceRes.body.success).toBe(true);
      expect(priceRes.body.data.quickSellPrice).toBeLessThan(
        priceRes.body.data.recommendedPrice,
      );
      expect(priceRes.body.data.recommendedPrice).toBeLessThan(
        priceRes.body.data.maxFairPrice,
      );

      // AI 3: Buyer Checklist (first call computes & caches, second call returns cached=true)
      const check1 = await request(app.getHttpServer())
        .post('/api/v1/ai/buyer-checklist')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ productId: product1Id })
        .expect(200);
      expect(check1.body.success).toBe(true);
      expect(check1.body.data.inspectionPoints.length).toBeGreaterThanOrEqual(
        3,
      );
      expect(check1.body.data.cached).toBe(false);

      const check2 = await request(app.getHttpServer())
        .post('/api/v1/ai/buyer-checklist')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ productId: product1Id })
        .expect(200);
      expect(check2.body.data.cached).toBe(true);

      // AI 4: Chatbot Assistant
      const chatRes = await request(app.getHttpServer())
        .post('/api/v1/ai/chat')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          message: 'Mình cần tìm tai nghe chống ồn Sony dưới 4.5 triệu',
          maxBudget: 4500000,
        })
        .expect(200);
      expect(chatRes.body.success).toBe(true);
      expect(chatRes.body.data.reply).toBeTruthy();
      expect(Array.isArray(chatRes.body.data.matchedProducts)).toBe(true);
      expect(chatRes.body.data.interactionId).toBeTruthy();
    });
  });

  describe('10. Orders, Payments, Atomic Reservation, Concurrency & Notifications E2E (/api/v1/orders & /api/v1/notifications)', () => {
    it('prevents concurrent duplicate purchases, restores product on cancel, and executes full 8-step Buyer-Seller Order & Bank Transfer flow', async () => {
      // Configure Seller A bank account via PATCH /api/v1/users/me
      const bankUpdateRes = await request(app.getHttpServer())
        .patch('/api/v1/users/me')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          bankInfo: {
            bankName: 'Vietcombank (VCB)',
            accountNumber: '1029384756',
            accountHolder: 'NGUYEN MINH KHOA',
            branch: 'CN Thủ Đức',
          },
        })
        .expect(200);
      expect(bankUpdateRes.body.data.bankInfo.accountNumber).toBe('1029384756');

      // Public seller profile must NEVER leak bankInfo
      const pubSellerRes = await request(app.getHttpServer())
        .get(`/api/v1/users/${sellerAId}`)
        .expect(200);
      expect(pubSellerRes.body.data.bankInfo).toBeUndefined();

      // 1. Concurrent order creation test: Buyer B and Outsider C attempt to buy product1Id simultaneously
      const [conc1, conc2] = await Promise.all([
        request(app.getHttpServer())
          .post('/api/v1/orders')
          .set('Authorization', `Bearer ${buyerBToken}`)
          .send({
            productId: product1Id,
            deliveryMethod: 'MEETUP',
            paymentMethod: 'CASH',
            meetupLocation: 'ĐH Bách Khoa Q10',
          }),
        request(app.getHttpServer())
          .post('/api/v1/orders')
          .set('Authorization', `Bearer ${outsiderCToken}`)
          .send({
            productId: product1Id,
            deliveryMethod: 'MEETUP',
            paymentMethod: 'CASH',
            meetupLocation: 'ĐH Bách Khoa Q10',
          }),
      ]);

      const statuses = [conc1.status, conc2.status].sort();
      expect(statuses).toEqual([201, 409]);

      const winningRes = conc1.status === 201 ? conc1 : conc2;
      const winningToken =
        conc1.status === 201 ? buyerBToken : outsiderCToken;
      const tempOrderId = String(winningRes.body.data.id);

      // Verify product1Id is now RESERVED
      const reservedCheck = await request(app.getHttpServer())
        .get(`/api/v1/products/${product1Id}`)
        .expect(200);
      expect(reservedCheck.body.data.status).toBe(ProductStatus.RESERVED);

      // Cancel the temporary order and verify product1Id is restored to ACTIVE
      const cancelRes = await request(app.getHttpServer())
        .patch(`/api/v1/orders/${tempOrderId}/cancel`)
        .set('Authorization', `Bearer ${winningToken}`)
        .send({ reason: 'Test hủy đơn để khôi phục sản phẩm' })
        .expect(200);
      expect(cancelRes.body.data.status).toBe('CANCELLED');

      const restoredCheck = await request(app.getHttpServer())
        .get(`/api/v1/products/${product1Id}`)
        .expect(200);
      expect(restoredCheck.body.data.status).toBe(ProductStatus.ACTIVE);

      // =========================================================================
      // FULL 8-STEP E2E BUYER & SELLER WORKFLOW
      // =========================================================================

      // Step 1: Buyer B opens product
      const openProd = await request(app.getHttpServer())
        .get(`/api/v1/products/${product1Id}`)
        .expect(200);
      expect(openProd.body.data.status).toBe(ProductStatus.ACTIVE);

      // Step 2: Buyer B creates order (DELIVERY + BANK_TRANSFER)
      const createOrderRes = await request(app.getHttpServer())
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          productId: product1Id,
          deliveryMethod: 'DELIVERY',
          shippingAddress: 'KTX Khu B ĐHQG TP.HCM, Dĩ An',
          recipientName: 'Trần Hoàng Minh',
          recipientPhone: '+84912345678',
          paymentMethod: 'BANK_TRANSFER',
          buyerNote: 'Giao giờ hành chính giúp mình nhé',
        })
        .expect(201);

      const orderId = String(createOrderRes.body.data.id);
      expect(createOrderRes.body.data.status).toBe('PENDING');
      expect(createOrderRes.body.data.paymentStatus).toBe('UNPAID');
      expect(createOrderRes.body.data.sellerBankInfo).toBeDefined();
      expect(createOrderRes.body.data.sellerBankInfo.accountNumber).toBe(
        '1029384756',
      );

      // Outsider C is strictly forbidden (403) from viewing Buyer B's order or seller bank info
      await request(app.getHttpServer())
        .get(`/api/v1/orders/${orderId}`)
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .expect(403);

      // Step 3: Seller A receives and confirms the order
      const sellerOrdersRes = await request(app.getHttpServer())
        .get('/api/v1/orders/seller')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(200);
      expect(sellerOrdersRes.body.data.length).toBeGreaterThanOrEqual(1);

      const confirmOrderRes = await request(app.getHttpServer())
        .patch(`/api/v1/orders/${orderId}/confirm`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ note: 'Đã xác nhận đơn, bạn chuyển khoản theo mã đơn nhé!' })
        .expect(200);
      expect(confirmOrderRes.body.data.status).toBe('CONFIRMED');

      // Seller A cannot confirm payment before Buyer B submits payment-confirmation -> 400
      await request(app.getHttpServer())
        .patch(`/api/v1/orders/${orderId}/payment/confirm`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .expect(400);

      // Step 4: Buyer B submits bank transfer confirmation
      const buyerPayRes = await request(app.getHttpServer())
        .post(`/api/v1/orders/${orderId}/payment-confirmation`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          transactionReference: 'VCB20261108999',
          transferNote: 'Đã chuyển khoản đủ qua VCB Digibank',
        })
        .expect(200);
      expect(buyerPayRes.body.data.paymentStatus).toBe('BUYER_CONFIRMED');
      expect(buyerPayRes.body.data.payment.transactionReference).toBe(
        'VCB20261108999',
      );

      // Step 5: Seller A confirms receiving bank transfer payment
      const sellerPayRes = await request(app.getHttpServer())
        .patch(`/api/v1/orders/${orderId}/payment/confirm`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ note: 'Đã nhận đủ tiền chuyển khoản' })
        .expect(200);
      expect(sellerPayRes.body.data.paymentStatus).toBe('PAID');
      expect(sellerPayRes.body.data.payment.status).toBe('PAID');

      // Step 6: Seller A updates delivery status to SHIPPING
      const shipRes = await request(app.getHttpServer())
        .patch(`/api/v1/orders/${orderId}/delivery`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          deliveryStatus: 'SHIPPING',
          note: 'Đã gửi shipper giao qua KTX Khu B',
        })
        .expect(200);
      expect(shipRes.body.data.status).toBe('SHIPPING');

      // Phase 9.6 Check: Buyer B CANNOT review an order that is not yet COMPLETED -> 400
      await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          orderId,
          rating: 5,
          comment: 'Thử đánh giá khi đơn chưa hoàn tất',
        })
        .expect(400);

      // Step 7: Buyer B confirms receiving the product
      const completeRes = await request(app.getHttpServer())
        .patch(`/api/v1/orders/${orderId}/complete`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ note: 'Đã nhận tai nghe đúng mô tả, cảm ơn bạn!' })
        .expect(200);

      // Step 8: Order is COMPLETED and Product is SOLD
      expect(completeRes.body.data.status).toBe('COMPLETED');
      expect(completeRes.body.data.paymentStatus).toBe('PAID');

      const finalProdRes = await request(app.getHttpServer())
        .get(`/api/v1/products/${product1Id}`)
        .expect(200);
      expect(finalProdRes.body.data.status).toBe(ProductStatus.SOLD);

      // Verify notifications were created for both Buyer B and Seller A
      const buyerNotifs = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);
      expect(buyerNotifs.body.data.length).toBeGreaterThanOrEqual(3);

      // =========================================================================
      // PHASE 9.6 — SELLER REPUTATION & REVIEWS E2E WORKFLOW
      // =========================================================================

      // 1. Outsider C cannot review Buyer B's completed order -> 403
      await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .set('Authorization', `Bearer ${outsiderCToken}`)
        .send({
          orderId,
          rating: 5,
          comment: 'Người khác cố tình đánh giá đơn của Buyer B',
        })
        .expect(403);

      // 2. Seller A cannot review their own order -> 403
      await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          orderId,
          rating: 5,
          comment: 'Người bán tự đánh giá đơn của mình',
        })
        .expect(403);

      // 3. Buyer B submits a 5-star review with comment and image -> 201
      const createRevRes = await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          orderId,
          rating: 5,
          comment:
              'Tai nghe Sony chống ồn cực tốt, đúng như mô tả khuyết điểm, người bán hỗ trợ nhiệt tình!',
          images: ['http://localhost:3000/uploads/products/review-sony-1.jpg'],
        })
        .expect(201);

      const reviewId = String(createRevRes.body.data.id);
      expect(createRevRes.body.data.rating).toBe(5);
      expect(createRevRes.body.data.images).toHaveLength(1);
      expect(createRevRes.body.data.canBuyerEdit).toBe(true);

      // 4. Duplicate review on the same order is rejected -> 409 Conflict
      await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          orderId,
          rating: 4,
          comment: 'Đánh giá lần 2 cho cùng đơn hàng',
        })
        .expect(409);

      // 5. GET /api/v1/orders/:orderId/review returns the review, and order has hasReview=true
      const orderReviewRes = await request(app.getHttpServer())
        .get(`/api/v1/orders/${orderId}/review`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);
      expect(orderReviewRes.body.data.id).toBe(reviewId);

      const orderAfterRev = await request(app.getHttpServer())
        .get(`/api/v1/orders/${orderId}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(200);
      expect(orderAfterRev.body.data.hasReview).toBe(true);
      expect(orderAfterRev.body.data.reviewId).toBe(reviewId);

      // 6. Buyer B updates their review within 7 days -> 200
      const updateRevRes = await request(app.getHttpServer())
        .patch(`/api/v1/reviews/${reviewId}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({
          rating: 5,
          comment:
              'Đã test pin 3 ngày rất trâu, người bán uy tín 5 sao, đóng gói kỹ!',
          images: [
            'http://localhost:3000/uploads/products/review-sony-1.jpg',
            'http://localhost:3000/uploads/products/review-sony-2.jpg',
          ],
        })
        .expect(200);
      expect(updateRevRes.body.data.images).toHaveLength(2);

      // 7. Arbitrary DELETE /api/v1/reviews/:id is blocked -> 403
      await request(app.getHttpServer())
        .delete(`/api/v1/reviews/${reviewId}`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .expect(403);

      // 8. Seller A views reviews on Seller Profile & replies to the review -> 201
      const sellerRevsBeforeReply = await request(app.getHttpServer())
        .get(`/api/v1/sellers/${sellerAId}/reviews?rating=5`)
        .expect(200);
      expect(sellerRevsBeforeReply.body.data.items).toHaveLength(1);
      expect(sellerRevsBeforeReply.body.data.ratingSummary.averageRating).toBe(
        5,
      );
      expect(sellerRevsBeforeReply.body.data.ratingSummary.totalReviews).toBe(1);

      // Buyer B cannot reply as seller -> 403
      await request(app.getHttpServer())
        .post(`/api/v1/reviews/${reviewId}/reply`)
        .set('Authorization', `Bearer ${buyerBToken}`)
        .send({ reply: 'Buyer cố giả làm seller phản hồi' })
        .expect(403);

      // Seller A replies -> 201
      const replyRes = await request(app.getHttpServer())
        .post(`/api/v1/reviews/${reviewId}/reply`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          reply: 'Cảm ơn bạn Minh đã giao dịch nhanh gọn và đánh giá 5 sao nhé!',
        })
        .expect(201);
      expect(replyRes.body.data.sellerReply).toContain('Cảm ơn bạn Minh');

      // Second reply by Seller A on the same review is blocked -> 409
      await request(app.getHttpServer())
        .post(`/api/v1/reviews/${reviewId}/reply`)
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({ reply: 'Phản hồi lần 2' })
        .expect(409);

      // 9. Seller Reputation endpoint & Public Seller Profile reflect accurate stats
      const repRes = await request(app.getHttpServer())
        .get(`/api/v1/sellers/${sellerAId}/reputation`)
        .expect(200);
      expect(repRes.body.data.averageRating).toBe(5);
      expect(repRes.body.data.ratingSummary.totalReviews).toBe(1);
      expect(repRes.body.data. ratingSummary.star5Count).toBe(1);
      expect(
        repRes.body.data.transactionStats.completedOrdersCount,
      ).toBeGreaterThanOrEqual(1);
      expect(repRes.body.data.reputationScore).toBeGreaterThan(60);
      expect(repRes.body.data.reputationScore).toBeLessThan(100);

      const sellerProfileAfterRev = await request(app.getHttpServer())
        .get(`/api/v1/users/${sellerAId}`)
        .expect(200);
      expect(sellerProfileAfterRev.body.data.stats.rating).toBe(5);
      expect(sellerProfileAfterRev.body.data.stats.totalReviews).toBe(1);
      expect(sellerProfileAfterRev.body.data.stats.reputationScore).toBe(
        repRes.body.data.reputationScore,
      );
    });
  });
});
