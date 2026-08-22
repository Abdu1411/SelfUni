import React, { useState, useRef, useEffect } from 'react';
import {
  Menu,
  Sparkles,
  Plus,
  Bot,
  BookOpen,
  FolderPlus,
  Video,
  PenTool,
  Flame,
  ChevronDown,
  X,
  GraduationCap
} from 'lucide-react';
import { useDecks } from '../store';

import { WorkspaceTab } from './Sidebar';

interface TopBarProps {
  currentTab: WorkspaceTab;
  onToggleMobileSidebar: () => void;
  onOpenAskAi: () => void;
  onOpenNewFolder: () => void;
  onOpenLiveModal: () => void;
  onOpenImportCourse: () => void;
  onNavigateTab: (tab: WorkspaceTab) => void;
}

export function TopBar({
  currentTab,
  onToggleMobileSidebar,
  onOpenAskAi,
  onOpenNewFolder,
  onOpenLiveModal,
  onOpenImportCourse,
  onNavigateTab
}: TopBarProps) {
  const { stats } = useDecks();
  const [isNewMenuOpen, setIsNewMenuOpen] = useState(false);
  const newMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (newMenuRef.current && !newMenuRef.current.contains(event.target as Node)) {
        setIsNewMenuOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const tabLabels: Record<string, string> = {
    dashboard: 'Dashboard & Overview',
    decks: 'Decks & Folders Library',
    lessons: 'CS Lecture Notes',
    live: 'Live Lectures & Streams',
    'deck-generator': 'AI Dart Deck Synthesizer',
    'lesson-generator': 'CS Lecture Notes Generator',
    studio: 'AlgoMaster Creation Studio'
  };

  return (
    <header className="h-16 px-4 sm:px-6 lg:px-8 border-b border-slate-200/80 bg-white/80 backdrop-blur-xl sticky top-0 z-40 flex items-center justify-between shadow-2xs">
      <div className="flex items-center gap-3">
        {/* Mobile menu button */}
        <button
          onClick={onToggleMobileSidebar}
          className="lg:hidden p-2 text-slate-500 hover:text-slate-900 rounded-xl hover:bg-slate-100 cursor-pointer"
          title="Toggle Navigation Menu"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Current Tab Heading */}
        <div className="hidden sm:block">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-widest block">AlgoMaster SRS</span>
          <h2 className="text-sm font-black text-slate-800 tracking-tight">{tabLabels[currentTab]}</h2>
        </div>
      </div>

      {/* Right Actions */}
      <div className="flex items-center gap-3">
        {/* Quick + Create Dropdown */}
        <div className="relative" ref={newMenuRef}>
          <button
            onClick={() => setIsNewMenuOpen(!isNewMenuOpen)}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-sm hover:shadow cursor-pointer"
            aria-expanded={isNewMenuOpen}
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Create</span>
            <ChevronDown className={`w-3 h-3 transition-transform ${isNewMenuOpen ? 'rotate-180' : ''}`} />
          </button>

          {isNewMenuOpen && (
            <div className="absolute right-0 mt-2 w-64 bg-white/98 backdrop-blur-xl border border-slate-200/90 rounded-2xl shadow-xl z-50 p-2 animate-fadeIn space-y-1">
              <div className="px-2 py-1 border-b border-slate-100 mb-1">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400">Quick Create</span>
              </div>

              <button
                onClick={() => {
                  onNavigateTab('deck-generator');
                  setIsNewMenuOpen(false);
                }}
                className="w-full flex items-center gap-3 p-2 rounded-xl text-left hover:bg-blue-50/80 transition-colors cursor-pointer group"
              >
                <div className="w-7 h-7 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200 shadow-2xs group-hover:scale-105 transition-transform">
                  <Bot className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="text-xs font-bold text-slate-800 block">AI Deck Synthesizer</span>
                  <span className="text-[10px] text-slate-400 block font-sans">Generate 30 flashcards</span>
                </div>
              </button>

              <button
                onClick={() => {
                  onNavigateTab('lesson-generator');
                  setIsNewMenuOpen(false);
                }}
                className="w-full flex items-center gap-3 p-2 rounded-xl text-left hover:bg-emerald-50/80 transition-colors cursor-pointer group"
              >
                <div className="w-7 h-7 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center border border-emerald-200 shadow-2xs group-hover:scale-105 transition-transform">
                  <BookOpen className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="text-xs font-bold text-slate-800 block">CS Lecture Notes</span>
                  <span className="text-[10px] text-slate-400 block font-sans">Multi-source synthesis</span>
                </div>
              </button>

              <button
                onClick={() => {
                  onOpenNewFolder();
                  setIsNewMenuOpen(false);
                }}
                className="w-full flex items-center gap-3 p-2 rounded-xl text-left hover:bg-amber-50/80 transition-colors cursor-pointer group"
              >
                <div className="w-7 h-7 rounded-lg bg-amber-50 text-amber-700 flex items-center justify-center border border-amber-200 shadow-2xs group-hover:scale-105 transition-transform">
                  <FolderPlus className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="text-xs font-bold text-slate-800 block">New Folder</span>
                  <span className="text-[10px] text-slate-400 block font-sans">Group related decks & notes</span>
                </div>
              </button>

              <button
                onClick={() => {
                  onOpenLiveModal();
                  setIsNewMenuOpen(false);
                }}
                className="w-full flex items-center gap-3 p-2 rounded-xl text-left hover:bg-rose-50/80 transition-colors cursor-pointer group"
              >
                <div className="w-7 h-7 rounded-lg bg-rose-50 text-rose-700 flex items-center justify-center border border-rose-200 shadow-2xs group-hover:scale-105 transition-transform">
                  <Video className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="text-xs font-bold text-slate-800 block">Live Lecture Stream</span>
                  <span className="text-[10px] text-slate-400 block font-sans">Attach YouTube video masterclass</span>
                </div>
              </button>

              <button
                onClick={() => {
                  onOpenImportCourse();
                  setIsNewMenuOpen(false);
                }}
                className="w-full flex items-center gap-3 p-2 rounded-xl text-left hover:bg-slate-100 transition-colors cursor-pointer group"
              >
                <div className="w-7 h-7 rounded-lg bg-slate-100 text-slate-700 flex items-center justify-center border border-slate-200 shadow-2xs group-hover:scale-105 transition-transform">
                  <GraduationCap className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="text-xs font-bold text-slate-800 block">Import Local Course</span>
                  <span className="text-[10px] text-slate-400 block font-sans">Read OCW/static course folders</span>
                </div>
              </button>
            </div>
          )}
        </div>

        {/* Ask AI Companion Button */}
        <button
          onClick={onOpenAskAi}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-gradient-to-r from-purple-50 to-indigo-50 hover:from-purple-100 hover:to-indigo-100 text-purple-700 border border-purple-200/80 shadow-2xs cursor-pointer group"
          title="Ask AlgoMaster AI"
        >
          <Sparkles className="w-3.5 h-3.5 text-purple-600 group-hover:rotate-12 transition-transform" />
          <span className="hidden sm:inline">Ask AI</span>
        </button>

        {/* Streak Counter */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200/70 shadow-2xs">
          <Flame className="w-4 h-4 text-orange-500 fill-orange-500 animate-pulse" />
          <div className="flex items-baseline gap-1">
            <span className="text-xs font-extrabold text-orange-600 font-mono">{stats.streak}</span>
            <span className="text-[10px] font-bold uppercase tracking-wider text-orange-600/80 hidden sm:inline">
              Days
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}
