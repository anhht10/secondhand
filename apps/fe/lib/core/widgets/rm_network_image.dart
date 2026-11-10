import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// Reusable network image widget that resolves relative `/uploads/...` URLs
/// via [appConfigProvider] and displays a fallback placeholder on error or empty URL.
class RmNetworkImage extends ConsumerWidget {
  const RmNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final resolved = config.resolveMediaUrl(imageUrl);
    if (resolved.isEmpty) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 26,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surfaceVariant,
      child: Image.network(
        resolved,
        fit: fit,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 26,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
