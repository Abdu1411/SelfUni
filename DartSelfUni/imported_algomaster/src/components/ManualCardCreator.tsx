import React, { useState } from 'react';
import { PenTool, Layers, Code2, Sparkles, Tag, HelpCircle, FolderGit2 } from 'lucide-react';
import { Card, Deck, CardType } from '../types';
import { useDecks } from '../store';
import { CodeEditor } from './CodeEditor';

interface ManualCardCreatorProps {
  decks: Deck[];
  onAddCard: (deckId: string, card: Card) => void;
  onAddDeck: (deck: Deck) => void;
}

export function ManualCardCreator({ decks, onAddCard, onAddDeck }: ManualCardCreatorProps) {
  const { folders } = useDecks();
  const [deckId, setDeckId] = useState<string>(decks.length > 0 ? decks[0].id : 'new');
  const [newDeckTitle, setNewDeckTitle] = useState('');
  const [targetFolderId, setTargetFolderId] = useState<string>('');
  const [type, setType] = useState<CardType>('Concept');
  const [front, setFront] = useState('');
  const [back, setBack] = useState('');
  const [codeSnippet, setCodeSnippet] = useState('');

  const noteTypes: { type: CardType; label: string; icon: string; desc: string; placeholderFront: string; placeholderBack: string }[] = [
    {
      type: 'Concept',
      label: 'Concept ("Why")',
      icon: '💡',
      desc: 'Understand the core algorithmic concept and mechanics in Dart.',
      placeholderFront: 'Why does Dart\'s SplayTreeMap provide O(log N) amortized operations?',
      placeholderBack: 'Because splay trees rotate accessed elements to the root, optimizing for temporal locality.',
    },
    {
      type: 'Complexity',
      label: 'Complexity (Big-O)',
      icon: '⚡',
      desc: 'Test time and auxiliary space complexity.',
      placeholderFront: 'What is the worst-case time complexity of QuickSort in Dart when choosing the first element as pivot?',
      placeholderBack: 'O(N²) when the list is already sorted or reverse sorted.',
    },
    {
      type: 'Pattern',
      label: 'Pattern Trigger',
      icon: '🎯',
      desc: 'Recognize when to apply this technique in problem solving.',
      placeholderFront: 'When should you use the Two-Pointers pattern on a Dart List<int>?',
      placeholderBack: 'When the list is sorted and we need to find pairs, triples, or subarrays matching a target sum.',
    },
    {
      type: 'Cloze',
      label: 'Cloze Deletion',
      icon: '🧩',
      desc: 'Fill in the blank test using Anki syntax: {{c1::hidden text}}.',
      placeholderFront: 'In Dart, a Binary Heap can be implemented efficiently using a {{c1::List<int>}} where parent of index i is at {{c2::(i - 1) ~/ 2}}.',
      placeholderBack: 'List<int> and integer division operator `~/`.',
    },
    {
      type: 'Comparison',
      label: 'Comparison',
      icon: '⚖️',
      desc: 'Compare trade-offs between two structures or algorithms.',
      placeholderFront: 'Compare Dart\'s `ListQueue<E>` vs `DoubleLinkedQueue<E>` in terms of memory overhead.',
      placeholderBack: '`ListQueue` uses a contiguous array with lower memory overhead and better cache locality than node-based `DoubleLinkedQueue`.',
    },
    {
      type: 'Trace',
      label: 'Trace / Visual',
      icon: '🔍',
      desc: 'Step-by-step state simulation on small Dart inputs.',
      placeholderFront: 'Trace the state of pointers `left` and `right` on `[2, 7, 11, 15]` when target is 9.',
      placeholderBack: 'left=0 (2), right=3 (15), sum=17 > 9 -> right=2 (11), sum=13 > 9 -> right=1 (7), sum=9 == target. Found at [0, 1].',
    },
    {
      type: 'Invariant',
      label: 'Invariant / Proof',
      icon: '🛡️',
      desc: 'Reasoning why the algorithm remains correct at each iteration.',
      placeholderFront: 'What loop invariant holds true in Dart Binary Search at the start of each while iteration?',
      placeholderBack: 'If target exists in the sorted list, it must lie strictly within the index range [left, right].',
    },
    {
      type: 'Debugging',
      label: 'Dart Debugging',
      icon: '🐛',
      desc: 'Identify and fix common bugs in Dart algorithm snippets.',
      placeholderFront: 'Identify the off-by-one bug in this Dart binary search midpoint calculation.',
      placeholderBack: '`mid = (left + right) / 2` returns a `double` and can overflow in 32-bit; use integer division `mid = left + ((right - left) ~/ 2)`.',
    },
    {
      type: 'Implementation',
      label: 'Dart Implementation',
      icon: '💻',
      desc: 'Hands-on coding challenge to be solved in the Dart code editor.',
      placeholderFront: 'Implement function `int binarySearch(List<int> nums, int target)` returning target index or -1.',
      placeholderBack: '```dart\nint binarySearch(List<int> nums, int target) {\n  int left = 0, right = nums.length - 1;\n  while (left <= right) {\n    int mid = left + ((right - left) ~/ 2);\n    if (nums[mid] == target) return mid;\n    if (nums[mid] < target) left = mid + 1;\n    else right = mid - 1;\n  }\n  return -1;\n}\n```',
    },
  ];

  const currentNoteTypeInfo = noteTypes.find(n => n.type === type) || noteTypes[0];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!front || !back) return;
    if (deckId === 'new' && !newDeckTitle) return;

    const newCard: Card = {
      id: crypto.randomUUID(),
      type,
      front,
      back,
      codeSnippet: codeSnippet.trim() || undefined,
      nextReview: Date.now(),
      interval: 0,
      ease: 2.5,
      reps: 0
    };

    if (deckId === 'new') {
      const newDeck: Deck = {
        id: crypto.randomUUID(),
        title: newDeckTitle,
        folderId: targetFolderId || undefined,
        createdAt: Date.now(),
        cards: [newCard]
      };
      onAddDeck(newDeck);
      setDeckId(newDeck.id);
      setNewDeckTitle('');
    } else {
      onAddCard(deckId, newCard);
    }

    setFront('');
    setBack('');
    setCodeSnippet('');
  };

  return (
    <section className="bg-white/90 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.04)] border border-slate-200/80 p-7 backdrop-blur-md relative overflow-hidden group hover:border-amber-300 transition-all hover:shadow-[0_8px_30px_rgba(245,158,11,0.06)]">
      {/* Decorative ambient background element */}
      <div className="absolute -bottom-20 -left-20 w-56 h-56 bg-gradient-to-tr from-amber-500/10 to-orange-500/10 rounded-full blur-2xl pointer-events-none"></div>
      
      <div className="max-w-2xl relative z-10">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center border border-amber-200 shadow-2xs">
            <PenTool className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-base font-extrabold tracking-tight text-slate-900 uppercase italic">
              Manual Dart Card Forge
            </h2>
          </div>
          <span className="ml-auto px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-amber-50 text-amber-700 border border-amber-200">
            9 Note Types
          </span>
        </div>
        <p className="text-slate-500 text-xs mb-5 leading-relaxed">
          Craft custom Dart algorithm flashcards across 9 note archetypes with syntax highlighting, clozes, and code snippets.
        </p>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Target Deck & New Deck Name */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest mb-1.5 font-bold flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5 text-amber-600" /> Target Deck
              </label>
              <select
                value={deckId}
                onChange={(e) => setDeckId(e.target.value)}
                className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all text-slate-800 font-sans text-xs cursor-pointer"
              >
                {decks.map(d => (
                  <option key={d.id} value={d.id}>{d.title} ({d.cards.length} cards)</option>
                ))}
                <option value="new">+ Create New Deck</option>
              </select>
            </div>
            
            {deckId === 'new' && (
              <div className="animate-fadeIn space-y-3">
                <div>
                  <label className="block text-[10px] text-slate-500 uppercase tracking-widest mb-1.5 font-bold">New Deck Title</label>
                  <input
                    type="text"
                    placeholder="e.g. Dart Trees & Graphs"
                    value={newDeckTitle}
                    onChange={(e) => setNewDeckTitle(e.target.value)}
                    className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs"
                  />
                </div>

                {folders.length > 0 && (
                  <div>
                    <label className="block text-[10px] text-slate-500 uppercase tracking-widest mb-1.5 font-bold flex items-center gap-1">
                      <FolderGit2 className="w-3 h-3 text-amber-600" /> Folder (Optional)
                    </label>
                    <select
                      value={targetFolderId}
                      onChange={(e) => setTargetFolderId(e.target.value)}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-sans text-xs focus:bg-white focus:border-amber-500 focus:outline-none transition-all cursor-pointer"
                    >
                      <option value="">📁 Unfiled (No Folder)</option>
                      {folders.map(f => (
                        <option key={f.id} value={f.id}>
                          📁 {f.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Note Type / Archetype Selector */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center gap-1.5">
              <Tag className="w-3.5 h-3.5 text-amber-600" /> Note Type (Card Archetype)
            </label>

            <select
              value={type}
              onChange={(e) => setType(e.target.value as CardType)}
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all text-slate-800 font-sans text-xs cursor-pointer font-medium"
            >
              {noteTypes.map(nt => (
                <option key={nt.type} value={nt.type}>
                  {nt.icon} {nt.label}
                </option>
              ))}
            </select>

            <p className="text-[11px] text-slate-500 mt-2 italic bg-amber-50/50 p-2.5 rounded-lg border border-amber-100 flex items-start gap-1.5">
              <HelpCircle className="w-3.5 h-3.5 text-amber-600 shrink-0 mt-0.5" />
              <span>{currentNoteTypeInfo.desc}</span>
            </p>
          </div>

          {/* Front Prompt */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest mb-1.5 font-bold">
              Front (Prompt / Dart Question)
            </label>
            <textarea
              placeholder={currentNoteTypeInfo.placeholderFront}
              value={front}
              onChange={(e) => setFront(e.target.value)}
              rows={2}
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs resize-none"
            />
          </div>

          {/* Optional Code Snippet (for Debugging, Trace, or Concept) */}
          {(type === 'Debugging' || type === 'Trace' || type === 'Concept' || type === 'Implementation') && (
            <div className="animate-fadeIn space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                  <Code2 className="w-3.5 h-3.5 text-amber-600" /> Front Dart Code Snippet (Optional)
                </label>
                <span className="text-[10px] font-mono text-slate-400 font-bold">Dart 3.x IDE</span>
              </div>
              <CodeEditor
                value={codeSnippet}
                onChange={setCodeSnippet}
                placeholder="void main() {&#10;  List<int> list = [1, 2, 3];&#10;  // Dart snippet displayed on front&#10;}"
                minHeight="120px"
              />
            </div>
          )}
          
          {/* Back Answer */}
          <div>
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest mb-1.5 font-bold">
              Back (Dart Answer / Solution)
            </label>
            <textarea
              placeholder={currentNoteTypeInfo.placeholderBack}
              value={back}
              onChange={(e) => setBack(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all text-slate-800 placeholder-slate-400 font-mono text-xs resize-none"
            />
          </div>

          <button
            type="submit"
            disabled={!front || !back || (deckId === 'new' && !newDeckTitle)}
            className="inline-flex items-center justify-center gap-2 px-7 py-2.5 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white font-bold rounded-xl transition-all shadow-[0_4px_16px_rgba(245,158,11,0.3)] text-xs uppercase tracking-widest disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none"
          >
            <PenTool className="w-4 h-4" />
            Forge Dart Card ({type})
          </button>
        </form>
      </div>
    </section>
  );
}
