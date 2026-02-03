import '../models/card_model.dart';

/// Cartes initiales par défaut
final List<FlashCard> initialCards = [
  FlashCard(
    id: '1',
    theme: FlashCardTheme.geographie,
    answer: 'Stromboli',
    triggers: ['Volcan 926m Italie', 'Volcan Jules Verne'],
    createdAt: DateTime.now().millisecondsSinceEpoch,
  ),
  FlashCard(
    id: '2',
    theme: FlashCardTheme.moderne,
    answer: 'Stromae',
    triggers: ['Paul Van Haver', 'Chanteur belge 12 mars 1985', 'Papaoutai'],
    createdAt: DateTime.now().millisecondsSinceEpoch - 1000,
  ),
  FlashCard(
    id: '3',
    theme: FlashCardTheme.histoire,
    answer: 'Charles V',
    triggers: ['Roi surnommé "le sage"', '1338 - 1380'],
    createdAt: DateTime.now().millisecondsSinceEpoch - 2000,
  ),
  FlashCard(
    id: '4',
    theme: FlashCardTheme.histoire,
    answer: 'George Sand',
    triggers: ['1804 Paris -> 1876 Nohant-Vic', 'Aurore Dupin'],
    createdAt: DateTime.now().millisecondsSinceEpoch - 3000,
  ),
];
