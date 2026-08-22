import React, { useState, useEffect, useMemo } from 'react';
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom';
import { useDecks } from '../store';
import { calculateNextReview, Grade } from '../srs';
import { Card, CardType, ARCHETYPE_CONFIG } from '../types';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import { ArrowLeft, CheckCircle2, Code2, Loader2, Sparkles, Sliders, Play, RotateCcw, Bot, Edit3 } from 'lucide-react';
import { CodeEditor } from '../components/CodeEditor';
import { CustomStudyModal } from '../components/CustomStudyModal';
import { EditCardModal } from '../components/modals/EditCardModal';
import { CodeBlock, MarkdownCodeRenderer } from '../components/CodeBlock';
import { useActiveView } from '../context/ActiveViewContext';

interface SessionCard extends Card {
  deckId: string;
  isRequeued?: boolean;
}

/**
 * Formats front text for Cloze deletion cards, replacing {{c1::answer}}, {{c1:answer}},
 * or any {{...}} with "[ ... ]" to hide the answer during active recall.
 */
function formatClozeQuestion(frontText: string): string {
  if (!frontText) return '';
  return frontText.replace(/{{(?:c\d+[:]{1,2}\s*)?(.*?)}}/gs, () => {
    return '`[ ... ]`';
  });
}

/**
 * Formats front text when answer is revealed, showing the full sentence with the
 * revealed answer emphasized in bold (**answer**).
 */
function formatClozeAnswer(frontText: string): string {
  if (!frontText) return '';
  return frontText.replace(/{{(?:c\d+[:]{1,2}\s*)?(.*?)}}/gs, (_match, content) => {
    const parts = (content || '').split(/::|(?<=\w):(?=\w)/);
    const answer = (parts[0] || content || '').trim();
    return `**${answer}**`;
  });
}

export function StudySession() {
  const { deckId } = useParams<{ deckId: string }>();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { decks, folders, updateCard, deleteCardFromDeck, logReview } = useDecks();
  const { setActiveResource, openAskAi } = useActiveView();

  const isUniversal = deckId === 'universal' || deckId === 'all' || deckId === 'master';
  const isAllDecks = isUniversal;
  const isFolder = deckId?.startsWith('folder-');
  const folderId = isFolder ? deckId.replace('folder-', '') : null;
  const currentFolder = folders?.find(f => f.id === folderId);
  const currentDeck = isUniversal
    ? { id: 'universal', title: 'Universal Master Deck', cards: decks.flatMap(d => d.cards), createdAt: Date.now() } as any
    : decks.find(d => d.id === deckId);

  const [sessionCards, setSessionCards] = useState<SessionCard[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const [code, setCode] = useState('');
  const [completedCount, setCompletedCount] = useState(0);
  const [sessionFinished, setSessionFinished] = useState(false);

  // Custom study & edit modal state
  const [isCustomModalOpen, setIsCustomModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);

  const currentCard = sessionCards[currentIndex];

  useEffect(() => {
    if (currentCard) {
      setActiveResource({
        title: `${currentDeck?.title || 'Study Session'} — ${currentCard.type} Card`,
        type: 'flashcard',
        contextText: `CURRENT FLASHCARD BEING STUDIED BY USER:
Deck Name: ${currentDeck?.title || 'Mixed Study Session'}
Card Type: ${currentCard.type}
Front Question:
${currentCard.front}

${showAnswer ? `Back Solution:\n${currentCard.back}\n` : 'Back Solution: [Currently hidden during recall]\n'}
${currentCard.codeSnippet ? `Sample Code Snippet:\n\`\`\`dart\n${currentCard.codeSnippet}\n\`\`\`\n` : ''}
${code ? `User's Current Code in Editor Workspace:\n\`\`\`dart\n${code}\n\`\`\`\n` : ''}`,
        suggestedPrompts: [
          `Explain the key invariant and intuition for this ${currentCard.type} card`,
          'How does this algorithm execute step-by-step in memory?',
          'What is the tightest time and space complexity bound?',
          'Can you review or debug my code in the editor?'
        ]
      });
    }
    return () => setActiveResource(null);
  }, [currentCard, currentDeck?.title, showAnswer, code, setActiveResource]);

  // Evaluation state
  const [isEvaluating, setIsEvaluating] = useState(false);
  const [evalResult, setEvalResult] = useState<{ grade: Grade; feedback: string } | null>(null);

  // Read URL query parameters
  const mode = searchParams.get('mode') || 'due';
  const filter = searchParams.get('filter') || (mode === 'all' ? 'all' : 'due');
  const typesParam = searchParams.get('types');
  const typeParam = searchParams.get('type');
  const limitParam = searchParams.get('limit');
  const shuffleParam = searchParams.get('shuffle');
  const updateSrsParam = searchParams.get('updateSrs');

  const shouldUpdateSrs = updateSrsParam !== 'false';

  const effectiveTypes = useMemo(() => {
    return (typesParam || typeParam || '')
      .split(',')
      .map(t => t.trim())
      .filter(Boolean) as CardType[];
  }, [typesParam, typeParam]);

  const sessionKey = `${deckId || ''}?${searchParams.toString()}`;
  const loadedSessionKeyRef = React.useRef<string | null>(null);

  const loadCards = () => {
    if (decks.length === 0) return;

    let pool: SessionCard[] = [];
    if (isAllDecks) {
      pool = decks.flatMap(d => d.cards.map(c => ({ ...c, deckId: d.id })));
    } else if (isFolder && folderId) {
      pool = decks.filter(d => d.folderId === folderId).flatMap(d => d.cards.map(c => ({ ...c, deckId: d.id })));
    } else if (currentDeck) {
      pool = currentDeck.cards.map(c => ({ ...c, deckId: currentDeck.id }));
    }

    // Filter by archetype if specified
    if (effectiveTypes.length > 0) {
      pool = pool.filter(c => effectiveTypes.includes(c.type));
    }

    // Apply due / hardest / newest filter
    if (filter === 'due') {
      pool = pool.filter(c => c.nextReview <= Date.now());
      pool.sort((a, b) => (a.nextReview || 0) - (b.nextReview || 0));
    } else if (filter === 'hardest') {
      pool = [...pool].sort((a, b) => a.ease - b.ease || a.reps - b.reps);
    } else if (filter === 'newest') {
      pool = [...pool].sort((a, b) => ((b as any).createdAt || 0) - ((a as any).createdAt || 0));
    }

    // Shuffle if explicitly requested via query parameter
    if (shuffleParam === 'true') {
      pool = [...pool].sort(() => Math.random() - 0.5);
    }

    // Apply limit if specified
    if (limitParam && !isNaN(Number(limitParam))) {
      pool = pool.slice(0, Number(limitParam));
    }

    setSessionCards(pool);
    setCurrentIndex(0);
    setShowAnswer(false);
    setCode('');
    setCompletedCount(0);
    setSessionFinished(false);
    setEvalResult(null);
  };

  useEffect(() => {
    if (decks.length === 0) return;
    if (loadedSessionKeyRef.current !== sessionKey) {
      loadedSessionKeyRef.current = sessionKey;
      loadCards();
    }
  }, [decks.length, sessionKey]);

  const isImplementationCard =
    currentCard?.type === 'Implementation' ||
    /^(write|implement|create|code|complete|develop|build|construct|solve|program)\s+(a\s+|an\s+|the\s+)?(dart\s+)?(function|class|method|algorithm|solution|program|tree|graph|queue|stack|heap|code|snippet)\b/i.test(
      currentCard?.front || ''
    ) ||
    /\b(implement\s+the\s+following|write\s+a\s+dart\s+function|write\s+code\s+to|code\s+the\s+algorithm|implement\s+in\s+dart|coding\s+challenge)\b/i.test(
      currentCard?.front || ''
    );

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const activeTag = document.activeElement?.tagName.toLowerCase();
      if (activeTag === 'input' || activeTag === 'textarea') return;

      if (e.key === 'Escape') {
        navigate('/');
        return;
      }

      if (e.code === 'Space' && !showAnswer && !isImplementationCard) {
        e.preventDefault();
        setShowAnswer(true);
      } else if (showAnswer) {
        if (e.key === '1') {
          handleGrade('Again');
        } else if (e.key === '2') {
          handleGrade('Good');
        } else if (e.key === '3') {
          handleGrade('Easy');
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [showAnswer, isImplementationCard, currentIndex, sessionCards]);

  if (!isAllDecks && !isFolder && !currentDeck && decks.length > 0) {
    return <div className="p-8 text-center text-slate-500 font-sans">Deck or folder not found</div>;
  }

  // Finished or Empty State
  if (sessionFinished || sessionCards.length === 0 || !currentCard) {
    const totalDeckCards = isAllDecks
      ? decks.reduce((acc, d) => acc + d.cards.length, 0)
      : isFolder && folderId
      ? decks.filter(d => d.folderId === folderId).reduce((acc, d) => acc + d.cards.length, 0)
      : currentDeck?.cards.length || 0;

    return (
      <div className="max-w-xl mx-auto mt-16 bg-white/95 rounded-3xl p-10 text-center shadow-[0_12px_40px_rgba(0,0,0,0.06)] border border-slate-200/90 relative overflow-hidden">
        <div
          className="absolute inset-0 pointer-events-none opacity-40"
          style={{ backgroundImage: 'radial-gradient(circle at center, #dbeafe 0%, transparent 70%)' }}
        ></div>
        <div className="relative z-10">
          <div className="w-16 h-16 bg-blue-50 text-blue-600 border border-blue-200 rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-[0_4px_20px_rgba(37,99,235,0.15)]">
            <CheckCircle2 className="w-8 h-8" />
          </div>

          <h2 className="text-2xl font-extrabold text-slate-900 mb-2 italic">
            {completedCount > 0 ? 'Dart Calibration Complete!' : "You're all caught up!"}
          </h2>

          <p className="text-slate-600 mb-8 font-sans text-sm leading-relaxed max-w-md mx-auto">
            {completedCount > 0
              ? `You mastered ${completedCount} Dart card${completedCount > 1 ? 's' : ''} in this study session.`
              : 'No cards are currently due in this queue. You can practice all cards or customize a focused Dart session below.'}
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center mb-6">
            <button
              onClick={() => {
                loadedSessionKeyRef.current = null;
                loadCards();
              }}
              className="inline-flex items-center justify-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-all shadow-[0_4px_16px_rgba(37,99,235,0.25)] cursor-pointer"
            >
              <RotateCcw className="w-4 h-4" />
              Study Again
            </button>

            {totalDeckCards > 0 && (
              <button
                onClick={() => {
                  loadedSessionKeyRef.current = null;
                  navigate(isAllDecks ? '/deck/all?mode=custom&filter=all' : `/deck/${deckId}?mode=custom&filter=all`);
                }}
                className="inline-flex items-center justify-center gap-2 px-6 py-3 bg-white hover:bg-slate-50 text-slate-700 font-bold text-xs uppercase tracking-wider rounded-xl border border-slate-200 shadow-2xs transition-all cursor-pointer"
              >
                <Sparkles className="w-4 h-4 text-blue-600" />
                Review All ({totalDeckCards} Cards)
              </button>
            )}

            <button
              onClick={() => setIsCustomModalOpen(true)}
              className="inline-flex items-center justify-center gap-2 px-6 py-3 bg-white hover:bg-slate-50 text-blue-600 font-bold text-xs uppercase tracking-wider rounded-xl border border-slate-200 shadow-2xs transition-all cursor-pointer"
            >
              <Sliders className="w-4 h-4" />
              Custom Study
            </button>
          </div>

          <div className="flex justify-center">
            <Link
              to="/"
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-semibold text-slate-600 hover:text-slate-900 hover:bg-slate-50/80 border border-slate-200/60 shadow-2xs transition-all cursor-pointer"
            >
              <ArrowLeft className="w-4 h-4 text-slate-500" />
              <span>Back to Workspace</span>
            </Link>
          </div>
        </div>

        <CustomStudyModal
          isOpen={isCustomModalOpen}
          onClose={() => setIsCustomModalOpen(false)}
          decks={decks}
          initialDeckId={deckId}
        />
      </div>
    );
  }

  const handleGrade = (grade: Grade) => {
    if (!currentCard) return;

    if (shouldUpdateSrs) {
      const updatedCard = calculateNextReview(currentCard, grade);
      updateCard(currentCard.deckId, updatedCard);
      logReview(currentCard.deckId, currentCard.id, grade);
    }

    setCompletedCount(prev => prev + 1);

    if (grade === 'Again') {
      // Re-queue card to be reviewed again at the end of this same session (Anki SM-2 style)
      const requeuedCard: SessionCard = { ...currentCard, isRequeued: true };
      setSessionCards(prev => [...prev, requeuedCard]);
      setCurrentIndex(prev => prev + 1);
      setShowAnswer(false);
      setCode('');
      setEvalResult(null);
    } else {
      // Move to next card
      if (currentIndex < sessionCards.length - 1) {
        setCurrentIndex(prev => prev + 1);
        setShowAnswer(false);
        setCode('');
        setEvalResult(null);
      } else {
        setSessionFinished(true);
      }
    }
  };

  const handleSubmitCode = async () => {
    if (!code.trim()) return;
    setIsEvaluating(true);
    setEvalResult(null);

    try {
      const res = await fetch('/api/evaluate-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: currentCard.front,
          code,
          expectedSolution: currentCard.back,
          language: 'dart'
        }),
      });
      const data = await res.json();
      if (!res.ok || data.error) {
        throw new Error(data.error || 'Evaluation failed');
      }
      setEvalResult(data);
      setShowAnswer(true);
    } catch (error: any) {
      console.error(error);
      setEvalResult({
        grade: 'Good',
        feedback: `### Submitted Implementation:\n\`\`\`dart\n${code}\n\`\`\`\n\n*(AI Evaluation note: ${error.message || 'Could not connect to evaluator'}. Please review against the official Dart solution below.)*`
      });
      setShowAnswer(true);
    } finally {
      setIsEvaluating(false);
    }
  };

  // Get current deck title for card
  const originDeck = decks.find(d => d.id === currentCard.deckId);

  return (
    <div className="max-w-3xl mx-auto pb-20 mt-4">
      {/* Session Top Bar */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          {effectiveTypes.length > 0 ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-blue-50 text-blue-700 border border-blue-200 shadow-2xs">
              <span>🎯</span>
              <span>{effectiveTypes.join(', ')} Archetype</span>
            </span>
          ) : filter !== 'due' ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-amber-50 text-amber-700 border border-amber-200">
              ⚡ Custom Study ({filter})
            </span>
          ) : null}
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          <button
            onClick={() => setIsCustomModalOpen(true)}
            className="text-slate-500 hover:text-blue-600 inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider transition-colors px-2.5 py-1 rounded-lg hover:bg-slate-100 cursor-pointer"
          >
            <Sliders className="w-3.5 h-3.5" /> Options
          </button>
          
          <div className="flex items-center gap-1.5">
            {currentCard?.isRequeued && (
              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-rose-50 text-rose-700 border border-rose-200 animate-pulse">
                <span>🔄</span>
                <span>Repeat Queue</span>
              </span>
            )}
            <span className="text-xs font-mono font-bold text-slate-700 bg-white px-3 py-1 rounded-full border border-slate-200 shadow-2xs">
              {currentIndex + 1} / {sessionCards.length} <span className="text-slate-400">({sessionCards.length - currentIndex} left)</span>
            </span>
          </div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="w-full h-2 bg-slate-200/80 rounded-full mb-6 overflow-hidden shadow-inner">
        <div
          className="h-full bg-gradient-to-r from-blue-600 via-indigo-600 to-cyan-500 transition-all duration-300 rounded-full"
          style={{ width: `${((currentIndex + 1) / sessionCards.length) * 100}%` }}
        ></div>
      </div>

      {/* Main Flashcard */}
      {currentCard && (() => {
        const cardType = currentCard.type || 'Concept';
        const typeMeta = ARCHETYPE_CONFIG[cardType] || ARCHETYPE_CONFIG.Concept;

        return (
          <div className="bg-white rounded-3xl shadow-[0_12px_45px_rgba(0,0,0,0.06)] border border-slate-200/90 overflow-hidden relative">
            {/* Card Header (Type Badge & Deck info) */}
            <div className="px-8 py-4 border-b border-slate-100 bg-slate-50/80 flex justify-between items-center relative z-10">
              <div className="flex items-center gap-2">
                <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-extrabold uppercase tracking-wider ${typeMeta.bg} ${typeMeta.text} ${typeMeta.border} border shadow-2xs`}>
                  <span>{typeMeta.icon}</span>
                  <span>{typeMeta.label}</span>
                </span>
                <span className="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-slate-100 text-slate-600 border border-slate-200/60">
                  Dart 3.x
                </span>
                {currentCard.isRequeued && (
                  <span className="px-2 py-0.5 rounded text-[10px] font-extrabold bg-rose-50 text-rose-700 border border-rose-200 flex items-center gap-1">
                    <span>🔄</span>
                    <span>Re-learning</span>
                  </span>
                )}
                {isUniversal && originDeck && (
                  <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-sans font-bold bg-purple-50 text-purple-700 border border-purple-200 truncate max-w-[220px]" title={`Origin Deck: ${originDeck.title}`}>
                    <span>🗂️</span>
                    <span>{originDeck.title}</span>
                  </span>
                )}
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setIsEditModalOpen(true)}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold text-slate-600 hover:text-blue-600 hover:bg-blue-50 border border-slate-200/80 transition-colors cursor-pointer shadow-2xs"
                  title="Edit this flashcard"
                >
                  <Edit3 className="w-3.5 h-3.5" />
                  <span>Edit Card</span>
                </button>
                <span className="text-slate-400 font-mono text-[10px]">ID: {currentCard.id.split('-')[0].toUpperCase()}</span>
              </div>
            </div>

            {/* Front Question Content */}
            <div className="px-8 py-10 relative z-10">
              {/* Type Category Indicator */}
              <div className="mb-4 inline-flex items-center gap-2 px-3 py-1 rounded-xl text-xs font-bold bg-slate-50 border border-slate-200 text-slate-700 shadow-2xs">
                <span>{typeMeta.icon}</span>
                <span className="text-[10px] uppercase font-extrabold text-slate-400 tracking-wider">Archetype:</span>
                <span className={`font-black ${typeMeta.text}`}>{typeMeta.label}</span>
              </div>

              <div className="prose prose-slate prose-blue max-w-none text-slate-800 leading-relaxed font-sans mb-6">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm, remarkMath]}
                  rehypePlugins={[rehypeKatex]}
                  components={{ code: MarkdownCodeRenderer }}
                >
                  {currentCard.type === 'Cloze' || currentCard.front.includes('{{')
                    ? formatClozeQuestion(currentCard.front)
                    : currentCard.front}
                </ReactMarkdown>
              </div>

          {currentCard.codeSnippet && !isImplementationCard && !currentCard.front.includes('```') && (
            <div className="mt-4 mb-2">
              <CodeBlock code={currentCard.codeSnippet} language="dart" />
            </div>
          )}

          {/* Dart Code Implementation Area */}
          {isImplementationCard && !showAnswer && (
            <div className="mt-8 space-y-4">
              <div className="border border-slate-200 rounded-2xl overflow-hidden bg-white shadow-sm focus-within:border-blue-500 transition-colors">
                <div className="bg-slate-50 px-4 py-2.5 text-xs font-mono font-bold text-slate-700 flex items-center justify-between border-b border-slate-200">
                  <div className="flex items-center gap-2 text-blue-600">
                    <Code2 className="w-4 h-4" />
                    <span>Dart Implementation Workspace</span>
                  </div>
                  <span className="text-[10px] text-slate-400 font-sans uppercase font-bold">Language: Dart 3.x</span>
                </div>
                <div className="p-4">
                  <CodeEditor
                    value={code}
                    onChange={setCode}
                    language="dart"
                    placeholder="// Write your Dart implementation here... (supports 2-space Tab indentation)"
                    minHeight="200px"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2.5">
                <button
                  onClick={handleSubmitCode}
                  disabled={isEvaluating || !code.trim()}
                  className="flex-1 py-3.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs uppercase tracking-widest rounded-xl transition-all shadow-[0_4px_16px_rgba(37,99,235,0.3)] disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none inline-flex items-center justify-center gap-2 cursor-pointer"
                >
                  {isEvaluating ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" /> Evaluating Dart Code with AI...
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4" /> Submit Dart Solution for Evaluation
                    </>
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => setShowAnswer(true)}
                  className="px-4 py-3.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition-colors cursor-pointer"
                >
                  Skip to Solution
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Back / Answer Area */}
        {!isImplementationCard && !showAnswer ? (
          <div className="px-8 py-6 bg-slate-50 border-t border-slate-100 relative z-10">
            <button
              onClick={() => setShowAnswer(true)}
              className="w-full py-4 bg-white hover:bg-blue-50 border-2 border-blue-500/30 hover:border-blue-500 text-blue-600 font-extrabold uppercase tracking-widest text-xs rounded-2xl transition-all shadow-xs flex items-center justify-center gap-2 cursor-pointer"
            >
              <span>Show Answer</span>
              <kbd className="px-2 py-0.5 bg-slate-100 border border-slate-200 rounded text-[10px] text-slate-500 font-mono font-bold">Space</kbd>
            </button>
          </div>
        ) : showAnswer ? (
          <div className="border-t border-slate-100 bg-slate-50/50 relative z-10 animate-fadeIn">
            <div className="px-8 py-8 border-b border-slate-100 space-y-6">
              {/* AI Evaluation Grade & Feedback Banner */}
              {isImplementationCard && evalResult && (
                <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Sparkles className="w-4 h-4 text-blue-600" />
                      <h4 className="text-xs font-black uppercase tracking-wider text-slate-800">
                        AI Code Evaluation Feedback
                      </h4>
                    </div>
                    <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl bg-slate-50 border border-slate-200 text-xs font-bold shadow-2xs">
                      <span className="text-slate-500">Grade:</span>
                      <span
                        className={`font-mono font-extrabold ${
                          evalResult.grade === 'Easy'
                            ? 'text-emerald-600'
                            : evalResult.grade === 'Good'
                            ? 'text-blue-600'
                            : 'text-rose-600'
                        }`}
                      >
                        {evalResult.grade}
                      </span>
                    </div>
                  </div>

                  <div className="prose prose-sm prose-slate max-w-none bg-slate-50/70 p-4 rounded-xl border border-slate-100 leading-relaxed font-sans">
                    <ReactMarkdown
                      remarkPlugins={[remarkGfm, remarkMath]}
                      rehypePlugins={[rehypeKatex]}
                      components={{ code: MarkdownCodeRenderer }}
                    >
                      {evalResult.feedback}
                    </ReactMarkdown>
                  </div>
                </div>
              )}

              {/* Official Solution & Analysis */}
              <div className="prose prose-slate prose-blue max-w-none bg-white p-6 rounded-2xl border border-slate-200 shadow-2xs">
                <h3 className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest mb-3 not-prose">
                  {isImplementationCard ? 'Official Dart 3.x Solution & Invariant' : 'Dart Analysis & Solution'}
                </h3>

                {(currentCard.type === 'Cloze' || currentCard.front.includes('{{')) ? (
                  <div className="not-prose">
                    <div className="p-5 bg-emerald-50/80 border border-emerald-200 rounded-2xl text-emerald-950 text-sm leading-relaxed shadow-2xs">
                      <span className="text-[10px] font-extrabold uppercase tracking-wider text-emerald-700 block mb-1.5">
                        Revealed Statement:
                      </span>
                      <div className="prose prose-sm prose-emerald max-w-none text-slate-800 leading-relaxed font-sans">
                        <ReactMarkdown
                          remarkPlugins={[remarkGfm, remarkMath]}
                          rehypePlugins={[rehypeKatex]}
                          components={{ code: MarkdownCodeRenderer }}
                        >
                          {formatClozeAnswer(currentCard.front)}
                        </ReactMarkdown>
                      </div>
                    </div>
                  </div>
                ) : (
                  <ReactMarkdown
                    remarkPlugins={[remarkGfm, remarkMath]}
                    rehypePlugins={[rehypeKatex]}
                    components={{ code: MarkdownCodeRenderer }}
                  >
                    {currentCard.back}
                  </ReactMarkdown>
                )}
              </div>
            </div>

            {/* SRS Calibration Buttons */}
            <div className="px-8 py-6">
              <p className="text-[11px] uppercase tracking-wider text-slate-500 font-bold text-center mb-4">
                Rate Recall {shouldUpdateSrs ? '' : '(Practice Mode - No Interval Change)'}
              </p>
              <div className="grid grid-cols-3 gap-4">
                <button
                  onClick={() => handleGrade('Again')}
                  className="py-3.5 px-3 bg-rose-50 hover:bg-rose-100/90 border border-rose-200 text-rose-700 font-bold rounded-2xl transition-all flex flex-col items-center shadow-2xs group cursor-pointer hover:-translate-y-0.5"
                >
                  <div className="flex items-center gap-1.5 mb-0.5">
                    <span className="text-xs uppercase tracking-wider">Again</span>
                    <kbd className="px-1.5 py-0.2 bg-white/80 border border-rose-300 rounded text-[9px] font-mono text-rose-600">1</kbd>
                  </div>
                  <span className="text-[10px] text-rose-500 font-mono">&lt; 10 min</span>
                </button>
                <button
                  onClick={() => handleGrade('Good')}
                  className="py-3.5 px-3 bg-blue-50 hover:bg-blue-100/90 border border-blue-200 text-blue-700 font-bold rounded-2xl transition-all flex flex-col items-center shadow-2xs group cursor-pointer hover:-translate-y-0.5"
                >
                  <div className="flex items-center gap-1.5 mb-0.5">
                    <span className="text-xs uppercase tracking-wider">Good</span>
                    <kbd className="px-1.5 py-0.2 bg-white/80 border border-blue-300 rounded text-[9px] font-mono text-blue-600">2</kbd>
                  </div>
                  <span className="text-[10px] text-blue-500 font-mono">1-2 days</span>
                </button>
                <button
                  onClick={() => handleGrade('Easy')}
                  className="py-3.5 px-3 bg-emerald-50 hover:bg-emerald-100/90 border border-emerald-200 text-emerald-700 font-bold rounded-2xl transition-all flex flex-col items-center shadow-2xs group cursor-pointer hover:-translate-y-0.5"
                >
                  <div className="flex items-center gap-1.5 mb-0.5">
                    <span className="text-xs uppercase tracking-wider">Easy</span>
                    <kbd className="px-1.5 py-0.2 bg-white/80 border border-emerald-300 rounded text-[9px] font-mono text-emerald-600">3</kbd>
                  </div>
                  <span className="text-[10px] text-emerald-500 font-mono">4+ days</span>
                </button>
              </div>
            </div>
          </div>
        ) : null}
            </div>
          );
        })()}

      {/* Custom Study Modal */}
      <CustomStudyModal
        isOpen={isCustomModalOpen}
        onClose={() => setIsCustomModalOpen(false)}
        decks={decks}
        initialDeckId={deckId}
      />

      {/* Edit Current Card Modal */}
      {currentCard && (
        <EditCardModal
          card={currentCard}
          isOpen={isEditModalOpen}
          onClose={() => setIsEditModalOpen(false)}
          onSave={(updatedCard) => {
            updateCard(currentCard.deckId, updatedCard);
            setSessionCards(prev =>
              prev.map((c, i) => (i === currentIndex ? { ...updatedCard, deckId: c.deckId } : c))
            );
          }}
          onDelete={(cardId) => {
            deleteCardFromDeck(currentCard.deckId, cardId);
            setSessionCards(prev => {
              const updated = prev.filter(c => c.id !== cardId);
              if (updated.length === 0) {
                setSessionFinished(true);
              } else if (currentIndex >= updated.length) {
                setCurrentIndex(updated.length - 1);
              }
              return updated;
            });
          }}
        />
      )}
    </div>
  );
}
