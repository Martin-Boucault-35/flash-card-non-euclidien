import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_event.dart';
import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/card_badges.dart';
import '../widgets/theme_badge.dart';

/// Page de détail d'une carte : réponse, réponses acceptées, indices, et
/// l'historique complet de sa vie (graphe en escalier + pile d'événements).
///
/// On travaille par [cardId] (et non par instance) pour rester à jour si la
/// carte change pendant l'affichage (édition, révision, sync).
class CardDetailScreen extends StatelessWidget {
  final String cardId;
  final void Function(FlashCard card)? onEdit;

  const CardDetailScreen({super.key, required this.cardId, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final matches = provider.cards.where((c) => c.id == cardId);

    // Carte supprimée (depuis cette page ou via la sync) : on referme.
    if (matches.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(
          child: Text('Carte introuvable.',
              style: TextStyle(color: AppColors.slate400)),
        ),
      );
    }

    final card = matches.first;
    final maxBox = provider.leitnerSettings.boxCount;

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slate400),
        title: const Text('Détail de la carte',
            style: TextStyle(fontSize: 18, color: Colors.white)),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: 'Modifier',
              onPressed: () {
                Navigator.of(context).pop();
                onEdit!(card);
              },
              icon: const Icon(Icons.edit_outlined, color: AppColors.slate400),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- En-tête : badges + réponse ----
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ThemeBadge(theme: card.theme),
              LeitnerBoxBadge(box: card.leitnerBox),
              NextReviewBadge(card: card),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            card.answer,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // ---- Réponses acceptées (variantes d'import) ----
          if (card.acceptedAnswers.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle(
                icon: Icons.spellcheck, label: 'Réponses acceptées'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: card.acceptedAnswers
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.slate800,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slate700),
                        ),
                        child: Text(a,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.slate300)),
                      ))
                  .toList(),
            ),
          ],

          // ---- Indices ----
          const SizedBox(height: 24),
          _SectionTitle(
              icon: Icons.lightbulb_outline,
              label: 'Indices (${card.triggers.length})'),
          const SizedBox(height: 10),
          ...card.triggers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: AppColors.slate600)),
                    Expanded(
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.slate300)),
                    ),
                  ],
                ),
              )),

          // ---- Historique ----
          const SizedBox(height: 28),
          _SectionTitle(
              icon: Icons.history,
              label: 'Historique (${card.history.length})'),
          const SizedBox(height: 12),
          if (card.history.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate800.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate700),
              ),
              child: const Text(
                'Pas encore d\'historique — joue cette carte dans le quotidien '
                'pour suivre son évolution.',
                style: TextStyle(fontSize: 13, color: AppColors.slate400),
              ),
            )
          else ...[
            // Graphe en escalier : lisible dès qu'il y a 2 points de boîte.
            if (_boxEvents(card).length >= 2) ...[
              Container(
                height: 150,
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.slate800.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BoxHistoryPainter(
                    events: _boxEvents(card),
                    maxBox: maxBox,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Pile antichronologique : la dernière action en haut.
            ...card.history.reversed.map((e) => _HistoryTile(event: e)),
          ],
        ],
      ),
    );
  }

  /// Événements qui font bouger la boîte (exclut les événements d'origine).
  static List<CardEvent> _boxEvents(FlashCard card) =>
      card.history.where((e) => !e.type.isOrigin).toList();
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.indigo400),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Une ligne de la pile d'historique.
class _HistoryTile extends StatelessWidget {
  final CardEvent event;

  const _HistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final style = _eventStyle(event.type);
    final movedBox = event.toBox != event.fromBox;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 18, color: style.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: style.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  movedBox
                      ? '${formatEventDate(event.at)} · boîte ${event.fromBox} → ${event.toBox}'
                      : formatEventDate(event.at),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Apparence d'un type d'événement (icône, couleur, libellé).
class _EventStyle {
  final IconData icon;
  final Color color;
  final String label;
  const _EventStyle(this.icon, this.color, this.label);
}

_EventStyle _eventStyle(CardEventType type) {
  switch (type) {
    case CardEventType.created:
      return const _EventStyle(
          Icons.add_circle_outline, AppColors.slate400, 'Carte créée');
    case CardEventType.imported:
      return const _EventStyle(
          Icons.download_done, AppColors.slate400, 'Carte importée');
    case CardEventType.added:
      // Carte antérieure à l'historique : on ne sait pas si elle a été créée
      // à la main ou importée, donc libellé neutre (jamais faux).
      return const _EventStyle(
          Icons.bookmark_added_outlined, AppColors.slate400, 'Carte ajoutée');
    case CardEventType.correct:
      return const _EventStyle(
          Icons.check_circle, AppColors.emerald400, 'Bonne réponse');
    case CardEventType.correctFast:
      return const _EventStyle(
          Icons.bolt, AppColors.amber200, 'Réponse rapide');
    case CardEventType.wrong:
      return const _EventStyle(
          Icons.cancel, AppColors.red400, 'Mauvaise réponse');
    case CardEventType.skipped:
      return const _EventStyle(
          Icons.skip_next, AppColors.red400, 'Question passée');
  }
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// Date courte en français, sans dépendance (intl n'est pas dans le projet).
String formatEventDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year} · $hh:$mm';
}

/// Trace l'évolution de la boîte dans le temps sous forme d'escalier :
/// axe X = ordre chronologique des événements, axe Y = boîte.
class _BoxHistoryPainter extends CustomPainter {
  final List<CardEvent> events;
  final int maxBox;

  _BoxHistoryPainter({required this.events, required this.maxBox});

  @override
  void paint(Canvas canvas, Size size) {
    if (events.length < 2) return;

    const leftPad = 22.0; // place pour les libellés de boîte
    final chartW = size.width - leftPad;
    final chartH = size.height;

    // Échelle Y : boîte 1 en bas, maxBox+1 (maîtrisé) en haut.
    final topBox = maxBox + 1;
    double yFor(int box) {
      final t = (box - 1) / (topBox - 1);
      return chartH - (t * chartH);
    }

    // Grille horizontale + libellés de boîte.
    final gridPaint = Paint()
      ..color = AppColors.slate700.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var box = 1; box <= topBox; box++) {
      final y = yFor(box);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '$box',
          style: const TextStyle(fontSize: 9, color: AppColors.slate500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Escalier : un pas par événement (X = index, régulier et lisible).
    final linePaint = Paint()
      ..color = AppColors.indigo400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final dx = events.length > 1 ? chartW / (events.length - 1) : chartW;
    final path = Path();
    var x = leftPad;
    path.moveTo(x, yFor(events.first.fromBox));

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      x = leftPad + i * dx;
      path.lineTo(x, yFor(e.fromBox)); // palier
      path.lineTo(x, yFor(e.toBox)); // marche
    }
    canvas.drawPath(path, linePaint);

    // Points aux événements, colorés selon la direction.
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final up = e.toBox > e.fromBox;
      final dotPaint = Paint()
        ..color = up ? AppColors.emerald400 : AppColors.red400;
      canvas.drawCircle(
          Offset(leftPad + i * dx, yFor(e.toBox)), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoxHistoryPainter old) =>
      old.events.length != events.length || old.maxBox != maxBox;
}
