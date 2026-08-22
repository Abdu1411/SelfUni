import React, { useState, useMemo } from 'react';
import {
  X,
  Layers,
  Search,
  Plus,
  Edit3,
  Trash2,
  Calendar,
  Sparkles,
  Bot,
  CheckCircle2,
  Code2
} from 'lucide-react';
import { Deck, Card, CardType, ARCHETYPE_CONFIG } from '../../types';
import { EditCardModal } from './EditCardModal';

interface DeckCardsModalProps {
  deck: Deck | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdateCard: (deckId: string, updatedCard: Card) => void;
  onDeleteCard: (deckId: string, cardId: string) => void;
  onAddCard: (deckId: string, newCard: Card) => void;
}

export function DeckCardsModal({
  deck,
  isOpen,
  onClose,
  onUpdateCard,
  onDeleteCard,
  onAddCard
}: DeckCardsModalProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedType, setSelectedType] = useState<string>('all');
  const [editingCard, setEditingCard] = useState<Card | null>(null);
  const [isCreatingCard, setIsCreatingCard] = useState(false);

  const safeCards = deck?.cards || [];

  const filteredCards = useMemo(() => {
    let list = [...safeCards];

    if (selectedType !== 'all') {
      list = list.filter((c) => c.type === selectedType);
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter(
        (c) =>
          (c.front || '').toLowerCase().includes(q) ||
          (c.back || '').toLowerCase().includes(q) ||
          (c.type || '').toLowerCase().includes(q)
      );
    }

    return list;
  }, [safeCards, selectedType, searchQuery]);

  if (!isOpen || !deck) return null;

  const handleSaveEditedCard = (updatedCard: Card) => {
    if (isCreatingCard) {
      onAddCard(deck.id, updatedCard);
      setIsCreatingCard(false);
    } else {
      onUpdateCard(deck.id, updatedCard);
    }
    setEditingCard(null);
  };

  const handleStartCreateCard = () => {
    const newBlankCard: Card = {
      id: crypto.randomUUID(),
      type: 'Concept',
      front: '',
      back: '',
      nextReview: Date.now(),
      interval: 0,
      ease: 2.5,
      reps: 0
    };
    setIsCreatingCard(true);
    setEditingCard(newBlankCard);
  };

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn">
        <div
          className="bg-white rounded-3xl shadow-2xl border border-slate-200 w-full max-w-4xl overflow-hidden flex flex-col max-h-[90vh] animate-scaleUp"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200 shadow-2xs">
                <Layers className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-base font-black text-slate-900 tracking-tight flex items-center gap-2">
                  <span>{deck.title}</span>
                  <span className="text-xs font-mono font-bold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                    {safeCards.length} cards
                  </span>
                </h2>
                <p className="text-[11px] text-slate-500 font-sans">
                  Browse, search, edit, or remove flashcards in this deck
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={handleStartCreateCard}
                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold transition-all shadow-sm cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                Add Card
              </button>
              <button
                onClick={onClose}
                className="p-1.5 text-slate-400 hover:text-slate-700 rounded-xl hover:bg-slate-100 transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search & Filter Toolbar */}
          <div className="p-4 border-b border-slate-100 bg-white flex flex-col sm:flex-row items-center gap-3">
            <div className="relative flex-1 w-full">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search flashcards by question, answer, or code..."
                className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all"
              />
            </div>

            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-700 focus:bg-white focus:border-blue-500 focus:outline-none transition-all cursor-pointer w-full sm:w-auto"
            >
              <option value="all">All Archetypes</option>
              <option value="Concept">💡 Concept</option>
              <option value="Complexity">⚡ Complexity</option>
              <option value="Pattern">🎯 Pattern</option>
              <option value="Cloze">🧩 Cloze Deletion</option>
              <option value="Comparison">⚖️ Comparison</option>
              <option value="Trace">🔍 Trace</option>
              <option value="Invariant">🛡️ Invariant</option>
              <option value="Debugging">🐛 Debugging</option>
              <option value="Implementation">💻 Implementation</option>
            </select>
          </div>

          {/* Cards List */}
          <div className="p-4 sm:p-6 overflow-y-auto flex-1 space-y-3 bg-slate-50/50">
            {filteredCards.length === 0 ? (
              <div className="text-center py-12 bg-white rounded-2xl border border-dashed border-slate-200 p-6">
                <Layers className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                <p className="text-xs font-bold text-slate-700">No flashcards found</p>
                <p className="text-[11px] text-slate-400 font-sans mt-0.5">
                  {searchQuery ? 'Try adjusting your search query' : 'This deck is currently empty'}
                </p>
              </div>
            ) : (
              filteredCards.map((card, idx) => (
                <div
                  key={card.id}
                  className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs hover:shadow-sm hover:border-blue-300 transition-all group"
                >
                  <div className="flex items-start justify-between gap-3 mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] font-mono font-bold text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded">
                        #{idx + 1}
                      </span>
                      {(() => {
                        const cardType = card.type || 'Concept';
                        const typeMeta = ARCHETYPE_CONFIG[cardType] || ARCHETYPE_CONFIG.Concept;
                        return (
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${typeMeta.bg} ${typeMeta.text} ${typeMeta.border} border inline-flex items-center gap-1 shadow-2xs`}>
                            <span>{typeMeta.icon}</span>
                            <span>{typeMeta.label}</span>
                          </span>
                        );
                      })()}
                      {card.reps > 0 && (
                        <span className="text-[10px] font-mono text-slate-400 flex items-center gap-1">
                          <Calendar className="w-3 h-3 text-slate-400" />
                          {card.interval}d interval ({card.reps} reps)
                        </span>
                      )}
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => {
                          setIsCreatingCard(false);
                          setEditingCard(card);
                        }}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors cursor-pointer"
                        title="Edit Flashcard"
                      >
                        <Edit3 className="w-3.5 h-3.5" />
                        Edit
                      </button>
                      <button
                        onClick={() => {
                          if (confirm('Are you sure you want to delete this card?')) {
                            onDeleteCard(deck.id, card.id);
                          }
                        }}
                        className="p-1 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors cursor-pointer"
                        title="Delete Flashcard"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Question / Front */}
                  <div className="mb-2">
                    <span className="text-[10px] font-extrabold uppercase tracking-widest text-slate-400 block mb-0.5">
                      Question:
                    </span>
                    <p className="text-xs font-medium text-slate-900 leading-relaxed font-sans">
                      {card.front}
                    </p>
                  </div>

                  {/* Answer / Back */}
                  <div className="p-2.5 bg-slate-50 rounded-xl border border-slate-100">
                    <span className="text-[10px] font-extrabold uppercase tracking-widest text-slate-400 block mb-0.5">
                      Answer:
                    </span>
                    <p className="text-xs text-slate-700 leading-relaxed font-sans line-clamp-3">
                      {card.back}
                    </p>
                  </div>

                  {card.codeSnippet && (
                    <div className="mt-2 text-[10px] text-blue-600 font-mono flex items-center gap-1">
                      <Code2 className="w-3 h-3" />
                      Includes Dart code snippet
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Edit Card Sub-Modal */}
      {editingCard && (
        <EditCardModal
          card={editingCard}
          isOpen={true}
          onClose={() => {
            setEditingCard(null);
            setIsCreatingCard(false);
          }}
          onSave={handleSaveEditedCard}
          onDelete={!isCreatingCard ? (cardId) => onDeleteCard(deck.id, cardId) : undefined}
        />
      )}
    </>
  );
}
