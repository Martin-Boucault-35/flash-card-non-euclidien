import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Écran de création/édition de carte
class CreateScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const CreateScreen({
    super.key,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  FlashCardTheme _selectedTheme = FlashCardTheme.cultureG;
  final _answerController = TextEditingController();
  final List<TextEditingController> _triggerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  String? _error;
  bool _isEditing = false;
  // Réponses acceptées importées (lecture seule, conservées via copyWith).
  List<String> _acceptedAnswers = const [];
  bool _showAccepted = false;

  @override
  void initState() {
    super.initState();
    // Charger les données si on est en mode édition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CardProvider>();
      if (provider.editingCard != null) {
        _loadEditingCard(provider.editingCard!);
      }
    });
  }

  void _loadEditingCard(FlashCard card) {
    setState(() {
      _isEditing = true;
      _selectedTheme = card.theme;
      _answerController.text = card.answer;
      _acceptedAnswers = card.acceptedAnswers;
      _triggerControllers.clear();
      for (var trigger in card.triggers) {
        _triggerControllers.add(TextEditingController(text: trigger));
      }
      if (_triggerControllers.isEmpty) {
        _triggerControllers.add(TextEditingController());
      }
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    for (var controller in _triggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTrigger() {
    setState(() {
      _triggerControllers.add(TextEditingController());
    });
  }

  void _removeTrigger(int index) {
    if (_triggerControllers.length > 1) {
      setState(() {
        _triggerControllers[index].dispose();
        _triggerControllers.removeAt(index);
      });
    }
  }

  Future<void> _handleSubmit() async {
    final answer = _answerController.text.trim();
    final triggers = _triggerControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (answer.isEmpty) {
      setState(() => _error = 'La réponse est requise.');
      return;
    }

    if (triggers.isEmpty) {
      setState(() => _error = 'Il faut au moins un trigger.');
      return;
    }

    setState(() => _error = null);

    final provider = context.read<CardProvider>();

    if (_isEditing && provider.editingCard != null) {
      // Mode édition
      final updatedCard = provider.editingCard!.copyWith(
        theme: _selectedTheme,
        answer: answer,
        triggers: triggers,
      );
      await provider.saveCard(updatedCard);
      provider.resetEditingCard();
    } else {
      // Mode création
      await provider.addCard(
        theme: _selectedTheme,
        answer: answer,
        triggers: triggers,
      );
      // Reset form
      _answerController.clear();
      for (var controller in _triggerControllers) {
        controller.clear();
      }
    }

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final isEditing = provider.editingCard != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.add,
                color: AppColors.indigo400,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Modifier la carte' : 'Nouvelle Carte',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Form container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.slate800.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme selection
                const Text(
                  'Thème',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate300,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FlashCardTheme.values.map((theme) {
                    final isSelected = _selectedTheme == theme;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTheme = theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.indigo600
                              : AppColors.slate800,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.indigo500
                                : AppColors.slate600,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.indigo500.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          theme.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.slate400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Answer input
                const Text(
                  'La Réponse (à deviner)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate300,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'ex: Stromboli',
                  ),
                ),

                const SizedBox(height: 24),

                // Triggers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Triggers (Indices)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate300,
                      ),
                    ),
                    GestureDetector(
                      onTap: _addTrigger,
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.indigo400),
                          SizedBox(width: 4),
                          Text(
                            'Ajouter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.indigo400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...List.generate(_triggerControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.slate700.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _triggerControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Indice ${index + 1}...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        if (_triggerControllers.length > 1)
                          IconButton(
                            onPressed: () => _removeTrigger(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.slate500,
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                // Réponses acceptées (importées) — lecture seule, repliable.
                // N'apparaît que pour les cartes importées de La Table des Savoirs.
                if (_acceptedAnswers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAccepted = !_showAccepted),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          _showAccepted ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_acceptedAnswers.length} réponse(s) acceptée(s) (importées)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showAccepted) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _acceptedAnswers
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.slate800,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: AppColors.slate700),
                                ),
                                child: Text(
                                  a,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate300,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gérées automatiquement à l\'import — non modifiables ici.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.slate500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red900.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.red900.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.red200,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    if (isEditing) ...[
                      Expanded(
                        child: AppButton(
                          onPressed: () {
                            context.read<CardProvider>().resetEditingCard();
                            widget.onCancel();
                          },
                          variant: AppButtonVariant.secondary,
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: AppButton(
                        onPressed: _handleSubmit,
                        fullWidth: true,
                        child: Text(
                          isEditing ? 'Mettre à jour' : 'Enregistrer la carte',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
