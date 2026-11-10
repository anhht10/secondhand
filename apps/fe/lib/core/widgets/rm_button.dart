import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum RmButtonVariant {
  primary,
  secondary,
  outlined,
  tonal,
  ghost,
  danger,
}

/// Standardized button component for ReMarket with built-in loading indicator.
class RmButton extends StatelessWidget {
  const RmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RmButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final RmButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == RmButtonVariant.primary ||
                        variant == RmButtonVariant.danger
                    ? Colors.white
                    : AppColors.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final minSize = fullWidth ? const Size.fromHeight(50) : const Size(0, 42);
    final compactPadding = fullWidth
        ? null
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );

    switch (variant) {
      case RmButtonVariant.secondary:
      case RmButtonVariant.outlined:
        return OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            padding: compactPadding,
          ),
          child: child,
        );
      case RmButtonVariant.ghost:
        return TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: minSize,
            padding: compactPadding,
          ),
          child: child,
        );
      case RmButtonVariant.tonal:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTintBg,
            foregroundColor: AppColors.primaryDark,
            minimumSize: minSize,
            padding: compactPadding,
            side: const BorderSide(color: AppColors.primaryTintBorder),
          ),
          child: child,
        );
      case RmButtonVariant.danger:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: minSize,
            padding: compactPadding,
          ),
          child: child,
        );
      case RmButtonVariant.primary:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: minSize,
            padding: compactPadding,
          ),
          child: child,
        );
    }
  }
}
