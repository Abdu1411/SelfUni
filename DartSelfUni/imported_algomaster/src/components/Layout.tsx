import React, { useState } from 'react';
import { useLocation, useNavigate, Link } from 'react-router-dom';
import { BrainCircuit, ArrowLeft, Sparkles, Flame } from 'lucide-react';
import { useDecks } from '../store';
import { AskAIModal } from './AskAIModal';
import { PomodoroTimer } from './PomodoroTimer';

export function Layout({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { stats } = useDecks();
  const [isAskAiOpen, setIsAskAiOpen] = useState(false);

  const isWorkspaceHome = location.pathname === '/';

  // If on the main workspace page, Home handles its own modern sidebar & topbar layout
  if (isWorkspaceHome) {
    return <>{children}</>;
  }

  // Focus layout for Study Sessions and Lesson Reader views
  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-900 flex flex-col font-sans relative selection:bg-blue-500/20 selection:text-blue-900">
      {/* Decorative ambient color blobs */}
      <div className="fixed top-0 left-1/4 w-[500px] h-[500px] bg-gradient-to-br from-blue-400/10 to-indigo-400/10 rounded-full blur-3xl pointer-events-none -z-10"></div>
      <div className="fixed top-1/3 right-10 w-[450px] h-[450px] bg-gradient-to-br from-cyan-400/10 to-blue-400/10 rounded-full blur-3xl pointer-events-none -z-10"></div>

      {/* Focus Header */}
      <header className="h-16 px-4 sm:px-6 lg:px-8 border-b border-slate-200/80 bg-white/80 backdrop-blur-xl sticky top-0 z-40 flex items-center justify-between shadow-2xs">
        <div className="max-w-[1900px] mx-auto w-full flex items-center justify-between">
          <Link
            to="/"
            onClick={(e) => {
              // Let the Link component handle the navigation
            }}
            className="inline-flex items-center gap-2.5 px-3.5 py-2 rounded-2xl text-xs font-semibold text-slate-600 hover:text-slate-900 hover:bg-slate-50/80 border border-slate-200/60 shadow-2xs transition-all cursor-pointer group"
          >
            <ArrowLeft className="w-4 h-4 text-slate-500 group-hover:-translate-x-0.5 transition-transform" />
            <span>Back to Workspace</span>
          </Link>

          <div className="flex items-center gap-2 sm:gap-3">
            <PomodoroTimer />
            <button
              onClick={() => setIsAskAiOpen(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-gradient-to-r from-purple-50 to-indigo-50 hover:from-purple-100 text-purple-700 border border-purple-200/80 shadow-2xs cursor-pointer group"
              title="Ask AI Companion"
            >
              <Sparkles className="w-3.5 h-3.5 text-purple-600 group-hover:rotate-12 transition-transform" />
              <span>Ask AI</span>
            </button>

            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200/70 shadow-2xs">
              <Flame className="w-4 h-4 text-orange-500 fill-orange-500 animate-pulse" />
              <div className="flex items-baseline gap-1">
                <span className="text-xs font-extrabold text-orange-600 font-mono">{stats.streak}</span>
                <span className="text-[10px] font-bold uppercase tracking-wider text-orange-600/80">Days</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Focus Container */}
      <main className="flex-1 w-full max-w-[1900px] mx-auto px-4 sm:px-6 lg:px-8 py-6 relative z-10">
        {children}
      </main>

      {/* Shortcuts Footer */}
      <footer className="border-t border-slate-200/80 bg-white/60 backdrop-blur-md py-4 px-6 lg:px-8 relative z-10 mt-auto">
        <div className="max-w-[1900px] mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500 font-sans">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-700">AlgoMaster SRS</span>
            <span>•</span>
            <span>Spaced Repetition Flashcard Engine</span>
          </div>

          <div className="flex items-center gap-3 font-mono text-[11px]">
            <span className="text-slate-400">Study Shortcuts:</span>
            <span className="px-1.5 py-0.5 bg-slate-100 border border-slate-200 rounded text-slate-600 font-bold">Space</span>
            <span className="text-slate-400">Flip</span>
            <span className="px-1.5 py-0.5 bg-slate-100 border border-slate-200 rounded text-slate-600 font-bold">1</span>
            <span className="text-slate-400">Again</span>
            <span className="px-1.5 py-0.5 bg-slate-100 border border-slate-200 rounded text-slate-600 font-bold">2</span>
            <span className="text-slate-400">Good</span>
            <span className="px-1.5 py-0.5 bg-slate-100 border border-slate-200 rounded text-slate-600 font-bold">3</span>
            <span className="text-slate-400">Easy</span>
          </div>
        </div>
      </footer>

      <AskAIModal
        isOpen={isAskAiOpen}
        onClose={() => setIsAskAiOpen(false)}
      />
    </div>
  );
}
