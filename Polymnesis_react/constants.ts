import { Card, Theme } from './types';

export const INITIAL_CARDS: Card[] = [
  {
    id: '1',
    theme: Theme.GEOGRAPHIE,
    answer: 'Stromboli',
    triggers: ['Volcan 926m Italie', 'Volcan Jules Verne'],
    createdAt: Date.now()
  },
  {
    id: '2',
    theme: Theme.MODERNE,
    answer: 'Stromae',
    triggers: ['Paul Van Haver', 'Chanteur belge 12 mars 1985', 'Papaoutai'],
    createdAt: Date.now() - 1000
  },
  {
    id: '3',
    theme: Theme.HISTOIRE,
    answer: 'Charles V',
    triggers: ['Roi surnommé "le sage"', '1338 - 1380'],
    createdAt: Date.now() - 2000
  },
  {
    id: '4',
    theme: Theme.HISTOIRE,
    answer: 'George Sand',
    triggers: ['1804 Paris -> 1876 Nohant-Vic', 'Aurore Dupin'],
    createdAt: Date.now() - 3000
  }
];

export const AVAILABLE_THEMES = Object.values(Theme);
