import React, { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { X, Sparkles, Sliders, Play, Layers, Zap, FolderGit2 } from 'lucide-react';
import { Deck, CardType } from '../types';
import { useDecks } from '../store';

interface CustomStudyModalProps {
  isOpen: boolean;
  onClose: () => void;
  decks: Deck[];
  initialDeckId?: string;
}

export function CustomStudyModal({
  isOpen,
  onClose,
  decks,
  initialDeckId = 'all',
}: CustomStudyModalProps) {
  const navigate = useNavigate();
  const { folders } = useDecks();

  const [selectedDeckId, setSelectedDeckId] = useState<string>(initialDeckId);
  const [filterMode, setFilterMode] = useState<'all' | 'due' | 'types' | 'hardest' | 'newest'>('all');
  const [selectedTypes, setSelectedTypes] = useState<CardType[]>([
    'Concept', 'Complexity', 'Pattern', 'Cloze', 'Comparison', 'Trace', 'Invariant', 'Debugging', 'Implementation'
  ]);
  const [cardLimit, setCardLimit] = useState<number | 'all'>(30);
  const [inputVal, setInputVal] = useState<string>('30');
  const [shuffle, setShuffle] = useState<boolean>(true);
  const [updateSrs, setUpdateSrs] = useState<boolean>(true);

  useEffect(() => {
    if (initialDeckId) {
      setSelectedDeckId(initialDeckId);
    }
  }, [initialDeckId]);

  const allCardTypes: { type: CardType; label: string; icon: string }[] = [
    { type: 'Concept', label: 'Concept ("Why")', icon: '💡' },
    { type: 'Complexity', label: 'Complexity (Big-O)', icon: '⚡' },
    { type: 'Pattern', label: 'Pattern Trigger', icon: '🎯' },
    { type: 'Cloze', label: 'Cloze Deletion', icon: '🧩' },
    { type: 'Comparison', label: 'Comparison', icon: '⚖️' },
    { type: 'Trace', label: 'Trace / Visual', icon: '🔍' },
    { type: 'Invariant', label: 'Invariant / Proof', icon: '🛡️' },
    { type: 'Debugging', label: 'Dart Debugging', icon: '🐛' },
    { type: 'Implementation', label: 'Dart Implementation', icon: '💻' },
  ];

  // Calculate matching cards count
  const matchingCardsCount = useMemo(() => {
    let pool = [];
    if (selectedDeckId === 'all') {
      pool = decks.flatMap(d => d.cards.map(c => ({ ...c, deckId: d.id })));
    } else if (selectedDeckId.startsWith('folder-')) {
      const targetFolderId = selectedDeckId.replace('folder-', '');
      pool = decks.filter(d => d.folderId === targetFolderId).flatMap(d => d.cards.map(c => ({ ...c, deckId: d.id })));
    } else {
      const target = decks.find(d => d.id === selectedDeckId);
      pool = target ? target.cards.map(c => ({ ...c, deckId: target.id })) : [];
    }

    if (filterMode === 'due') {
      pool = pool.filter(c => c.nextReview <= Date.now());
    } else if (filterMode === 'types') {
      pool = pool.filter(c => selectedTypes.includes(c.type));
    }

    if (cardLimit !== 'all') {
      const numericLimit = typeof cardLimit === 'number' ? cardLimit : 30;
      const clamped = Math.min(500, Math.max(10, numericLimit));
      return Math.min(pool.length, clamped);
    }
    return pool.length;
  }, [decks, selectedDeckId, filterMode, selectedTypes, cardLimit]);

  if (!isOpen) return null;

  const toggleType = (type: CardType) => {
    if (selectedTypes.includes(type)) {
      if (selectedTypes.length > 1) {
        setSelectedTypes(selectedTypes.filter(t => t !== type));
      }
    } else {
      setSelectedTypes([...selectedTypes, type]);
    }
  };

  const handleSelectAllTypes = () => {
    setSelectedTypes(allCardTypes.map(t => t.type));
  };

  const handleStartSession = () => {
    const params = new URLSearchParams();
    params.set('mode', 'custom');
    params.set('filter', filterMode);
    if (filterMode === 'types') {
      params.set('types', selectedTypes.join(','));
    }
    if (cardLimit !== 'all') {
      const num = typeof cardLimit === 'number' ? cardLimit : parseInt(inputVal, 10) || 30;
      const clamped = Math.min(500, Math.max(10, num));
      params.set('limit', clamped.toString());
    }
    params.set('shuffle', shuffle.toString());
    params.set('updateSrs', updateSrs.toString());

    onClose();
    if (selectedDeckId === 'all') {
      navigate(`/deck/all?${params.toString()}`);
    } else {
      navigate(`/deck/${selectedDeckId}?${params.toString()}`);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-white border border-slate-200 rounded-3xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-[0_20px_60px_-15px_rgba(0,0,0,0.3)] overflow-hidden relative">
        {/* Glow accent */}
        <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-blue-600 via-indigo-600 to-cyan-500"></div>

        {/* Modal Header */}
        <div className="px-6 py-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200 shadow-2xs">
              <Sliders className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-slate-900 uppercase italic tracking-wide">
                Custom Dart Study Session
              </h2>
              <p className="text-xs text-slate-500 font-sans">Configure custom deck review parameters</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-700 transition-colors p-1.5 rounded-lg hover:bg-slate-100"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 space-y-6 overflow-y-auto custom-scrollbar">
          {/* Deck Selection */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center gap-1.5">
              <Layers className="w-3.5 h-3.5 text-blue-600" /> Target Deck or Folder
            </label>
            <select
              value={selectedDeckId}
              onChange={(e) => setSelectedDeckId(e.target.value)}
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-sans text-xs focus:bg-white focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-all cursor-pointer"
            >
              <option value="all">⚡ All Decks Combined ({decks.reduce((acc, d) => acc + d.cards.length, 0)} Total Cards)</option>
              
              {folders && folders.length > 0 && (
                <optgroup label="📁 Folders">
                  {folders.map(f => {
                    const folderDecks = decks.filter(d => d.folderId === f.id);
                    const folderCards = folderDecks.reduce((acc, d) => acc + d.cards.length, 0);
                    return (
                      <option key={f.id} value={`folder-${f.id}`}>
                        📁 Folder: {f.name} ({folderDecks.length} decks, {folderCards} cards)
                      </option>
                    );
                  })}
                </optgroup>
              )}

              <optgroup label="📖 Individual Decks">
                {decks.map(d => (
                  <option key={d.id} value={d.id}>
                    {d.title} ({d.cards.length} cards, {d.cards.filter(c => c.nextReview <= Date.now()).length} due)
                  </option>
                ))}
              </optgroup>
            </select>
          </div>

          {/* Review Mode / Strategy */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-blue-600" /> Study Scope & Filter
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
              {[
                { id: 'all', label: 'Review All Cards', desc: 'Study entire deck regardless of due date' },
                { id: 'due', label: 'Due Cards Only', desc: 'Standard spaced repetition queue' },
                { id: 'types', label: 'Filter By Archetype', desc: 'Focus on Dart Code, Big-O, etc.' },
                { id: 'hardest', label: 'Hardest Cards First', desc: 'Lowest ease & lowest reps' },
                { id: 'newest', label: 'Newest Cards First', desc: 'Most recently added cards' },
              ].map(mode => (
                <button
                  key={mode.id}
                  type="button"
                  onClick={() => setFilterMode(mode.id as any)}
                  className={`p-3 rounded-xl text-left border transition-all flex flex-col justify-between ${
                    filterMode === mode.id
                      ? 'bg-blue-50/80 border-blue-500 text-blue-900 shadow-sm ring-1 ring-blue-500/30'
                      : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100/70 hover:border-slate-300'
                  }`}
                >
                  <span className="text-xs font-bold font-sans tracking-tight">{mode.label}</span>
                  <span className="text-[10px] text-slate-500 mt-1 leading-snug">{mode.desc}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Archetype Filter Sub-section */}
          {filterMode === 'types' && (
            <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-3 animate-fadeIn">
              <div className="flex items-center justify-between">
                <span className="text-[10px] text-slate-500 uppercase tracking-widest font-bold">Select Dart Card Archetypes:</span>
                <button
                  type="button"
                  onClick={handleSelectAllTypes}
                  className="text-[10px] text-blue-600 hover:text-blue-700 font-semibold uppercase tracking-wider"
                >
                  Select All
                </button>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {allCardTypes.map(archetype => {
                  const isSelected = selectedTypes.includes(archetype.type);
                  return (
                    <button
                      key={archetype.type}
                      type="button"
                      onClick={() => toggleType(archetype.type)}
                      className={`px-3 py-2 rounded-xl border text-xs font-sans text-left flex items-center gap-2 transition-all ${
                        isSelected
                          ? 'bg-blue-600 text-white border-blue-600 shadow-xs'
                          : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                      }`}
                    >
                      <span>{archetype.icon}</span>
                      <span className="truncate font-medium">{archetype.type}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* Card Limit Input Field (min 10, max 500) */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                <Zap className="w-3.5 h-3.5 text-blue-600" /> Study Card Limit (Min: 10, Max: 500)
              </label>
              <span className="text-[11px] font-mono font-bold text-blue-600">
                {cardLimit === 'all' ? 'All Available Cards' : `${cardLimit} Cards`}
              </span>
            </div>

            <div className="space-y-2">
              <div className="relative">
                <input
                  type="number"
                  min={10}
                  max={500}
                  step={1}
                  value={inputVal}
                  onChange={(e) => {
                    const val = e.target.value;
                    setInputVal(val);
                    const num = parseInt(val, 10);
                    if (!isNaN(num)) {
                      if (num >= 10 && num <= 500) {
                        setCardLimit(num);
                      }
                    }
                  }}
                  onBlur={() => {
                    const num = parseInt(inputVal, 10);
                    if (isNaN(num) || num < 10) {
                      setInputVal('10');
                      setCardLimit(10);
                    } else if (num > 500) {
                      setInputVal('500');
                      setCardLimit(500);
                    } else {
                      setInputVal(num.toString());
                      setCardLimit(num);
                    }
                  }}
                  placeholder="Enter number of cards (10 - 500)"
                  className="w-full pl-3.5 pr-28 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-mono text-sm focus:bg-white focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-all placeholder:text-slate-400 placeholder:font-sans placeholder:text-xs"
                />
                <div className="absolute inset-y-0 right-3 flex items-center pointer-events-none text-slate-400 font-mono text-xs">
                  cards (10-500)
                </div>
              </div>

              {/* Quick Presets */}
              <div className="flex items-center gap-1.5 overflow-x-auto pt-1">
                <span className="text-[10px] text-slate-400 uppercase font-mono tracking-wider mr-1">Presets:</span>
                {[10, 20, 30, 50, 100, 200, 500].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => {
                      setCardLimit(preset);
                      setInputVal(preset.toString());
                    }}
                    className={`px-2.5 py-1 rounded-lg text-[11px] font-mono font-bold transition-all ${
                      cardLimit === preset
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-slate-100 text-slate-600 hover:bg-slate-200 hover:text-slate-900 border border-slate-200'
                    }`}
                  >
                    {preset}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={() => {
                    setCardLimit('all');
                    setInputVal('');
                  }}
                  className={`px-2.5 py-1 rounded-lg text-[11px] font-mono font-bold transition-all ${
                    cardLimit === 'all'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200 hover:text-slate-900 border border-slate-200'
                  }`}
                >
                  All
                </button>
              </div>
            </div>
          </div>

          {/* Additional Options */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2 border-t border-slate-100">
            <label className="flex items-center gap-3 cursor-pointer p-3 rounded-xl bg-slate-50 border border-slate-200 hover:bg-slate-100/70 transition-colors">
              <input
                type="checkbox"
                checked={shuffle}
                onChange={(e) => setShuffle(e.target.checked)}
                className="w-4 h-4 rounded text-blue-600 focus:ring-blue-500/20 border-slate-300"
              />
              <div>
                <div className="text-xs font-bold text-slate-800">Shuffle Card Order</div>
                <div className="text-[10px] text-slate-500 font-sans">Randomize card presentation</div>
              </div>
            </label>

            <label className="flex items-center gap-3 cursor-pointer p-3 rounded-xl bg-slate-50 border border-slate-200 hover:bg-slate-100/70 transition-colors">
              <input
                type="checkbox"
                checked={updateSrs}
                onChange={(e) => setUpdateSrs(e.target.checked)}
                className="w-4 h-4 rounded text-blue-600 focus:ring-blue-500/20 border-slate-300"
              />
              <div>
                <div className="text-xs font-bold text-slate-800">Update SRS Schedule</div>
                <div className="text-[10px] text-slate-500 font-sans">Recalculate intervals on rating</div>
              </div>
            </label>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-4 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
          <div className="text-xs font-sans text-slate-600">
            Matching cards: <span className="font-extrabold text-blue-600 font-mono">{matchingCardsCount}</span>
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-xs font-bold uppercase tracking-wider text-slate-500 hover:text-slate-800 transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleStartSession}
              disabled={matchingCardsCount === 0}
              className="inline-flex items-center gap-2 px-6 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs uppercase tracking-widest rounded-xl transition-all shadow-[0_4px_16px_rgba(37,99,235,0.3)] disabled:opacity-40 disabled:cursor-not-allowed disabled:shadow-none"
            >
              <Play className="w-3.5 h-3.5 fill-current" />
              Launch Session ({matchingCardsCount})
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
