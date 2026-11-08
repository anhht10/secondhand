import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import * as bcrypt from 'bcrypt';
import { AppModule } from '../app.module';
import { CategoriesService } from '../modules/categories/categories.service';
import { CreateProductDto } from '../modules/products/dto/create-product.dto';
import { ProductsService } from '../modules/products/products.service';
import {
  ProductCondition,
  ProductStatus,
} from '../modules/products/schemas/product.schema';
import { UsersService } from '../modules/users/users.service';

async function runSeed(): Promise<void> {
  const logger = new Logger('DatabaseSeeder');
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const categoriesService = app.get(CategoriesService);
    const usersService = app.get(UsersService);
    const productsService = app.get(ProductsService);

    await categoriesService.seedInitialCategories();
    const categories = await categoriesService.findAll();
    logger.log(`Seeded ${categories.length} marketplace categories.`);

    const catBySlug = (slug: string) =>
      categories.find((c) => c.slug === slug) ?? categories[0];

    const passwordHash = await bcrypt.hash('ReMarket123!', 10);

    // 1. Demo Seller Account
    const sellerEmail = 'khoa.nguyen@remarket.vn';
    let seller = await usersService.findByEmailWithPassword(sellerEmail);
    if (!seller) {
      seller = await usersService.create({
        email: sellerEmail,
        passwordHash,
        displayName: 'Nguyễn Minh Khoa',
        phoneNumber: '+84901234567',
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        university: 'ĐH Bách Khoa - ĐHQG TP.HCM',
        bio: 'Sinh viên năm cuối Khoa KH&KT Máy tính ĐH Bách Khoa. Chuyên pass lại bàn phím cơ, tai nghe và đồ công nghệ giữ kỹ, cam kết minh bạch 100%.',
        isEmailVerified: true,
        bankInfo: {
          bankName: 'Vietcombank (VCB)',
          accountNumber: '1029384756',
          accountHolder: 'NGUYEN MINH KHOA',
          branch: 'CN Thủ Đức, TP.HCM',
        },
      });
      logger.log(`Created demo seller account: ${sellerEmail}`);
    } else {
      await usersService.updateProfile(String(seller._id), {
        displayName: 'Nguyễn Minh Khoa',
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        university: 'ĐH Bách Khoa - ĐHQG TP.HCM',
        bio: 'Sinh viên năm cuối Khoa KH&KT Máy tính ĐH Bách Khoa. Chuyên pass lại bàn phím cơ, tai nghe và đồ công nghệ giữ kỹ, cam kết minh bạch 100%.',
        bankInfo: {
          bankName: 'Vietcombank (VCB)',
          accountNumber: '1029384756',
          accountHolder: 'NGUYEN MINH KHOA',
          branch: 'CN Thủ Đức, TP.HCM',
        },
      });
    }

    // 2. Demo Buyer Account
    const buyerEmail = 'minh.tran@student.edu.vn';
    let buyer = await usersService.findByEmailWithPassword(buyerEmail);
    if (!buyer) {
      buyer = await usersService.create({
        email: buyerEmail,
        passwordHash,
        displayName: 'Trần Hoàng Minh',
        phoneNumber: '+84912345678',
        location: 'Quận 5, TP.HCM',
        university: 'ĐH Khoa học Tự nhiên - ĐHQG TP.HCM',
        bio: 'Sinh viên CNTT năm 2 ĐH KHTN, đang tìm đồ setup góc học tập tại ký túc xá.',
        isEmailVerified: true,
      });
      logger.log(`Created demo buyer account: ${buyerEmail}`);
    }

    // 3. Seed 12 Student Marketplace Products idempotently
    const existingListings = await productsService.findMyListings(
      String(seller._id),
      { page: 1, limit: 50 },
    );
    const existingTitles = new Set(
      existingListings.items.map((item) => item.title.toLowerCase()),
    );

    const sampleProducts: CreateProductDto[] = [
      {
        categoryId: String(catBySlug('electronics')._id),
        title: 'Tai nghe chống ồn Sony WH-1000XM4 Wireless Fullbox',
        brand: 'Sony',
        price: 3950000,
        originalPrice: 6490000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Cơ sở Lý Thường Kiệt, Quận 10, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Đệm tai da còn nguyên vẹn không bong tróc, chỉ có 1 vết xước lông mèo 2mm ở mặt ngoài hộp đựng cứng.',
        transparencyNote:
          'Pin thực tế còn hơn 27 tiếng bật ANC, đầy đủ cáp sạc USB-C, dây AUX và jack máy bay zin.',
        transparencyScore: 98,
        tags: ['#sony', '#wh1000xm4', '#tainghechongon', '#sinhviencntt'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nTai nghe chống ồn chủ động đỉnh cao Sony WH-1000XM4 màu Đen nhám, cực kỳ phù hợp cho các bạn sinh viên học bài trong thư viện hoặc quán cà phê.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Đệm tai êm, không bong tróc, màng loa trong trẻo.\n- Khai báo minh bạch: Chỉ có 1 vết xước nhẹ 2mm ngoài hộp vải đựng, thân tai nghe đẹp 99%.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Fullbox gồm hộp cứng, cáp USB-C, dây 3.5mm.\n- Hẹn test trực tiếp tại ĐH Bách Khoa Quận 10 hoặc Làng ĐH Thủ Đức.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
            sortOrder: 0,
            altText: 'Sony WH-1000XM4 Headphones',
          },
        ],
        aiChecklistCache: {
          inspectionPoints: [
            'Kết nối ứng dụng Sony Headphones Connect để kiểm tra số serial và firmware chính hãng.',
            'Bật chế độ Chống ồn (ANC) và Xuyên âm (Ambient Sound) nghe thử 5 phút xem có tiếng sôi hay lệch vế không.',
            'Kiểm tra cảm ứng vuốt tăng giảm âm lượng ở củ tai bên phải và cảm biến tự dừng nhạc khi tháo tai nghe.',
            'Kiểm tra phần bản lề gập mở và lớp da đệm tai đúng như mô tả.',
          ],
          suggestedQuestions: [
            'Chào bạn, tai nghe Sony XM4 này kết nối app Sony Headphones Connect bình thường chứ ạ?',
            'Pin thực tế khi bật chống ồn liên tục hiện tại còn khoảng bao nhiêu tiếng?',
            'Mình hẹn test trực tiếp ở thư viện ĐH Bách Khoa chiều mai được không?',
          ],
          safetyTip:
            'Hãy tải sẵn ứng dụng Sony Headphones Connect trên điện thoại để ghép nối kiểm tra tai nghe chính hãng ngay khi gặp mặt.',
          generatedAt: new Date(),
        },
      },
      {
        categoryId: String(catBySlug('computers-accessories')._id),
        title: 'Bàn phím cơ không dây Keychron K6 Hotswap (Gateron Brown)',
        brand: 'Keychron',
        price: 1350000,
        originalPrice: 2390000,
        condition: ProductCondition.GOOD,
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Khung nhôm cạnh phải có vết xước nhẹ 1mm do cọ vào đế tản nhiệt, phím Space hơi bóng nhẹ, toàn bộ switch nhận 100%.',
        transparencyNote:
          'Đã mod foam đáy tiêu âm và lube sẵn stabilizer, gõ cực êm không ồn khi dùng trong phòng trọ/thư viện.',
        transparencyScore: 96,
        tags: ['#keychron', '#keychronk6', '#banphimco', '#hotswap'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nBàn phím cơ Bluetooth 5.1 / Type-C Keychron K6 bản khung nhôm, Hotswap, LED RGB, Gateron Brown Switch gõ đầm tay.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Mạch nguyên zin 100%, kết nối cùng lúc 3 thiết bị Mac/Windows/iPad.\n- Khai báo minh bạch: Cạnh phải khung nhôm có vết xước 1mm và keycap Space hơi bóng nhẹ.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Hộp, cáp Type-C góc vuông zin, keycap puller, switch puller và bộ keycap Mac/Win.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3',
            sortOrder: 0,
            altText: 'Keychron K6 Mechanical Keyboard',
          },
        ],
        aiChecklistCache: {
          inspectionPoints: [
            'Mở trang web keytest.vn trên laptop để bấm thử toàn bộ 68 phím (tránh lỗi chập hoặc double-click).',
            'Gạt công tắc cạnh bên sang chế độ Bluetooth và thử chuyển đổi giữa 3 thiết bị (Fn1 + Q/W/E).',
            'Kiểm tra cổng cắm USB Type-C xem có bị lỏng hay chập chờn khi lắc nhẹ dây không.',
            'Xem trực tiếp vết xước 1mm ở cạnh phải khung nhôm như người bán đã khai báo.',
          ],
          suggestedQuestions: [
            'Bàn phím có bị liệt hay chập chờn phím nào khi dùng chế độ Bluetooth không bạn?',
            'Pin dùng bật LED nhẹ thì khoảng bao lâu mới phải sạc một lần ạ?',
            'Mình ở KTX Khu B qua lấy ngay tối nay thì bạn có fix nhẹ tiền xăng không?',
          ],
          safetyTip:
            'Mang theo laptop hoặc điện thoại để test trực tiếp cả kết nối dây Type-C lẫn Bluetooth tại chỗ.',
          generatedAt: new Date(),
        },
      },
      {
        categoryId: String(catBySlug('computers-accessories')._id),
        title: 'Màn hình đồ họa Dell UltraSharp U2422H 24 inch FHD IPS USB-C',
        brand: 'Dell',
        price: 3650000,
        originalPrice: 5890000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Quận 10, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Tấm nền sáng đẹp 100% không điểm chết, không ám ố; chân đế có 1 vết xước mờ do để bàn phím lên.',
        transparencyNote:
          'Chuẩn màu 100% sRGB từ nhà máy, còn giấy cân màu và đầy đủ cáp DisplayPort + USB-C.',
        transparencyScore: 97,
        tags: ['#dellultrasharp', '#u2422h', '#manhinhcode', '#sinhvienit'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nMàn hình quốc dân Dell UltraSharp U2422H viền siêu mỏng 4 cạnh, tấm nền IPS chống chói cực kỳ dịu mắt khi code và đọc tài liệu.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Không điểm chết, không hở sáng nặng.\n- Khai báo minh bạch: Mặt chân đế có vết xước mảnh 3cm do đặt bàn phím nhôm lên.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Dây nguồn, cáp DisplayPort và cáp USB-C zin theo màn.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf',
            sortOrder: 0,
            altText: 'Dell UltraSharp Monitor',
          },
        ],
      },
      {
        categoryId: String(catBySlug('computers-accessories')._id),
        title: 'Chuột công thái học Logitech MX Master 3S Silent Wireless',
        brand: 'Logitech',
        price: 1650000,
        originalPrice: 2490000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Feet chuột dưới đáy có xước dăm tự nhiên theo thời gian sử dụng trên pad vải, lớp cao su thân chuột còn nguyên sần như mới.',
        transparencyNote:
          'Click Silent êm tuyệt đối, con lăn vô cực MagSpeed hoạt động mượt mà, kèm đầu thu Logi Bolt.',
        transparencyScore: 95,
        tags: ['#logitech', '#mxmaster3s', '#chuotkhongday', '#ergonomic'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nChuột không dây Logitech MX Master 3S màu Graphite, mắt đọc 8000 DPI chạy được trên cả mặt kính.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Nút bấm êm không double-click, pin dùng hơn 1 tháng.\n- Khai báo minh bạch: Feet dưới đáy có vết trượt nhẹ trên bàn di chuột.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Fullbox gồm chuột, receiver Logi Bolt và cáp sạc USB-C.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46',
            sortOrder: 0,
            altText: 'Logitech MX Master 3S Mouse',
          },
        ],
      },
      {
        categoryId: String(catBySlug('computers-accessories')._id),
        title: 'Bàn phím cơ Akko 3068B Plus Black & Gold (Jelly Pink Switch)',
        brand: 'Akko',
        price: 980000,
        originalPrice: 1790000,
        condition: ProductCondition.GOOD,
        location: 'KTX Khu B ĐHQG, Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Mất nắp nhựa che bụi đi kèm, còn lại bàn phím + USB Receiver 2.4Ghz hoạt động hoàn hảo 3 chế độ.',
        transparencyNote:
          'Keycap PBT Double-shot không bám vân tay, Jelly Pink switch tuyến tính êm ái.',
        transparencyScore: 94,
        tags: ['#akko', '#3068bplus', '#banphimco', '#ktxdhqg'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nBàn phím cơ Akko 3068B Plus 3 mode (Bluetooth 5.0 / Wireless 2.4Ghz / Type-C), keycap PBT cực bền.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- LED RGB sáng đều tất cả các phím.\n- Khai báo minh bạch: Thất lạc tấm nhựa che bụi trong lúc dọn phòng, còn hộp và đủ phụ kiện khác.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- USB Receiver 2.4Ghz, cáp xoắn, keycap tặng kèm.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1618384887929-16ec33fab9ef',
            sortOrder: 0,
            altText: 'Akko 3068B Plus Keyboard',
          },
        ],
      },
      {
        categoryId: String(catBySlug('home-living')._id),
        title: 'Đèn bàn học chống cận Xiaomi Mi LED Desk Lamp 1S (Bản Quốc Tế)',
        brand: 'Xiaomi',
        price: 520000,
        originalPrice: 890000,
        condition: ProductCondition.LIKE_NEW,
        location: 'KTX Khu A ĐHQG, Thủ Đức, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Không có vết trầy xước, núm xoay chỉnh độ sáng & nhiệt độ màu nhạy 100%, kết nối app Mi Home bình thường.',
        transparencyNote:
          'Chỉ số hoàn màu Ra90 chuẩn ánh sáng tự nhiên, học đêm không mỏi mắt.',
        transparencyScore: 99,
        tags: ['#xiaomi', '#denbanhoc', '#chongcan', '#dophongtro'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nĐèn bàn thông minh Xiaomi Mi LED Desk Lamp 1S thân kim loại gập gọn, chỉnh được nhiệt độ màu vàng ấm sang trắng sáng.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Đèn đẹp như mới 99%, không trầy xước.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Đèn + củ nguồn zin theo hộp. Giao dịch tại cổng KTX Khu A.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1534073828943-f801091bb18c',
            sortOrder: 0,
            altText: 'Xiaomi Mi LED Desk Lamp 1S',
          },
        ],
      },
      {
        categoryId: String(catBySlug('computers-accessories')._id),
        title: 'Giá đỡ Laptop hợp kim nhôm HyperWork L01 (Chịu tải 10kg)',
        brand: 'HyperWork',
        price: 290000,
        originalPrice: 550000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Quận 10, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Đệm cao su chống trượt còn nguyên, khớp xoay cứng cáp không bị xệ khi đặt laptop 16 inch.',
        transparencyNote:
          'Phù hợp cho laptop từ 13 đến 17 inch, giúp nâng tầm mắt chống mỏi cổ khi ngồi code.',
        transparencyScore: 98,
        tags: ['#hyperwork', '#giadolaptop', '#ergonomic', '#goclamviec'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nGiá đỡ laptop nhôm nguyên khối HyperWork L01 cắt CNC sắc sảo, thoáng khí tản nhiệt cực tốt.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Khớp bản lề rất chắc, không trầy xước.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Kèm cờ-lê lục giác chỉnh độ cứng khớp xoay.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46',
            sortOrder: 0,
            altText: 'HyperWork Aluminum Laptop Stand',
          },
        ],
      },
      {
        categoryId: String(catBySlug('home-living')._id),
        title:
          'Bàn học gỗ thông tự nhiên gấp gọn 120x60cm cho phòng trọ sinh viên',
        brand: 'IKEA Style',
        price: 450000,
        originalPrice: 950000,
        condition: ProductCondition.GOOD,
        location: 'Phường Đông Hòa, Dĩ An (Sát Làng ĐH Thủ Đức)',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Mặt bàn góc trái có vết vệt ly nước mờ đường kính 4cm, chân sắt sơn tĩnh điện chắc chắn không rung lắc.',
        transparencyNote:
          'Chân bàn tháo lắp bằng ốc lục giác trong 5 phút, chở vừa bằng xe máy.',
        transparencyScore: 93,
        tags: ['#banhoc', '#banlamviec', '#dophongtro', '#langdaihoc'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nBàn học kích thước rộng rãi 120x60x75cm để thoải mái 1 màn hình rời + laptop + sách vở.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Kết cấu chắc chắn, chịu lực tốt.\n- Khai báo minh bạch: Có vết mờ nhỏ góc trái mặt bàn do đặt ly nước lạnh.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Hỗ trợ tháo sẵn chân bàn và buộc lên xe máy giúp bạn mua.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd',
            sortOrder: 0,
            altText: 'Wooden Study Desk',
          },
        ],
      },
      {
        categoryId: String(catBySlug('books')._id),
        title:
          'Combo 3 Giáo trình Giải tích 1, Giải tích 2 & Đại số Tuyến tính (ĐHQG)',
        brand: 'NXB ĐHQG TP.HCM',
        price: 120000,
        originalPrice: 285000,
        condition: ProductCondition.GOOD,
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        status: ProductCondition.GOOD
          ? ProductStatus.ACTIVE
          : ProductStatus.ACTIVE,
        defectDisclosure:
          'Có highlight bút dạ quang nhẹ ở khoảng 15 trang công thức quan trọng, bìa bọc plastic sạch sẽ không rách trang nào.',
        transparencyNote:
          'Tặng kèm tập đề thi cuối kỳ các năm trước có lời giải chi tiết của ĐH Bách Khoa & KHTN.',
        transparencyScore: 97,
        tags: ['#giaotrinh', '#giaitich', '#daisotuyentinh', '#dhqg'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nTrọn bộ 3 cuốn giáo trình Toán đại cương bắt buộc cho sinh viên năm nhất khối Kỹ thuật & CNTT ĐHQG TP.HCM.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Sách in chính hãng NXB ĐHQG, đã bọc bìa kính.\n- Khai báo minh bạch: Có tô dạ quang các định lý trọng tâm.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Tặng kèm xấp đề ôn thi Giữa kỳ + Cuối kỳ.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c',
            sortOrder: 0,
            altText: 'Calculus & Linear Algebra Textbooks',
          },
        ],
      },
      {
        categoryId: String(catBySlug('phones-tablets')._id),
        title: 'Máy đọc sách Kindle Paperwhite 5 (8GB, Màn 6.8 inch Đèn Vàng)',
        brand: 'Amazon',
        price: 2450000,
        originalPrice: 3690000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Quận 5, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Màn hình E-Ink không vết xước, mặt lưng nhám có 1 vệt bóng nhẹ do lắp ốp từ tính.',
        transparencyNote:
          'Tặng kèm bao da tự động tắt/mở màn hình và kho 500 ebook chuyên ngành + ngoại ngữ.',
        transparencyScore: 96,
        tags: ['#kindle', '#paperwhite5', '#maydocsach', '#sinhvien'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nKindle Paperwhite Gen 11 (PPW5) màn hình 6.8 inch chống nước IPX8, có đèn nền vàng ấm đọc tài liệu PDF/EPUB cực thích.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Pin chờ hơn 3 tuần, cảm ứng nhạy.\n- Khai báo minh bạch: Mặt lưng hơi bóng nhẹ ở góc gắn cover.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Máy, cáp USB-C và bao da từ tính.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c',
            sortOrder: 0,
            altText: 'Kindle Paperwhite 5 E-reader',
          },
        ],
      },
      {
        categoryId: String(catBySlug('fashion')._id),
        title: 'Balo Laptop chống sốc Tomtoc Slash Flip 15.6 inch chống nước',
        brand: 'Tomtoc',
        price: 680000,
        originalPrice: 1290000,
        condition: ProductCondition.LIKE_NEW,
        location: 'Quận 10, TP.HCM',
        status: ProductStatus.ACTIVE,
        defectDisclosure:
          'Khóa kéo YKK mượt 100%, vải kháng nước sạch đẹp không sờn rách.',
        transparencyNote:
          'Ngăn đựng laptop có đệm góc Armor bảo vệ cực êm khi di chuyển bằng xe buýt đi học.',
        transparencyScore: 98,
        tags: ['#balo', '#tomtoc', '#balolaptop', '#sinhvien'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nBalo chính hãng Tomtoc thiết kế tối giản, nhẹ và có ngăn chống sốc chuyên dụng cho laptop 15.6" - 16".\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Mới đeo vài lần, đã giặt khô sạch sẽ.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Xem trực tiếp tại Quận 10 hoặc Thủ Đức.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62',
            sortOrder: 0,
            altText: 'Tomtoc Laptop Backpack',
          },
        ],
      },
      {
        categoryId: String(catBySlug('sports-hobbies')._id),
        title:
          'Máy tính khoa học Casio fx-580VN X chính hãng Bitex (Đã đặt gạch)',
        brand: 'Casio',
        price: 380000,
        originalPrice: 680000,
        condition: ProductCondition.GOOD,
        location: 'Làng ĐH Thủ Đức, TP.HCM',
        status: ProductStatus.RESERVED,
        defectDisclosure:
          'Nắp trượt có xước dăm nhẹ do để trong bóp viết, màn hình LCD sắc nét, còn nguyên tem chống giả Bitex.',
        transparencyNote:
          'Đã qua các môn Toán đại cương và Xác suất thống kê nên nhượng lại cho khóa dưới.',
        transparencyScore: 95,
        tags: ['#casio', '#fx580vnx', '#maytinhbotui', '#onthi'],
        description:
          '1. Tổng quan & Điểm nổi bật:\nMáy tính Casio fx-580VN X tốc độ xử lý nhanh, tính ma trận, hệ phương trình 4 ẩn và tích phân cực nhanh.\n\n2. Tình trạng thực tế & Minh bạch khuyết điểm:\n- Tem Bitex chính hãng được mang vào phòng thi.\n- Khai báo minh bạch: Vỏ nắp trượt có xước nhẹ bên ngoài.\n\n3. Phụ kiện đi kèm & Giao dịch:\n- Máy + nắp trượt, tặng kèm 1 viên pin AAA dự phòng.',
        images: [
          {
            url: 'https://images.unsplash.com/photo-1587145820266-a5951ee6f620',
            sortOrder: 0,
            altText: 'Casio fx-580VN X Calculator',
          },
        ],
      },
    ];

    let seededCount = 0;
    for (const item of sampleProducts) {
      if (!existingTitles.has(item.title.toLowerCase())) {
        await productsService.create(String(seller._id), item);
        seededCount++;
      }
    }

    logger.log(
      `Seeded ${seededCount} new student marketplace products (Total seller inventory: ${existingListings.meta.total + seededCount}).`,
    );
  } finally {
    await app.close();
  }
}

void runSeed();
