import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_badge.dart';

/// Écran de collection (Pokédex)
class CollectionScreen extends StatefulWidget {
  final Function(FlashCard) onEdit;

  const CollectionScreen({
    super.key,
    required this.onEdit,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _searchTerm = '';
  FlashCardTheme? _filterTheme;
  int? _filterBox;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final filteredCards = provider.filterCards(
      searchTerm: _searchTerm,
      theme: _filterTheme,
      leitnerBox: _filterBox,
    );

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view, color: AppColors.indigo400, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Mon Pokédex',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                onChanged: (value) => setState(() => _searchTerm = value),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.slate500, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  fillColor: AppColors.slate800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate700),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filters row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate700),
                      ),
                      child: DropdownButton<FlashCardTheme?>(
                        value: _filterTheme,
                        isExpanded: true,
                        hint: const Text(
                          'Thème',
                          style: TextStyle(color: AppColors.slate400, fontSize: 14),
                        ),
                        underline: const SizedBox(),
                        dropdownColor: AppColors.slate800,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                        items: [
                          const DropdownMenuItem<FlashCardTheme?>(
                            value: null,
                            child: Text('Tous', style: TextStyle(color: Colors.white)),
                          ),
                          ...FlashCardTheme.values.map((theme) => DropdownMenuItem(
                            value: theme,
                            child: Text(
                              theme.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )),
                        ],
                        onChanged: (value) => setState(() => _filterTheme = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate700),
                      ),
                      child: DropdownButton<int?>(
                        value: _filterBox,
                        isExpanded: true,
                        hint: const Text(
                          'Boîte',
                          style: TextStyle(color: AppColors.slate400, fontSize: 14),
                        ),
                        underline: const SizedBox(),
                        dropdownColor: AppColors.slate800,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Toutes', style: TextStyle(color: Colors.white)),
                          ),
                          ...List.generate(provider.leitnerSettings.boxCount, (i) {
                            final box = i + 1;
                            return DropdownMenuItem(
                              value: box,
                              child: Text(
                                'Boîte $box',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }),
                          DropdownMenuItem(
                            value: provider.leitnerSettings.boxCount + 1,
                            child: const Text(
                              'Maîtrisé',
                              style: TextStyle(color: AppColors.emerald400),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _filterBox = value),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cards list
        Expanded(
          child: filteredCards.isEmpty
              ? _buildEmptyState()
              : _buildCardsList(filteredCards, provider),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.slate800.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.slate700,
            style: BorderStyle.solid,
          ),
        ),
        child: const Text(
          'Aucune carte trouvée.',
          style: TextStyle(color: AppColors.slate400),
        ),
      ),
    );
  }

  Widget _buildCardsList(List<FlashCard> cards, CardProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardItem(
          card: card,
          onEdit: () => widget.onEdit(card),
          onDelete: () => _confirmDelete(context, provider, card.id),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, CardProvider provider, String cardId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate800,
        title: const Text('Supprimer cette carte ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Cette action est irréversible.',
          style: TextStyle(color: AppColors.slate400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCard(cardId);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.red400)),
          ),
        ],
      ),
    );
  }
}

class _CardItem extends StatelessWidget {
  final FlashCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardItem({
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ThemeBadge(theme: card.theme),
                  const SizedBox(width: 8),
                  _LeitnerBoxBadge(box: card.leitnerBox),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppColors.slate600,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.slate600,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            card.answer,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...card.triggers.map((trigger) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(color: AppColors.slate600),
                ),
                Expanded(
                  child: Text(
                    trigger,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _LeitnerBoxBadge extends StatelessWidget {
  final int box;

  const _LeitnerBoxBadge({required this.box});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CardProvider>();
    final maxBox = provider.leitnerSettings.boxCount;
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
