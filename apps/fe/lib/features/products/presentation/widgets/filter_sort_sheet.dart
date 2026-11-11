import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_text_field.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../data/models/product_model.dart';

/// Filter & Sort Modal Bottom Sheet (`07 - Filter & Sort Sheet` in Figma).
///
/// Allows buyers to filter by Category, Condition (`NEW`, `LIKE_NEW`, `GOOD`, `FAIR`),
/// Price Range (`minPrice`, `maxPrice`), and Sort Order (`createdAt`, `price`, `viewsCount`).
class FilterSortSheet extends ConsumerStatefulWidget {
  const FilterSortSheet({
    super.key,
    required this.initialQuery,
    required this.onApply,
  });

  final ProductFilterQuery initialQuery;
  final ValueChanged<ProductFilterQuery> onApply;

  static Future<void> show({
    required BuildContext context,
    required ProductFilterQuery initialQuery,
    required ValueChanged<ProductFilterQuery> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => FilterSortSheet(
        initialQuery: initialQuery,
        onApply: onApply,
      ),
    );
  }

  @override
  ConsumerState<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends ConsumerState<FilterSortSheet> {
  late String? _selectedCategoryId;
  late ProductCondition? _selectedCondition;
  late String _sortBy;
  late String _sortOrder;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialQuery.categoryId;
    _selectedCondition = widget.initialQuery.condition;
    _sortBy = widget.initialQuery.sortBy;
    _sortOrder = widget.initialQuery.sortOrder;
    _minPriceController = TextEditingController(
      text: widget.initialQuery.minPrice?.toInt().toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialQuery.maxPrice?.toInt().toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedCondition = null;
      _sortBy = 'createdAt';
      _sortOrder = 'desc';
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _applyFilters() {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());

    final nextQuery = widget.initialQuery.copyWith(
      categoryId: _selectedCategoryId,
      clearCategory: _selectedCategoryId == null,
      condition: _selectedCondition,
      clearCondition: _selectedCondition == null,
      minPrice: minPrice,
      clearMinPrice: minPrice == null,
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );

    widget.onApply(nextQuery);
    Navigator.of(context).pop();
  }

  void _setPricePreset(int? min, int? max) {
    setState(() {
      _minPriceController.text = min?.toString() ?? '';
      _maxPriceController.text = max?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc & Sắp xếp sản phẩm',
                    style: AppTypography.titleLarge,
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // 1. Sort Options
              const Text(
                'Sắp xếp theo',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _SortOptionChip(
                    label: 'Mới đăng nhất',
                    selected: _sortBy == 'createdAt' && _sortOrder == 'desc',
                    onTap: () => setState(() {
                      _sortBy = 'createdAt';
                      _sortOrder = 'desc';
                    }),
                  ),
                  _SortOptionChip(
                    label: 'Giá thấp → cao',
                    selected: _sortBy == 'price' && _sortOrder == 'asc',
                    onTap: () => setState(() {
                      _sortBy = 'price';
                      _sortOrder = 'asc';
                    }),
                  ),
                  _SortOptionChip(
                    label: 'Giá cao → thấp',
                    selected: _sortBy == 'price' && _sortOrder == 'desc',
                    onTap: () => setState(() {
                      _sortBy = 'price';
                      _sortOrder = 'desc';
                    }),
                  ),
                  _SortOptionChip(
                    label: 'Xem nhiều nhất',
                    selected: _sortBy == 'viewsCount' && _sortOrder == 'desc',
                    onTap: () => setState(() {
                      _sortBy = 'viewsCount';
                      _sortOrder = 'desc';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Category
              const Text(
                'Danh mục',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                data: (categories) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = null),
                    ),
                    for (final cat in categories)
                      ChoiceChip(
                        label: Text(cat.name),
                        selected: _selectedCategoryId == cat.id,
                        onSelected: (_) => setState(
                          () => _selectedCategoryId =
                              _selectedCategoryId == cat.id ? null : cat.id,
                        ),
                      ),
                  ],
                ),
                loading: () => const SizedBox(
                  height: 36,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, _) => const Text(
                  'Không thể tải danh mục',
                  style: AppTypography.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Condition
              const Text(
                'Tình trạng sản phẩm',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _selectedCondition == null,
                    onSelected: (_) =>
                        setState(() => _selectedCondition = null),
                  ),
                  for (final condition in ProductCondition.values)
                    ChoiceChip(
                      label: Text(condition.labelVi),
                      selected: _selectedCondition == condition,
                      onSelected: (_) => setState(
                        () => _selectedCondition =
                            _selectedCondition == condition ? null : condition,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Price Range (VND)
              const Text(
                'Khoảng giá (VNĐ)',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  ActionChip(
                    label: const Text('Dưới 1 triệu'),
                    onPressed: () => _setPricePreset(0, 1000000),
                  ),
                  ActionChip(
                    label: const Text('1 - 5 triệu'),
                    onPressed: () => _setPricePreset(1000000, 5000000),
                  ),
                  ActionChip(
                    label: const Text('5 - 15 triệu'),
                    onPressed: () => _setPricePreset(5000000, 15000000),
                  ),
                  ActionChip(
                    label: const Text('Trên 15 triệu'),
                    onPressed: () => _setPricePreset(15000000, null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: RmTextField(
                      label: 'Giá từ (₫)',
                      hintText: 'VD: 500000',
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: RmTextField(
                      label: 'Đến (₫)',
                      hintText: 'VD: 5000000',
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 5. Actions
              Row(
                children: [
                  Expanded(
                    child: RmButton(
                      label: 'Xóa lọc',
                      variant: RmButtonVariant.secondary,
                      onPressed: () {
                        _resetFilters();
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: RmButton(
                      label: 'Áp dụng bộ lọc',
                      icon: Icons.check_rounded,
                      onPressed: _applyFilters,
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

class _SortOptionChip extends StatelessWidget {
  const _SortOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryTintBg,
      labelStyle: AppTypography.bodySmall.copyWith(
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
