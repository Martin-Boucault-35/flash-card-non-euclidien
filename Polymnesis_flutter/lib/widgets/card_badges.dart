import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';

/// Pill indiquant la boîte Leitner d'une carte (ou "Maîtrisé").
class LeitnerBoxBadge extends StatelessWidget {
  final int box;

  const LeitnerBoxBadge({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    final maxBox = context.read<CardProvider>().leitnerSettings.boxCount;
    final isMastered = box > maxBox;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMastered
            ? AppColors.emerald900.withValues(alpha: 0.5)
            : AppColors.amber900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMastered ? AppColors.emerald700 : AppColors.amber700,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMastered ? Icons.check_circle : Icons.inbox,
            size: 12,
            color: isMastered ? AppColors.emerald400 : AppColors.amber200,
          ),
          const SizedBox(width: 4),
          Text(
            isMastered ? 'Maîtrisé' : 'Boîte $box',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMastered ? AppColors.emerald400 : AppColors.amber200,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill indiquant dans combien de jours la carte revient dans le jeu quotidien.
/// Calculé sur la date PROPRE de la carte ([FlashCard.nextReviewAt]) — deux
/// cartes de la même boîte peuvent revenir des jours différents.
class NextReviewBadge extends StatelessWidget {
  final FlashCard card;

  const NextReviewBadge({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final maxBox = context.read<CardProvider>().leitnerSettings.boxCount;
    // Carte maîtrisée : pas de compte à rebours (la boîte affiche déjà "Maîtrisé").
    if (card.leitnerBox > maxBox) return const SizedBox.shrink();

    final diff = card.nextReviewAt - DateTime.now().millisecondsSinceEpoch;
    final due = diff <= 0;
    final days =
        due ? 0 : (diff / const Duration(days: 1).inMilliseconds).ceil();
    final label = due ? 'À réviser' : 'Dans $days j';

    final Color fg = due ? AppColors.indigo400 : AppColors.slate400;
    final Color border = due ? AppColors.indigo500 : AppColors.slate600;
    final Color bg = (due ? AppColors.indigo600 : AppColors.slate700)
        .withValues(alpha: due ? 0.2 : 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            due ? Icons.notifications_active : Icons.schedule,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
