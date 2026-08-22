import React, { useState } from 'react';
import { Sparkles, Bot, PenTool, Zap, Check } from 'lucide-react';
import { AICardGenerator } from '../components/AICardGenerator';
import { ManualCardCreator } from '../components/ManualCardCreator';
import { Deck, Folder, Card } from '../types';

interface DeckGeneratorViewProps {
  decks: Deck[];
  folders: Folder[];
  onAddDeck: (deck: Deck) => Promise<void> | void;
  onAddCardToDeck: (deckId: string, card: Card) => Promise<void> | void;
}

export function DeckGeneratorView({
  decks,
  folders,
  onAddDeck,
  onAddCardToDeck
}: DeckGeneratorViewProps) {
  const [activeMode, setActiveMode] = useState<'ai' | 'manual'>('ai');

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Header & Mode Switcher */}
      <section className="bg-white/95 rounded-3xl border border-slate-200/90 shadow-sm p-6 sm:p-8 backdrop-blur-md relative overflow-hidden">
        {/* Glow decoration */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-bl from-blue-400/10 via-indigo-400/5 to-transparent rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 border-b border-slate-100 pb-5 relative z-10">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-blue-50 text-blue-700 border border-blue-200 mb-1.5">
              <Zap className="w-3 h-3 text-blue-600" />
              Flashcard Engine
            </div>
            <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-blue-600" />
              AI Deck Synthesizer
            </h1>
            <p className="text-xs text-slate-500 font-sans mt-0.5">
              Synthesize 30-card spaced repetition decks with AI from multiple documentation sources, or forge cards manually
            </p>
          </div>

          {/* Mode Pill Toggle */}
          <div className="inline-flex p-1 bg-slate-100/90 border border-slate-200/80 rounded-2xl self-start sm:self-auto">
            <button
              type="button"
              onClick={() => setActiveMode('ai')}
              className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold uppercase tracking-wider transition-all cursor-pointer ${
                activeMode === 'ai'
                  ? 'bg-white text-blue-600 shadow-sm border border-slate-200/60'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <Bot className="w-3.5 h-3.5" />
              AI Deck Synthesizer
            </button>
            <button
              type="button"
              onClick={() => setActiveMode('manual')}
              className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold uppercase tracking-wider transition-all cursor-pointer ${
                activeMode === 'manual'
                  ? 'bg-white text-amber-600 shadow-sm border border-slate-200/60'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <PenTool className="w-3.5 h-3.5" />
              Manual Card Forge
            </button>
          </div>
        </div>

        {/* Active Component */}
        <div className="animate-fadeIn">
          {activeMode === 'ai' ? (
            <AICardGenerator onDeckGenerated={onAddDeck} />
          ) : (
            <ManualCardCreator
              decks={decks}
              onAddDeck={onAddDeck}
              onAddCard={onAddCardToDeck}
            />
          )}
        </div>
      </section>
    </div>
  );
}
