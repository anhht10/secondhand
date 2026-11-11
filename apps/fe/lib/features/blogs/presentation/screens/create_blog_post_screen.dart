import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/models/blog_models.dart';
import '../providers/blog_providers.dart';

class CreateBlogPostScreen extends ConsumerStatefulWidget {
  const CreateBlogPostScreen({super.key});

  @override
  ConsumerState<CreateBlogPostScreen> createState() =>
      _CreateBlogPostScreenState();
}

class _CreateBlogPostScreenState extends ConsumerState<CreateBlogPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _aiTopicController = TextEditingController();
  final _aiKeyPointsController = TextEditingController();
  final _imageUrlController = TextEditingController();

  BlogCategory _selectedCategory = BlogCategory.experience;
  ProductModel? _attachedProduct;
  final List<String> _imageUrls = <String>[];
  bool _isGeneratingAi = false;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _aiTopicController.dispose();
    _aiKeyPointsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateAiDraft() async {
    final topic = _aiTopicController.text.trim().isNotEmpty
        ? _aiTopicController.text.trim()
        : _titleController.text.trim();
    if (topic.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập chủ đề hoặc ý tưởng bài viết (tối thiểu 3 ký tự) để AI viết nháp.',
          ),
        ),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);
    final result = await ref.read(blogRepositoryProvider).generateAiDraft(
          topic: topic,
          category: _selectedCategory,
          keyPoints: _aiKeyPointsController.text.trim(),
          attachedProductTitle: _attachedProduct?.title,
        );
    if (!mounted) return;
    setState(() => _isGeneratingAi = false);

    result.when(
      success: (draft, _, _) {
        setState(() {
          if (_titleController.text.trim().isEmpty ||
              draft.suggestedTitle.isNotEmpty) {
            _titleController.text = draft.suggestedTitle;
          }
          _contentController.text = draft.suggestedContent;
          if (draft.suggestedTags.isNotEmpty) {
            _tagsController.text = draft.suggestedTags.join(', ');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✨ Đã tạo bản nháp bài viết bằng AI! Bạn có thể chỉnh sửa thêm trước khi đăng.',
            ),
          ),
        );
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || _imageUrls.length >= 6) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);
      final bytes = await picked.readAsBytes();
      final uploadRes = await ref
          .read(productRemoteDataSourceProvider)
          .uploadImages(<UploadableImageFile>[
        UploadableImageFile(
          bytes: bytes,
          fileName: picked.name.isNotEmpty ? picked.name : 'blog_image.jpg',
        ),
      ]);
      if (!mounted) return;
      setState(() => _isUploadingImage = false);

      uploadRes.when(
        success: (urls, _, _) {
          if (urls.isNotEmpty) {
            setState(() => _imageUrls.addAll(urls));
          }
        },
        failure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tải ảnh thất bại: ${err.message}')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
    }
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final tags = _tagsController.text
        .split(RegExp(r'[,\s#]+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _isSubmitting = true);
    final result = await ref.read(blogRepositoryProvider).createBlogPost(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          tags: tags,
          images: _imageUrls,
          attachedProductId: _attachedProduct?.id,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (post, _, _) {
        ref.read(blogFeedControllerProvider.notifier).loadPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Đã đăng bài viết lên Blog Cộng đồng thành công!'),
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedProducts = ref.watch(productFeedControllerProvider).items;
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Viết bài Blog Cộng đồng'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // 1. Category Selector
            RmCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Chọn chuyên mục bài viết',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in BlogCategory.values)
                        ChoiceChip(
                          label: Text('${cat.emoji} ${cat.labelVi}'),
                          selected: _selectedCategory == cat,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. AI Blog Assistant Card
            RmCard(
              backgroundColor: AppColors.primaryTintBg,
              borderColor: AppColors.primaryTintBorderStrong,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Trợ lý Gemini AI viết nháp bài Blog tự động',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chỉ cần nhập chủ đề hoặc vài gạch đầu dòng, AI sẽ gợi ý tiêu đề, bố cục bài viết và hashtag chuẩn cho bạn.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _aiTopicController,
                    decoration: const InputDecoration(
                      labelText: 'Chủ đề bạn muốn viết',
                      hintText:
                          'VD: Kinh nghiệm test MacBook Pro M1 cũ cho sinh viên IT',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _aiKeyPointsController,
                    decoration: const InputDecoration(
                      labelText: 'Các ý chính muốn nhấn mạnh (Tùy chọn)',
                      hintText:
                          'VD: Kiểm tra chu kỳ sạc pin, màn hình, MDM, test loa và phím',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _isGeneratingAi ? null : _handleGenerateAiDraft,
                      icon: _isGeneratingAi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _isGeneratingAi
                            ? 'AI đang soạn bài viết...'
                            : '✨ Nhờ AI viết nháp bài Blog',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Main Post Content
            RmCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Nội dung bài viết',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề bài viết *',
                      hintText: 'Nhập tiêu đề hấp dẫn (5 - 200 ký tự)',
                    ),
                    validator: (val) {
                      final t = (val ?? '').trim();
                      if (t.length < 5) {
                        return 'Tiêu đề cần ít nhất 5 ký tự.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _contentController,
                    minLines: 7,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết *',
                      hintText:
                          'Chia sẻ kinh nghiệm, đánh giá thực tế hoặc câu chuyện của bạn...',
                      alignLabelWithHint: true,
                    ),
                    validator: (val) {
                      final t = (val ?? '').trim();
                      if (t.length < 10) {
                        return 'Nội dung bài viết cần ít nhất 10 ký tự.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Hashtags (ngăn cách bởi dấu phẩy)',
                      hintText: 'VD: laptop-cu, kinh-nghiem, goc-hoc-tap',
                      prefixIcon: Icon(Icons.tag_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Attach Product on ReMarket
            RmCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Đính kèm sản phẩm trên ReMarket (Tùy chọn)',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gắn sản phẩm đang bán để người đọc có thể bấm xem chi tiết ngay từ bài viết của bạn.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<ProductModel?>(
                    initialValue: _attachedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn sản phẩm đính kèm',
                      prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem<ProductModel?>(
                        value: null,
                        child: Text('Không đính kèm sản phẩm'),
                      ),
                      for (final prod in feedProducts)
                        DropdownMenuItem<ProductModel?>(
                          value: prod,
                          child: Text(
                            '${prod.title} (${AppFormatters.formatVnd(prod.price)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _attachedProduct = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Images section
            RmCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '4. Hình ảnh minh họa (${_imageUrls.length}/6)',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isUploadingImage ? null : _pickAndUploadImage,
                        icon: _isUploadingImage
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                        label: const Text('Tải ảnh lên'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            hintText: 'Hoặc dán URL hình ảnh vào đây...',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: _addImageUrl,
                        child: const Text('Thêm'),
                      ),
                    ],
                  ),
                  if (_imageUrls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final img = _imageUrls[index];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: AppSpacing.borderRadiusSm,
                                child: Image.network(
                                  config.resolveMediaUrl(img),
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 86,
                                    height: 86,
                                    color: AppColors.surfaceVariant,
                                    child: const Icon(Icons.image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _imageUrls.removeAt(index),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  _isSubmitting ? 'Đang đăng bài viết...' : 'Đăng bài lên Blog',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
