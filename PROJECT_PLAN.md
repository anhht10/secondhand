# Kế Hoạch Phát Triển & Kiến Trúc Hệ Thống: Nền Tảng Mua Bán Đồ Cũ (Secondhand E-commerce Platform - ReMarket)

> **Cấu trúc 3 phân hệ tại `D:\cross-ck` (`root -> backend, ai, fe`)**:
> 1. **`D:\cross-ck\backend` (Backend)**: **NestJS (TypeScript)** + **MongoDB (`@nestjs/mongoose`)** + **JWT Authentication (`@nestjs/jwt`)** + **Multer Image Upload**.
> 2. **`D:\cross-ck\ai` (AI Service)**: **Python (FastAPI + Uvicorn)** + **Google Gemini SDK (`google-genai` >= 2.30.1)** sử dụng model **`gemini-3.8-flash`** qua **Interactions API (`client.interactions.create`)**.
> 3. **`D:\cross-ck\fe` (Frontend Mobile)**: **Flutter + Dart + Riverpod 2 + Local Storage (`shared_preferences`)** hỗ trợ lưu nháp tin đăng & cache sản phẩm khi offline.

---

## 1. Phân Tích Ý Tưởng & Giá Trị Cốt Lõi (Core Value Proposition)

Dự án giải quyết **4 bài toán thực tế** của chợ đồ cũ sinh viên & giới trẻ:
1. **Giảm rào cản đăng bán (Frictionless Selling)**: Người bán thường ngại viết mô tả dài dòng và không biết định giá bao nhiêu -> Giải quyết bằng **AI tự động tạo tiêu đề, mô tả chuẩn chỉnh & gợi ý khoảng giá hợp lý**, kèm tính năng **lưu bản nháp (Local Draft)**.
2. **Tăng độ tin cậy & minh bạch (Trust & Transparency)**: Người mua sợ hàng lỗi không giống mô tả -> Giải quyết bằng **khung khai báo tình trạng & khuyết điểm bắt buộc (Condition & Defect Disclosure)**, **AI gợi ý câu hỏi kiểm tra hàng**, quy trình người bán duyệt lại nội dung AI, và tính năng **Báo cáo tin đăng (Report)**.
3. **Tìm kiếm nhanh & tư vấn thông minh (Smart Discovery)**: Hỗ trợ tìm kiếm từ khóa, lọc theo danh mục, tình trạng, khoảng giá, sắp xếp linh hoạt và **Chatbot AI tư vấn tìm đồ theo nhu cầu/ngân sách**.
4. **Kết nối trực tiếp (Direct Communication)**: Hỗ trợ nhắn tin hỏi thông tin sản phẩm / thương lượng trực tiếp giữa người mua và người bán trên từng món đồ.

---

## 2. Danh Sách Các Tính Năng Đã Chốt (Finalized Feature Specification)

### 2.1. Nhóm Tính Năng Cốt Lõi (Must-Have - Core E-commerce)

| Mã | Phân hệ | Tính năng cụ thể | Chi tiết nghiệp vụ & API (NestJS + MongoDB) |
| :--- | :--- | :--- | :--- |
| **F01** | **Authentication & Profile** | Đăng ký, Đăng nhập, Đăng xuất | Xác thực qua NestJS AuthModule (`/api/auth/register`, `/api/auth/login`, `/api/auth/me`) dùng **JWT + bcrypt** lưu trên MongoDB. |
| **F02** | **Authentication & Profile** | Hồ sơ cá nhân (`User Profile`) | Xem và cập nhật tên hiển thị, ảnh đại diện, SĐT/Zalo liên hệ, khu vực/trường học, giới thiệu ngắn và thống kê số tin đã đăng/đã bán. |
| **F03** | **Product Discovery** | Trang chủ (`Home Feed`) | Hiển thị banner, nút mở **AI Chatbot**, thanh chọn nhanh Danh mục (`Quần áo`, `Sách & Giáo trình`, `Đồ điện tử`, `Phụ kiện`, `Đồ phòng trọ`, `Khác`), danh sách sản phẩm dạng lưới 2 cột (`GET /api/products`). |
| **F04** | **Product Discovery** | Tìm kiếm, Bộ lọc & Sắp xếp (`Search & Filter`) | Tìm kiếm theo từ khóa; lọc theo **Danh mục**, **Khoảng giá (Min–Max)**, **Tình trạng (Condition)**; sắp xếp theo *Mới nhất*, *Giá tăng dần*, *Giá giảm dần*. |
| **F05** | **Product Details** | Chi tiết sản phẩm (`Product Detail`) | Slide ảnh sản phẩm, giá bán, nhãn độ mới, **Thẻ minh bạch tình trạng & vết xước (Defect Disclosure)**, khung **AI Gợi ý kiểm tra cho người mua**, thông tin người bán, nút *Nhắn tin hỏi mua*, *Lưu yêu thích* & *Báo cáo tin*. |
| **F06** | **Core Listing CRUD** | Đăng bán & Xem trước (`Create & Preview Listing`) | Chọn/chụp ảnh sản phẩm, nhập tên, hãng, danh mục, giá, độ mới (`Như mới (99%)`, `Tốt (90%)`, `Khá (80%)`, `Cần sửa nhẹ`), ghi chú khuyết điểm, **Xem trước (Preview)** trước khi xuất bản (`POST /api/products`). |
| **F07** | **Core Listing CRUD** | Quản lý tin đăng (`My Listings`) | Xem danh sách tin của bản thân theo trạng thái (`Đang bán - available`, `Đã đặt gạch - reserved`, `Đã bán - sold`), chỉnh sửa nội dung (`PUT /api/products/:id`), đổi trạng thái nhanh hoặc xóa tin (`DELETE /api/products/:id`). |

---

### 2.2. Nhóm 4 Tính Năng AI (Python FastAPI + Gemini 3.8 Flash)

Flutter gọi lên **NestJS Backend (`/api/ai/...`)**, NestJS kết hợp dữ liệu MongoDB và gọi sang **Python AI Microservice (`http://localhost:8000/ai/...`)**:

1. **AI 1 – AI-Assisted Listing Generator (`POST /api/ai/generate-listing` -> Python `/ai/generate-listing`)**:
   - Nhận thông tin cơ bản (tên, hãng, danh mục, độ mới, khuyết điểm, giá) + ảnh chụp món đồ (Multimodal).
   - Sinh ra JSON gồm `suggestedTitle`, `suggestedDescription` (chia 3 phần rõ ràng), `suggestedCategory`, `suggestedTags`, `transparencyNote`.
   - Người bán kiểm tra, chỉnh sửa trên màn hình **AI Preview & Edit** và tick xác nhận cam kết minh bạch trước khi đăng.
2. **AI 2 – AI Smart Price Estimator (`POST /api/ai/estimate-price` -> Python `/ai/estimate-price`)**:
   - Phân tích thương hiệu, độ mới, giá mua mới và khuyết điểm để gợi ý 3 mức giá VNĐ (`quickSellPrice`, `recommendedPrice`, `maxFairPrice`) kèm giải thích nhu cầu thị trường.
3. **AI 3 – AI Buyer Inspection Checklist (`POST /api/ai/buyer-checklist` -> Python `/ai/buyer-checklist`)**:
   - Tại màn hình Chi tiết sản phẩm, phân tích tin đăng để đưa ra 3–4 điểm cần kiểm tra khi nhận hàng (`inspectionPoints`) và 3 câu hỏi thông minh (`suggestedQuestions`) cho phép người mua bấm 1 chạm gửi thẳng cho người bán. Kết quả được cache vào MongoDB (`aiChecklistCache`).
4. **AI 4 – AI Secondhand Assistant Chatbot (`POST /api/ai/chat` -> Python `/ai/chat`)**:
   - Trợ lý ảo AI hỗ trợ hội thoại nhiều lượt (`previous_interaction_id`), nhận ngữ cảnh danh sách sản phẩm đang bán thật từ MongoDB để tư vấn và trả về danh sách sản phẩm gợi ý (`matchedProducts`) hiển thị ngay trong khung chat.

---

### 2.3. Nhóm Tính Năng Hoàn Thiện & An Toàn (Should-Have)

| Mã | Phân hệ | Tính năng cụ thể | Chi tiết nghiệp vụ |
| :--- | :--- | :--- | :--- |
| **F08** | **Communication** | Nhắn tin Mua – Bán (`Buyer–Seller Messaging`) | Lưu trữ hội thoại và tin nhắn trong MongoDB (`/api/messages`). Người mua nhắn tin hỏi mua/trả giá trực tiếp từ trang chi tiết sản phẩm; quản lý danh sách cuộc trò chuyện trong tab **Tin nhắn**. |
| **F09** | **Offline Resilience** | Lưu nháp tự động (`Local Draft Saving`) | Khi đang tạo tin đăng trên app mà thoát ra hoặc mất mạng, tự động lưu bản nháp vào `SharedPreferences` trên thiết bị để mở lại viết tiếp bất cứ lúc nào. |
| **F10** | **Offline Resilience** | Cache danh sách sản phẩm (`Offline Feed Cache`) | Lưu bộ nhớ đệm danh sách sản phẩm vừa tải từ MongoDB vào máy; khi mất mạng vẫn xem được các sản phẩm đã cache và hiển thị banner cảnh báo Offline. |
| **F11** | **Safety & Quality** | Khai báo lỗi & Báo cáo tin (`Condition Disclosure & Report`) | Mục khai báo khuyết điểm rõ ràng cho người bán; nút **Báo cáo tin đăng (`POST /api/reports`)** lưu vào MongoDB khi người mua phát hiện tin lừa đảo/sai sự thật. |
| **F12** | **UX Bonus** | Lưu tin yêu thích (`Wishlist / Saved Items`) | Cho phép người mua thả tim lưu lại sản phẩm quan tâm (`/api/auth/wishlist/:productId`). |

---

## 3. Cấu Trúc Thư Mục Dự Án (`D:\cross-ck`)

```text
D:\cross-ck\
├── PROJECT_PLAN.md              # Tài liệu phân tích & kiến trúc dự án
├── ai/                          # Python AI Microservice (FastAPI + google-genai SDK)
│   ├── requirements.txt
│   ├── .env                     # Cấu hình GEMINI_API_KEY, GEMINI_MODEL=gemini-3.8-flash
│   ├── prompts.py               # System instructions & JSON Schemas cho 4 tính năng AI
│   ├── engine.py                # SecondhandAiEngine gọi client.interactions.create
│   └── main.py                  # FastAPI server chạy tại cổng 8000
├── backend/                     # NestJS + MongoDB REST API Server
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env                     # Cấu hình PORT=5000, MONGODB_URI, JWT_SECRET, AI_SERVICE_URL
│   └── src/
│       ├── main.ts              # Entrypoint NestJS (http://localhost:5000/api)
│       ├── app.module.ts
│       ├── schemas/             # Mongoose Schemas: user, product, message, report
│       ├── auth/                # AuthModule (JWT, Register, Login, Profile, Wishlist)
│       ├── products/            # ProductsModule (CRUD, Filter, Sort, Image Upload)
│       ├── ai/                  # AiModule (Kết nối Python AI + MongoDB)
│       ├── messages/            # MessagesModule (Buyer-Seller Chat)
│       ├── reports/             # ReportsModule (Safety Reporting)
│       └── seed/                # SeedModule (Tự động khởi tạo dữ liệu mẫu khi DB trống)
└── fe/                          # Flutter Cross-Platform Mobile App (Riverpod 2)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/                # Cấu hình API, Theme, Định dạng tiền tệ/thời gian
        ├── models/              # Models: User, Product, ListingDraft, Message, AiModels
        ├── services/            # ApiService, LocalStorageService (Drafts & Offline Cache)
        ├── providers/           # Riverpod 2 State Management
        └── screens/             # 20 màn hình đầy đủ theo 5 luồng nghiệp vụ + AI
```

---

## 4. Phân Tích Chuyên Sâu UX/UI, Design System & Kiến Trúc 20 Màn Hình (Figma)

### 4.1. Ngôn Ngữ Thiết Kế & Hệ Thống Màu Sắc (Modern White & Royal Blue)
- **Tone màu chủ đạo (Primary Palette)**:
  - **Pure White (`#FFFFFF`) & Soft Cool Surface (`#F8FAFC`)**: Tạo không gian hiển thị sản phẩm sáng sủa, sạch sẽ, hiện đại và tối ưu độ tương phản cho hình ảnh đồ cũ.
  - **Royal Blue (`#2563EB`) & Deep Blue (`#1D4ED8`)**: Màu thương hiệu chủ đạo thể hiện **Sự Tin Cậy (Trust)**, **Minh Bạch (Transparency)** và **Trí Tuệ Nhân Tạo (Gemini AI)** — sử dụng cho các nút hành động chính (Primary CTA), giá sản phẩm, huy hiệu xác thực và các thẻ tính năng AI.
  - **Soft Blue Tint (`#EFF6FF` nền / `#BFDBFE` & `#93C5FD` viền)**: Dùng cho các vùng thông tin thông minh (Thẻ Minh Bạch Khuyết Điểm, Khung AI Checklist, Gợi ý Định giá AI, Bản nháp đã lưu).
- **Màu ngữ nghĩa bổ trợ (Semantic Colors)**:
  - **Text Hierarchy**: `#0F172A` (Heading đậm), `#475569` (Body text), `#64748B` (Metadata/Subtext).
  - **Warning / Offline (`#FFFBEB` nền / `#F59E0B` viền / `#B45309` chữ)**: Cảnh báo mất kết nối mạng (`Offline Mode`) và mẹo giao dịch an toàn.
  - **Safety / Danger (`#FEF2F2` nền / `#EF4444` nút)**: Báo cáo tin đăng vi phạm hoặc xóa tin.
- **Kích thước chuẩn Mobile**: `390 x 844 px` (Tỷ lệ chuẩn iPhone 14/15 Pro, bo góc `36px`, hệ thống Auto Layout đồng bộ, thanh Status Bar thực tế `9:41` và Bottom Navigation 5 tab).

---

### 4.2. Ma Trận 20 Màn Hình Đầy Đủ Đã Thiết Kế Trên Figma (5 Luồng x 4 Màn Hình)

#### Luồng 1 (Hàng 1 - `y = 0`): Chào Mừng, Xác Thực & Cá Nhân Hóa (`F01`, `F02`)
1. **`01 - Welcome` (`x = 0, y = 0`)**: Màn hình chào mừng với thẻ Hero minh họa chợ đồ cũ thông minh AI, thẻ xem trước sản phẩm nổi, 3 giá trị cốt lõi, nút *"Bắt đầu ngay"*, *"Đăng nhập tài khoản"* và *"Khám phá trước với tư cách Khách"*.
2. **`02 - Login` (`x = 440, y = 0`)**: Màn hình đăng nhập chuẩn với Email/SĐT sinh viên, mật khẩu, nút *"Đăng nhập"*, khung **Đăng nhập nhanh tài khoản trải nghiệm (1 chạm)** cho mục đích Demo (*Sinh viên Mua* / *Người bán*) và đăng nhập Google `.edu.vn`.
3. **`03 - Register` (`x = 880, y = 0`)**: Màn hình đăng ký tài khoản mới (Bước 1/2) gồm Họ tên, Email, SĐT/Zalo, Khu vực/Trường đại học, Mật khẩu và checkbox cam kết khai báo minh bạch tình trạng sản phẩm.
4. **`04 - Onboarding Setup` (`x = 1320, y = 0`)**: Màn hình thiết lập hồ sơ cá nhân hóa (Bước 2/2) cho phép tải ảnh đại diện, chọn Trường đại học ưu tiên giao dịch trực tiếp, chọn các danh mục quan tâm và viết giới thiệu ngắn.

#### Luồng 2 (Hàng 2 - `y = 920`): Trang Chủ, Tìm Kiếm, Bộ Lọc & Chế Độ Offline (`F03`, `F04`, `F10`)
5. **`05 - Home Feed` (`x = 0, y = 920`)**: Trang chủ khám phá với thanh chọn khu vực (*Làng ĐH Thủ Đức*), ô tìm kiếm, **Banner mở Trợ lý mua sắm Gemini AI**, thanh chọn nhanh Danh mục, lưới sản phẩm 2 cột hiển thị giá/độ mới/nhãn minh bạch và Bottom Navigation Bar.
6. **`06 - Search & Results` (`x = 440, y = 920`)**: Màn hình kết quả tìm kiếm từ khóa (*"Bàn phím cơ"*), các chip bộ lọc đang kích hoạt, danh sách sản phẩm chi tiết kèm khoảng cách/thời gian đăng và thẻ gợi ý nhờ AI so sánh trực tiếp các mẫu đang hiển thị.
7. **`07 - Filter & Sort Sheet` (`x = 880, y = 920`)**: Màn hình Bộ lọc & Sắp xếp chuyên sâu theo Danh mục, Khoảng giá Min–Max (`100.000đ – 1.500.000đ`), Tình trạng độ mới (`Như mới 99%`, `Tốt 90%`, `Khá 80%`, `Cần sửa nhẹ`) và Sắp xếp theo giá/thời gian.
8. **`08 - Offline Cached Mode` (`x = 1320, y = 920`)**: Màn hình khi thiết bị mất mạng (`F10`), hiển thị **Banner cảnh báo Ngoại tuyến**, lối tắt mở lại **Bản nháp tin đăng đã lưu trên máy (`F09`)**, và danh sách 12 sản phẩm từ bộ nhớ đệm (`SharedPreferences`).

#### Luồng 3 (Hàng 3 - `y = 1840`): Chi Tiết Sản Phẩm, AI Buyer Checklist, Báo Cáo & Hồ Sơ Người Bán (`F05`, `AI 3`, `F11`)
9. **`09 - Product Detail` (`x = 0, y = 1840`)**: Màn hình chi tiết sản phẩm với bộ sưu tập ảnh (kèm tab *Ảnh cận cảnh vết xước*), giá bán & % tiết kiệm so với giá mới, **Thẻ Minh Bạch Tình Trạng & Khuyết Điểm Bắt Buộc**, mô tả chi tiết, thẻ người bán và thanh công cụ cố định dưới đáy (*Lưu tin*, *Trả giá*, *Nhắn hỏi mua*).
10. **`10 - AI Buyer Checklist` (`x = 440, y = 1840`)**: Màn hình **AI Hỗ trợ kiểm tra hàng (`AI 3`)** hiển thị 4 điểm kiểm tra thực tế khi nhận hàng (`inspectionPoints`) dành riêng cho món đồ đó, 3 **Câu hỏi thông minh 1-chạm (`suggestedQuestions`)** để gửi thẳng cho người bán, và hộp mẹo giao dịch an toàn.
11. **`11 - Report Listing Modal` (`x = 880, y = 1840`)**: Màn hình **Báo cáo tin đăng bất thường (`F11`)** với 5 nhóm lý do vi phạm (sai sự thật/che giấu lỗi, hàng giả, lừa đặt cọc,...), ô nhập mô tả kèm ảnh bằng chứng và cam kết bảo mật danh tính người báo cáo.
12. **`12 - Seller Public Profile` (`x = 1320, y = 1840`)**: Trang hồ sơ công khai của người bán hiển thị trường đại học đã xác thực, chỉ số uy tín (`4.9/5`), số món đã bán, tỷ lệ khai báo minh bạch `100%` và danh sách các sản phẩm người bán đang rao.

#### Luồng 4 (Hàng 4 - `y = 2760`): Đăng Bán Nhanh Với AI, Định Giá 3 Mức & Lưu Nháp (`F06`, `AI 1`, `AI 2`, `F09`)
13. **`13 - Create Listing & Draft` (`x = 0, y = 2760`)**: Màn hình tạo tin đăng với thông báo **Tự động lưu nháp trên thiết bị (`F09`)**, khung tải ảnh (gồm slot ảnh chụp rõ vết xước), nhập thông tin cơ bản, chọn độ mới, **ô khai báo khuyết điểm bắt buộc** và 2 nút gọi AI (*Định giá thông minh* & *Tạo bài đăng AI*).
14. **`14 - AI Price Estimator` (`x = 440, y = 2760`)**: Màn hình **AI Định giá thông minh (`AI 2`)** gợi ý 3 mức giá trực quan: 🚀 *Giá Bán Nhanh (`1.150.000đ`)*, ⭐ *Giá Khuyên Dùng (`1.350.000đ`)*, 💎 *Giá Tối Đa Hợp Lý (`1.500.000đ`)* kèm phân tích khấu hao và nhu cầu thị trường sinh viên từ Gemini 3.8 Flash.
15. **`15 - AI Listing Preview & Verify` (`x = 880, y = 2760`)**: Màn hình **Xem trước & Duyệt bài đăng AI (`AI 1`)** hiển thị tiêu đề tối ưu, mô tả 3 phần rõ ràng, điểm minh bạch `98/100`, bộ thẻ `#tags`, **checkbox bắt buộc người bán xác nhận cam kết đúng thực tế** trước khi bấm xuất bản.
16. **`16 - Listing Published Success` (`x = 1320, y = 2760`)**: Màn hình thông báo đăng tin thành công, xác nhận đã xóa bản nháp tạm trên máy và thông báo hệ thống đã tự động khởi tạo *AI Buyer Checklist* cho bài đăng.

#### Luồng 5 (Hàng 5 - `y = 3680`): Chatbot AI Tư Vấn, Nhắn Tin Mua Bán, Quản Lý Tin & Cá Nhân (`AI 4`, `F07`, `F08`, `F12`, `F02`)
17. **`17 - AI Shopping Chatbot` (`x = 0, y = 3680`)**: Màn hình **Trợ lý mua sắm ảo Gemini AI (`AI 4`)** hỗ trợ hội thoại nhiều lượt theo nhu cầu & ngân sách sinh viên, hiển thị **Thẻ sản phẩm khớp nhu cầu (`matchedProducts`)** ngay trong luồng chat kèm nút bấm xem chi tiết và các chip câu hỏi gợi ý tiếp theo.
18. **`18 - Buyer Seller Chat` (`x = 440, y = 3680`)**: Màn hình **Nhắn tin & Thương lượng trực tiếp (`F08`)** giữa người mua và người bán, có thanh ghim thông tin món đồ trên đầu, hiển thị tin nhắn câu hỏi nhanh từ AI, ảnh chụp cận cảnh thực tế người bán gửi và **Thẻ đề nghị trả giá / Chốt lịch hẹn**.
19. **`19 - My Listings & Drafts` (`x = 880, y = 3680`)**: Màn hình **Quản lý tin đăng của tôi (`F07`)** phân loại theo tab (`Đang bán`, `Đã đặt gạch`, `Đã bán`, `Nháp`), cho phép mở lại **Bản nháp trên thiết bị (`F09`)**, đổi trạng thái nhanh, sửa nội dung hoặc xóa tin.
20. **`20 - User Profile & Wishlist` (`x = 1320, y = 3680`)**: Màn hình **Hồ sơ cá nhân (`F02`) & Danh sách Yêu thích đã lưu (`F12`)** hiển thị thông tin liên hệ Zalo/Trường học, thống kê hoạt động, danh sách các món đồ đã thả tim lưu lại và menu cài đặt/đăng xuất.

