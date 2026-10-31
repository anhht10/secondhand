import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class GenerateListingDto {
  @ApiPropertyOptional({
    example: 'Bàn phím cơ Keychron K6',
    description: 'Raw item name or short draft title',
  })
  @ValidateIf((o: GenerateListingDto) => !o.productName)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  title?: string;

  @ApiPropertyOptional({
    example: 'Bàn phím cơ Keychron K6',
    description: 'Alias for title (Prompt 3 compatibility)',
  })
  @ValidateIf((o: GenerateListingDto) => !o.title)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  productName?: string;

  @ApiPropertyOptional({
    example: 'Keychron',
    description: 'Brand / Manufacturer',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  brand?: string;

  @ApiPropertyOptional({
    example: 'Máy tính & Phụ kiện',
    description: 'Category name or slug',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @ApiPropertyOptional({
    example: 'LIKE_NEW',
    description: 'Condition (NEW, LIKE_NEW, GOOD, FAIR)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  condition?: string;

  @ApiPropertyOptional({
    example: 1350000,
    description: 'Expected selling price in VND',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price?: number;

  @ApiPropertyOptional({
    example: 1350000,
    description: 'Expected selling price in VND (alias)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  sellingPrice?: number;

  @ApiPropertyOptional({
    example: 2450000,
    description: 'Original purchase price in VND',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiPropertyOptional({
    example:
      'Xước nhẹ 1mm ở cạnh phải khung nhôm, các phím và LED RGB hoạt động 100%.',
    description: 'Seller disclosure of any scratches or defects',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defectDisclosure?: string;

  @ApiPropertyOptional({
    example:
      'Xước nhẹ 1mm ở cạnh phải khung nhôm, các phím và LED RGB hoạt động 100%.',
    description: 'Alias for defectDisclosure',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defects?: string;

  @ApiPropertyOptional({
    type: [String],
    description: 'Optional list of uploaded image URLs',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  imageUrls?: string[];

  @ApiPropertyOptional({
    type: [String],
    description: 'Optional list of uploaded image URLs (alias)',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  images?: string[];

  @ApiPropertyOptional({
    description: 'Optional base64-encoded image for multimodal analysis',
  })
  @IsOptional()
  @IsString()
  @MaxLength(7000000)
  imageBase64?: string;

  @ApiPropertyOptional({
    example: 'image/jpeg',
    description: 'Optional MIME type for base64 image',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  imageMimeType?: string;
}

export class EstimatePriceDto {
  @ApiPropertyOptional({
    example: 'Bàn phím cơ Keychron K6 Wireless',
    description: 'Product name',
  })
  @ValidateIf((o: EstimatePriceDto) => !o.productName)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  title?: string;

  @ApiPropertyOptional({
    example: 'Bàn phím cơ Keychron K6 Wireless',
    description: 'Product name (alias for title)',
  })
  @ValidateIf((o: EstimatePriceDto) => !o.title)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  productName?: string;

  @ApiPropertyOptional({
    example: 'Keychron',
    description: 'Brand name',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  brand?: string;

  @ApiPropertyOptional({
    example: 'Máy tính & Phụ kiện',
    description: 'Category name or slug',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @ApiProperty({
    example: 'LIKE_NEW',
    description: 'Item condition (NEW, LIKE_NEW, GOOD, FAIR)',
  })
  @IsString()
  @MaxLength(50)
  condition!: string;

  @ApiPropertyOptional({
    example: 2450000,
    description: 'Original new retail price in VND',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  originalPrice?: number;

  @ApiPropertyOptional({
    example: 'Xước dăm nhẹ ở cạnh khung nhôm, đầy đủ cáp và hộp.',
    description: 'Known defects or wear notes',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defectDisclosure?: string;

  @ApiPropertyOptional({
    example: 'Xước dăm nhẹ ở cạnh khung nhôm, đầy đủ cáp và hộp.',
    description: 'Alias for defectDisclosure',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defects?: string;
}

export class BuyerChecklistDto {
  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012345679',
    description: 'Product MongoDB ObjectId (if inspecting an existing listing)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  productId?: string;

  @ApiPropertyOptional({
    example: '672b3a9f8e1b2c0012345679',
    description: 'Alias for productId',
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  product_id?: string;

  @ApiPropertyOptional({
    example: 'Tai nghe Sony WH-1000XM4',
    description: 'Product title (used when productId is omitted)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  title?: string;

  @ApiPropertyOptional({
    example: 'Tai nghe Sony WH-1000XM4',
    description: 'Alias for title',
  })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  productName?: string;

  @ApiPropertyOptional({ example: 'Sony' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  brand?: string;

  @ApiPropertyOptional({ example: 'Đồ điện tử' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @ApiPropertyOptional({ example: 'LIKE_NEW' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  condition?: string;

  @ApiPropertyOptional({ example: 4200000 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price?: number;

  @ApiPropertyOptional({
    example: 'Đệm tai còn êm, xước nhẹ trên vỏ hộp đựng.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defectDisclosure?: string;

  @ApiPropertyOptional({
    example: 'Đệm tai còn êm, xước nhẹ trên vỏ hộp đựng.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  defects?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  images?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(2048, { each: true })
  imageUrls?: string[];

  @ApiPropertyOptional({
    default: false,
    description:
      'Set true to bypass MongoDB cache and regenerate via Gemini AI',
  })
  @IsOptional()
  @IsBoolean()
  forceRefresh?: boolean;
}

export class AiChatDto {
  @ApiProperty({
    example:
      'Tôi muốn mua laptop cũ để lập trình, ngân sách dưới 10 triệu',
    description: 'User message to the AI Shopping Assistant',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  message!: string;

  @ApiPropertyOptional({
    example: 'conv-user-session-001',
    description: 'LangGraph thread_id for multi-turn conversation state',
  })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  thread_id?: string;

  @ApiPropertyOptional({
    example: 'conv-user-session-001',
    description: 'Alias for thread_id',
  })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  conversation_id?: string;

  @ApiPropertyOptional({
    example: 'v1_interaction_abc123',
    description: 'Previous Gemini Interaction ID for multi-turn conversation',
  })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  previousInteractionId?: string;

  @ApiPropertyOptional({
    example: 10000000,
    description: 'Optional budget filter in VND',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxBudget?: number;

  @ApiPropertyOptional({
    example: 'computers-accessories',
    description: 'Optional category preference',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;
}

export class GeneratedListingResponseDto {
  @ApiProperty({ example: 'Bàn phím cơ Keychron K6 - Như mới (99%)' })
  suggestedTitle!: string;

  @ApiProperty({ example: 'Bàn phím cơ Keychron K6 - Như mới (99%)' })
  suggested_title!: string;

  @ApiProperty({
    example:
      '📦 [TỔNG QUAN SẢN PHẨM]\nBàn phím cơ Keychron K6 chính hãng...\n\n🔍 [TÌNH TRẠNG & KHUYẾT ĐIỂM MINH BẠCH]\nXước nhẹ 1mm ở cạnh phải khung nhôm...\n\n🤝 [LÝ DO BÁN & CAM KẾT GIAO DỊCH]\nDo ít có nhu cầu sử dụng...',
  })
  description!: string;

  @ApiProperty({ example: 'Máy tính & Phụ kiện' })
  suggestedCategory!: string;

  @ApiProperty({ example: 'Máy tính & Phụ kiện' })
  suggested_category!: string;

  @ApiProperty({ type: [String], example: ['keychron', 'secondhand', 'likenew'] })
  tags!: string[];

  @ApiProperty({
    type: [String],
    example: ['Thương hiệu: Keychron', 'Tình trạng thực tế: Như mới (99%)'],
  })
  highlights!: string[];

  @ApiProperty({
    example:
      'Người bán đã công khai chi tiết ngoại hình và tình trạng hoạt động thực tế của sản phẩm.',
  })
  transparencyNote!: string;

  @ApiProperty({
    type: [String],
    example: [
      'Chụp rõ các góc cạnh và khu vực có vết xước hoặc hao mòn.',
      'Giao dịch trực tiếp hoặc quay video kiểm tra trước khi gửi hàng.',
    ],
  })
  ConditionTips!: string[];

  @ApiProperty({ type: [String] })
  condition_tips!: string[];

  @ApiProperty({ example: 'gemini-3.8-flash' })
  model!: string;
}

export class ComparableProductItemDto {
  @ApiProperty({ example: '672b3a9f8e1b2c0012345679' })
  id!: string;

  @ApiProperty({ example: 'Bàn phím cơ Keychron K6 Wireless' })
  title!: string;

  @ApiProperty({ example: 1350000 })
  price!: number;

  @ApiProperty({ example: 'LIKE_NEW' })
  condition!: string;

  @ApiProperty({ example: 'ACTIVE' })
  status!: string;
}

export class EstimatedPriceResponseDto {
  @ApiProperty({ example: 1510000 })
  quickSellPrice!: number;

  @ApiProperty({ example: 1510000 })
  quick_sell_price!: number;

  @ApiProperty({ example: 1720000 })
  recommendedPrice!: number;

  @ApiProperty({ example: 1720000 })
  recommended_price!: number;

  @ApiProperty({ example: 1860000 })
  maxFairPrice!: number;

  @ApiProperty({ example: 1860000 })
  max_fair_price!: number;

  @ApiProperty({ example: 0.85 })
  confidence!: number;

  @ApiProperty({
    example:
      'Mức giá đề xuất được tính toán dựa trên giá gốc (2,450,000 VNĐ), hệ số khấu hao tình trạng LIKE_NEW và tham chiếu sản phẩm tương đương trên ReMarket.',
  })
  reasoning!: string;

  @ApiProperty({
    type: [String],
    example: ['Khấu hao theo tình trạng: LIKE_NEW', 'Tham chiếu giá bán lẻ ban đầu'],
  })
  factors!: string[];

  @ApiProperty({ type: [ComparableProductItemDto] })
  comparableProducts!: ComparableProductItemDto[];

  @ApiProperty({ example: 'gemini-3.8-flash' })
  model!: string;
}

export class BuyerChecklistResponseDto {
  @ApiPropertyOptional({ example: '672b3a9f8e1b2c0012345679', nullable: true })
  productId?: string | null;

  @ApiProperty({
    type: [String],
    example: [
      'Đối chiếu ngoại hình thực tế với hình ảnh tin đăng và kiểm tra kỹ: Xước nhẹ trên vỏ hộp đựng.',
      'Kiểm tra kết nối Bluetooth, màng loa trái/phải và chống ồn ANC.',
    ],
  })
  checklist!: string[];

  @ApiProperty({
    type: [String],
    example: [
      'Khuyết điểm đã nêu có phát sinh thêm lỗi ẩn nào không?',
      'Sản phẩm đã từng qua sửa chữa hoặc thay thế linh kiện chưa?',
      'Có hỗ trợ kiểm tra trực tiếp hoặc quay video test thực tế trước khi giao dịch không?',
    ],
  })
  questionsForSeller!: string[];

  @ApiProperty({ type: [String] })
  suggested_questions!: string[];

  @ApiProperty({
    type: [String],
    example: ['Kiểm tra kỹ khu vực khuyết điểm đã công bố trước khi thanh toán.'],
  })
  riskNotes!: string[];

  @ApiProperty({ type: [String] })
  risk_notes!: string[];

  @ApiProperty({
    example: 'Đánh giá kiểm tra cho Tai nghe Sony WH-1000XM4 (Tình trạng: LIKE_NEW).',
  })
  inspectionSummary!: string;

  @ApiProperty({ example: false })
  cached!: boolean;

  @ApiProperty({ example: 'gemini-3.8-flash' })
  model!: string;
}

export class AiChatResponseDto {
  @ApiProperty({
    example:
      'Chào bạn! Dưới đây là các mẫu bàn phím cơ phù hợp với ngân sách của bạn hiện đang mở bán trên ReMarket...',
  })
  reply!: string;

  @ApiProperty({
    example:
      'Chào bạn! Dưới đây là các mẫu bàn phím cơ phù hợp với ngân sách của bạn hiện đang mở bán trên ReMarket...',
  })
  response!: string;

  @ApiProperty({ example: 'conv-user-session-001' })
  thread_id!: string;

  @ApiProperty({ example: 'conv-user-session-001' })
  conversation_id!: string;

  @ApiProperty({ example: 'conv-user-session-001' })
  interactionId!: string;

  @ApiProperty({
    type: [String],
    example: ['search_products', 'get_product_categories'],
  })
  tools_used!: string[];

  @ApiProperty({ type: [Object], description: 'Verified ACTIVE Product documents' })
  matchedProducts!: unknown[];

  @ApiProperty({ type: [Object] })
  recommended_products!: unknown[];

  @ApiProperty({
    type: [String],
    example: [
      'Gợi ý checklist kiểm tra khi mua sản phẩm này',
      'So sánh mức giá các sản phẩm trên',
    ],
  })
  follow_up_questions!: string[];

  @ApiProperty({ example: 'gemini-3.8-flash' })
  model!: string;
}

export class AiConversationHistoryResponseDto {
  @ApiProperty({ example: 'conv-user-session-001' })
  conversation_id!: string;

  @ApiProperty({ example: 'conv-user-session-001' })
  thread_id!: string;

  @ApiProperty({ example: true })
  exists!: boolean;

  @ApiProperty({ example: 2 })
  turn_count!: number;

  @ApiProperty({ type: [Object] })
  messages!: Record<string, unknown>[];

  @ApiProperty({ type: Object })
  user_preferences!: Record<string, unknown>;

  @ApiProperty({ type: [String] })
  last_recommended_product_ids!: string[];
}

export class AiDeleteConversationResponseDto {
  @ApiProperty({ example: 'conv-user-session-001' })
  conversation_id!: string;

  @ApiProperty({ example: 'conv-user-session-001' })
  thread_id!: string;

  @ApiProperty({ example: true })
  deleted!: boolean;
}

