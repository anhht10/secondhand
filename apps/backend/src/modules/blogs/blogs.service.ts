import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { FilterQuery, Model, Types } from 'mongoose';
import { AiHttpClient } from '../ai/ai-http.client';
import { Product, ProductDocument } from '../products/schemas/product.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import {
  CreateBlogCommentDto,
  CreateBlogPostDto,
  GenerateAiBlogDraftDto,
  QueryBlogPostsDto,
  UpdateBlogPostDto,
} from './dto/blog.dto';
import {
  BlogComment,
  BlogCommentDocument,
} from './schemas/blog-comment.schema';
import {
  BlogCategory,
  BlogPost,
  BlogPostDocument,
  BlogPostStatus,
} from './schemas/blog-post.schema';

@Injectable()
export class BlogsService {
  private readonly logger = new Logger(BlogsService.name);
  private isSeedChecked = false;

  constructor(
    @InjectModel(BlogPost.name)
    private readonly blogPostModel: Model<BlogPostDocument>,
    @InjectModel(BlogComment.name)
    private readonly blogCommentModel: Model<BlogCommentDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(Product.name)
    private readonly productModel: Model<ProductDocument>,
    private readonly aiHttpClient: AiHttpClient,
  ) {}

  private async ensureSeededIfEmpty(): Promise<void> {
    if (this.isSeedChecked) return;
    this.isSeedChecked = true;
    try {
      const count = await this.blogPostModel.countDocuments().exec();
      if (count > 0) return;

      const users = await this.userModel.find().limit(3).exec();
      if (users.length === 0) return;

      const products = await this.productModel.find().limit(3).exec();
      const author0 = users[0]._id;
      const author1 = (users[1] ?? users[0])._id;
      const author2 = (users[2] ?? users[0])._id;

      const prod0 = products[0]?._id ?? null;
      const prod1 = products[1]?._id ?? null;

      const initialPosts = [
        {
          authorId: author0,
          title:
            'Kinh nghiệm kiểm tra Laptop & MacBook cũ cho sinh viên trước khi xuống tiền',
          content:
            'Chào anh em sinh viên trên ReMarket! Sau 3 lần mua hộ laptop cũ cho bạn cùng phòng ở Làng Đại học Thủ Đức, mình đúc kết được 5 bước test máy cực kỳ quan trọng:\n\n' +
            '1. **Đối chiếu khuyết điểm công khai**: Trên ReMarket người bán thường ghi rõ vết xước hoặc tình trạng pin. Khi gặp trực tiếp, bạn hãy đối chiếu đúng vị trí đó đầu tiên.\n' +
            '2. **Kiểm tra màn hình**: Mở nền trắng và nền đen toàn màn hình để soi điểm chết (dead pixel), vết bầm hoặc ám màu.\n' +
            '3. **Test bàn phím & cổng kết nối**: Mở trang web test phím online, gõ thử toàn bộ các phím xem có phím nào bị liệt hoặc kẹt switch không.\n' +
            '4. **Kiểm tra tài khoản ẩn (iCloud / MDM / BIOS password)**: Bắt buộc kiểm tra máy không dính mật khẩu BIOS hoặc MDM trước khi thanh toán.\n' +
            '5. **Giao dịch an toàn**: Luôn hẹn gặp ở quán cà phê hoặc thư viện trường có sẵn Wi-Fi và ổ cắm sạc.',
          category: BlogCategory.EXPERIENCE,
          tags: ['laptop-cu', 'kinh-nghiem', 'sinh-vien', 'kiem-tra-may'],
          images: products[0]?.images?.[0]?.url
            ? [products[0].images[0].url]
            : [],
          attachedProductId: prod0,
          likedBy: [author1, author2],
          likesCount: 2,
          commentsCount: 1,
          viewsCount: 48,
          status: BlogPostStatus.PUBLISHED,
        },
        {
          authorId: author1,
          title:
            'Góc học tập sinh viên dưới 1.5 triệu: Đèn chống cận + Giá đỡ nhôm + Bàn phím cơ cũ',
          content:
            'Mình vừa hoàn thiện góc học tập tại ký túc xá với toàn bộ đồ săn trên ReMarket chỉ hết hơn 1 triệu đồng nhưng dùng cực sướng:\n\n' +
            '- **Đèn bàn chống cận**: Ánh sáng vàng ấm không gây mỏi mắt khi code đêm.\n' +
            '- **Giá đỡ Laptop hợp kim nhôm**: Nâng màn hình ngang tầm mắt, đỡ mỏi cổ vai gáy hẳn.\n' +
            '- **Bàn phím cơ Keychron cũ**: Mua lại của một anh khóa trên còn mới 95%, gõ êm và kết nối Bluetooth gọn gàng.\n\n' +
            'Bạn nào đang muốn setup góc học tập tiết kiệm thì tham khảo món mình đính kèm bên dưới nhé!',
          category: BlogCategory.STUDY_CORNER,
          tags: ['goc-hoc-tap', 'setup', 'tiet-kiem', 'decor'],
          images: products[1]?.images?.[0]?.url
            ? [products[1].images[0].url]
            : [],
          attachedProductId: prod1,
          likedBy: [author0],
          likesCount: 1,
          commentsCount: 0,
          viewsCount: 31,
          status: BlogPostStatus.PUBLISHED,
        },
        {
          authorId: author2,
          title:
            '3 dấu hiệu nhận biết lừa đảo bắt đặt cọc khi mua đồ cũ và cách phòng tránh',
          content:
            'Dạo gần đây có một số đối tượng xấu thường đăng bán điện thoại/máy ảnh giá rẻ bất ngờ rồi thúc giục người mua chuyển khoản đặt cọc giữ hàng.\n\n' +
            '**Nguyên tắc vàng khi giao dịch trên ReMarket:**\n' +
            '- Không bao giờ chuyển khoản đặt cọc trước khi chưa nhìn thấy sản phẩm thực tế.\n' +
            '- Sử dụng tính năng **Tạo đơn hàng** và **Checklist kiểm tra AI** ngay trên ứng dụng để được lưu lịch sử giao dịch minh bạch.\n' +
            '- Ưu tiên người bán có **Điểm uy tín (Reputation Score)** cao và đã có đánh giá thực tế từ các giao dịch hoàn tất.',
          category: BlogCategory.SCAM_ALERT,
          tags: ['an-toan', 'canh-bao', 'chong-lua-dao'],
          images: [],
          attachedProductId: null,
          likedBy: [author0, author1],
          likesCount: 2,
          commentsCount: 0,
          viewsCount: 64,
          status: BlogPostStatus.PUBLISHED,
        },
      ];

      const created = await this.blogPostModel.insertMany(initialPosts);
      if (created.length > 0) {
        await this.blogCommentModel.create({
          postId: created[0]._id,
          authorId: author1,
          content:
            'Bài viết rất chi tiết! Mình cũng hay dùng thêm tính năng Checklist AI trên ReMarket để khỏi quên các bước test máy.',
        });
      }
    } catch (err) {
      this.logger.warn(`Skip blog seed: ${err}`);
    }
  }

  private serializePost(
    post: BlogPostDocument,
    currentUserId?: string,
  ): Record<string, unknown> {
    const raw =
      typeof post.toJSON === 'function'
        ? (post.toJSON() as Record<string, unknown>)
        : (post as unknown as Record<string, unknown>);

    const likedByArr = Array.isArray(post.likedBy) ? post.likedBy : [];
    const isLiked = currentUserId
      ? likedByArr.some((id) => String(id) === String(currentUserId))
      : false;

    return {
      ...raw,
      id: String(post._id),
      likesCount: Number(post.likesCount ?? likedByArr.length) || 0,
      commentsCount: Number(post.commentsCount ?? 0) || 0,
      viewsCount: Number(post.viewsCount ?? 0) || 0,
      isLiked,
    };
  }

  async findAll(queryDto: QueryBlogPostsDto, currentUserId?: string) {
    await this.ensureSeededIfEmpty();

    const page = Math.max(1, queryDto.page ?? 1);
    const limit = Math.min(50, Math.max(1, queryDto.limit ?? 20));
    const skip = (page - 1) * limit;

    const filter: FilterQuery<BlogPostDocument> = {
      status: BlogPostStatus.PUBLISHED,
    };

    if (queryDto.category) {
      filter.category = queryDto.category;
    }

    if (queryDto.authorId && Types.ObjectId.isValid(queryDto.authorId)) {
      filter.authorId = new Types.ObjectId(queryDto.authorId);
    }

    if (queryDto.tag?.trim()) {
      filter.tags = queryDto.tag.trim().toLowerCase();
    }

    if (queryDto.keyword?.trim()) {
      const kw = queryDto.keyword.trim();
      const escaped = kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      filter.$or = [
        { title: { $regex: escaped, $options: 'i' } },
        { content: { $regex: escaped, $options: 'i' } },
        { tags: { $regex: escaped, $options: 'i' } },
      ];
    }

    const [items, total] = await Promise.all([
      this.blogPostModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate(
          'authorId',
          'displayName avatarUrl location isEmailVerified reputation stats',
        )
        .populate(
          'attachedProductId',
          'title price originalPrice condition status images location defectDisclosure',
        )
        .exec(),
      this.blogPostModel.countDocuments(filter).exec(),
    ]);

    const serialized = items.map((item) =>
      this.serializePost(item, currentUserId),
    );
    const totalPages = Math.ceil(total / limit) || 1;

    return {
      items: serialized,
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

  async findById(postId: string, currentUserId?: string) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }

    const post = await this.blogPostModel
      .findByIdAndUpdate(
        postId,
        { $inc: { viewsCount: 1 } },
        { new: true },
      )
      .populate(
        'authorId',
        'displayName avatarUrl location isEmailVerified reputation stats',
      )
      .populate(
        'attachedProductId',
        'title price originalPrice condition status images location defectDisclosure',
      )
      .exec();

    if (!post || post.status === BlogPostStatus.HIDDEN) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }

    const comments = await this.blogCommentModel
      .find({ postId: post._id })
      .sort({ createdAt: 1 })
      .populate('authorId', 'displayName avatarUrl location reputation')
      .exec();

    return {
      ...this.serializePost(post, currentUserId),
      comments: comments.map((c) => {
        const raw =
          typeof c.toJSON === 'function'
            ? (c.toJSON() as Record<string, unknown>)
            : (c as unknown as Record<string, unknown>);
        return {
          ...raw,
          id: String(c._id),
          postId: String(c.postId),
        };
      }),
    };
  }

  async create(userId: string, dto: CreateBlogPostDto) {
    let attachedObjId: Types.ObjectId | null = null;
    if (dto.attachedProductId && dto.attachedProductId.trim()) {
      if (!Types.ObjectId.isValid(dto.attachedProductId.trim())) {
        throw new BadRequestException('attachedProductId không hợp lệ');
      }
      attachedObjId = new Types.ObjectId(dto.attachedProductId.trim());
    }

    const normalizedTags = (dto.tags ?? [])
      .map((t) => t.trim().toLowerCase().replace(/^#/, ''))
      .filter(Boolean)
      .slice(0, 10);

    const created = await this.blogPostModel.create({
      authorId: new Types.ObjectId(userId),
      title: dto.title.trim(),
      content: dto.content.trim(),
      category: dto.category ?? BlogCategory.EXPERIENCE,
      tags: normalizedTags,
      images: (dto.images ?? []).map((u) => u.trim()).filter(Boolean),
      attachedProductId: attachedObjId,
      likedBy: [],
      likesCount: 0,
      commentsCount: 0,
      viewsCount: 1,
      status: BlogPostStatus.PUBLISHED,
    });

    const populated = await this.blogPostModel
      .findById(created._id)
      .populate(
        'authorId',
        'displayName avatarUrl location isEmailVerified reputation stats',
      )
      .populate(
        'attachedProductId',
        'title price originalPrice condition status images location defectDisclosure',
      )
      .exec();

    return this.serializePost(populated ?? created, userId);
  }

  async update(postId: string, userId: string, dto: UpdateBlogPostDto) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    const post = await this.blogPostModel.findById(postId).exec();
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    if (String(post.authorId) !== String(userId)) {
      throw new ForbiddenException(
        'Bạn chỉ có thể chỉnh sửa bài viết của chính mình',
      );
    }

    if (dto.title !== undefined) post.title = dto.title.trim();
    if (dto.content !== undefined) post.content = dto.content.trim();
    if (dto.category !== undefined) post.category = dto.category;
    if (dto.tags !== undefined) {
      post.tags = dto.tags
        .map((t) => t.trim().toLowerCase().replace(/^#/, ''))
        .filter(Boolean)
        .slice(0, 10);
    }
    if (dto.images !== undefined) {
      post.images = dto.images.map((u) => u.trim()).filter(Boolean);
    }
    if (dto.attachedProductId !== undefined) {
      post.attachedProductId =
        dto.attachedProductId && Types.ObjectId.isValid(dto.attachedProductId)
          ? new Types.ObjectId(dto.attachedProductId)
          : null;
    }

    await post.save();

    const populated = await this.blogPostModel
      .findById(post._id)
      .populate(
        'authorId',
        'displayName avatarUrl location isEmailVerified reputation stats',
      )
      .populate(
        'attachedProductId',
        'title price originalPrice condition status images location defectDisclosure',
      )
      .exec();

    return this.serializePost(populated ?? post, userId);
  }

  async remove(postId: string, userId: string) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    const post = await this.blogPostModel.findById(postId).exec();
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    if (String(post.authorId) !== String(userId)) {
      throw new ForbiddenException(
        'Bạn chỉ có thể xóa bài viết của chính mình',
      );
    }

    await Promise.all([
      this.blogPostModel.deleteOne({ _id: post._id }).exec(),
      this.blogCommentModel.deleteMany({ postId: post._id }).exec(),
    ]);

    return { id: postId, deleted: true };
  }

  async toggleLike(postId: string, userId: string) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    const post = await this.blogPostModel.findById(postId).exec();
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }

    const userObjId = new Types.ObjectId(userId);
    const existingIdx = (post.likedBy ?? []).findIndex(
      (id) => String(id) === String(userId),
    );

    let isLiked = false;
    if (existingIdx >= 0) {
      post.likedBy.splice(existingIdx, 1);
      isLiked = false;
    } else {
      post.likedBy.push(userObjId);
      isLiked = true;
    }
    post.likesCount = post.likedBy.length;
    await post.save();

    return {
      postId: String(post._id),
      isLiked,
      likesCount: post.likesCount,
    };
  }

  async getComments(postId: string) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    const comments = await this.blogCommentModel
      .find({ postId: new Types.ObjectId(postId) })
      .sort({ createdAt: 1 })
      .populate('authorId', 'displayName avatarUrl location reputation')
      .exec();

    return comments.map((c) => {
      const raw =
        typeof c.toJSON === 'function'
          ? (c.toJSON() as Record<string, unknown>)
          : (c as unknown as Record<string, unknown>);
      return {
        ...raw,
        id: String(c._id),
        postId: String(c.postId),
      };
    });
  }

  async addComment(
    postId: string,
    userId: string,
    dto: CreateBlogCommentDto,
  ) {
    if (!Types.ObjectId.isValid(postId)) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }
    const post = await this.blogPostModel.findById(postId).exec();
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết Blog');
    }

    const cleanedContent = (dto.content ?? '').trim();
    const cleanedImages = (dto.images ?? [])
      .map((u) => u.trim())
      .filter(Boolean)
      .slice(0, 4);

    if (!cleanedContent && cleanedImages.length === 0) {
      throw new BadRequestException(
        'Vui lòng nhập nội dung bình luận hoặc đính kèm ít nhất 1 hình ảnh',
      );
    }

    const comment = await this.blogCommentModel.create({
      postId: post._id,
      authorId: new Types.ObjectId(userId),
      content: cleanedContent,
      images: cleanedImages,
    });

    post.commentsCount = (post.commentsCount ?? 0) + 1;
    await post.save();

    const populated = await this.blogCommentModel
      .findById(comment._id)
      .populate('authorId', 'displayName avatarUrl location reputation')
      .exec();

    const raw =
      populated && typeof populated.toJSON === 'function'
        ? (populated.toJSON() as Record<string, unknown>)
        : (comment.toJSON() as Record<string, unknown>);

    return {
      ...raw,
      id: String(comment._id),
      postId: String(post._id),
      commentsCount: post.commentsCount,
    };
  }

  async deleteComment(postId: string, commentId: string, userId: string) {
    if (
      !Types.ObjectId.isValid(postId) ||
      !Types.ObjectId.isValid(commentId)
    ) {
      throw new NotFoundException('Không tìm thấy bình luận');
    }

    const [post, comment] = await Promise.all([
      this.blogPostModel.findById(postId).exec(),
      this.blogCommentModel.findById(commentId).exec(),
    ]);

    if (!post || !comment || String(comment.postId) !== String(post._id)) {
      throw new NotFoundException('Không tìm thấy bình luận');
    }

    const isCommentAuthor = String(comment.authorId) === String(userId);
    const isPostAuthor = String(post.authorId) === String(userId);
    if (!isCommentAuthor && !isPostAuthor) {
      throw new ForbiddenException('Bạn không có quyền xóa bình luận này');
    }

    await this.blogCommentModel.deleteOne({ _id: comment._id }).exec();
    post.commentsCount = Math.max(0, (post.commentsCount ?? 1) - 1);
    await post.save();

    return {
      id: commentId,
      postId,
      deleted: true,
      commentsCount: post.commentsCount,
    };
  }

  async generateAiDraft(dto: GenerateAiBlogDraftDto) {
    const topic = dto.topic.trim();
    const category = dto.category ?? BlogCategory.EXPERIENCE;
    const keyPoints = (dto.keyPoints ?? '').trim();
    const prodTitle = (dto.attachedProductTitle ?? '').trim();

    const categoryLabels: Record<BlogCategory, string> = {
      [BlogCategory.EXPERIENCE]: 'Kinh nghiệm mua bán đồ cũ',
      [BlogCategory.REVIEW]: 'Review thực tế đồ cũ',
      [BlogCategory.STUDY_CORNER]: 'Góc học tập & Setup sinh viên',
      [BlogCategory.WANT_TO_BUY]: 'Cần tìm mua đồ cũ',
      [BlogCategory.SCAM_ALERT]: 'Cảnh báo lừa đảo & Giao dịch an toàn',
      [BlogCategory.GENERAL]: 'Chia sẻ cộng đồng ReMarket',
    };

    const catLabel = categoryLabels[category] || 'Chia sẻ kinh nghiệm';

    try {
      const prompt =
        `Hãy viết một bài đăng Blog cộng đồng hấp dẫn trên ứng dụng đồ cũ sinh viên ReMarket thuộc chuyên mục "${catLabel}" ` +
        `với chủ đề: "${topic}". ` +
        (keyPoints ? `Các ý chính cần có: ${keyPoints}. ` : '') +
        (prodTitle ? `Bài viết có đính kèm sản phẩm: "${prodTitle}". ` : '') +
        `Trình bày rõ ràng, chia đoạn dễ đọc, giọng văn gần gũi với sinh viên và thực tế.`;

      const aiRes = await this.aiHttpClient.post<Record<string, unknown>>(
        '/ai/chat',
        { message: prompt },
      );
      const aiReply = String(aiRes?.message || aiRes?.reply || '').trim();
      if (aiReply && aiReply.length > 60 && !aiReply.startsWith('Xin chào!')) {
        return {
          suggestedTitle:
            topic.length >= 12 ? topic : `[${catLabel}] ${topic}`,
          suggestedContent: aiReply,
          suggestedTags: this.buildTagsForDraft(topic, category),
          aiProvider: String(aiRes?.aiProvider || 'gemini-ai'),
        };
      }
    } catch (err) {
      this.logger.debug(`AI blog draft fallback triggered: ${err}`);
    }

    // Smart deterministic fallback tailored to category and topic
    const suggestedTitle =
      topic.length >= 15 ? topic : `[${catLabel}] Chia sẻ thực tế: ${topic}`;

    const prodSection = prodTitle
      ? `\n\n📦 **Sản phẩm đính kèm trong bài**: Mình có gắn kèm sản phẩm **${prodTitle}** ngay trong bài viết này, bạn nào quan tâm có thể bấm vào thẻ sản phẩm để xem chi tiết giá và tình trạng nhé!`
      : '';

    const keyPointsSection = keyPoints
      ? `\n\n💡 **Điểm nhấn quan trọng**:\n- ${keyPoints
          .split(/[,\n;]+/)
          .map((s) => s.trim())
          .filter(Boolean)
          .join('\n- ')}`
      : '';

    let bodyTemplate = '';
    switch (category) {
      case BlogCategory.REVIEW:
        bodyTemplate =
          `Chào cộng đồng ReMarket! Hôm nay mình muốn viết bài review chi tiết về **${topic}** sau một thời gian trải nghiệm thực tế.\n\n` +
          `1. **Ngoại hình & Độ hoàn thiện**: Sản phẩm giữ được độ mới rất tốt so với mức giá đồ cũ, các chi tiết khớp nối và bề mặt đúng như mô tả minh bạch của người bán.\n` +
          `2. **Trải nghiệm sử dụng thực tế**: Hoạt động ổn định, đáp ứng tốt nhu cầu học tập và làm việc hằng ngày của sinh viên.\n` +
          `3. **Đánh giá mức giá / hiệu năng**: Cực kỳ đáng tiền so với mua mới, tiết kiệm được 35% – 50% ngân sách.` +
          keyPointsSection +
          prodSection +
          `\n\nBạn nào đang phân vân về dòng này thì cứ để lại bình luận bên dưới mình giải đáp thêm nhé!`;
        break;
      case BlogCategory.STUDY_CORNER:
        bodyTemplate =
          `Xin chào mọi người! Mình vừa nâng cấp góc học tập với chủ đề **${topic}** từ những món đồ săn được trên ReMarket nên lên bài chia sẻ cùng anh em:\n\n` +
          `- **Tiêu chí lựa chọn**: Gọn gàng, tối ưu công thái học để ngồi học/code lâu không mỏi lưng và tiết kiệm chi phí sinh viên.\n` +
          `- **Mẹo phối đồ cũ**: Ưu tiên chọn các món tình trạng Như mới (Like New) hoặc Tốt, vừa bền vừa đẹp mắt.` +
          keyPointsSection +
          prodSection +
          `\n\nMọi người chấm điểm góc học tập này bao nhiêu trên 10? Cùng chia sẻ góc học tập của bạn dưới phần bình luận nhé!`;
        break;
      case BlogCategory.WANT_TO_BUY:
        bodyTemplate =
          `Hiện tại mình đang có nhu cầu tìm mua: **${topic}** trên ReMarket.\n\n` +
          `- **Yêu cầu tình trạng**: Hoạt động tốt, nguyên bản, công khai rõ ràng các vết trầy xước hoặc khuyết điểm (nếu có).\n` +
          `- **Hình thức giao dịch**: Ưu tiên gặp mặt kiểm tra trực tiếp hoặc đặt qua hệ thống Đơn hàng của ReMarket.` +
          keyPointsSection +
          `\n\nBạn nào đang muốn pass lại món này thì bình luận trực tiếp dưới bài hoặc nhắn tin cho mình nhé. Cảm ơn mọi người!`;
        break;
      case BlogCategory.SCAM_ALERT:
        bodyTemplate =
          `Mình viết bài này để chia sẻ lưu ý an toàn xoay quanh chủ đề **${topic}** giúp các bạn mới mua bán đồ cũ trên ReMarket tránh rủi ro:\n\n` +
          `1. **Tuyệt đối không chuyển khoản đặt cọc ngoài luồng**: Chỉ thanh toán sau khi đã kiểm tra hàng trực tiếp hoặc theo quy trình đơn hàng trên ứng dụng.\n` +
          `2. **Kiểm tra Điểm uy tín (Reputation Score) của người bán**: Xem kỹ lịch sử đánh giá từ các người mua trước.\n` +
          `3. **Đối chiếu Checklist AI**: Sử dụng công cụ tạo danh sách kiểm tra của ReMarket khi đi xem hàng.` +
          keyPointsSection +
          `\n\nHãy cùng nhau xây dựng cộng đồng mua bán đồ cũ minh bạch và an toàn nhé!`;
        break;
      default:
        bodyTemplate =
          `Chào các bạn trên ReMarket! Hôm nay mình muốn chia sẻ kinh nghiệm thực tế về **${topic}**:\n\n` +
          `1. **Chuẩn bị trước khi mua/bán**: Tìm hiểu kỹ mặt bằng giá và đọc kỹ phần công khai khuyết điểm của sản phẩm.\n` +
          `2. **Các điểm cần kiểm tra trực tiếp**: Test kỹ các chức năng cốt lõi, ngoại hình và phụ kiện đi kèm tại nơi có đủ ánh sáng.\n` +
          `3. **Kinh nghiệm thương lượng văn minh**: Trao đổi lịch sự qua khung chat ReMarket và chốt đơn rõ ràng.` +
          keyPointsSection +
          prodSection +
          `\n\nHy vọng bài viết hữu ích cho các bạn. Ai có thêm mẹo hay thì góp ý ở phần bình luận bên dưới nha!`;
        break;
    }

    return {
      suggestedTitle,
      suggestedContent: bodyTemplate,
      suggestedTags: this.buildTagsForDraft(topic, category),
      aiProvider: 'remarket-ai-writer',
    };
  }

  private buildTagsForDraft(topic: string, category: BlogCategory): string[] {
    const baseTags: Record<BlogCategory, string[]> = {
      [BlogCategory.EXPERIENCE]: ['kinh-nghiem', 'meo-mua-do-cu', 'sinh-vien'],
      [BlogCategory.REVIEW]: ['review', 'danh-gia-thuc-te', 'do-cu'],
      [BlogCategory.STUDY_CORNER]: ['goc-hoc-tap', 'setup', 'decor'],
      [BlogCategory.WANT_TO_BUY]: ['can-mua', 'tim-do', 'pass-do'],
      [BlogCategory.SCAM_ALERT]: ['an-toan', 'canh-bao', 'giao-dich-minh-bach'],
      [BlogCategory.GENERAL]: ['cong-dong', 'remarket', 'chia-se'],
    };
    const tags = [...(baseTags[category] ?? ['remarket', 'chia-se'])];
    const lowered = topic.toLowerCase();
    if (lowered.includes('laptop') || lowered.includes('macbook')) {
      tags.unshift('laptop');
    } else if (lowered.includes('điện thoại') || lowered.includes('iphone')) {
      tags.unshift('dien-thoai');
    } else if (lowered.includes('bàn phím') || lowered.includes('chuột')) {
      tags.unshift('gear');
    }
    return Array.from(new Set(tags)).slice(0, 5);
  }
}
