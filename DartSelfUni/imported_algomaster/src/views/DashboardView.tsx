import React from 'react';
import { Link } from 'react-router-dom';
import {
  Sparkles,
  Play,
  Layers,
  BookOpen,
  Flame,
  Clock,
  ArrowRight,
  Plus,
  Sliders,
  CheckCircle2,
  BrainCircuit,
  Bot
} from 'lucide-react';
import { ProgressDashboard } from '../components/ProgressDashboard';
import { Deck, Folder, Lesson, CardType, ARCHETYPE_CONFIG } from '../types';
import { WorkspaceTab } from '../components/Sidebar';

interface DashboardViewProps {
  decks: Deck[];
  folders: Folder[];
  lessons: Lesson[];
  onOpenCustomStudy: (deckId?: string) => void;
  onNavigateTab: (tab: WorkspaceTab) => void;
}

export function DashboardView({
  decks,
  folders,
  lessons,
  onOpenCustomStudy,
  onNavigateTab
}: DashboardViewProps) {
  const safeDecks = Array.isArray(decks) ? decks : [];
  const safeLessons = Array.isArray(lessons) ? lessons : [];

  const totalCards = safeDecks.reduce((acc, d) => acc + (d?.cards?.length || 0), 0);
  const dueCardsTotal = safeDecks.reduce(
    (acc, d) => acc + (d?.cards || []).filter((c) => c.nextReview <= Date.now()).length,
    0
  );

  // Find the deck with the most due cards
  const decksWithDue = safeDecks
    .map((d) => ({
      deck: d,
      due: (d.cards || []).filter((c) => c.nextReview <= Date.now()).length
    }))
    .filter((d) => d.due > 0)
    .sort((a, b) => b.due - a.due);

  const topDueDeck = decksWithDue[0]?.deck;

  // Recent decks (last 4)
  const recentDecks = [...safeDecks]
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, 4);

  // Recent lessons (last 3)
  const recentLessons = [...safeLessons]
    .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
    .slice(0, 4);

  const archetypeStats = React.useMemo(() => {
    const allCards = safeDecks.flatMap(d => d.cards || []);
    const counts: Record<string, { total: number; due: number }> = {};

    (Object.keys(ARCHETYPE_CONFIG) as CardType[]).forEach(type => {
      counts[type] = { total: 0, due: 0 };
    });

    allCards.forEach(c => {
      const type = c.type || 'Concept';
      if (!counts[type]) {
        counts[type] = { total: 0, due: 0 };
      }
      counts[type].total += 1;
      if (c.nextReview <= Date.now()) {
        counts[type].due += 1;
      }
    });

    return counts;
  }, [safeDecks]);

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Hero Daily Queue Banner */}
      <div className="relative overflow-hidden bg-gradient-to-r from-blue-600 via-indigo-600 to-cyan-600 rounded-3xl p-6 sm:p-8 text-white shadow-[0_12px_36px_rgba(37,99,235,0.25)] border border-blue-400/30">
        {/* Glow decoration */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-white/10 rounded-full blur-3xl pointer-events-none -mr-20 -mt-20"></div>

        <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div className="space-y-2 max-w-xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/15 backdrop-blur-md border border-white/20 text-xs font-mono font-bold tracking-wide">
              <BrainCircuit className="w-3.5 h-3.5" />
              SM-2 Spaced Repetition Engine
            </div>
            <h1 className="text-2xl sm:text-3xl font-black tracking-tight leading-tight">
              {dueCardsTotal > 0 ? (
                <>
                  You have <span className="underline decoration-cyan-300 decoration-wavy underline-offset-4">{dueCardsTotal} cards</span> due for review today
                </>
              ) : (
                <>🎉 You're all caught up for today!</>
              )}
            </h1>
            <p className="text-sm text-blue-100 font-sans leading-relaxed">
              {dueCardsTotal > 0
                ? 'Review these cards to reinforce your memory and maintain long-term algorithm mastery.'
                : 'Great job! Explore your library, read lecture notes, or synthesize new 30-card decks in the Studio.'}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {dueCardsTotal > 0 && topDueDeck ? (
              <Link
                to={`/deck/${topDueDeck.id}`}
                className="inline-flex items-center gap-2.5 px-6 py-3.5 bg-white text-blue-600 hover:bg-blue-50 rounded-2xl text-sm font-extrabold uppercase tracking-wider transition-all shadow-lg hover:shadow-xl hover:scale-105 active:scale-95"
              >
                <Play className="w-4 h-4 fill-current" />
                Start Review ({dueCardsTotal})
              </Link>
            ) : safeDecks.length > 0 ? (
              <Link
                to={`/deck/${safeDecks[0].id}?mode=custom&filter=all`}
                className="inline-flex items-center gap-2.5 px-6 py-3.5 bg-white text-blue-600 hover:bg-blue-50 rounded-2xl text-sm font-extrabold uppercase tracking-wider transition-all shadow-lg hover:scale-105"
              >
                <Play className="w-4 h-4 fill-current" />
                Quick Review
              </Link>
            ) : null}

            <button
              onClick={() => onNavigateTab('studio')}
              className="inline-flex items-center gap-2 px-5 py-3.5 bg-white/20 hover:bg-white/30 text-white rounded-2xl text-sm font-bold uppercase tracking-wider backdrop-blur-md border border-white/30 transition-all cursor-pointer hover:scale-105"
            >
              <Sparkles className="w-4 h-4" />
              Creation Studio
            </button>
          </div>
        </div>

        {/* Quick stat counters at bottom of banner */}
        <div className="relative z-10 grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-6 border-t border-white/20">
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-blue-200 block">Total Decks</span>
            <span className="text-xl font-extrabold font-mono">{safeDecks.length}</span>
          </div>
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-blue-200 block">Total Flashcards</span>
            <span className="text-xl font-extrabold font-mono">{totalCards}</span>
          </div>
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-blue-200 block">Lecture Notes</span>
            <span className="text-xl font-extrabold font-mono">{safeLessons.length}</span>
          </div>
          <div>
            <span className="text-[10px] font-mono uppercase tracking-widest text-blue-200 block">Folders Organized</span>
            <span className="text-xl font-extrabold font-mono">{folders.length}</span>
          </div>
        </div>
      </div>

      {/* Progress & Retention Dashboard */}
      <ProgressDashboard />

      {/* 🎯 Study by Archetype Hub */}
      <section className="bg-white/95 rounded-3xl border border-slate-200/90 shadow-sm p-6 sm:p-7 backdrop-blur-md relative overflow-hidden">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-5">
          <div>
            <h2 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
              <span className="text-lg">🎯</span>
              Study by Note Archetype
            </h2>
            <p className="text-xs text-slate-500 font-sans mt-0.5">
              Target a specific cognitive skill: time complexity proofs, Cloze blanks, loop invariants, or Dart coding
            </p>
          </div>

          <span className="text-[11px] font-mono font-bold text-slate-400 self-start sm:self-auto bg-slate-100 px-2.5 py-1 rounded-xl">
            9 Note Archetypes
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-3 gap-3.5">
          {(Object.entries(ARCHETYPE_CONFIG) as [CardType, typeof ARCHETYPE_CONFIG[CardType]][]).map(([archKey, meta]) => {
            const stats = archetypeStats[archKey] || { total: 0, due: 0 };
            const hasCards = stats.total > 0;
            const studyUrl = stats.due > 0
              ? `/deck/all?types=${archKey}&filter=due`
              : `/deck/all?types=${archKey}&filter=all`;

            return (
              <div
                key={archKey}
                className={`p-4 rounded-2xl border transition-all duration-200 flex flex-col justify-between ${
                  hasCards
                    ? 'bg-white hover:bg-slate-50/80 border-slate-200/90 hover:border-blue-300 shadow-2xs hover:shadow-md hover:-translate-y-0.5'
                    : 'bg-slate-50/50 border-slate-200/60 opacity-60'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between gap-2 mb-2">
                    <span className="text-xl">{meta.icon}</span>
                    {stats.due > 0 ? (
                      <span className="text-[10px] font-mono font-extrabold px-2 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200">
                        {stats.due} due
                      </span>
                    ) : (
                      <span className="text-[10px] font-mono font-bold text-slate-400">
                        {stats.total} cards
                      </span>
                    )}
                  </div>

                  <h3 className="text-xs font-bold text-slate-900 tracking-tight mb-1">
                    {meta.label}
                  </h3>
                  <span className={`text-[9px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded ${meta.bg} ${meta.text} inline-block mb-3`}>
                    {archKey}
                  </span>
                </div>

                {hasCards ? (
                  <Link
                    to={studyUrl}
                    className="inline-flex items-center justify-center gap-1.5 w-full py-2 bg-slate-100 hover:bg-blue-600 text-slate-700 hover:text-white rounded-xl text-[11px] font-bold transition-all cursor-pointer shadow-2xs group"
                  >
                    <Play className="w-3 h-3 fill-current group-hover:text-white" />
                    <span>Study ({stats.total})</span>
                  </Link>
                ) : (
                  <span className="text-center text-[10px] text-slate-400 py-1.5 font-sans">
                    0 cards created
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </section>

      {/* Recent Activity Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Recent Decks (2 cols) */}
        <div className="lg:col-span-2 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-extrabold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <Layers className="w-4 h-4 text-blue-600" />
              Recent Flashcard Decks
            </h2>
            <button
              onClick={() => onNavigateTab('decks')}
              className="text-xs font-bold text-blue-600 hover:text-blue-700 flex items-center gap-1 hover:underline cursor-pointer"
            >
              View All ({safeDecks.length}) <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {recentDecks.length === 0 ? (
            <div className="bg-white/80 rounded-3xl border border-dashed border-slate-200 p-8 text-center">
              <div className="w-12 h-12 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center mx-auto mb-3 border border-blue-200">
                <Bot className="w-6 h-6" />
              </div>
              <h3 className="text-sm font-bold text-slate-800">No Decks Yet</h3>
              <p className="text-xs text-slate-500 font-sans mt-1 max-w-sm mx-auto">
                Generate your first 30-card deck with the AI Deck Synthesizer in Creation Studio.
              </p>
              <button
                onClick={() => onNavigateTab('deck-generator')}
                className="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-xl text-xs font-bold transition-all shadow-md hover:bg-blue-500 cursor-pointer"
              >
                <Sparkles className="w-3.5 h-3.5" />
                Synthesize First Deck
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {recentDecks.map((deck) => {
                const dueCards = (deck.cards || []).filter((c) => c.nextReview <= Date.now()).length;
                const parentFolder = folders.find((f) => f.id === deck.folderId);

                return (
                  <div
                    key={deck.id}
                    className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:shadow-md hover:border-blue-300 transition-all flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center justify-between gap-2 mb-2">
                        {parentFolder ? (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-slate-100 text-slate-600 border border-slate-200">
                            📁 {parentFolder.name}
                          </span>
                        ) : (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-slate-50 text-slate-400 border border-slate-200/60">
                            Unfiled
                          </span>
                        )}
                        <span className={`text-[10px] font-mono font-bold ${dueCards > 0 ? 'text-blue-600' : 'text-slate-400'}`}>
                          {dueCards > 0 ? `${dueCards} due` : `${deck.cards.length} cards`}
                        </span>
                      </div>

                      <h3 className="font-bold text-sm text-slate-900 line-clamp-1 mb-3">{deck.title}</h3>
                    </div>

                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                      <Link
                        to={dueCards > 0 ? `/deck/${deck.id}` : `/deck/${deck.id}?mode=custom&filter=all`}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 hover:bg-blue-100 text-blue-700 rounded-xl text-xs font-bold transition-all"
                      >
                        <Play className="w-3 h-3 fill-current" />
                        {dueCards > 0 ? 'Study Due' : 'Review'}
                      </Link>

                      <button
                        onClick={() => onOpenCustomStudy(deck.id)}
                        className="p-1.5 text-slate-400 hover:text-blue-600 rounded-lg hover:bg-slate-50 cursor-pointer"
                        title="Custom Study Options"
                      >
                        <Sliders className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Recent Lecture Notes (1 col) */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-extrabold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-emerald-600" />
              Recent CS Notes
            </h2>
            <button
              onClick={() => onNavigateTab('lessons')}
              className="text-xs font-bold text-emerald-600 hover:text-emerald-700 flex items-center gap-1 hover:underline cursor-pointer"
            >
              All ({safeLessons.length}) <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {recentLessons.length === 0 ? (
            <div className="bg-white/80 rounded-3xl border border-dashed border-slate-200 p-6 text-center">
              <p className="text-xs text-slate-500 font-sans">No lecture notes generated yet.</p>
              <button
                onClick={() => onNavigateTab('lesson-generator')}
                className="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-xl text-xs font-bold transition-all hover:bg-emerald-100 cursor-pointer"
              >
                <Plus className="w-3 h-3" />
                Generate Notes
              </button>
            </div>
          ) : (
            <div className="space-y-3">
              {recentLessons.map((lesson) => (
                <Link
                  key={lesson.id}
                  to={`/lesson/${lesson.id}`}
                  className="block bg-white/95 rounded-2xl border border-slate-200/90 p-4 shadow-2xs hover:shadow-sm hover:border-emerald-300 transition-all group"
                >
                  <div className="flex items-center gap-2 mb-1.5">
                    <span className="px-2 py-0.5 rounded-full text-[9px] font-mono font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                      {lesson.topic}
                    </span>
                    <span className="text-[10px] text-slate-400 font-mono ml-auto">
                      {new Date(lesson.createdAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                    </span>
                  </div>
                  <h4 className="font-bold text-xs text-slate-900 group-hover:text-emerald-600 transition-colors line-clamp-1">
                    {lesson.title}
                  </h4>
                  <p className="text-[11px] text-slate-500 font-sans line-clamp-2 mt-1">
                    {lesson.content.replace(/[#*`_$-]/g, '').slice(0, 90)}...
                  </p>
                </Link>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
