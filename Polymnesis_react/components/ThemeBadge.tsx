import React from 'react';
import { Theme } from '../types';

interface ThemeBadgeProps {
  theme: Theme;
}

export const ThemeBadge: React.FC<ThemeBadgeProps> = ({ theme }) => {
  const getColor = (t: Theme) => {
    switch (t) {
      case Theme.CLASSIQUE: return 'bg-amber-900/50 text-amber-200 border-amber-700';
      case Theme.HISTOIRE: return 'bg-yellow-900/50 text-yellow-200 border-yellow-700';
      case Theme.GEOGRAPHIE: return 'bg-emerald-900/50 text-emerald-200 border-emerald-700';
      case Theme.MODERNE: return 'bg-cyan-900/50 text-cyan-200 border-cyan-700';
      case Theme.ANIMAUX: return 'bg-orange-900/50 text-orange-200 border-orange-700';
      case Theme.SCIENCES: return 'bg-blue-900/50 text-blue-200 border-blue-700';
      case Theme.SPORT: return 'bg-red-900/50 text-red-200 border-red-700';
      case Theme.CULTURE_G: return 'bg-purple-900/50 text-purple-200 border-purple-700';
      default: return 'bg-slate-800 text-slate-300 border-slate-700';
    }
  };

  return (
    <span className={`px-2 py-0.5 rounded-full text-xs font-medium border ${getColor(theme)}`}>
      {theme}
    </span>
  );
};