import { INestApplication, ValidationPipe } from '@nestjs/common';
import { getConnectionToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { ChildProcess, spawn } from 'child_process';
import * as fs from 'fs';
import * as http from 'http';
import { AddressInfo } from 'net';
import * as path from 'path';
import { Connection, Types } from 'mongoose';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { CategoriesService } from '../src/modules/categories/categories.service';
import {
  ProductCondition,
  ProductStatus,
} from '../src/modules/products/schemas/product.schema';

function resolvePythonExecutable(): string {
  const candidates = [
    process.env.PYTHON_BIN,
    'C:\\Users\\ASUS\\AppData\\Local\\Programs\\Python\\Python311\\python.exe',
    'python',
  ].filter((c): c is string => Boolean(c));

  for (const candidate of candidates) {
    if (candidate === 'python' || fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return 'python';
}

async function getFreePort(): Promise<number> {
  return new Promise<number>((resolve, reject) => {
    const srv = http.createServer();
    srv.listen(0, '127.0.0.1', () => {
      const port = (srv.address() as AddressInfo).port;
      srv.close((err) => (err ? reject(err) : resolve(port)));
    });
  });
}

async function waitForAiHealth(baseUrl: string, timeoutMs = 25000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${baseUrl}/health`);
      if (res.ok) {
        return;
      }
    } catch {
      // Wait for uvicorn startup
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error(`Python AI Service at ${baseUrl} did not become healthy within ${timeoutMs}ms`);
}

describe('Phase 4 — NestJS Backend <-> Python FastAPI LangGraph Integration (12 Scenarios)', () => {
  jest.setTimeout(60000);

  let app: INestApplication;
  let dbConnection: Connection;
  let pythonProcess: ChildProcess | null = null;
  let liveAiBaseUrl = '';

  const testEmailPrefix = 'phase4.ai.e2e.';
  const sellerAEmail = `${testEmailPrefix}seller.a@remarket.vn`;
  const buyerBEmail = `${testEmailPrefix}buyer.b@remarket.vn`;

  let sellerAToken = '';
  let buyerBToken = '';
  let computersCategoryId = '';

  let thinkpadProductId = '';
  let dellProductId = '';
  let macbookProductId = '';
  let draftProductId = '';

  async function cleanUpScopedData(): Promise<void> {
    if (!dbConnection) return;
    const testUsers = await dbConnection
      .collection('users')
      .find({ email: { $regex: `^${testEmailPrefix}` } })
      .project({ _id: 1 })
      .toArray();
    const userIds = testUsers.map((u) => u._id as Types.ObjectId);
    if (userIds.length > 0) {
      await dbConnection
        .collection('products')
        .deleteMany({ sellerId: { $in: userIds } });
      await dbConnection
        .collection('refreshsessions')
        .deleteMany({ userId: { $in: userIds } });
      await dbConnection
        .collection('users')
        .deleteMany({ _id: { $in: userIds } });
    }
  }

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.MONGODB_TEST_URI =
      process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/remarket_test';
    process.env.THROTTLE_LIMIT = '1000';
    process.env.AI_REQUEST_TIMEOUT_MS = '15000';

    const aiPort = await getFreePort();
    liveAiBaseUrl = `http://127.0.0.1:${aiPort}`;
    process.env.AI_SERVICE_URL = liveAiBaseUrl;

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
    await app.listen(0, '127.0.0.1');
    const nestAddress = app.getHttpServer().address() as AddressInfo;
    const nestBaseUrl = `http://127.0.0.1:${nestAddress.port}/api/v1`;

    dbConnection = app.get<Connection>(getConnectionToken());
    await cleanUpScopedData();

    const categoriesService = app.get(CategoriesService);
    await categoriesService.seedInitialCategories();

    // Start the real Python FastAPI + LangGraph AI Service pointing back to this NestJS instance
    const aiDir = path.resolve(__dirname, '../../ai');
    const pythonBin = resolvePythonExecutable();

    pythonProcess = spawn(
      pythonBin,
      [
        '-m',
        'uvicorn',
        'app.main:app',
        '--host',
        '127.0.0.1',
        '--port',
        String(aiPort),
      ],
      {
        cwd: aiDir,
        env: {
          ...process.env,
          GEMINI_API_KEY: '',
          VECTOR_STORE_TYPE: 'memory',
          BACKEND_API_BASE_URL: nestBaseUrl,
          AI_SERVICE_PORT: String(aiPort),
          AI_RATE_LIMIT_REQUESTS: '200',
        },
        stdio: 'ignore',
      },
    );

    await waitForAiHealth(liveAiBaseUrl);

    // Register Seller A and Buyer B
    const regA = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: sellerAEmail,
        password: 'Password123!',
        displayName: 'Seller A Phase4',
        phoneNumber: '+84909111222',
        location: 'Thủ Đức, TP.HCM',
      })
      .expect(201);
    sellerAToken = regA.body.data.tokens.accessToken;

    const regB = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: buyerBEmail,
        password: 'Password123!',
        displayName: 'Buyer B Phase4',
        phoneNumber: '+84909333444',
        location: 'Quận 10, TP.HCM',
      })
      .expect(201);
    buyerBToken = regB.body.data.tokens.accessToken;

    // Fetch Computers category ID
    const catRes = await request(app.getHttpServer())
      .get('/api/v1/categories')
      .expect(200);
    const compCat = catRes.body.data.find(
      (c: { slug: string }) => c.slug === 'computers-accessories',
    );
    computersCategoryId = String(compCat._id);

    // Seed real products in MongoDB for tool calls & shopping assistant tests
    const p1 = await request(app.getHttpServer())
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        categoryId: computersCategoryId,
        title: 'Laptop Lenovo ThinkPad T14 Gen 1 lập trình bền bỉ',
        brand: 'Lenovo',
        description:
          'Laptop cũ dành cho sinh viên lập trình CNTT, RAM 16GB SSD 512GB, máy nguyên bản.',
        price: 8500000,
        originalPrice: 18000000,
        condition: ProductCondition.LIKE_NEW,
        defectDisclosure: 'Trầy nhẹ góc nắp lưng, pin còn 91% dùng 5 tiếng',
        images: [{ url: 'https://cdn.remarket.vn/thinkpad-t14.jpg' }],
        location: 'Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
      })
      .expect(201);
    thinkpadProductId = String(p1.body.data._id);

    const p2 = await request(app.getHttpServer())
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        categoryId: computersCategoryId,
        title: 'Laptop Dell Latitude 7400 dành cho sinh viên lập trình',
        brand: 'Dell',
        description:
          'Laptop mỏng nhẹ học lập trình web và di động, bàn phím gõ êm.',
        price: 7200000,
        originalPrice: 16500000,
        condition: ProductCondition.GOOD,
        defectDisclosure: 'Mòn nhẹ phím Space và xước dăm mặt đáy, pin 82%',
        images: [{ url: 'https://cdn.remarket.vn/dell-7400.jpg' }],
        location: 'Quận 10, TP.HCM',
        status: ProductStatus.ACTIVE,
      })
      .expect(201);
    dellProductId = String(p2.body.data._id);

    const p3 = await request(app.getHttpServer())
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        categoryId: computersCategoryId,
        title: 'Laptop Apple MacBook Pro M2 16GB 512GB',
        brand: 'Apple',
        description: 'MacBook cấu hình cao cho đồ họa và lập trình.',
        price: 24500000,
        originalPrice: 32000000,
        condition: ProductCondition.LIKE_NEW,
        defectDisclosure: 'Không trầy xước, fullbox',
        images: [{ url: 'https://cdn.remarket.vn/mbp-m2.jpg' }],
        location: 'Quận 1, TP.HCM',
        status: ProductStatus.ACTIVE,
      })
      .expect(201);
    macbookProductId = String(p3.body.data._id);

    const pDraft = await request(app.getHttpServer())
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        categoryId: computersCategoryId,
        title: 'Laptop Asus Vivobook cũ bản nháp chưa đăng',
        brand: 'Asus',
        description: 'Bản nháp DRAFT không được phép hiển thị cho người mua.',
        price: 6500000,
        condition: ProductCondition.GOOD,
        defectDisclosure: 'Xước nhẹ mặt A',
        images: [{ url: 'https://cdn.remarket.vn/asus-draft.jpg' }],
        location: 'Thủ Đức, TP.HCM',
        status: ProductStatus.DRAFT,
      })
      .expect(201);
    draftProductId = String(pDraft.body.data._id);
  });

  afterAll(async () => {
    if (pythonProcess) {
      pythonProcess.kill();
      pythonProcess = null;
    }
    await cleanUpScopedData();
    if (app) {
      await app.close();
    }
  });

  // =========================================================================
  // 1. Generate Listing qua NestJS -> Python AI
  // =========================================================================
  it('1. POST /api/v1/ai/generate-listing generates structured listing via Python LangGraph and preserves seller defects', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/generate-listing')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        title: 'Bàn phím cơ không dây Gateron Brown Switch',
        category: 'Máy tính & Phụ kiện',
        condition: 'GOOD',
        defectDisclosure:
          'Trầy nhẹ góc phải khung nhôm và mất đầu thu USB 2.4GHz',
        originalPrice: 1800000,
        price: 950000,
        images: [
          'https://cdn.remarket.vn/kb-1.jpg',
          'https://cdn.remarket.vn/kb-2.jpg',
        ],
      })
      .expect(200);

    expect(res.body.success).toBe(true);
    const data = res.body.data;
    expect(typeof data.suggestedTitle).toBe('string');
    expect(data.suggestedDescription).toEqual(
      expect.objectContaining({
        overview: expect.any(String),
        condition: expect.any(String),
        defects: expect.stringContaining('mất đầu thu USB 2.4GHz'),
      }),
    );
    expect(data.transparencyNote.toLowerCase()).toContain(
      'mất đầu thu usb 2.4ghz',
    );
    expect(data.requiresSellerApproval).toBe(true);
  });

  // =========================================================================
  // 2. Estimate Price qua NestJS -> Python AI -> Product Tools -> NestJS
  // =========================================================================
  it('2. POST /api/v1/ai/estimate-price queries real comparable products from NestJS via Python Product Tools', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/estimate-price')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        title: 'Laptop Lenovo ThinkPad T14',
        brand: 'Lenovo',
        category: 'Máy tính & Phụ kiện',
        condition: 'GOOD',
        defectDisclosure: 'Trầy nhẹ nắp lưng, pin 85%',
        originalPrice: 18000000,
      })
      .expect(200);

    expect(res.body.success).toBe(true);
    const data = res.body.data;
    expect(data.currency).toBe('VND');
    expect(data.quickSellPrice).toBeGreaterThan(0);
    expect(data.quickSellPrice).toBeLessThanOrEqual(data.recommendedPrice);
    expect(data.recommendedPrice).toBeLessThanOrEqual(data.maxFairPrice);
    // Verified that Python AI called NestJS GET /api/v1/products and found our seeded ThinkPad
    expect(data.comparableCount).toBeGreaterThanOrEqual(1);
    expect(data.confidence).toBe('HIGH');
    expect(data.dataSourceNote).toContain('Backend ReMarket');
  });

  // =========================================================================
  // 3. Buyer Checklist với productId thật
  // =========================================================================
  it('3. POST /api/v1/ai/buyer-checklist generates tailored checklist from real MongoDB product + RAG and caches result', async () => {
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/ai/buyer-checklist')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({ productId: thinkpadProductId })
      .expect(200);

    expect(res1.body.success).toBe(true);
    const data1 = res1.body.data;
    expect(data1.productId).toBe(thinkpadProductId);
    expect(data1.cached).toBe(false);
    expect(data1.inspectionPoints.length).toBeGreaterThanOrEqual(3);
    expect(data1.suggestedQuestions.length).toBe(3);

    const combinedDesc = data1.inspectionPoints
      .map((p: { description: string }) => p.description)
      .join(' ')
      .toLowerCase();
    expect(combinedDesc).toContain('trầy nhẹ góc nắp lưng');

    // Second call hits MongoDB cache
    const res2 = await request(app.getHttpServer())
      .post('/api/v1/ai/buyer-checklist')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({ productId: thinkpadProductId })
      .expect(200);

    expect(res2.body.data.cached).toBe(true);
    expect(res2.body.data.inspectionPoints.length).toBeGreaterThanOrEqual(3);
  });

  // =========================================================================
  // 4. Buyer Checklist với productId không tồn tại
  // =========================================================================
  it('4. POST /api/v1/ai/buyer-checklist returns 404 PRODUCT_NOT_FOUND when productId does not exist', async () => {
    const nonExistentId = '65f000000000000000000999';
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/buyer-checklist')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({ productId: nonExistentId })
      .expect(404);

    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('PRODUCT_NOT_FOUND');
  });

  // =========================================================================
  // 5 & 6. Shopping Assistant tìm sản phẩm thật & hội thoại nhiều lượt
  // =========================================================================
  const sharedThreadId = 'conv-phase4-multiturn-laptop';

  it('5. POST /api/v1/ai/chat (Turn 1) finds real ACTIVE laptops <= 10M with all 10 required product schema fields', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({
        message:
          'Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu',
        thread_id: sharedThreadId,
      })
      .expect(200);

    expect(res.body.success).toBe(true);
    const data = res.body.data;
    expect(data.thread_id).toBe(sharedThreadId);
    expect(data.intent).toBe('PRODUCT_DISCOVERY');
    expect(data.matchedProducts.length).toBe(2);

    const returnedIds = data.matchedProducts.map((p: { _id: string }) => p._id);
    expect(returnedIds).toContain(thinkpadProductId);
    expect(returnedIds).toContain(dellProductId);
    // MacBook (24.5M) and Asus DRAFT (6.5M) must NOT be returned
    expect(returnedIds).not.toContain(macbookProductId);
    expect(returnedIds).not.toContain(draftProductId);

    // Verify all 10 required fields on each matched product
    for (const prod of data.matchedProducts) {
      expect(prod._id).toBeDefined();
      expect(prod.sellerId).toBeDefined();
      expect(prod.categoryId).toBe(computersCategoryId);
      expect(typeof prod.title).toBe('string');
      expect(typeof prod.description).toBe('string');
      expect(prod.price).toBeLessThanOrEqual(10000000);
      expect(typeof prod.condition).toBe('string');
      expect(Array.isArray(prod.images)).toBe(true);
      expect(typeof prod.location).toBe('string');
      expect(prod.status).toBe(ProductStatus.ACTIVE);
    }
  });

  it('6. POST /api/v1/ai/chat (Turn 2) remembers Turn 1 matchedProducts via thread_id and compares them', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({
        message: 'Trong số đó, con nào đáng mua nhất?',
        thread_id: sharedThreadId,
      })
      .expect(200);

    expect(res.body.success).toBe(true);
    const data = res.body.data;
    expect(data.thread_id).toBe(sharedThreadId);
    expect(data.intent).toBe('PRODUCT_COMPARISON');
    expect(data.matchedProducts.length).toBe(2);
    expect(data.message).toContain('Đáng mua nhất');
    expect(data.message).toContain('Lenovo ThinkPad T14');
    expect(data.message).toContain('Dell Latitude 7400');
  });

  // =========================================================================
  // 7. Không có sản phẩm phù hợp
  // =========================================================================
  it('7. POST /api/v1/ai/chat returns empty matchedProducts and helpful guidance when no products match', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({
        message: 'Tôi muốn mua máy ảnh Sony Alpha dưới 500 nghìn',
      })
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.matchedProducts).toEqual([]);
    expect(res.body.data.message.toLowerCase()).toContain('chưa tìm thấy');
  });

  // =========================================================================
  // 8. Sản phẩm đã xóa hoặc không hợp lệ không được trả về
  // =========================================================================
  it('8. Deleted or non-ACTIVE products are never returned by Shopping Assistant even if previously in conversation memory', async () => {
    // Seller A deletes Dell Latitude 7400 from MongoDB
    await request(app.getHttpServer())
      .delete(`/api/v1/products/${dellProductId}`)
      .set('Authorization', `Bearer ${sellerAToken}`)
      .expect(200);

    // Buyer B sends a follow-up on the same thread_id where Dell was previously stored in memory
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({
        message: 'Trong số đó, con nào đáng mua nhất?',
        thread_id: sharedThreadId,
      })
      .expect(200);

    const returnedIds = res.body.data.matchedProducts.map(
      (p: { _id: string }) => p._id,
    );
    // Deleted Dell product must be stripped out; only ACTIVE ThinkPad remains
    expect(returnedIds).not.toContain(dellProductId);
    expect(returnedIds).toEqual([thinkpadProductId]);
  });

  // =========================================================================
  // 9. Request không có JWT (và client gửi user_id giả mạo)
  // =========================================================================
  it('9. Rejects requests without JWT with 401 UNAUTHORIZED and rejects client-supplied user_id with 400 VALIDATION_ERROR', async () => {
    const noJwtRes = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .send({ message: 'Tìm laptop cũ' })
      .expect(401);

    expect(noJwtRes.body.success).toBe(false);
    expect(noJwtRes.body.error.code).toBe('UNAUTHORIZED');

    // Client-supplied user_id in body is rejected
    const spoofRes = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({
        message: 'Tìm laptop cũ',
        user_id: '65f1a2b3c4d5e6f7a8b9c0d1',
      })
      .expect(400);

    expect(spoofRes.body.success).toBe(false);
    expect(spoofRes.body.error.code).toBe('VALIDATION_ERROR');
  });

  // =========================================================================
  // 10. User khác không đọc được thread_id của user hiện tại
  // =========================================================================
  it('10. Blocks another user (Seller A) from reading, hijacking, or deleting Buyer B thread_id with 403 FORBIDDEN', async () => {
    // Buyer B can read their own conversation
    const ownRes = await request(app.getHttpServer())
      .get(`/api/v1/ai/conversations/${sharedThreadId}`)
      .set('Authorization', `Bearer ${buyerBToken}`)
      .expect(200);
    expect(ownRes.body.data.conversation_id).toBe(sharedThreadId);

    // Seller A cannot read Buyer B's conversation
    const otherGetRes = await request(app.getHttpServer())
      .get(`/api/v1/ai/conversations/${sharedThreadId}`)
      .set('Authorization', `Bearer ${sellerAToken}`)
      .expect(403);
    expect(otherGetRes.body.error.code).toBe('FORBIDDEN');

    // Seller A cannot hijack Buyer B's thread_id in POST /api/v1/ai/chat
    const otherChatRes = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${sellerAToken}`)
      .send({
        message: 'Cho mình xem tiếp',
        thread_id: sharedThreadId,
      })
      .expect(403);
    expect(otherChatRes.body.error.code).toBe('FORBIDDEN');
  });

  // =========================================================================
  // 11. AI Service tắt -> Backend trả lỗi chuẩn, không crash
  // =========================================================================
  it('11. Returns 503 AI_SERVICE_UNAVAILABLE when Python AI Service is down without crashing NestJS', async () => {
    const previousUrl = process.env.AI_SERVICE_URL;
    process.env.AI_SERVICE_URL = 'http://127.0.0.1:59997';
    // Also override ConfigService value temporarily via env or spy
    const configService = app.get(
      (await import('@nestjs/config')).ConfigService,
    );
    const getSpy = jest
      .spyOn(configService, 'get')
      .mockImplementation((key: string) => {
        if (key === 'ai.serviceUrl') return 'http://127.0.0.1:59997';
        if (key === 'ai.timeoutMs') return 2000;
        return undefined;
      });

    try {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/generate-listing')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          title: 'Bàn phím cơ Keychron K6',
          condition: 'LIKE_NEW',
        })
        .expect(503);

      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('AI_SERVICE_UNAVAILABLE');

      // Verify NestJS Backend is still alive and serving requests normally
      const healthRes = await request(app.getHttpServer())
        .get('/api/v1/health')
        .expect(200);
      expect(healthRes.body.data.status).toBe('ok');
    } finally {
      getSpy.mockRestore();
      process.env.AI_SERVICE_URL = previousUrl;
    }
  });

  // =========================================================================
  // 12. AI Service timeout -> Backend trả lỗi chuẩn
  // =========================================================================
  it('12. Returns 504 AI_REQUEST_TIMEOUT when Python AI Service exceeds timeout threshold', async () => {
    const slowServer = http.createServer((_req, res) => {
      setTimeout(() => {
        res.statusCode = 200;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ ok: true }));
      }, 1500);
    });
    await new Promise<void>((resolve) =>
      slowServer.listen(0, '127.0.0.1', () => resolve()),
    );
    const slowPort = (slowServer.address() as AddressInfo).port;

    const configService = app.get(
      (await import('@nestjs/config')).ConfigService,
    );
    const getSpy = jest
      .spyOn(configService, 'get')
      .mockImplementation((key: string) => {
        if (key === 'ai.serviceUrl') return `http://127.0.0.1:${slowPort}`;
        if (key === 'ai.timeoutMs') return 200;
        return undefined;
      });

    try {
      const res = await request(app.getHttpServer())
        .post('/api/v1/ai/estimate-price')
        .set('Authorization', `Bearer ${sellerAToken}`)
        .send({
          title: 'Laptop Lenovo ThinkPad T14',
          condition: 'GOOD',
        })
        .expect(504);

      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('AI_REQUEST_TIMEOUT');
    } finally {
      getSpy.mockRestore();
      await new Promise<void>((resolve) => slowServer.close(() => resolve()));
    }
  });

  // =========================================================================
  // 13. Full 7-Step End-to-End User & Buyer Journey (Phase 5 Section 3)
  // =========================================================================
  it('13. Executes the complete 7-step Seller & Buyer E2E workflow (Login -> AI Generate Listing -> Edit & Publish Product -> Buyer View Detail -> AI Buyer Checklist -> AI Shopping Assistant -> Real Grounded Retrieval)', async () => {
    // Step 1: Seller A and Buyer B log in via POST /api/v1/auth/login
    const sellerLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: sellerAEmail, password: 'Password123!' })
      .expect(200);
    const freshSellerToken = sellerLogin.body.data.tokens.accessToken;

    const buyerLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: buyerBEmail, password: 'Password123!' })
      .expect(200);
    const freshBuyerToken = buyerLogin.body.data.tokens.accessToken;

    // Step 2: Seller A uses AI Listing Generator & AI Price Estimator
    const aiListingRes = await request(app.getHttpServer())
      .post('/api/v1/ai/generate-listing')
      .set('Authorization', `Bearer ${freshSellerToken}`)
      .send({
        title: 'Tai nghe chống ồn Sony WH-1000XM4',
        brand: 'Sony',
        category: 'Máy tính & Phụ kiện',
        condition: 'LIKE_NEW',
        defectDisclosure:
          'Xước nhẹ 2mm ở gọng nhựa bên trái, đệm tai êm, pin bật ANC 26 tiếng',
        originalPrice: 6990000,
        price: 3900000,
        images: ['https://cdn.remarket.vn/sony-xm4-main.jpg'],
      })
      .expect(200);

    const genListing = aiListingRes.body.data;
    expect(genListing.requiresSellerApproval).toBe(true);
    expect(genListing.suggestedDescription.defects).toContain(
      'Xước nhẹ 2mm ở gọng nhựa bên trái',
    );

    const aiPriceRes = await request(app.getHttpServer())
      .post('/api/v1/ai/estimate-price')
      .set('Authorization', `Bearer ${freshSellerToken}`)
      .send({
        title: 'Tai nghe chống ồn Sony WH-1000XM4',
        brand: 'Sony',
        condition: 'LIKE_NEW',
        defectDisclosure: 'Xước nhẹ 2mm ở gọng nhựa bên trái',
        originalPrice: 6990000,
      })
      .expect(200);

    expect(aiPriceRes.body.data.quickSellPrice).toBeLessThanOrEqual(
      aiPriceRes.body.data.recommendedPrice,
    );

    // Step 3: Seller A edits the AI-suggested content and publishes the product listing
    const createProdRes = await request(app.getHttpServer())
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${freshSellerToken}`)
      .send({
        categoryId: computersCategoryId,
        title: genListing.suggestedTitle,
        brand: 'Sony',
        description: `${genListing.suggestedDescriptionText}\n[Đã kiểm tra kỹ trước khi đăng bán]`,
        price: 3850000,
        originalPrice: 6990000,
        condition: ProductCondition.LIKE_NEW,
        defectDisclosure:
          'Xước nhẹ 2mm ở gọng nhựa bên trái, đệm tai êm, pin bật ANC 26 tiếng',
        transparencyNote: genListing.transparencyNote,
        transparencyScore: genListing.transparencyScore,
        tags: genListing.suggestedTags,
        images: [{ url: 'https://cdn.remarket.vn/sony-xm4-main.jpg' }],
        location: 'Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
      })
      .expect(201);

    const publishedProductId = String(createProdRes.body.data._id);

    // Seller A further edits price via PATCH /api/v1/products/:id
    const patchProdRes = await request(app.getHttpServer())
      .patch(`/api/v1/products/${publishedProductId}`)
      .set('Authorization', `Bearer ${freshSellerToken}`)
      .send({ price: 3750000 })
      .expect(200);
    expect(patchProdRes.body.data.price).toBe(3750000);

    // Step 4: Buyer B views the product detail (GET /api/v1/products/:id)
    const detailRes = await request(app.getHttpServer())
      .get(`/api/v1/products/${publishedProductId}`)
      .set('Authorization', `Bearer ${freshBuyerToken}`)
      .expect(200);

    expect(detailRes.body.data._id).toBe(publishedProductId);
    expect(detailRes.body.data.price).toBe(3750000);
    expect(detailRes.body.data.viewCount).toBeGreaterThanOrEqual(1);
    expect(detailRes.body.data.sellerId.passwordHash).toBeUndefined();

    // Step 5: Buyer B generates AI Buyer Inspection Checklist for this real product
    const checklistRes = await request(app.getHttpServer())
      .post('/api/v1/ai/buyer-checklist')
      .set('Authorization', `Bearer ${freshBuyerToken}`)
      .send({ productId: publishedProductId })
      .expect(200);

    const checklist = checklistRes.body.data;
    expect(checklist.productId).toBe(publishedProductId);
    expect(checklist.inspectionPoints.length).toBeGreaterThanOrEqual(3);
    expect(checklist.suggestedQuestions.length).toBe(3);
    const allPointDescriptions = checklist.inspectionPoints
      .map((pt: { description: string }) => pt.description)
      .join(' ')
      .toLowerCase();
    expect(allPointDescriptions).toContain('xước nhẹ 2mm ở gọng nhựa bên trái');

    // Step 6 & 7: Buyer B asks Shopping Assistant -> AI retrieves the real Sony WH-1000XM4 from MongoDB and answers
    const journeyThreadId = 'conv-phase5-full-journey-sony';
    const chatTurn1 = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${freshBuyerToken}`)
      .send({
        message: 'Tôi muốn tìm mua tai nghe Sony dưới 4 triệu',
        thread_id: journeyThreadId,
      })
      .expect(200);

    expect(chatTurn1.body.data.intent).toBe('PRODUCT_DISCOVERY');
    const matchedIds = chatTurn1.body.data.matchedProducts.map(
      (p: { _id: string }) => p._id,
    );
    expect(matchedIds).toContain(publishedProductId);
    const matchedSony = chatTurn1.body.data.matchedProducts.find(
      (p: { _id: string }) => p._id === publishedProductId,
    );
    expect(matchedSony.price).toBe(3750000);
    expect(matchedSony.status).toBe(ProductStatus.ACTIVE);
  });

  // =========================================================================
  // 14. Input Length & Payload Boundary Validation (Phase 5 Section 5)
  // =========================================================================
  it('14. Enforces strict input size limits on AI endpoints and never leaks stack traces', async () => {
    const oversizedMessage = 'A'.repeat(2500);
    const res = await request(app.getHttpServer())
      .post('/api/v1/ai/chat')
      .set('Authorization', `Bearer ${buyerBToken}`)
      .send({ message: oversizedMessage })
      .expect(400);

    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.stack).toBeUndefined();
    expect(res.body.error.stack).toBeUndefined();
  });
});
