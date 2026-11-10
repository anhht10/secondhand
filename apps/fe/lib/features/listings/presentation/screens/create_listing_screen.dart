import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../../core/widgets/rm_text_field.dart';
import '../../../ai/data/models/ai_models.dart';
import '../../../ai/presentation/providers/ai_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/models/listing_draft_model.dart';

/// Create & Edit Listing Screen (`13 - Create Listing & Draft`, `14 - AI Price Estimator`,
/// `15 - AI Listing Preview & Verify`).
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({
    super.key,
    this.editProductId,
  });

  final String? editProductId;

  bool get isEditMode => editProductId != null && editProductId!.isNotEmpty;

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController =
      TextEditingController();
  final TextEditingController _defectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedCategoryId;
  String _selectedCategoryName = '';
  ProductCondition _selectedCondition = ProductCondition.likeNew;
  List<String> _imageUrls = <String>[];
  List<String> _aiTags = <String>[];
  String? _aiTransparencyNote;
  List<String> _aiConditionTips = <String>[];
  AiPriceEstimateModel? _priceEstimate;

  bool _isUploadingImages = false;
  bool _isGeneratingListing = false;
  bool _isEstimatingPrice = false;
  bool _isSubmitting = false;
  bool _isLoadingEditProduct = false;
  bool _restoredFromDraft = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_initializeForm);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _defectController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    final userLocation = ref.read(authControllerProvider).user?.location;
    if (userLocation != null && userLocation.trim().isNotEmpty) {
      _locationController.text = userLocation;
    }

    if (widget.isEditMode) {
      setState(() => _isLoadingEditProduct = true);
      final result = await ref
          .read(productRepositoryProvider)
          .getProductById(widget.editProductId!);
      if (!mounted) return;
      setState(() => _isLoadingEditProduct = false);

      result.when(
        success: (product, _, _) {
          setState(() {
            _titleController.text = product.title;
            _priceController.text = product.price.toInt().toString();
            if (product.originalPrice != null) {
              _originalPriceController.text =
                  product.originalPrice!.toInt().toString();
            }
            _defectController.text = product.defects;
            _descriptionController.text = product.description;
            _locationController.text = product.location ?? '';
            _selectedCategoryId = product.categoryId.isNotEmpty
                ? product.categoryId
                : product.category.id;
            _selectedCategoryName = product.category.name;
            _selectedCondition = product.condition;
            _imageUrls = List<String>.from(product.images);
            _aiTags = List<String>.from(product.tags);
          });
        },
        failure: (error) {
          setState(() => _errorMessage = error.message);
        },
      );
      return;
    }

    // Restore local draft if creating a new listing
    final prefs = ref.read(localPreferencesProvider);
    final rawDraft = prefs?.readListingDraftJson();
    if (rawDraft != null) {
      final draft = ListingDraftModel.fromJson(rawDraft);
      if (draft.isNotEmpty) {
        setState(() {
          _titleController.text = draft.title;
          _brandController.text = draft.brand;
          _selectedCategoryId = draft.categoryId;
          _selectedCategoryName = draft.categoryName;
          _selectedCondition = draft.condition;
          _priceController.text = draft.priceText;
          _originalPriceController.text = draft.originalPriceText;
          _defectController.text = draft.defectDisclosure;
          _descriptionController.text = draft.description;
          if (draft.location.trim().isNotEmpty) {
            _locationController.text = draft.location;
          }
          _imageUrls = List<String>.from(draft.uploadedImageUrls);
          _aiTransparencyNote = draft.aiTransparencyNote;
          _aiTags = List<String>.from(draft.aiTags);
          _restoredFromDraft = true;
        });
      }
    }
  }

  Future<void> _saveLocalDraft() async {
    if (widget.isEditMode) return;
    final prefs = ref.read(localPreferencesProvider);
    if (prefs == null) return;

    final draft = ListingDraftModel(
      title: _titleController.text,
      brand: _brandController.text,
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategoryName,
      condition: _selectedCondition,
      priceText: _priceController.text,
      originalPriceText: _originalPriceController.text,
      defectDisclosure: _defectController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      uploadedImageUrls: _imageUrls,
      aiTransparencyNote: _aiTransparencyNote,
      aiTags: _aiTags,
      aiQuickSellPrice: _priceEstimate?.quickSellPrice,
      aiRecommendedPrice: _priceEstimate?.recommendedPrice,
      aiMaxFairPrice: _priceEstimate?.maxFairPrice,
      updatedAt: DateTime.now(),
    );

    await prefs.saveListingDraftJson(draft.toJson());
  }

  Future<void> _clearLocalDraft() async {
    final prefs = ref.read(localPreferencesProvider);
    await prefs?.clearListingDraftJson();
    if (!mounted) return;
    setState(() {
      _titleController.clear();
      _brandController.clear();
      _priceController.clear();
      _originalPriceController.clear();
      _defectController.clear();
      _descriptionController.clear();
      _imageUrls = <String>[];
      _aiTags = <String>[];
      _aiTransparencyNote = null;
      _aiConditionTips = <String>[];
      _priceEstimate = null;
      _restoredFromDraft = false;
      _errorMessage = null;
    });
  }

  Future<void> _pickAndUploadImages() async {
    if (_imageUrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 6 hình ảnh cho mỗi tin đăng.')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (pickedFiles.isEmpty) return;

      setState(() {
        _isUploadingImages = true;
        _errorMessage = null;
      });

      final uploadItems = <UploadableImageFile>[];
      for (final file in pickedFiles.take(6 - _imageUrls.length)) {
        final bytes = await file.readAsBytes();
        uploadItems.add(
          UploadableImageFile(
            bytes: bytes,
            fileName: file.name.isNotEmpty ? file.name : 'product.jpg',
          ),
        );
      }

      final result =
          await ref.read(productRepositoryProvider).uploadImages(uploadItems);
      if (!mounted) return;
      setState(() => _isUploadingImages = false);

      result.when(
        success: (urls, _, _) {
          setState(() {
            _imageUrls = <String>[..._imageUrls, ...urls];
          });
          _saveLocalDraft();
        },
        failure: (error) {
          setState(() => _errorMessage = error.message);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImages = false;
        _errorMessage = 'Không thể mở thư viện ảnh: $e';
      });
    }
  }

  Future<void> _runAiListingGenerator() async {
    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() {
        _errorMessage =
            'Vui lòng nhập tên sản phẩm (tối thiểu 3 ký tự) trước khi tạo mô tả bằng AI.';
      });
      return;
    }

    setState(() {
      _isGeneratingListing = true;
      _errorMessage = null;
    });

    final result = await ref.read(aiRepositoryProvider).generateListing(
          title: title,
          brand: _brandController.text.trim().isNotEmpty
              ? _brandController.text.trim()
              : null,
          category: _selectedCategoryName.isNotEmpty
              ? _selectedCategoryName
              : null,
          condition: _selectedCondition,
          price: double.tryParse(_priceController.text.trim()),
          originalPrice: double.tryParse(_originalPriceController.text.trim()),
          defectDisclosure: _defectController.text.trim().isNotEmpty
              ? _defectController.text.trim()
              : null,
          imageUrls: _imageUrls,
        );

    if (!mounted) return;
    setState(() => _isGeneratingListing = false);

    result.when(
      success: (generated, _, _) {
        setState(() {
          if (generated.title.trim().isNotEmpty) {
            _titleController.text = generated.title.trim();
          }
          _descriptionController.text = generated.description.trim();
          _aiTags = generated.tags;
          _aiTransparencyNote = generated.transparencyNote;
          _aiConditionTips = generated.conditionTips;
        });
        _saveLocalDraft();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✨ Gemini AI đã tạo tiêu đề & bài đăng chuẩn 3 phần minh bạch!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      },
      failure: (error) {
        setState(() => _errorMessage = error.message);
      },
    );
  }

  Future<void> _runAiPriceEstimator() async {
    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() {
        _errorMessage =
            'Vui lòng nhập tên sản phẩm trước khi yêu cầu AI định giá.';
      });
      return;
    }

    setState(() {
      _isEstimatingPrice = true;
      _errorMessage = null;
    });

    final result = await ref.read(aiRepositoryProvider).estimatePrice(
          title: title,
          brand: _brandController.text.trim().isNotEmpty
              ? _brandController.text.trim()
              : null,
          category: _selectedCategoryName.isNotEmpty
              ? _selectedCategoryName
              : null,
          condition: _selectedCondition,
          originalPrice: double.tryParse(_originalPriceController.text.trim()),
          defectDisclosure: _defectController.text.trim().isNotEmpty
              ? _defectController.text.trim()
              : null,
        );

    if (!mounted) return;
    setState(() => _isEstimatingPrice = false);

    result.when(
      success: (estimate, _, _) {
        setState(() {
          _priceEstimate = estimate;
          if (_priceController.text.trim().isEmpty &&
              estimate.recommendedPrice > 0) {
            _priceController.text =
                estimate.recommendedPrice.toInt().toString();
          }
        });
        _saveLocalDraft();
      },
      failure: (error) {
        setState(() => _errorMessage = error.message);
      },
    );
  }

  void _openPreviewSheet(List<CategoryModel> categories) {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      if (categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
        _selectedCategoryName = categories.first.name;
      } else {
        setState(() => _errorMessage = 'Vui lòng chọn danh mục sản phẩm.');
        return;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => _ListingPreviewSheet(
        title: _titleController.text.trim(),
        categoryName: _selectedCategoryName,
        condition: _selectedCondition,
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        originalPrice: double.tryParse(_originalPriceController.text.trim()),
        defects: _defectController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        isEditMode: widget.isEditMode,
        onConfirmPublish: (status) {
          Navigator.of(ctx).pop();
          _submitListing(status: status);
        },
      ),
    );
  }

  Future<void> _submitListing({required ProductStatus status}) async {
    if (_isSubmitting) return;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final originalPrice = double.tryParse(_originalPriceController.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repo = ref.read(productRepositoryProvider);
    final aiMeta = _priceEstimate != null
        ? ProductAiMetadata(
            suggestedPriceMin: _priceEstimate!.quickSellPrice,
            suggestedPriceRecommended: _priceEstimate!.recommendedPrice,
            suggestedPriceMax: _priceEstimate!.maxFairPrice,
            priceReasoning: _priceEstimate!.reasoning,
          )
        : null;

    final result = widget.isEditMode
        ? await repo.updateProduct(
            productId: widget.editProductId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            originalPrice: originalPrice,
            categoryId: _selectedCategoryId,
            condition: _selectedCondition,
            defectDisclosure: _defectController.text.trim(),
            images: _imageUrls,
            location: _locationController.text.trim(),
          )
        : await repo.createProduct(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            originalPrice: originalPrice,
            categoryId: _selectedCategoryId!,
            condition: _selectedCondition,
            defectDisclosure: _defectController.text.trim(),
            images: _imageUrls,
            location: _locationController.text.trim(),
            status: status,
            aiMetadata: aiMeta,
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (createdOrUpdated, _, _) async {
        if (!widget.isEditMode) {
          await ref.read(localPreferencesProvider)?.clearListingDraftJson();
        }
        ref.read(productFeedControllerProvider.notifier).refresh();
        if (widget.isEditMode) {
          ref.invalidate(productDetailProvider(createdOrUpdated.id));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? 'Đã cập nhật tin đăng thành công!'
                  : status == ProductStatus.draft
                      ? 'Đã lưu tin đăng ở trạng thái Bản nháp!'
                      : 'Đã đăng bán sản phẩm công khai thành công!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.push(RouteNames.productDetail(createdOrUpdated.id));
      },
      failure: (error) {
        setState(() => _errorMessage = error.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final config = ref.watch(appConfigProvider);
    final categories = categoriesAsync.valueOrNull ?? const <CategoryModel>[];

    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
      _selectedCategoryName = categories.first.name;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Chỉnh sửa tin đăng' : 'Đăng bán minh bạch & AI',
        ),
        actions: [
          if (!widget.isEditMode)
            TextButton.icon(
              onPressed: () {
                _saveLocalDraft();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã lưu bản nháp vào bộ nhớ máy!'),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Lưu nháp'),
            ),
        ],
      ),
      body: _isLoadingEditProduct
          ? const RmLoadingIndicator(
              message: 'Đang tải dữ liệu tin đăng...',
            )
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: _formKey,
                onChanged: _saveLocalDraft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Local Draft Restored Banner (`F09`)
                    if (_restoredFromDraft && !widget.isEditMode) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTintBg,
                          borderRadius: AppSpacing.borderRadiusMd,
                          border: Border.all(color: AppColors.primaryTintBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.restore_page_outlined,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Đã khôi phục bản nháp chưa hoàn tất của bạn.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _clearLocalDraft,
                              child: const Text('Xóa nháp'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (_errorMessage != null) ...[
                      RmErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // 2. Product Images Section (`POST /api/v1/upload/images`)
                    RmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Hình ảnh thực tế (Tối đa 6 ảnh)',
                                  style: AppTypography.titleMedium,
                                ),
                              ),
                              Text(
                                '${_imageUrls.length}/6',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Chụp rõ ngoại hình và vị trí trầy xước (nếu có) để tăng độ tin cậy.',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (int i = 0; i < _imageUrls.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: AppSpacing.borderRadiusMd,
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        color: AppColors.surfaceVariant,
                                        child: Image.network(
                                          config.resolveMediaUrl(_imageUrls[i]),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.image_outlined,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _imageUrls.removeAt(i);
                                          });
                                          _saveLocalDraft();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
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
                                ),
                              if (_imageUrls.length < 6)
                                InkWell(
                                  borderRadius: AppSpacing.borderRadiusMd,
                                  onTap: _isUploadingImages
                                      ? null
                                      : _pickAndUploadImages,
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTintBg,
                                      borderRadius: AppSpacing.borderRadiusMd,
                                      border: Border.all(
                                        color: AppColors.primaryTintBorderStrong,
                                      ),
                                    ),
                                    child: _isUploadingImages
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo_outlined,
                                                color: AppColors.primary,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Tải ảnh',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.primaryDark,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 3. Core Product Info & Defect Disclosure
                    RmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin cơ bản & Tình trạng',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          RmTextField(
                            label: 'Tên sản phẩm *',
                            hintText:
                                'VD: iPhone 13 Pro 128GB VN/A Xanh Sierra',
                            controller: _titleController,
                            validator: (val) {
                              if (val == null || val.trim().length < 5) {
                                return 'Tên sản phẩm phải từ 5 ký tự trở lên';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: RmTextField(
                                  label: 'Thương hiệu / Hãng',
                                  hintText: 'VD: Apple, Sony, Dell...',
                                  controller: _brandController,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: RmTextField(
                                  label: 'Khu vực giao dịch *',
                                  hintText: 'VD: Quận 1, TP.HCM',
                                  controller: _locationController,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Nhập khu vực';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Category Dropdown
                          Text(
                            'Danh mục sản phẩm *',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs + 2),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: categories.any(
                              (c) => c.id == _selectedCategoryId,
                            )
                                ? _selectedCategoryId
                                : null,
                            items: [
                              for (final cat in categories)
                                DropdownMenuItem<String>(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ),
                            ],
                            onChanged: (val) {
                              final matched = categories
                                  .where((c) => c.id == val)
                                  .firstOrNull;
                              setState(() {
                                _selectedCategoryId = val;
                                _selectedCategoryName = matched?.name ?? '';
                              });
                              _saveLocalDraft();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Chọn danh mục',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Condition Selector
                          Text(
                            'Độ mới sản phẩm *',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs + 2),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final cond in ProductCondition.values)
                                ChoiceChip(
                                  label: Text(cond.labelVi),
                                  selected: _selectedCondition == cond,
                                  onSelected: (_) {
                                    setState(() => _selectedCondition = cond);
                                    _saveLocalDraft();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Mandatory Defect Disclosure
                          RmTextField(
                            label:
                                'Công khai khuyết điểm & Tình trạng thực tế *',
                            hintText:
                                'VD: Trầy nhẹ góc phải, pin 87%, màn hình zin không ám ố, đầy đủ hộp cáp',
                            controller: _defectController,
                            maxLines: 2,
                            validator: (val) {
                              if (val == null || val.trim().length < 5) {
                                return 'Vui lòng mô tả trung thực tình trạng hoặc ghi "Không có lỗi/trầy xước"';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 4. AI 2 — Smart Price Estimator (`14 - AI Price Estimator`)
                    RmCard(
                      backgroundColor: AppColors.primaryTintBg,
                      borderColor: AppColors.primaryTintBorderStrong,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.price_check_rounded,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Định giá thông minh Gemini AI',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              RmButton(
                                label: 'Gợi ý 3 mức giá',
                                icon: Icons.auto_awesome_rounded,
                                fullWidth: false,
                                isLoading: _isEstimatingPrice,
                                onPressed: _runAiPriceEstimator,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Phân tích tình trạng máy, khuyết điểm và dữ liệu các tin đang bán trên sàn ReMarket để đề xuất mức giá hợp lý.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                          if (_priceEstimate != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: _PriceTierCard(
                                    badge: '🚀 Bán nhanh',
                                    price: _priceEstimate!.quickSellPrice,
                                    isSelected: _priceController.text.trim() ==
                                        _priceEstimate!.quickSellPrice
                                            .toInt()
                                            .toString(),
                                    onTap: () {
                                      setState(() {
                                        _priceController.text = _priceEstimate!
                                            .quickSellPrice
                                            .toInt()
                                            .toString();
                                      });
                                      _saveLocalDraft();
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _PriceTierCard(
                                    badge: '⭐ Khuyên dùng',
                                    price: _priceEstimate!.recommendedPrice,
                                    isRecommended: true,
                                    isSelected: _priceController.text.trim() ==
                                        _priceEstimate!.recommendedPrice
                                            .toInt()
                                            .toString(),
                                    onTap: () {
                                      setState(() {
                                        _priceController.text = _priceEstimate!
                                            .recommendedPrice
                                            .toInt()
                                            .toString();
                                      });
                                      _saveLocalDraft();
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _PriceTierCard(
                                    badge: '💎 Giá tối đa',
                                    price: _priceEstimate!.maxFairPrice,
                                    isSelected: _priceController.text.trim() ==
                                        _priceEstimate!.maxFairPrice
                                            .toInt()
                                            .toString(),
                                    onTap: () {
                                      setState(() {
                                        _priceController.text = _priceEstimate!
                                            .maxFairPrice
                                            .toInt()
                                            .toString();
                                      });
                                      _saveLocalDraft();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Nhận định AI (${_priceEstimate!.confidenceLabelVi}): ${_priceEstimate!.reasoning}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: RmTextField(
                                  label: 'Giá bán mong muốn (₫) *',
                                  hintText: 'VD: 11500000',
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    final parsed =
                                        double.tryParse(val?.trim() ?? '');
                                    if (parsed == null || parsed < 1000) {
                                      return 'Nhập giá bán hợp lệ (≥ 1.000₫)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: RmTextField(
                                  label: 'Giá mua mới (Tùy chọn)',
                                  hintText: 'VD: 21990000',
                                  controller: _originalPriceController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 5. AI 1 — Smart Listing Generator & Description
                    RmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Mô tả chi tiết sản phẩm',
                                  style: AppTypography.titleMedium,
                                ),
                              ),
                              RmButton(
                                label: 'Tạo mô tả bằng AI',
                                icon: Icons.auto_fix_high_rounded,
                                variant: RmButtonVariant.tonal,
                                fullWidth: false,
                                isLoading: _isGeneratingListing,
                                onPressed: _runAiListingGenerator,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          RmTextField(
                            label:
                                'Nội dung bài đăng (Tổng quan, Tình trạng, Phụ kiện) *',
                            hintText:
                                'Nhấn "Tạo mô tả bằng AI" hoặc tự viết chi tiết về nguồn gốc, tình trạng và phụ kiện đi kèm...',
                            controller: _descriptionController,
                            maxLines: 6,
                            validator: (val) {
                              if (val == null || val.trim().length < 20) {
                                return 'Mô tả chi tiết cần tối thiểu 20 ký tự';
                              }
                              return null;
                            },
                          ),
                          if (_aiTransparencyNote != null &&
                              _aiTransparencyNote!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: AppSpacing.borderRadiusSm,
                                border: Border.all(
                                  color: AppColors.successBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    size: 16,
                                    color: AppColors.successText,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Ghi chú minh bạch AI: $_aiTransparencyNote',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.successText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_aiConditionTips.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final tip in _aiConditionTips)
                                  Chip(
                                    label: Text(
                                      tip,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 6. Submit / Preview Button
                    RmButton(
                      label: widget.isEditMode
                          ? 'Xem trước & Lưu thay đổi'
                          : 'Xem trước & Đăng tin bán',
                      icon: Icons.visibility_outlined,
                      isLoading: _isSubmitting,
                      onPressed: () => _openPreviewSheet(categories),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PriceTierCard extends StatelessWidget {
  const _PriceTierCard({
    required this.badge,
    required this.price,
    required this.isSelected,
    required this.onTap,
    this.isRecommended = false,
  });

  final String badge;
  final double price;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : isRecommended
              ? Colors.white
              : AppColors.surfaceVariant,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: isSelected || isRecommended
                  ? AppColors.primary
                  : AppColors.border,
              width: isSelected || isRecommended ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.formatVnd(price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview & Seller Transparency Verification Sheet (`15 - AI Listing Preview & Verify`).
class _ListingPreviewSheet extends StatefulWidget {
  const _ListingPreviewSheet({
    required this.title,
    required this.categoryName,
    required this.condition,
    required this.price,
    this.originalPrice,
    required this.defects,
    required this.description,
    required this.location,
    required this.isEditMode,
    required this.onConfirmPublish,
  });

  final String title;
  final String categoryName;
  final ProductCondition condition;
  final double price;
  final double? originalPrice;
  final String defects;
  final String description;
  final String location;
  final bool isEditMode;
  final ValueChanged<ProductStatus> onConfirmPublish;

  @override
  State<_ListingPreviewSheet> createState() => _ListingPreviewSheetState();
}

class _ListingPreviewSheetState extends State<_ListingPreviewSheet> {
  bool _confirmedTransparency = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xem trước & Cam kết Minh bạch',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              RmCard(
                backgroundColor: AppColors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: AppTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatVnd(widget.price),
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.condition.labelVi} • ${widget.categoryName} • ${widget.location}',
                      style: AppTypography.bodySmall,
                    ),
                    const Divider(height: AppSpacing.lg),
                    Text(
                      '🔍 Khuyết điểm công khai: ${widget.defects}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Material(
                color: AppColors.primaryTintBg,
                borderRadius: AppSpacing.borderRadiusMd,
                child: CheckboxListTile(
                  value: _confirmedTransparency,
                  onChanged: (val) =>
                      setState(() => _confirmedTransparency = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primary,
                  title: Text(
                    'Tôi cam kết mô tả trung thực tình trạng sản phẩm và công khai đầy đủ các khuyết điểm đã biết.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (!widget.isEditMode) ...[
                    Expanded(
                      child: RmButton(
                        label: 'Lưu nháp Server',
                        variant: RmButtonVariant.secondary,
                        onPressed: _confirmedTransparency
                            ? () =>
                                widget.onConfirmPublish(ProductStatus.draft)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: RmButton(
                      label: widget.isEditMode
                          ? 'Cập nhật tin đăng'
                          : 'Đăng bán công khai',
                      icon: Icons.publish_rounded,
                      onPressed: _confirmedTransparency
                          ? () => widget.onConfirmPublish(ProductStatus.active)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
