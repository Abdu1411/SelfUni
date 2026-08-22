import React, { useState, useEffect } from 'react';
import {
  X,
  Edit3,
  Sparkles,
  Code2,
  Check,
  RotateCcw,
  Layers,
  HelpCircle,
  Trash2
} from 'lucide-react';
import { Card, CardType } from '../../types';

interface EditCardModalProps {
  card: Card | null;
  isOpen: boolean;
  onClose: () => void;
  onSave: (updatedCard: Card) => void;
  onDelete?: (cardId: string) => void;
}

const ARCHETYPES: { type: CardType; label: string; icon: string; desc: string }[] = [
  { type: 'Concept', label: 'Concept', icon: '💡', desc: 'Core intuition & theoretical foundations' },
  { type: 'Complexity', label: 'Complexity', icon: '⚡', desc: 'Time & Space bounds with LaTeX math' },
  { type: 'Pattern', label: 'Pattern', icon: '🎯', desc: 'Algorithmic recognition & application' },
  { type: 'Cloze', label: 'Cloze Deletion', icon: '🧩', desc: 'Fill-in-the-blank with {{c1::hidden}}' },
  { type: 'Comparison', label: 'Comparison', icon: '⚖️', desc: 'Trade-off & structure comparison' },
  { type: 'Trace', label: 'Trace', icon: '🔍', desc: 'Step-by-step execution simulation' },
  { type: 'Invariant', label: 'Invariant', icon: '🛡️', desc: 'Correctness proofs & loop invariants' },
  { type: 'Debugging', label: 'Debugging', icon: '🐛', desc: 'Edge cases, pitfalls & Dart null safety' },
  { type: 'Implementation', label: 'Implementation', icon: '💻', desc: 'Interactive Dart coding challenge' },
];

export function EditCardModal({ card, isOpen, onClose, onSave, onDelete }: EditCardModalProps) {
  const [type, setType] = useState<CardType>('Concept');
  const [front, setFront] = useState('');
  const [back, setBack] = useState('');
  const [codeSnippet, setCodeSnippet] = useState('');
  const [showCodeInput, setShowCodeInput] = useState(false);
  const [resetSrs, setResetSrs] = useState(false);

  useEffect(() => {
    if (card) {
      setType(card.type || 'Concept');
      setFront(card.front || '');
      setBack(card.back || '');
      setCodeSnippet(card.codeSnippet || '');
      setShowCodeInput(!!card.codeSnippet);
      setResetSrs(false);
    }
  }, [card]);

  if (!isOpen || !card) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!front.trim() || !back.trim()) return;

    const updatedCard: Card = {
      ...card,
      type,
      front: front.trim(),
      back: back.trim(),
      codeSnippet: showCodeInput && codeSnippet.trim() ? codeSnippet.trim() : undefined,
      ...(resetSrs
        ? {
            nextReview: Date.now(),
            interval: 0,
            ease: 2.5,
            reps: 0
          }
        : {})
    };

    onSave(updatedCard);
    onClose();
  };

  const handleInsertCloze = () => {
    setFront(prev => prev + ' {{c1::hidden_answer}}');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn">
      <div
        className="bg-white rounded-3xl shadow-2xl border border-slate-200 w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh] animate-scaleUp"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200">
              <Edit3 className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-sm font-black text-slate-900 tracking-tight">Edit Flashcard</h2>
              <span className="text-[10px] text-slate-400 font-mono">ID: {card.id.split('-')[0].toUpperCase()}</span>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 text-slate-400 hover:text-slate-700 rounded-xl hover:bg-slate-100 transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Modal Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4 overflow-y-auto flex-1">
          {/* Card Type / Archetype Selector */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center justify-between">
              <span>Card Archetype</span>
              <span className="text-slate-400 font-normal lowercase">9 note archetypes</span>
            </label>
            <div className="grid grid-cols-3 gap-2">
              {ARCHETYPES.map((arch) => {
                const isSelected = type === arch.type;
                return (
                  <button
                    key={arch.type}
                    type="button"
                    onClick={() => setType(arch.type)}
                    className={`p-2 rounded-xl text-left border transition-all cursor-pointer flex items-center gap-2 ${
                      isSelected
                        ? 'bg-blue-50/80 border-blue-500 text-blue-900 shadow-2xs'
                        : 'bg-slate-50/60 border-slate-200 hover:bg-slate-100/80 text-slate-700'
                    }`}
                  >
                    <span className="text-base">{arch.icon}</span>
                    <div className="min-w-0 flex-1">
                      <span className="block text-xs font-bold truncate">{arch.label}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Front / Question Input */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold">
                Front (Question & Recall Prompt)
              </label>
              {type === 'Cloze' && (
                <button
                  type="button"
                  onClick={handleInsertCloze}
                  className="text-[11px] font-bold text-blue-600 hover:text-blue-700 inline-flex items-center gap-1 cursor-pointer"
                >
                  <Sparkles className="w-3 h-3" />
                  Insert Cloze {'{{c1::...}}'}
                </button>
              )}
            </div>
            <textarea
              rows={3}
              value={front}
              onChange={(e) => setFront(e.target.value)}
              placeholder="e.g. What is the time complexity of building a heap from an array of N items?"
              className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all leading-relaxed"
              required
            />
            {type === 'Cloze' && (
              <p className="text-[10px] text-slate-500 font-sans mt-1">
                Tip: Wrap words in <code className="bg-slate-100 px-1 py-0.5 rounded text-blue-600 font-mono font-bold">{'{{c1::answer}}'}</code> to cover them with dots during review.
              </p>
            )}
          </div>

          {/* Back / Answer Input */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Back (Answer & Explanation — Markdown & LaTeX)
            </label>
            <textarea
              rows={4}
              value={back}
              onChange={(e) => setBack(e.target.value)}
              placeholder="e.g. $O(N)$ using Floyd's bottom-up heapify method. Explanation: ..."
              className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all leading-relaxed font-mono"
              required
            />
          </div>

          {/* Optional Code Snippet */}
          <div>
            {!showCodeInput ? (
              <button
                type="button"
                onClick={() => setShowCodeInput(true)}
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-blue-600 cursor-pointer"
              >
                <Code2 className="w-3.5 h-3.5 text-blue-600" />
                + Add Dart Code Snippet
              </button>
            ) : (
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                    <Code2 className="w-3.5 h-3.5 text-blue-600" />
                    Dart Code Snippet
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setShowCodeInput(false);
                      setCodeSnippet('');
                    }}
                    className="text-[10px] text-slate-400 hover:text-rose-600 cursor-pointer"
                  >
                    Remove Code
                  </button>
                </div>
                <textarea
                  rows={3}
                  value={codeSnippet}
                  onChange={(e) => setCodeSnippet(e.target.value)}
                  placeholder="void heapify(List<int> arr, int n, int i) { ... }"
                  className="w-full p-3 bg-slate-900 border border-slate-800 text-emerald-400 rounded-xl text-xs font-mono placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all"
                />
              </div>
            )}
          </div>

          {/* Reset SRS Stats Checkbox */}
          <div className="pt-2 border-t border-slate-100 flex items-center justify-between">
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={resetSrs}
                onChange={(e) => setResetSrs(e.target.checked)}
                className="w-4 h-4 rounded text-blue-600 focus:ring-blue-500 border-slate-300"
              />
              <span className="text-xs font-medium text-slate-600 flex items-center gap-1">
                <RotateCcw className="w-3 h-3 text-slate-400" />
                Reset SRS Interval (Move back to "Learn" queue)
              </span>
            </label>
          </div>

          {/* Modal Footer */}
          <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2.5">
            {onDelete ? (
              <button
                type="button"
                onClick={() => {
                  if (confirm('Are you sure you want to permanently delete this flashcard?')) {
                    onDelete(card.id);
                    onClose();
                  }
                }}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold text-rose-600 hover:text-rose-700 hover:bg-rose-50 rounded-xl transition-colors cursor-pointer"
                title="Delete this flashcard"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Delete Card</span>
              </button>
            ) : (
              <div></div>
            )}

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={!front.trim() || !back.trim()}
                className="inline-flex items-center gap-1.5 px-6 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-md disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
              >
                <Check className="w-3.5 h-3.5" />
                Save Changes
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
