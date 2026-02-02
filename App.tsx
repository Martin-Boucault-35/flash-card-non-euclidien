import React, { useState, useEffect, useMemo } from 'react';
import { 
  Brain, 
  Plus, 
  LayoutGrid, 
  Play, 
  Trash2, 
  Search, 
  ArrowRight, 
  CheckCircle2, 
  XCircle, 
  RotateCcw, 
  Menu,
  ChevronRight,
  HelpCircle,
  SkipForward,
  Settings,
  RefreshCw,
  Pencil // Added Pencil icon
} from 'lucide-react';
import { Card, Theme, GameConfig, GameState, SyncCredentials } from './types';
import { INITIAL_CARDS, AVAILABLE_THEMES } from './constants';
import { Button } from './components/Button';
import { ThemeBadge } from './components/ThemeBadge';
import { SettingsModal } from './components/SettingsModal';
import { initSupabase, fetchRemoteCards, upsertRemoteCard, deleteRemoteCard } from './services/supabase';

// --- Local Storage Helper ---
const useStickyState = <T,>(defaultValue: T, key: string): [T, React.Dispatch<React.SetStateAction<T>>] => {
  const [value, setValue] = useState<T>(() => {
    const stickyValue = window.localStorage.getItem(key);
    return stickyValue !== null ? JSON.parse(stickyValue) : defaultValue;
  });

  useEffect(() => {
    window.localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue];
};

// --- Sub-Components for Views ---

// 1. Navigation / Layout
const NavBar: React.FC<{ 
  currentView: string; 
  setView: (v: string) => void;
  cardCount: number;
  onOpenSettings: () => void;
  isSyncing: boolean;
  onResetEdit: () => void; // Added to reset edit state when clicking create
}> = ({ currentView, setView, cardCount, onOpenSettings, isSyncing, onResetEdit }) => (
  <nav className="border-b border-slate-800 bg-slate-900/50 backdrop-blur-md sticky top-0 z-50">
    <div className="max-w-4xl mx-auto px-4 h-16 flex items-center justify-between">
      <div 
        onClick={() => { setView('home'); onResetEdit(); }}
        className="flex items-center gap-2 cursor-pointer group"
      >
        <div className="p-2 bg-indigo-600 rounded-lg group-hover:rotate-12 transition-transform">
          <Brain className="w-6 h-6 text-white" />
        </div>
        <span className="font-bold text-xl tracking-tight text-white">PolyMnesis</span>
      </div>
      
      <div className="flex items-center gap-1 md:gap-4">
        <button 
          onClick={() => { setView('create'); onResetEdit(); }}
          className={`p-2 md:px-3 md:py-2 rounded-lg flex items-center gap-2 transition-colors ${currentView === 'create' ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white'}`}
        >
          <Plus className="w-5 h-5" />
          <span className="hidden md:inline text-sm font-medium">Créer</span>
        </button>
        <button 
          onClick={() => { setView('collection'); onResetEdit(); }}
          className={`p-2 md:px-3 md:py-2 rounded-lg flex items-center gap-2 transition-colors ${currentView === 'collection' ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white'}`}
        >
          <LayoutGrid className="w-5 h-5" />
          <span className="hidden md:inline text-sm font-medium">Pokedex ({cardCount})</span>
        </button>
        
        <div className="w-px h-6 bg-slate-800 mx-1"></div>

        <button 
          onClick={onOpenSettings}
          className={`p-2 rounded-lg transition-colors relative ${isSyncing ? 'text-indigo-400 animate-pulse' : 'text-slate-400 hover:text-white hover:bg-slate-800'}`}
          title="Paramètres de synchronisation"
        >
          {isSyncing ? <RefreshCw className="w-5 h-5 animate-spin" /> : <Settings className="w-5 h-5" />}
        </button>

        <button 
          onClick={() => { setView('game'); onResetEdit(); }}
          className={`ml-2 p-2 md:px-3 md:py-2 rounded-lg flex items-center gap-2 transition-colors ${currentView === 'game' ? 'bg-indigo-600/20 text-indigo-300' : 'bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-500/20'}`}
        >
          <Play className="w-5 h-5 fill-current" />
          <span className="hidden md:inline text-sm font-medium">Jouer</span>
        </button>
      </div>
    </div>
  </nav>
);

// 2. Home View
const HomeView: React.FC<{ setView: (v: string) => void }> = ({ setView }) => (
  <div className="flex flex-col items-center justify-center py-20 text-center space-y-8 animate-fade-in">
    <div className="space-y-4 max-w-2xl px-4">
      <h1 className="text-4xl md:text-6xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 to-purple-400">
        Mémoire Non-Euclidienne
      </h1>
      <p className="text-lg text-slate-400">
        Entraînez votre cerveau avec des cartes dynamiques. Une réponse, une infinité de chemins pour y arriver.
      </p>
    </div>

    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full max-w-lg px-4">
      <div 
        onClick={() => setView('create')}
        className="group p-6 bg-slate-800 rounded-2xl border border-slate-700 hover:border-indigo-500 hover:bg-slate-800/80 cursor-pointer transition-all"
      >
        <Plus className="w-10 h-10 text-indigo-400 mb-4 group-hover:scale-110 transition-transform" />
        <h3 className="text-xl font-bold mb-2">Créer des cartes</h3>
        <p className="text-sm text-slate-400">Ajoutez de nouvelles connaissances avec plusieurs triggers.</p>
      </div>

      <div 
        onClick={() => setView('game')}
        className="group p-6 bg-slate-800 rounded-2xl border border-slate-700 hover:border-emerald-500 hover:bg-slate-800/80 cursor-pointer transition-all"
      >
        <Play className="w-10 h-10 text-emerald-400 mb-4 group-hover:scale-110 transition-transform" />
        <h3 className="text-xl font-bold mb-2">Lancer une session</h3>
        <p className="text-sm text-slate-400">Testez votre mémoire avec le mode aléatoire adaptatif.</p>
      </div>
    </div>
  </div>
);

// 3. Create View (Handles both Create and Edit)
const CreateView: React.FC<{ 
  onSaveCard: (c: Card) => void; 
  initialCard?: Card | null; 
  onCancel: () => void;
}> = ({ onSaveCard, initialCard, onCancel }) => {
  const [theme, setTheme] = useState<Theme>(Theme.CULTURE_G);
  const [answer, setAnswer] = useState('');
  const [triggers, setTriggers] = useState<string[]>(['']);
  const [errors, setErrors] = useState<string | null>(null);

  // Load initial data if editing
  useEffect(() => {
    if (initialCard) {
      setTheme(initialCard.theme);
      setAnswer(initialCard.answer);
      setTriggers([...initialCard.triggers]);
    } else {
      // Reset defaults
      setTheme(Theme.CULTURE_G);
      setAnswer('');
      setTriggers(['', '']);
    }
  }, [initialCard]);

  const handleAddTrigger = () => setTriggers([...triggers, '']);
  const handleRemoveTrigger = (idx: number) => setTriggers(triggers.filter((_, i) => i !== idx));
  const handleTriggerChange = (idx: number, val: string) => {
    const newTriggers = [...triggers];
    newTriggers[idx] = val;
    setTriggers(newTriggers);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const validTriggers = triggers.filter(t => t.trim() !== '');
    
    if (!answer.trim()) {
      setErrors("La réponse est requise.");
      return;
    }
    if (validTriggers.length === 0) {
      setErrors("Il faut au moins un trigger.");
      return;
    }

    const newCard: Card = {
      id: initialCard ? initialCard.id : crypto.randomUUID(), // Keep ID if editing
      theme,
      answer: answer.trim(),
      triggers: validTriggers,
      createdAt: initialCard ? initialCard.createdAt : Date.now()
    };

    onSaveCard(newCard);
    
    // Reset form only if creating new (if editing, the parent will likely switch view)
    if (!initialCard) {
      setAnswer('');
      setTriggers(['', '']);
      setErrors(null);
    }
  };

  return (
    <div className="max-w-2xl mx-auto py-10 px-4">
      <h2 className="text-2xl font-bold mb-6 flex items-center gap-3">
        {initialCard ? <Pencil className="text-indigo-400" /> : <Plus className="text-indigo-400" />}
        {initialCard ? 'Modifier la carte' : 'Nouvelle Carte'}
      </h2>

      <form onSubmit={handleSubmit} className="space-y-6 bg-slate-800/50 p-6 rounded-2xl border border-slate-700">
        
        {/* Theme Selection */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-slate-300">Thème</label>
          <div className="flex flex-wrap gap-2">
            {AVAILABLE_THEMES.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTheme(t)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium transition-all border ${
                  theme === t 
                  ? 'bg-indigo-600 border-indigo-500 text-white shadow-lg shadow-indigo-500/20' 
                  : 'bg-slate-800 border-slate-600 text-slate-400 hover:border-slate-500'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        {/* Answer Input */}
        <div className="space-y-2">
          <label className="block text-sm font-medium text-slate-300">La Réponse (à deviner)</label>
          <input
            type="text"
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            placeholder="ex: Stromboli"
            className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
          />
        </div>

        {/* Triggers Input */}
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <label className="block text-sm font-medium text-slate-300">Triggers (Indices)</label>
            <button 
              type="button" 
              onClick={handleAddTrigger}
              className="text-xs text-indigo-400 hover:text-indigo-300 font-medium flex items-center gap-1"
            >
              <Plus className="w-3 h-3" /> Ajouter
            </button>
          </div>
          
          <div className="space-y-3">
            {triggers.map((trigger, idx) => (
              <div key={idx} className="flex gap-2">
                <div className="bg-slate-700/50 px-3 py-3 rounded-lg flex items-center justify-center text-slate-500 text-xs font-mono w-8">
                  {idx + 1}
                </div>
                <input
                  type="text"
                  value={trigger}
                  onChange={(e) => handleTriggerChange(idx, e.target.value)}
                  placeholder={`Indice ${idx + 1}...`}
                  className="flex-1 bg-slate-900 border border-slate-700 rounded-lg px-4 py-2 text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                />
                {triggers.length > 1 && (
                  <button 
                    type="button" 
                    onClick={() => handleRemoveTrigger(idx)}
                    className="p-2 text-slate-500 hover:text-red-400 hover:bg-red-400/10 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>

        {errors && (
          <div className="p-3 bg-red-900/20 border border-red-900/50 rounded-lg text-red-200 text-sm">
            {errors}
          </div>
        )}

        <div className="pt-4 flex gap-3">
          {initialCard && (
             <Button type="button" variant="secondary" onClick={onCancel} className="flex-1">Annuler</Button>
          )}
          <Button type="submit" fullWidth className="flex-1">
            {initialCard ? 'Mettre à jour' : 'Enregistrer la carte'}
          </Button>
        </div>

      </form>
    </div>
  );
};

// 4. Collection View (Pokedex)
const CollectionView: React.FC<{ 
  cards: Card[]; 
  onDelete: (id: string) => void;
  onEdit: (card: Card) => void;
}> = ({ cards, onDelete, onEdit }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [filterTheme, setFilterTheme] = useState<Theme | 'ALL'>('ALL');

  const filteredCards = useMemo(() => {
    return cards.filter(card => {
      const matchesSearch = card.answer.toLowerCase().includes(searchTerm.toLowerCase()) || 
                            card.triggers.some(t => t.toLowerCase().includes(searchTerm.toLowerCase()));
      const matchesTheme = filterTheme === 'ALL' || card.theme === filterTheme;
      return matchesSearch && matchesTheme;
    });
  }, [cards, searchTerm, filterTheme]);

  return (
    <div className="max-w-4xl mx-auto py-10 px-4">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <h2 className="text-2xl font-bold flex items-center gap-3">
          <LayoutGrid className="text-indigo-400" />
          Mon Pokedex
        </h2>
        
        <div className="flex gap-2">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
            <input
              type="text"
              placeholder="Rechercher..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9 pr-4 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:ring-1 focus:ring-indigo-500 outline-none w-full md:w-64"
            />
          </div>
          <select
            value={filterTheme}
            onChange={(e) => setFilterTheme(e.target.value as Theme | 'ALL')}
            className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:ring-1 focus:ring-indigo-500 outline-none cursor-pointer"
          >
            <option value="ALL">Tous les thèmes</option>
            {AVAILABLE_THEMES.map(t => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>
      </div>

      {filteredCards.length === 0 ? (
        <div className="text-center py-20 bg-slate-800/30 rounded-2xl border border-dashed border-slate-700">
          <p className="text-slate-400">Aucune carte trouvée.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredCards.map(card => (
            <div key={card.id} className="bg-slate-800 rounded-xl p-5 border border-slate-700 hover:border-indigo-500/50 transition-colors group relative">
              <div className="flex justify-between items-start mb-3">
                <ThemeBadge theme={card.theme} />
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button 
                    onClick={() => onEdit(card)}
                    className="text-slate-600 hover:text-indigo-400 p-1 transition-colors"
                    title="Modifier"
                  >
                    <Pencil className="w-4 h-4" />
                  </button>
                  <button 
                    onClick={() => onDelete(card.id)}
                    className="text-slate-600 hover:text-red-400 p-1 transition-colors"
                    title="Supprimer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              
              <h3 className="text-lg font-bold text-white mb-4">{card.answer}</h3>
              
              <div className="space-y-2">
                {card.triggers.map((trigger, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-slate-400">
                    <span className="text-slate-600 select-none mt-0.5">•</span>
                    <span>{trigger}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// 5. Game Mode
const GameView: React.FC<{ cards: Card[] }> = ({ cards }) => {
  const [gameState, setGameState] = useState<GameState>(GameState.SETUP);
  const [config, setConfig] = useState<GameConfig>({ themes: [], questionCount: 5 });
  
  // Game Play State
  const [queue, setQueue] = useState<Card[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [currentTriggerIndex, setCurrentTriggerIndex] = useState(0);
  const [userAnswer, setUserAnswer] = useState('');
  const [score, setScore] = useState(0);
  const [feedback, setFeedback] = useState<'IDLE' | 'CORRECT' | 'WRONG'>('IDLE');
  
  // Setup Component
  const Setup = () => {
    const toggleTheme = (t: Theme) => {
      setConfig(prev => {
        const exists = prev.themes.includes(t);
        return {
          ...prev,
          themes: exists ? prev.themes.filter(th => th !== t) : [...prev.themes, t]
        };
      });
    };

    const handleStart = () => {
      // Filter cards by theme (if any selected, otherwise all)
      let pool = config.themes.length > 0 
        ? cards.filter(c => config.themes.includes(c.theme))
        : cards;
      
      // Shuffle
      pool = [...pool].sort(() => Math.random() - 0.5);
      
      // Slice
      const gameQueue = pool.slice(0, config.questionCount);
      
      if (gameQueue.length === 0) {
        alert("Pas assez de cartes pour ces critères !");
        return;
      }

      setQueue(gameQueue);
      setCurrentIndex(0);
      setCurrentTriggerIndex(0);
      setScore(0);
      setFeedback('IDLE');
      setUserAnswer('');
      setGameState(GameState.PLAYING);
    };

    return (
      <div className="max-w-xl mx-auto py-10 px-4">
        <h2 className="text-2xl font-bold mb-6 text-center">Configuration de la Partie</h2>
        
        <div className="bg-slate-800 p-6 rounded-2xl border border-slate-700 space-y-6">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-3">Choisir les thèmes</label>
            <div className="flex flex-wrap gap-2">
              <button
                 onClick={() => setConfig(prev => ({...prev, themes: []}))}
                 className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                    config.themes.length === 0
                    ? 'bg-slate-200 text-slate-900 border-white'
                    : 'bg-slate-800 border-slate-600 text-slate-400'
                 }`}
              >
                Tout
              </button>
              {AVAILABLE_THEMES.map(t => (
                <button
                  key={t}
                  onClick={() => toggleTheme(t)}
                  className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                    config.themes.includes(t)
                    ? 'bg-indigo-600 border-indigo-500 text-white'
                    : 'bg-slate-800 border-slate-600 text-slate-400 hover:border-slate-500'
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Nombre de questions: <span className="text-indigo-400 font-bold">{config.questionCount}</span>
            </label>
            <input
              type="range"
              min="1"
              max={Math.max(cards.length, 1)}
              value={config.questionCount}
              onChange={(e) => setConfig({...config, questionCount: parseInt(e.target.value)})}
              className="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-indigo-500"
            />
            <p className="text-xs text-slate-500 mt-1 text-right">Total disponible: {cards.length}</p>
          </div>

          <Button onClick={handleStart} fullWidth size="lg">
            <Play className="w-5 h-5" /> Commencer
          </Button>
        </div>
      </div>
    );
  };

  // Playing Component
  const Playing = () => {
    const currentCard = queue[currentIndex];
    
    // Safety check
    if (!currentCard) return <div>Erreur de chargement...</div>;

    const currentTrigger = currentCard.triggers[currentTriggerIndex] || "Erreur de trigger";
    const isLastTrigger = currentTriggerIndex >= currentCard.triggers.length - 1;

    const normalize = (s: string) => s.trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");

    const handleSubmit = (e: React.FormEvent) => {
      e.preventDefault();
      if (feedback !== 'IDLE') return; // Prevent double submit

      const isCorrect = normalize(userAnswer) === normalize(currentCard.answer);

      if (isCorrect) {
        setFeedback('CORRECT');
        setScore(s => s + 1);
        setTimeout(() => nextCard(), 1500);
      } else {
        setFeedback('WRONG');
        setTimeout(() => {
            if (!isLastTrigger) {
                // Show next trigger
                setFeedback('IDLE');
                setCurrentTriggerIndex(prev => prev + 1);
                setUserAnswer('');
            } else {
                // Really wrong, move to next card
                // Don't clear feedback immediately so user sees 'WRONG'
                setTimeout(() => nextCard(), 1000); 
            }
        }, 1500);
      }
    };

    const handleSkip = () => {
        setFeedback('WRONG'); // Visual indicator that it was counted as wrong/skipped
        setTimeout(() => nextCard(), 1000);
    }

    const nextCard = () => {
      if (currentIndex < queue.length - 1) {
        setCurrentIndex(prev => prev + 1);
        setCurrentTriggerIndex(0);
        setUserAnswer('');
        setFeedback('IDLE');
      } else {
        setGameState(GameState.FINISHED);
      }
    };

    return (
      <div className="max-w-2xl mx-auto py-10 px-4 flex flex-col items-center">
        {/* Header Progress */}
        <div className="w-full flex justify-between items-center mb-8 text-sm text-slate-400">
          <span>Carte {currentIndex + 1} / {queue.length}</span>
          <ThemeBadge theme={currentCard.theme} />
        </div>

        {/* Card Area */}
        <div className="w-full perspective-1000 mb-8">
          <div className="relative w-full aspect-[16/9] md:aspect-[21/9] bg-slate-800 rounded-2xl border border-slate-700 shadow-2xl flex flex-col items-center justify-center p-8 text-center overflow-hidden">
            
            {/* Background decoration */}
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-indigo-500 to-transparent opacity-50"></div>
            
            <p className="text-sm font-medium text-indigo-400 mb-2 uppercase tracking-widest">
              Trigger {currentTriggerIndex + 1}
            </p>
            
            <h3 className="text-2xl md:text-3xl font-bold text-white animate-fade-in-up">
              {currentTrigger}
            </h3>

            {/* Hint dots indicating remaining triggers */}
            <div className="absolute bottom-4 flex gap-1">
              {currentCard.triggers.map((_, idx) => (
                <div 
                  key={idx} 
                  className={`w-2 h-2 rounded-full transition-colors ${
                    idx === currentTriggerIndex 
                      ? 'bg-indigo-500' 
                      : idx < currentTriggerIndex 
                        ? 'bg-slate-600' // Past
                        : 'bg-slate-700' // Future
                  }`}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Feedback Overlay or Animation Area */}
        <div className="h-8 mb-4">
          {feedback === 'CORRECT' && (
            <div className="text-emerald-400 font-bold flex items-center gap-2 animate-bounce">
              <CheckCircle2 /> Bonne réponse !
            </div>
          )}
          {feedback === 'WRONG' && (
            <div className="text-red-400 font-bold flex items-center gap-2 animate-shake">
              <XCircle /> {isLastTrigger ? `Faux ! C'était: ${currentCard.answer}` : "Faux ! Trigger suivant..."}
            </div>
          )}
        </div>

        {/* Input Area */}
        <form onSubmit={handleSubmit} className="w-full flex gap-2">
            <div className="relative flex-1">
                <input
                    type="text"
                    value={userAnswer}
                    onChange={(e) => setUserAnswer(e.target.value)}
                    disabled={feedback !== 'IDLE'}
                    autoFocus
                    placeholder="Votre réponse..."
                    className={`w-full bg-slate-800 border-2 rounded-xl px-5 py-4 text-lg text-white outline-none transition-all ${
                    feedback === 'CORRECT' ? 'border-emerald-500' : 
                    feedback === 'WRONG' ? 'border-red-500' : 
                    'border-slate-700 focus:border-indigo-500'
                    }`}
                />
            </div>
            <button
                type="submit"
                disabled={feedback !== 'IDLE' || !userAnswer.trim()}
                className="bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:bg-slate-700 text-white px-6 rounded-xl font-bold transition-colors"
            >
                <ArrowRight />
            </button>
        </form>
        
        <div className="mt-4">
             <Button variant="ghost" onClick={handleSkip} disabled={feedback !== 'IDLE'}>
                 <SkipForward className="w-4 h-4 mr-2" /> Passer
             </Button>
        </div>
      </div>
    );
  };

  // Results Component
  const Results = () => (
    <div className="max-w-lg mx-auto py-20 px-4 text-center animate-fade-in">
      <div className="inline-flex items-center justify-center p-6 bg-slate-800 rounded-full mb-8 border border-slate-700">
        <Brain className="w-16 h-16 text-indigo-400" />
      </div>
      
      <h2 className="text-4xl font-bold mb-2">Session Terminée !</h2>
      <p className="text-slate-400 mb-8">Voici votre performance</p>

      <div className="bg-slate-800 rounded-2xl p-8 mb-8 border border-slate-700">
        <div className="text-6xl font-black text-white mb-2">{score} <span className="text-2xl text-slate-500">/ {queue.length}</span></div>
        <div className="w-full bg-slate-700 h-2 rounded-full overflow-hidden">
          <div 
            className="bg-indigo-500 h-full transition-all duration-1000" 
            style={{ width: `${(score / queue.length) * 100}%` }}
          />
        </div>
        <p className="mt-4 text-indigo-300 font-medium">
            {score === queue.length ? "Parfait ! Mémoire absolue." : 
             score > queue.length / 2 ? "Bien joué !" : "Continuez à vous entraîner."}
        </p>
      </div>

      <div className="flex gap-4 justify-center">
        <Button onClick={() => setGameState(GameState.SETUP)} variant="secondary">
          <Menu className="w-4 h-4" /> Menu Jeu
        </Button>
        <Button onClick={() => {
            // Quick restart same config
            setGameState(GameState.SETUP);
            // In a real app we'd auto-trigger start, but for now going back to setup is fine
        }}>
          <RotateCcw className="w-4 h-4" /> Rejouer
        </Button>
      </div>
    </div>
  );

  return (
    <div>
      {gameState === GameState.SETUP && <Setup />}
      {gameState === GameState.PLAYING && <Playing />}
      {gameState === GameState.FINISHED && <Results />}
    </div>
  );
};

// --- Main App Component ---

const App: React.FC = () => {
  const [currentView, setCurrentView] = useState('home');
  const [cards, setCards] = useStickyState<Card[]>(INITIAL_CARDS, 'polymnesis-cards');
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);
  
  // Edit State
  const [editingCard, setEditingCard] = useState<Card | null>(null);
  
  // Settings / Sync State
  const [syncCreds, setSyncCreds] = useStickyState<SyncCredentials>({
    url: '',
    key: '',
    enabled: false
  }, 'polymnesis-sync-creds');

  // Initialize Supabase on load or config change
  useEffect(() => {
    const isConfigured = initSupabase(syncCreds);
    if (isConfigured && syncCreds.enabled) {
      performSync();
    }
  }, [syncCreds]);

  const performSync = async () => {
    setIsSyncing(true);
    const remoteCards = await fetchRemoteCards();
    if (remoteCards) {
      // Simple strategy: Merge remote into local, prefer remote if duplicates for now
      // Real app would do smarter conflict resolution
      setCards(prev => {
        const remoteIds = new Set(remoteCards.map(c => c.id));
        const localOnly = prev.filter(c => !remoteIds.has(c.id));
        return [...remoteCards, ...localOnly];
      });
    }
    setIsSyncing(false);
  };

  const handleSaveCard = async (savedCard: Card) => {
    // Check if updating or adding
    setCards(prev => {
        const exists = prev.find(c => c.id === savedCard.id);
        if (exists) {
            return prev.map(c => c.id === savedCard.id ? savedCard : c);
        }
        return [savedCard, ...prev];
    });

    if (syncCreds.enabled) {
      setIsSyncing(true);
      await upsertRemoteCard(savedCard); // upsert handles both insert and update based on ID
      setIsSyncing(false);
    }
    
    // If we were editing, return to collection
    if (editingCard) {
        setEditingCard(null);
        setCurrentView('collection');
    }
  };

  const handleDeleteCard = async (id: string) => {
    if(confirm("Supprimer cette carte ?")) {
        setCards(prev => prev.filter(c => c.id !== id));
        if (syncCreds.enabled) {
          setIsSyncing(true);
          await deleteRemoteCard(id);
          setIsSyncing(false);
        }
    }
  };

  const handleEditCard = (card: Card) => {
      setEditingCard(card);
      setCurrentView('create');
  };

  const handleCancelEdit = () => {
      setEditingCard(null);
      setCurrentView('collection');
  };

  const handleSaveSettings = (newCreds: SyncCredentials) => {
    setSyncCreds(newCreds);
    setIsSettingsOpen(false);
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-200 font-sans selection:bg-indigo-500/30 selection:text-indigo-200">
      <NavBar 
        currentView={currentView} 
        setView={setCurrentView} 
        cardCount={cards.length}
        onOpenSettings={() => setIsSettingsOpen(true)}
        isSyncing={isSyncing}
        onResetEdit={() => setEditingCard(null)}
      />
      
      <SettingsModal 
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        credentials={syncCreds}
        onSave={handleSaveSettings}
      />

      <main className="container mx-auto pb-20">
        {currentView === 'home' && <HomeView setView={setCurrentView} />}
        {currentView === 'create' && (
            <CreateView 
                onSaveCard={handleSaveCard} 
                initialCard={editingCard}
                onCancel={handleCancelEdit}
            />
        )}
        {currentView === 'collection' && (
            <CollectionView 
                cards={cards} 
                onDelete={handleDeleteCard} 
                onEdit={handleEditCard}
            />
        )}
        {currentView === 'game' && <GameView cards={cards} />}
      </main>
    </div>
  );
};

export default App;