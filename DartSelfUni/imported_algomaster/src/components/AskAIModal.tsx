import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import {
  Sparkles,
  Send,
  Loader2,
  X,
  Copy,
  Check,
  Bot,
  PlusCircle,
  Eye,
  FileText,
  Layers,
  BookOpen,
  ChevronDown,
  ChevronUp,
  HelpCircle,
  Code2
} from 'lucide-react';
import { useDecks } from '../store';
import { Card, Deck, CardType } from '../types';
import { MarkdownCodeRenderer } from './CodeBlock';
import { useActiveView } from '../context/ActiveViewContext';

const cardArchetypes: { type: CardType; label: string; icon: string; desc: string }[] = [
  { type: 'Concept', label: 'Concept', icon: '💡', desc: '"Why" & Core Intuition' },
  { type: 'Complexity', label: 'Complexity', icon: '⚡', desc: 'Big-O Time & Space Bounds' },
  { type: 'Pattern', label: 'Pattern', icon: '🧩', desc: 'Algorithmic Pattern' },
  { type: 'Cloze', label: 'Cloze', icon: '📝', desc: 'Fill-in-the-Blank [___]' },
  { type: 'Comparison', label: 'Comparison', icon: '⚖️', desc: 'Trade-offs & Alternatives' },
  { type: 'Trace', label: 'Trace', icon: '🔍', desc: 'Step-by-Step State Trace' },
  { type: 'Invariant', label: 'Invariant', icon: '🛡️', desc: 'Loop & Structural Invariants' },
  { type: 'Debugging', label: 'Debugging', icon: '🐛', desc: 'Bug Traps & Pitfalls' },
  { type: 'Implementation', label: 'Implementation', icon: '💻', desc: 'Dart Code Challenge' },
];

interface AskAIModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialQuery?: string;
  contextInfo?: string;
}

export function AskAIModal({ isOpen, onClose, initialQuery = '', contextInfo }: AskAIModalProps) {
  const { decks, addDeck, addCardToDeck } = useDecks();
  const { activeResource } = useActiveView();

  const [inquiry, setInquiry] = useState(initialQuery);
  const [isLoading, setIsLoading] = useState(false);
  const [answer, setAnswer] = useState<string | null>(null);
  const [lastInquiry, setLastInquiry] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [cardSaved, setCardSaved] = useState(false);
  const [includeContext, setIncludeContext] = useState(true);
  const [showContextPreview, setShowContextPreview] = useState(false);

  // Card Archetype Converter State
  const [selectedCardType, setSelectedCardType] = useState<CardType>('Concept');
  const [isFormattingCard, setIsFormattingCard] = useState(false);
  const [saveSuccessMessage, setSaveSuccessMessage] = useState('');

  // Deck selector state if converting to flashcard
  const [selectedDeckId, setSelectedDeckId] = useState<string>(decks.length > 0 ? decks[0].id : 'new');
  const [newDeckTitle, setNewDeckTitle] = useState('AI Insights');

  // Compute effective context
  const effectiveContext = contextInfo || (includeContext ? activeResource?.contextText : undefined);

  // Dynamic context-aware query suggestions
  const defaultQueries = [
    'How do I implement a Trie in Dart?',
    'What is the time complexity of Dart SplayTreeMap?',
    'When should I use Two Pointers vs Sliding Window?',
    'Explain Breadth-First Search on a Graph in Dart'
  ];

  const contextQueries = activeResource?.suggestedPrompts || (
    activeResource?.type === 'flashcard' ? [
      'Explain the key intuition and invariant for this card',
      'How does this work under the hood in memory?',
      'Can you give me an alternative Dart implementation?',
      'Test me with a variation of this question'
    ] : activeResource?.type === 'lesson' ? [
      'Summarize the core takeaways and Big-O complexities',
      'Explain the systems trade-offs in this note',
      'Generate 3 active recall questions from these notes',
      'Show an interactive Dart example for this algorithm'
    ] : defaultQueries
  );

  React.useEffect(() => {
    if (initialQuery) {
      setInquiry(initialQuery);
    }
  }, [initialQuery]);

  const handleSubmit = async (e?: React.FormEvent, customQuery?: string) => {
    if (e) e.preventDefault();
    const queryToSend = customQuery || inquiry;
    if (!queryToSend.trim() || isLoading) return;

    setIsLoading(true);
    setError(null);
    setAnswer(null);
    setLastInquiry(queryToSend);
    setCardSaved(false);

    try {
      const response = await fetch('/api/ask-ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          inquiry: queryToSend.trim(),
          context: effectiveContext
        })
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.error || `Request failed with status ${response.status}`);
      }

      const data = await response.json();
      setAnswer(data.answer);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Failed to get answer from AI');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopy = () => {
    if (!answer) return;
    navigator.clipboard.writeText(answer);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Helper to extract code snippets from markdown if present
  const extractCodeSnippet = (text: string): string | undefined => {
    const match = /```(?:dart)?\n([\s\S]*?)```/.exec(text);
    return match ? match[1].trim() : undefined;
  };

  const handleSaveCard = async (archetype: CardType, frontText?: string, backText?: string, snippet?: string) => {
    if (!lastInquiry || !answer) return;

    const front = frontText || lastInquiry;
    const back = backText || answer;
    const codeSnippet = snippet || extractCodeSnippet(answer);

    const newCard: Card = {
      id: crypto.randomUUID(),
      type: archetype,
      front,
      back,
      codeSnippet,
      nextReview: Date.now(),
      interval: 0,
      ease: 2.5,
      reps: 0
    };

    if (selectedDeckId === 'new') {
      const targetTitle = newDeckTitle.trim() || 'AI Insights';
      const newDeck: Deck = {
        id: crypto.randomUUID(),
        title: targetTitle,
        createdAt: Date.now(),
        cards: [newCard]
      };
      await addDeck(newDeck);
      setSelectedDeckId(newDeck.id);
      setSaveSuccessMessage(`Saved as "${archetype}" in new deck "${targetTitle}"!`);
    } else {
      await addCardToDeck(selectedDeckId, newCard);
      const targetDeck = decks.find(d => d.id === selectedDeckId);
      setSaveSuccessMessage(`Saved as "${archetype}" in "${targetDeck?.title || 'Deck'}"!`);
    }

    setCardSaved(true);
    setTimeout(() => {
      setCardSaved(false);
      setSaveSuccessMessage('');
    }, 4000);
  };

  // AI-powered intelligent card converter for specific archetype
  const handleAIFormatAndSave = async () => {
    if (!lastInquiry || !answer || isFormattingCard) return;

    setIsFormattingCard(true);
    try {
      const response = await fetch('/api/format-card-archetype', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question: lastInquiry,
          answer,
          targetType: selectedCardType
        })
      });

      if (!response.ok) {
        throw new Error(`AI formatting failed with status ${response.status}`);
      }

      const formatted = await response.json();
      await handleSaveCard(
        selectedCardType,
        formatted.front || lastInquiry,
        formatted.back || answer,
        formatted.codeSnippet
      );
    } catch (err: any) {
      console.warn('AI card format fallback to standard:', err);
      // Fallback to standard save
      await handleSaveCard(selectedCardType);
    } finally {
      setIsFormattingCard(false);
    }
  };

  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' || e.key === 'Esc') {
        onClose();
      }
    };
    if (isOpen) {
      window.addEventListener('keydown', handleKeyDown);
    }
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 md:p-8 bg-slate-950/70 backdrop-blur-md animate-fadeIn"
      onClick={(e) => {
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      <div className="bg-white border border-slate-200/90 rounded-3xl w-full max-w-4xl lg:max-w-5xl h-[90vh] max-h-[880px] flex flex-col shadow-[0_25px_80px_rgba(0,0,0,0.35)] overflow-hidden relative animate-scaleIn my-auto">
        {/* Glow accent */}
        <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-purple-600 via-indigo-600 to-cyan-500"></div>

        {/* Header */}
        <div className="px-6 py-4 sm:py-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/70 shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-purple-500/10 to-indigo-500/10 text-purple-600 flex items-center justify-center border border-purple-200/80 shadow-2xs">
              <Bot className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base sm:text-lg font-black text-slate-900 uppercase italic tracking-wide">
                  AlgoMaster AI Assistant
                </h2>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-purple-50 text-purple-700 border border-purple-200">
                  Gemini 3.6 Flash
                </span>
              </div>
              <p className="text-xs text-slate-500 font-sans">
                Full-screen pop-up AI assistant with real-time access to your active flashcards, notes, & code
              </p>
            </div>
          </div>
        </div>

        {/* Currently Viewed Resource Context Banner */}
        {activeResource && (
          <div className="bg-gradient-to-r from-purple-50/95 via-indigo-50/85 to-blue-50/75 border-b border-purple-100/80 px-6 py-3 flex flex-col gap-2 text-xs shrink-0">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2 font-medium text-slate-800">
                <div className="w-6 h-6 rounded-lg bg-purple-100 text-purple-700 flex items-center justify-center text-xs shadow-2xs">
                  {activeResource.type === 'lesson' ? <BookOpen className="w-3.5 h-3.5" /> : <Layers className="w-3.5 h-3.5" />}
                </div>
                <span>
                  <strong className="text-purple-900 uppercase tracking-wider text-[10px] font-mono mr-1.5">Active View Context:</strong>
                  <span className="text-slate-800 font-bold">{activeResource.title}</span>
                </span>
              </div>

              <div className="flex items-center gap-3 ml-auto">
                <label className="flex items-center gap-1.5 text-xs font-semibold text-slate-700 cursor-pointer select-none bg-white/70 px-2.5 py-1 rounded-lg border border-purple-200/60 shadow-2xs">
                  <input
                    type="checkbox"
                    checked={includeContext}
                    onChange={(e) => setIncludeContext(e.target.checked)}
                    className="rounded text-purple-600 focus:ring-purple-500 cursor-pointer"
                  />
                  AI Reads Active Screen
                </label>

                <button
                  type="button"
                  onClick={() => setShowContextPreview(!showContextPreview)}
                  className="inline-flex items-center gap-1 text-xs font-semibold text-purple-700 hover:text-purple-800 cursor-pointer bg-white/70 px-2.5 py-1 rounded-lg border border-purple-200/60 shadow-2xs"
                >
                  <Eye className="w-3.5 h-3.5" />
                  {showContextPreview ? 'Hide Context' : 'Preview Context'}
                  {showContextPreview ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                </button>
              </div>
            </div>

            {/* Context Data Preview Drawer */}
            {showContextPreview && (
              <div className="p-3.5 bg-white rounded-xl border border-purple-200 text-xs font-mono text-slate-700 max-h-40 overflow-y-auto whitespace-pre-wrap leading-relaxed shadow-inner animate-fadeIn">
                {activeResource.contextText}
              </div>
            )}
          </div>
        )}

        {/* Content Body */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1 custom-scrollbar">
          {/* Inquiry Input Area */}
          <form onSubmit={(e) => handleSubmit(e)} className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-purple-600" />
                Your Inquiry / Question
              </label>

              {inquiry && (
                <button
                  type="button"
                  onClick={() => setInquiry('')}
                  className="text-[11px] font-semibold text-slate-400 hover:text-rose-600 transition-colors inline-flex items-center gap-1 cursor-pointer"
                  title="Clear text field"
                >
                  <X className="w-3 h-3" /> Clear Text
                </button>
              )}
            </div>

            <div className="relative">
              <textarea
                value={inquiry}
                onChange={(e) => setInquiry(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                    handleSubmit();
                  }
                }}
                rows={3}
                placeholder="Ask anything about the currently viewed note, flashcard, or Dart algorithms..."
                className="w-full px-4 py-3 pb-12 bg-slate-50 border border-slate-200 rounded-2xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500 text-slate-800 text-xs font-sans placeholder-slate-400 transition-all resize-none shadow-2xs"
              />
              <div className="absolute right-3 bottom-3 flex items-center gap-2">
                <button
                  type="submit"
                  disabled={isLoading || !inquiry.trim()}
                  className="px-4 py-1.5 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider transition-all shadow-md disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center gap-1.5 cursor-pointer"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      Thinking...
                    </>
                  ) : (
                    <>
                      <Send className="w-3.5 h-3.5" />
                      Ask AI
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* Quick Inspiration Pills */}
            <div className="flex flex-wrap items-center gap-1.5 pt-1">
              <span className="text-[10px] text-slate-400 font-semibold uppercase tracking-wider mr-1">
                {activeResource ? 'Contextual Prompts:' : 'Suggestions:'}
              </span>
              {contextQueries.map((q) => (
                <button
                  key={q}
                  type="button"
                  onClick={() => {
                    setInquiry(q);
                    handleSubmit(undefined, q);
                  }}
                  className="text-[11px] px-2.5 py-1 bg-slate-50 hover:bg-purple-50 text-slate-600 hover:text-purple-700 border border-slate-200 hover:border-purple-200 rounded-lg font-sans transition-all cursor-pointer truncate max-w-[280px]"
                  title={q}
                >
                  {q}
                </button>
              ))}
            </div>
          </form>

          {/* Error Banner */}
          {error && (
            <div className="p-4 bg-rose-50 border border-rose-200 rounded-2xl text-rose-700 text-xs font-medium animate-fadeIn">
              <strong>Error:</strong> {error}
            </div>
          )}

          {/* Loading Indicator */}
          {isLoading && (
            <div className="py-12 text-center space-y-3 bg-purple-50/30 rounded-2xl border border-purple-100 animate-pulse">
              <div className="w-10 h-10 rounded-2xl bg-purple-100 text-purple-600 flex items-center justify-center mx-auto">
                <Sparkles className="w-5 h-5 animate-spin" />
              </div>
              <p className="text-xs font-bold text-slate-700">Synthesizing Dart algorithm insights...</p>
              <p className="text-[11px] text-slate-400 max-w-xs mx-auto font-sans">
                Consulting Gemini for time complexities, idiomatic Dart code, and data structure proofs.
              </p>
            </div>
          )}

          {/* AI Response Card */}
          {answer && (
            <div className="bg-slate-50/80 rounded-2xl border border-slate-200 p-6 space-y-4 shadow-xs animate-fadeIn relative">
              <div className="flex items-center justify-between border-b border-slate-200/80 pb-3">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-lg bg-purple-100 text-purple-700 flex items-center justify-center text-xs font-bold font-mono">
                    AI
                  </div>
                  <div>
                    <h3 className="text-xs font-bold text-slate-800">Response for:</h3>
                    <p className="text-[11px] text-slate-500 font-sans italic line-clamp-1">"{lastInquiry}"</p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={handleCopy}
                    className="inline-flex items-center gap-1 px-2.5 py-1 bg-white hover:bg-slate-100 text-slate-600 border border-slate-200 rounded-lg text-xs font-semibold transition-all shadow-2xs cursor-pointer"
                    title="Copy to clipboard"
                  >
                    {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    {copied ? 'Copied' : 'Copy'}
                  </button>
                </div>
              </div>

              {/* Markdown Content */}
              <div className="text-slate-800 text-xs sm:text-sm font-sans leading-relaxed space-y-3 prose prose-slate max-w-none prose-headings:font-bold prose-headings:text-slate-900">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm, remarkMath]}
                  rehypePlugins={[rehypeKatex]}
                  components={{ code: MarkdownCodeRenderer }}
                >
                  {answer}
                </ReactMarkdown>
              </div>

              {/* Convert to Flashcard Archetype Section */}
              <div className="pt-4 border-t border-slate-200/90 space-y-3 bg-white p-4 sm:p-5 rounded-2xl border border-purple-100 shadow-xs">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-lg bg-purple-100 text-purple-700 flex items-center justify-center">
                      <Sparkles className="w-3.5 h-3.5" />
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-slate-800">
                        Convert AI Answer to Flashcard Archetype
                      </h4>
                      <p className="text-[11px] text-slate-500 font-sans">
                        Pick a specialized active recall archetype to save this insight into your SRS library.
                      </p>
                    </div>
                  </div>

                  {saveSuccessMessage && (
                    <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200 animate-fadeIn flex items-center gap-1.5">
                      <Check className="w-3.5 h-3.5" />
                      {saveSuccessMessage}
                    </span>
                  )}
                </div>

                {/* Archetype Selector Chips */}
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-2 pt-1">
                  {cardArchetypes.map((arch) => {
                    const isSelected = selectedCardType === arch.type;
                    return (
                      <button
                        key={arch.type}
                        type="button"
                        onClick={() => setSelectedCardType(arch.type)}
                        className={`px-2.5 py-2 rounded-xl text-left transition-all border cursor-pointer flex flex-col gap-0.5 ${
                          isSelected
                            ? 'bg-purple-600 text-white border-purple-600 shadow-sm ring-2 ring-purple-400/30'
                            : 'bg-slate-50 hover:bg-purple-50/70 text-slate-700 hover:text-purple-900 border-slate-200/80 hover:border-purple-200'
                        }`}
                        title={arch.desc}
                      >
                        <div className="flex items-center gap-1.5 font-bold text-xs">
                          <span>{arch.icon}</span>
                          <span>{arch.label}</span>
                        </div>
                        <span className={`text-[10px] truncate ${isSelected ? 'text-purple-100' : 'text-slate-400 font-sans'}`}>
                          {arch.desc}
                        </span>
                      </button>
                    );
                  })}
                </div>

                {/* Destination Deck and Action Buttons */}
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-2">
                  <div className="flex items-center gap-2 flex-1 max-w-sm">
                    <label className="text-[11px] font-bold text-slate-700 whitespace-nowrap">
                      Target Deck:
                    </label>
                    <select
                      value={selectedDeckId}
                      onChange={(e) => setSelectedDeckId(e.target.value)}
                      className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs text-slate-800 font-sans focus:outline-none focus:border-purple-500 cursor-pointer"
                    >
                      {decks.map((d) => (
                        <option key={d.id} value={d.id}>
                          📁 {d.title} ({d.cards.length} cards)
                        </option>
                      ))}
                      <option value="new">+ Create New Deck ("AI Insights")</option>
                    </select>
                  </div>

                  <div className="flex items-center gap-2 ml-auto">
                    <button
                      type="button"
                      onClick={() => handleSaveCard(selectedCardType)}
                      disabled={isFormattingCard}
                      className="px-3.5 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs uppercase tracking-wider transition-all cursor-pointer inline-flex items-center gap-1.5 shadow-2xs"
                      title="Save question and answer as card immediately"
                    >
                      <PlusCircle className="w-3.5 h-3.5 text-slate-500" />
                      Quick Save
                    </button>

                    <button
                      type="button"
                      onClick={handleAIFormatAndSave}
                      disabled={isFormattingCard}
                      className="px-4 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider transition-all shadow-md disabled:opacity-50 cursor-pointer inline-flex items-center gap-1.5"
                    >
                      {isFormattingCard ? (
                        <>
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                          Structuring as {selectedCardType}...
                        </>
                      ) : (
                        <>
                          <Sparkles className="w-3.5 h-3.5 text-amber-300" />
                          AI Format & Save as {selectedCardType}
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-3.5 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
          <span className="text-[11px] text-slate-400 font-mono hidden sm:inline">
            Press <kbd className="px-1.5 py-0.5 bg-white border border-slate-200 rounded text-slate-600 font-bold">Esc</kbd> to exit
          </span>

          <div className="flex items-center gap-2 ml-auto">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs uppercase tracking-wider transition-all cursor-pointer inline-flex items-center gap-1.5"
            >
              <X className="w-3.5 h-3.5" />
              Exit AI Assistant
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
