import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }
enum AppButtonSize { sm, md, lg }

/// Bouton personnalisé avec variantes (comme le composant React)
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool fullWidth;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.fullWidth = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    final padding = _getPadding();
    final fontSize = _getFontSize();

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: colors['background'],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: variant == AppButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: AppColors.indigo500.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors['foreground'],
                      ),
                    )
                  : DefaultTextStyle(
                      style: TextStyle(
                        color: colors['foreground'],
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                          color: colors['foreground'],
                          size: fontSize + 4,
                        ),
                        child: child,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Color?> _getColors() {
    switch (variant) {
      case AppButtonVariant.primary:
        return {
          'background': AppColors.indigo600,
          'foreground': Colors.white,
        };
      case AppButtonVariant.secondary:
        return {
          'background': AppColors.slate700,
          'foreground': AppColors.slate100,
        };
      case AppButtonVariant.danger:
        return {
          'background': AppColors.red500,
          'foreground': Colors.white,
        };
      case AppButtonVariant.ghost:
        return {
          'background': Colors.transparent,
          'foreground': AppColors.slate400,
        };
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppButtonSize.sm:
        return 12;
      case AppButtonSize.md:
        return 14;
      case AppButtonSize.lg:
        return 16;
    }
  }
}
