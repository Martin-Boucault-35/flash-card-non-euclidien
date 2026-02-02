export enum Theme {
  CLASSIQUE = 'Classique',
  HISTOIRE = 'Histoire',
  GEOGRAPHIE = 'Géographie',
  MODERNE = 'Moderne',
  ANIMAUX = 'Animaux',
  SCIENCES = 'Sciences',
  SPORT = 'Sport',
  CULTURE_G = 'Culture Générale'
}

export interface Card {
  id: string;
  theme: Theme;
  answer: string;
  triggers: string[];
  createdAt: number;
}

export interface GameConfig {
  themes: Theme[];
  questionCount: number;
}

export enum GameState {
  SETUP = 'SETUP',
  PLAYING = 'PLAYING',
  FINISHED = 'FINISHED'
}
