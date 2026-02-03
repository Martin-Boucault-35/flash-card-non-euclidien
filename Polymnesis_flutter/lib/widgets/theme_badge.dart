import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/app_theme.dart';

/// Badge coloré pour afficher le thème d'une carte
class ThemeBadge extends StatelessWidget {
  final FlashCardTheme theme;
  final double fontSize;

  const ThemeBadge({
    super.key,
    required this.theme,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors['border']!),
      ),
      child: Text(
        theme.displayName,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: colors['text'],
        ),
      ),
    );
  }

  Map<String, Color> _getColors() {
    switch (theme) {
      case FlashCardTheme.classique:
        return {
          'background': AppColors.amber900.withValues(alpha: 0.5),
          'text': AppColors.amber200,
          'border': AppColors.amber700,
        };
      case FlashCardTheme.histoire:
        return {
          'background': AppColors.yellow900.withValues(alpha: 0.5),
          'text': AppColors.yellow200,
          'border': AppColors.yellow700,
        };
      case FlashCardTheme.geographie:
        return {
          'background': AppColors.emerald900.withValues(alpha: 0.5),
          'text': AppColors.emerald200,
          'border': AppColors.emerald700,
        };
      case FlashCardTheme.moderne:
        return {
          'background': AppColors.cyan900.withValues(alpha: 0.5),
          'text': AppColors.cyan200,
          'border': AppColors.cyan700,
        };
      case FlashCardTheme.animaux:
        return {
          'background': AppColors.orange900.withValues(alpha: 0.5),
          'text': AppColors.orange200,
          'border': AppColors.orange700,
        };
      case FlashCardTheme.sciences:
        return {
          'background': AppColors.blue900.withValues(alpha: 0.5),
          'text': AppColors.blue200,
          'border': AppColors.blue700,
        };
      case FlashCardTheme.sport:
        return {
          'background': AppColors.red900.withValues(alpha: 0.5),
          'text': AppColors.red200,
          'border': AppColors.red700,
        };
      case FlashCardTheme.cultureG:
        return {
          'background': AppColors.purple900.withValues(alpha: 0.5),
          'text': AppColors.purple200,
          'border': AppColors.purple700,
        };
    }
  }
}
