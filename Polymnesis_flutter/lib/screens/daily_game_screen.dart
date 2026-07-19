import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/card_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Écran du jeu quotidien Leitner
class DailyGameScreen extends StatefulWidget {
  const DailyGameScreen({super.key});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  _DailyState _state = _DailyState.ready;

  List<FlashCard> _queue = [];
  int _currentIndex = 0;
  int _currentTriggerIndex = 0;
  List<String> _currentCardShuffledTriggers = [];
  final TextEditingController _answerController = TextEditingController();
  int _score = 0;
  int _totalAnswered = 0;
  _FeedbackState _feedback = _FeedbackState.idle;

  // Timer pour mesurer le temps de réponse
  DateTime? _cardStartTime;

  // Ensemble des ID de cartes déjà validées (pour ne compter le score qu'une fois)
  final Set<String> _correctIds = {};

  // Cartes ratées au moins une fois pendant la session courante.
  final Set<String> _failedTodayIds = {};

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _DailyState.ready:
        return _ReadyView(onStart: _handleStart);
      case _DailyState.empty:
        return const _EmptyView();
      case _DailyState.playing:
        return _PlayingView(
          queue: _queue,
          currentIndex: _currentIndex,
          currentTriggerIndex: _currentTriggerIndex,
          shuffledTriggers: _currentCardShuffledTriggers,
          answerController: _answerController,
          feedback: _feedback,
          cardStartTime: _cardStartTime!,
          goldenSeconds:
              context.read<CardProvider>().leitnerSettings.goldenSeconds,
          onSubmit: _handleSubmit,
          onNextTrigger: _handleNextTrigger,
          onSkip: _handleSkip,
        );
      case _DailyState.finished:
        return _ResultsView(
          score: _score,
          total: _totalAnswered,
          onRestart: () => setState(() => _state = _DailyState.ready),
        );
    }
  }

  void _handleStart() {
    final provider = context.read<CardProvider>();
    final dailyCards = provider.getDailyCards();

    if (dailyCards.isEmpty) {
      setState(() => _state = _DailyState.empty);
      return;
    }

    setState(() {
      _queue = dailyCards;
      _currentIndex = 0;
      _currentTriggerIndex = 0;
      _currentCardShuffledTriggers = List<String>.from(dailyCards.first.triggers)..shuffle();
      _score = 0;
      _totalAnswered = dailyCards.length;
      _correctIds.clear();
      _failedTodayIds.clear();
      _feedback = _FeedbackState.idle;
      _answerController.clear();
      _cardStartTime = DateTime.now();
      _state = _DailyState.playing;
    });
  }

  void _handleSubmit() {
    if (_feedback != _FeedbackState.idle) return;

    final currentCard = _queue[_currentIndex];
    final isCorrect = currentCard.matchesAnswer(_answerController.text);
    final isLastTrigger = _currentTriggerIndex >= currentCard.triggers.length - 1;

    if (isCorrect) {
      // Mesurer le temps de réponse
      final elapsed = DateTime.now().difference(_cardStartTime!);
      final provider = context.read<CardProvider>();
      final wasFailedToday = _failedTodayIds.contains(currentCard.id);
      final goldenMs = provider.leitnerSettings.goldenSeconds * 1000;
      final wantsEasyStep =
          elapsed.inMilliseconds < goldenMs && !wasFailedToday;
      final wouldJumpToMastered = wantsEasyStep && currentCard.leitnerBox + 2 > provider.leitnerSettings.boxCount;
      final useEasyStep = wantsEasyStep && !wouldJumpToMastered;

      setState(() {
        _feedback = wouldJumpToMastered
            ? _FeedbackState.correctSoftLanding
            : useEasyStep
                ? _FeedbackState.correctEasy
                : _FeedbackState.correctHard;
        if (!_correctIds.contains(currentCard.id)) {
          _score++;
          _correctIds.add(currentCard.id);
        }
      });
      // Bonne réponse -> monte de +2 (facile) ou +1 (dur). On évite le saut direct vers maîtrisé.
      provider.leitnerCorrect(currentCard, easy: useEasyStep);
      Future.delayed(const Duration(milliseconds: 1500), _nextCard);
    } else {
      final provider = context.read<CardProvider>();
      setState(() => _feedback = _FeedbackState.wrong);
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!isLastTrigger) {
          // Mauvaise réponse mais encore des triggers -> trigger suivant
          setState(() {
            _feedback = _FeedbackState.idle;
            _currentTriggerIndex++;
          });
        } else {
          // Mauvaise réponse au dernier trigger -> recule d'une boîte
          _failedTodayIds.add(currentCard.id);
          provider.leitnerIncorrect(currentCard);
          // Réinsérer la carte à la fin de la queue
          _reinsertCard(currentCard);
          _nextCard();
        }
      });
    }
  }

  /// Réinsère une carte ratée à la fin de la queue
  void _reinsertCard(FlashCard card) {
    _queue.add(card);
  }

  void _handleNextTrigger() {
    final isLastTrigger = _currentTriggerIndex >= _currentCardShuffledTriggers.length - 1;
    if (!isLastTrigger) {
      setState(() {
        _currentTriggerIndex++;
        _answerController.clear();
      });
    }
  }

  void _handleSkip() {
    final currentCard = _queue[_currentIndex];
    final provider = context.read<CardProvider>();
    setState(() => _feedback = _FeedbackState.skipped);
    _failedTodayIds.add(currentCard.id);
    provider.leitnerIncorrect(currentCard);
    _reinsertCard(currentCard);
    Future.delayed(const Duration(milliseconds: 3000), _nextCard);
  }

  void _nextCard() {
    if (_currentIndex < _queue.length - 1) {
      final nextCard = _queue[_currentIndex + 1];
      setState(() {
        _currentIndex++;
        _currentTriggerIndex = 0;
        _currentCardShuffledTriggers = List<String>.from(nextCard.triggers)..shuffle();
        _answerController.clear();
        _feedback = _FeedbackState.idle;
        _cardStartTime = DateTime.now();
      });
    } else {
      context.read<CardProvider>().markDailyCompleted();
      setState(() => _state = _DailyState.finished);
    }
  }

}

enum _DailyState { ready, empty, playing, finished }
enum _FeedbackState { idle, correctEasy, correctHard, correctSoftLanding, wrong, skipped }

// Ready View - shows daily card count and start button
class _ReadyView extends StatelessWidget {
  final VoidCallback onStart;

  const _ReadyView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final dailyCount = provider.dailyCardCount;
    final settings = provider.leitnerSettings;

    // Count cards per box
    final boxCounts = <int, int>{};
    for (final card in provider.cards) {
      final box = card.leitnerBox.clamp(1, settings.boxCount + 1);
      boxCounts[box] = (boxCounts[box] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.calendar_today, size: 48, color: AppColors.amber200),
          const SizedBox(height: 16),
          const Text(
            'Jeu Quotidien',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Révision espacée — Système Leitner',
            style: TextStyle(fontSize: 14, color: AppColors.slate400),
          ),
          const SizedBox(height: 24),

          // Daily count card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Column(
              children: [
                Text(
                  '$dailyCount',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: dailyCount > 0 ? AppColors.amber200 : AppColors.emerald400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dailyCount > 0
                      ? 'carte${dailyCount > 1 ? 's' : ''} à réviser aujourd\'hui'
                      : 'Tout est à jour !',
                  style: const TextStyle(fontSize: 16, color: AppColors.slate300),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Box overview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répartition des boîtes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate300,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(settings.boxCount, (i) {
                  final box = i + 1;
                  final count = boxCounts[box] ?? 0;
                  final total = provider.cardCount;
                  final ratio = total > 0 ? count / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Boîte $box',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: AppColors.slate700,
                              color: _boxColor(box),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if ((boxCounts[settings.boxCount + 1] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 60,
                          child: Text(
                            '✓ Maîtrisé',
                            style: TextStyle(fontSize: 11, color: AppColors.emerald400),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: provider.cardCount > 0
                                  ? (boxCounts[settings.boxCount + 1]! / provider.cardCount)
                                  : 0,
                              backgroundColor: AppColors.slate700,
                              color: AppColors.emerald400,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${boxCounts[settings.boxCount + 1]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          AppButton(
            onPressed: dailyCount > 0 ? onStart : null,
            fullWidth: true,
            size: AppButtonSize.lg,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow),
                const SizedBox(width: 8),
                Text(dailyCount > 0 ? 'Commencer la révision' : 'Rien à réviser'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _boxColor(int box) {
    const colors = [
      AppColors.red400,
      AppColors.amber200,
      AppColors.yellow200,
      AppColors.emerald400,
      AppColors.cyan200,
      AppColors.blue200,
      AppColors.indigo400,
    ];
    return colors[(box - 1) % colors.length];
  }
}

// Empty View
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: AppColors.emerald400),
            const SizedBox(height: 24),
            const Text(
              'Félicitations !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aucune carte à réviser aujourd\'hui.\nRevenez demain !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}

// Playing View — StatefulWidget pour le chrono live
class _PlayingView extends StatefulWidget {
  final List<FlashCard> queue;
  final int currentIndex;
  final int currentTriggerIndex;
  final List<String> shuffledTriggers;
  final TextEditingController answerController;
  final _FeedbackState feedback;
  final DateTime cardStartTime;
  final int goldenSeconds;
  final VoidCallback onSubmit;
  final VoidCallback onNextTrigger;
  final VoidCallback onSkip;

  const _PlayingView({
    required this.queue,
    required this.currentIndex,
    required this.currentTriggerIndex,
    required this.shuffledTriggers,
    required this.answerController,
    required this.feedback,
    required this.cardStartTime,
    required this.goldenSeconds,
    required this.onSubmit,
    required this.onNextTrigger,
    required this.onSkip,
  });

  @override
  State<_PlayingView> createState() => _PlayingViewState();
}

class _PlayingViewState extends State<_PlayingView> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PlayingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset timer when card changes
    if (oldWidget.cardStartTime != widget.cardStartTime) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = DateTime.now().difference(widget.cardStartTime).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.feedback == _FeedbackState.idle) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(widget.cardStartTime).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.queue[widget.currentIndex];
    final currentTrigger = widget.shuffledTriggers[widget.currentTriggerIndex];
    final isLastTrigger = widget.currentTriggerIndex >= widget.shuffledTriggers.length - 1;
    final isUnderThreshold = _elapsedSeconds < widget.goldenSeconds;

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
                'Carte ${widget.currentIndex + 1} / ${widget.queue.length}',
                style: const TextStyle(fontSize: 14, color: AppColors.slate400),
              ),
              Row(
                children: [
                  // Chrono
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUnderThreshold
                          ? AppColors.emerald900.withValues(alpha: 0.5)
                          : AppColors.slate800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUnderThreshold ? AppColors.emerald700 : AppColors.slate700,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUnderThreshold ? Icons.bolt : Icons.timer_outlined,
                          size: 12,
                          color: isUnderThreshold ? AppColors.amber200 : AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_elapsedSeconds}s',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isUnderThreshold ? AppColors.amber200 : AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Boîte ${currentCard.leitnerBox}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ThemeBadge(theme: currentCard.theme),
                ],
              ),
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
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.amber200.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'TRIGGER ${widget.currentTriggerIndex + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.amber200,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.shuffledTriggers.length,
                    (idx) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: idx == widget.currentTriggerIndex
                            ? AppColors.amber200
                            : idx < widget.currentTriggerIndex
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

          // Feedback area (hauteur mini pour éviter les sauts, mais peut grandir
          // pour afficher une réponse longue en entier)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: _buildFeedback(isLastTrigger, currentCard.answer),
          ),

          const SizedBox(height: 16),

          // Input area
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.answerController,
                  onSubmitted: (_) => widget.onSubmit(),
                  enabled: widget.feedback == _FeedbackState.idle,
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
                        color: widget.feedback == _FeedbackState.correctEasy || widget.feedback == _FeedbackState.correctHard
                            ? AppColors.emerald500
                            : widget.feedback == _FeedbackState.wrong || widget.feedback == _FeedbackState.skipped
                                ? AppColors.red500
                                : AppColors.slate700,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.amber200,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.answerController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Material(
                    color: widget.feedback == _FeedbackState.idle && hasText
                        ? AppColors.indigo600
                        : AppColors.slate700,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: widget.feedback == _FeedbackState.idle && hasText
                          ? widget.onSubmit
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

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isLastTrigger)
                AppButton(
                  onPressed: widget.feedback == _FeedbackState.idle ? widget.onNextTrigger : null,
                  variant: AppButtonVariant.ghost,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigate_next, size: 18),
                      SizedBox(width: 4),
                      Text('Trigger suivant'),
                    ],
                  ),
                ),
              if (!isLastTrigger) const SizedBox(width: 12),
              AppButton(
                onPressed: widget.feedback == _FeedbackState.idle ? widget.onSkip : null,
                variant: AppButtonVariant.ghost,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_next, size: 18),
                    SizedBox(width: 4),
                    Text('Passer'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(bool isLastTrigger, String answer) {
    if (widget.feedback == _FeedbackState.correctEasy) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt, color: AppColors.amber200),
          SizedBox(width: 8),
          Text(
            'Rapide ! ↑↑ +2 boîtes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.amber200,
            ),
          ),
        ],
      );
    }

    if (widget.feedback == _FeedbackState.correctHard) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.emerald400),
          SizedBox(width: 8),
          Text(
            'Bonne réponse ! ↑ +1 boîte',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.emerald400,
            ),
          ),
        ],
      );
    }

    if (widget.feedback == _FeedbackState.correctSoftLanding) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_circle, color: AppColors.cyan200),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Bien vu ! +1 boîte pour éviter le saut direct',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.cyan200,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (widget.feedback == _FeedbackState.skipped) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.skip_next, color: AppColors.red400),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '↓ -1 boîte — Réponse : $answer',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.red400,
              ),
            ),
          ),
        ],
      );
    }

    if (widget.feedback == _FeedbackState.wrong) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel, color: AppColors.red400),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isLastTrigger ? "Faux ! ↓ -1 boîte ($answer)" : 'Faux ! Trigger suivant...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.red400,
              ),
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
            child: const Icon(Icons.calendar_today, size: 64, color: AppColors.amber200),
          ),

          const SizedBox(height: 32),

          const Text(
            'Révision Terminée !',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Voici votre performance du jour',
            style: TextStyle(fontSize: 16, color: AppColors.slate400),
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
                    value: total > 0 ? score / total : 0,
                    backgroundColor: AppColors.slate700,
                    color: percentage >= 70 ? AppColors.emerald400 : AppColors.amber200,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${percentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: percentage >= 70 ? AppColors.emerald400 : AppColors.amber200,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  score == total
                      ? 'Parfait ! Toutes vos cartes progressent.'
                      : '$score carte${score > 1 ? 's' : ''} progressent, ${total - score} reculent d\'une boîte.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.slate400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          AppButton(
            onPressed: onRestart,
            fullWidth: true,
            size: AppButtonSize.lg,
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
