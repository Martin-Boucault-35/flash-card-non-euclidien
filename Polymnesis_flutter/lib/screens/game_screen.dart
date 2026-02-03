import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Écran du jeu
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameState _gameState = GameState.setup;
  GameConfig _config = GameConfig();

  // Game play state
  List<FlashCard> _queue = [];
  int _currentIndex = 0;
  int _currentTriggerIndex = 0;
  List<String> _currentCardShuffledTriggers = [];
  final TextEditingController _answerController = TextEditingController();
  int _score = 0;
  _FeedbackState _feedback = _FeedbackState.idle;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_gameState) {
      case GameState.setup:
        return _SetupView(
          config: _config,
          onConfigChanged: (config) => setState(() => _config = config),
          onStart: _handleStart,
        );
      case GameState.playing:
        return _PlayingView(
          queue: _queue,
          currentIndex: _currentIndex,
          currentTriggerIndex: _currentTriggerIndex,
          shuffledTriggers: _currentCardShuffledTriggers,
          answerController: _answerController,
          feedback: _feedback,
          onSubmit: _handleSubmit,
          onSkip: _handleSkip,
        );
      case GameState.finished:
        return _ResultsView(
          score: _score,
          total: _queue.length,
          onRestart: () => setState(() => _gameState = GameState.setup),
        );
    }
  }

  void _handleStart() {
    final provider = context.read<CardProvider>();
    final gameQueue = provider.getCardsForGame(
      _config.themes,
      _config.questionCount,
    );

    if (gameQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pas assez de cartes pour ces critères !'),
          backgroundColor: AppColors.red500,
        ),
      );
      return;
    }

    setState(() {
      _queue = gameQueue;
      _currentIndex = 0;
      _currentTriggerIndex = 0;
      _currentCardShuffledTriggers = List<String>.from(gameQueue.first.triggers)..shuffle();
      _score = 0;
      _feedback = _FeedbackState.idle;
      _answerController.clear();
      _gameState = GameState.playing;
    });
  }

  void _handleSubmit() {
    if (_feedback != _FeedbackState.idle) return;

    final currentCard = _queue[_currentIndex];
    final isCorrect = _normalize(_answerController.text) == _normalize(currentCard.answer);
    final isLastTrigger = _currentTriggerIndex >= currentCard.triggers.length - 1;

    if (isCorrect) {
      setState(() {
        _feedback = _FeedbackState.correct;
        _score++;
      });
      Future.delayed(const Duration(milliseconds: 1500), _nextCard);
    } else {
      setState(() => _feedback = _FeedbackState.wrong);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!isLastTrigger) {
          // Mauvaise réponse mais pas le dernier trigger: on garde le texte
          setState(() {
            _feedback = _FeedbackState.idle;
            _currentTriggerIndex++;
          });
        } else {
          Future.delayed(const Duration(milliseconds: 1000), _nextCard);
        }
      });
    }
  }

  void _handleSkip() {
    setState(() => _feedback = _FeedbackState.wrong);
    Future.delayed(const Duration(milliseconds: 1000), _nextCard);
  }

  void _nextCard() {
    if (_currentIndex < _queue.length - 1) {
      final nextCard = _queue[_currentIndex + 1];
      setState(() {
        _currentIndex++;
        _currentTriggerIndex = 0;
        _currentCardShuffledTriggers = List<String>.from(nextCard.triggers)..shuffle();
        _answerController.clear(); // Effacer seulement quand on passe à la carte suivante
        _feedback = _FeedbackState.idle;
      });
    } else {
      setState(() => _gameState = GameState.finished);
    }
  }

  String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }
}

enum _FeedbackState { idle, correct, wrong }

// Setup View
class _SetupView extends StatelessWidget {
  final GameConfig config;
  final Function(GameConfig) onConfigChanged;
  final VoidCallback onStart;

  const _SetupView({
    required this.config,
    required this.onConfigChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final availableCards = provider.getCardCountForThemes(config.themes);

    // Ajuster automatiquement questionCount si supérieur au nombre de cartes disponibles
    final effectiveQuestionCount = config.questionCount.clamp(1, availableCards.clamp(1, 50));
    if (effectiveQuestionCount != config.questionCount && availableCards > 0) {
      // Déclencher la mise à jour après le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onConfigChanged(config.copyWith(questionCount: effectiveQuestionCount));
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Configuration de la Partie',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisir les thèmes',
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
                  children: [
                    _ThemeChip(
                      label: 'Tout',
                      isSelected: config.themes.isEmpty,
                      onTap: () => onConfigChanged(config.copyWith(themes: [])),
                      isAll: true,
                    ),
                    ...FlashCardTheme.values.map((theme) => _ThemeChip(
                      label: theme.displayName,
                      isSelected: config.themes.contains(theme.displayName),
                      onTap: () {
                        final themes = List<String>.from(config.themes);
                        if (themes.contains(theme.displayName)) {
                          themes.remove(theme.displayName);
                        } else {
                          themes.add(theme.displayName);
                        }
                        onConfigChanged(config.copyWith(themes: themes));
                      },
                    )),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'Nombre de questions: $effectiveQuestionCount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate300,
                  ),
                ),
                const SizedBox(height: 8),

                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.indigo500,
                    inactiveTrackColor: AppColors.slate700,
                    thumbColor: AppColors.indigo500,
                    overlayColor: AppColors.indigo500.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: effectiveQuestionCount.toDouble(),
                    min: 1,
                    max: availableCards.clamp(1, 50).toDouble(),
                    divisions: availableCards >= 2 ? (availableCards.clamp(2, 50) - 1) : null,
                    onChanged: availableCards > 0
                        ? (value) => onConfigChanged(
                              config.copyWith(questionCount: value.toInt()),
                            )
                        : null,
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total disponible: $availableCards',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                AppButton(
                  onPressed: availableCards > 0 ? onStart : null,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Commencer'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAll;

  const _ThemeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAll ? AppColors.slate200 : AppColors.indigo600)
              : AppColors.slate800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isAll ? Colors.white : AppColors.indigo500)
                : AppColors.slate600,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? (isAll ? AppColors.slate900 : Colors.white)
                : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}

// Playing View
class _PlayingView extends StatelessWidget {
  final List<FlashCard> queue;
  final int currentIndex;
  final int currentTriggerIndex;
  final List<String> shuffledTriggers;
  final TextEditingController answerController;
  final _FeedbackState feedback;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  const _PlayingView({
    required this.queue,
    required this.currentIndex,
    required this.currentTriggerIndex,
    required this.shuffledTriggers,
    required this.answerController,
    required this.feedback,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final currentCard = queue[currentIndex];
    final currentTrigger = shuffledTriggers[currentTriggerIndex];
    final isLastTrigger = currentTriggerIndex >= shuffledTriggers.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Carte ${currentIndex + 1} / ${queue.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.slate400,
                ),
              ),
              ThemeBadge(theme: currentCard.theme),
            ],
          ),

          const SizedBox(height: 24),

          // Card area
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top gradient bar
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.indigo500.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'TRIGGER ${currentTriggerIndex + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.indigo400,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  currentTrigger,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Trigger dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    shuffledTriggers.length,
                    (idx) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: idx == currentTriggerIndex
                            ? AppColors.indigo500
                            : idx < currentTriggerIndex
                                ? AppColors.slate600
                                : AppColors.slate700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Feedback area
          SizedBox(
            height: 32,
            child: _buildFeedback(isLastTrigger, currentCard.answer),
          ),

          const SizedBox(height: 16),

          // Input area
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: answerController,
                  onSubmitted: (_) => onSubmit(),
                  enabled: feedback == _FeedbackState.idle,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Votre réponse...',
                    fillColor: AppColors.slate800,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: feedback == _FeedbackState.correct
                            ? AppColors.emerald500
                            : feedback == _FeedbackState.wrong
                                ? AppColors.red500
                                : AppColors.slate700,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.indigo500,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: answerController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Material(
                    color: feedback == _FeedbackState.idle && hasText
                        ? AppColors.indigo600
                        : AppColors.slate700,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: feedback == _FeedbackState.idle && hasText
                          ? onSubmit
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          AppButton(
            onPressed: feedback == _FeedbackState.idle ? onSkip : null,
            variant: AppButtonVariant.ghost,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next, size: 18),
                SizedBox(width: 8),
                Text('Passer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(bool isLastTrigger, String answer) {
    if (feedback == _FeedbackState.correct) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.emerald400),
          SizedBox(width: 8),
          Text(
            'Bonne réponse !',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.emerald400,
            ),
          ),
        ],
      );
    }

    if (feedback == _FeedbackState.wrong) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel, color: AppColors.red400),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isLastTrigger ? "Faux ! C'était: $answer" : 'Faux ! Trigger suivant...',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.red400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// Results View
class _ResultsView extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRestart;

  const _ResultsView({
    required this.score,
    required this.total,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (score / total * 100) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.slate700),
            ),
            child: const Icon(
              Icons.psychology,
              size: 64,
              color: AppColors.indigo400,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Session Terminée !',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Voici votre performance',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.slate400,
            ),
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$score ',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: '/ $total',
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppColors.slate700,
                    valueColor: const AlwaysStoppedAnimation(AppColors.indigo500),
                    minHeight: 8,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  score == total
                      ? 'Parfait ! Mémoire absolue.'
                      : score > total / 2
                          ? 'Bien joué !'
                          : 'Continuez à vous entraîner.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.indigo300,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                onPressed: onRestart,
                variant: AppButtonVariant.secondary,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu, size: 18),
                    SizedBox(width: 8),
                    Text('Menu Jeu'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AppButton(
                onPressed: onRestart,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Rejouer'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
