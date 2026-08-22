import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  BrainCircuit,
  LayoutDashboard,
  Layers,
  BookOpen,
  Video,
  Sparkles,
  FolderGit2,
  FolderPlus,
  Flame,
  Play,
  ChevronRight,
  Plus,
  Sliders,
  Folder as FolderIcon,
  GraduationCap,
  Trash2
} from 'lucide-react';
import { useDecks } from '../store';
import { Folder, Course } from '../types';

export type WorkspaceTab =
  | 'dashboard'
  | 'decks'
  | 'lessons'
  | 'live'
  | 'deck-generator'
  | 'lesson-generator'
  | 'studio';

interface SidebarProps {
  currentTab: WorkspaceTab;
  activeFolderId: string | null;
  onSelectTab: (tab: WorkspaceTab) => void;
  onSelectFolder: (folderId: string | null) => void;
  onOpenNewFolder: () => void;
  onOpenAskAi: () => void;
  isMobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export function Sidebar({
  currentTab,
  activeFolderId,
  onSelectTab,
  onSelectFolder,
  onOpenNewFolder,
  onOpenAskAi,
  isMobileOpen,
  onCloseMobile
}: SidebarProps) {
  const { decks, folders, lessons, courses, stats, deleteCourse } = useDecks();

  const safeDecks = Array.isArray(decks) ? decks : [];
  const safeFolders = Array.isArray(folders) ? folders : [];
  const safeLessons = Array.isArray(lessons) ? lessons : [];
  const safeCourses = Array.isArray(courses) ? courses : [];

  const totalDue = safeDecks.reduce(
    (acc, d) => acc + (d?.cards || []).filter((c) => c.nextReview <= Date.now()).length,
    0
  );

  const topDueDeck = safeDecks
    .map((d) => ({
      deck: d,
      due: (d.cards || []).filter((c) => c.nextReview <= Date.now()).length
    }))
    .filter((d) => d.due > 0)
    .sort((a, b) => b.due - a.due)[0]?.deck;

  const navItems = [
    {
      id: 'dashboard' as const,
      label: 'Dashboard',
      icon: LayoutDashboard,
      badge: null,
      color: 'text-blue-600',
      activeBg: 'bg-blue-50 text-blue-700 border-blue-200/80 shadow-2xs font-bold'
    },
    {
      id: 'decks' as const,
      label: 'Decks & Folders',
      icon: Layers,
      badge: safeDecks.length,
      color: 'text-indigo-600',
      activeBg: 'bg-indigo-50 text-indigo-700 border-indigo-200/80 shadow-2xs font-bold'
    },
    {
      id: 'lessons' as const,
      label: 'Notes & PDFs',
      icon: BookOpen,
      badge: safeLessons.length,
      color: 'text-emerald-600',
      activeBg: 'bg-emerald-50 text-emerald-700 border-emerald-200/80 shadow-2xs font-bold'
    },
    {
      id: 'live' as const,
      label: 'Live Lectures',
      icon: Video,
      badge: safeLessons.filter((l) => !!l.videoUrl).length || null,
      color: 'text-rose-600',
      activeBg: 'bg-rose-50 text-rose-700 border-rose-200/80 shadow-2xs font-bold'
    },
    {
      id: 'deck-generator' as const,
      label: 'AI Deck Synthesizer',
      icon: Sparkles,
      badge: '30 Cards',
      color: 'text-blue-600',
      activeBg: 'bg-blue-50 text-blue-700 border-blue-200/80 shadow-2xs font-bold'
    },
    {
      id: 'lesson-generator' as const,
      label: 'Notes Generator',
      icon: BookOpen,
      badge: 'Multi-Source',
      color: 'text-emerald-600',
      activeBg: 'bg-emerald-50 text-emerald-700 border-emerald-200/80 shadow-2xs font-bold'
    }
  ];

  const handleNavClick = (tabId: typeof currentTab) => {
    onSelectTab(tabId);
    if (onCloseMobile) onCloseMobile();
  };

  return (
    <aside
      className={`fixed lg:sticky top-0 left-0 h-screen w-72 bg-white/95 backdrop-blur-xl border-r border-slate-200/90 z-50 flex flex-col justify-between transition-transform duration-300 ${
        isMobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
      }`}
    >
      {/* Top Branding */}
      <div>
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <Link
            to="/"
            onClick={() => handleNavClick('dashboard')}
            className="flex items-center gap-3 group"
          >
            <div className="w-10 h-10 bg-gradient-to-br from-blue-600 via-indigo-600 to-cyan-500 rounded-2xl flex items-center justify-center shadow-[0_4px_16px_rgba(37,99,235,0.25)] group-hover:scale-105 transition-transform">
              <BrainCircuit className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <h1 className="text-base font-extrabold tracking-tight text-slate-900 uppercase italic">
                  AlgoMaster <span className="bg-gradient-to-r from-blue-600 to-cyan-500 bg-clip-text text-transparent">SRS</span>
                </h1>
              </div>
              <span className="text-[10px] font-mono text-slate-400 block tracking-wider">
                Dart & CS Accelerator
              </span>
            </div>
          </Link>
        </div>

        {/* Primary Navigation Tabs */}
        <div className="px-3 py-4 space-y-1">
          <div className="px-3 pb-2 text-[10px] font-extrabold uppercase tracking-wider text-slate-400">
            Workspace
          </div>

          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id && (!activeFolderId || item.id !== 'decks');

            return (
              <button
                key={item.id}
                onClick={() => handleNavClick(item.id)}
                className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-2xl text-xs transition-all cursor-pointer border ${
                  isActive
                    ? item.activeBg
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50/80 border-transparent font-semibold'
                }`}
              >
                <div className="flex items-center gap-2.5">
                  <Icon className={`w-4 h-4 ${isActive ? 'fill-current/10' : item.color}`} />
                  <span>{item.label}</span>
                </div>

                {item.badge !== null && (
                  <span
                    className={`px-2 py-0.5 rounded-full text-[10px] font-mono font-bold ${
                      isActive
                        ? 'bg-white/80 border border-current/20'
                        : 'bg-slate-100 text-slate-600 border border-slate-200/60'
                    }`}
                  >
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Universal Deck Quick Access */}
        <div className="px-3 pt-1">
          <Link
            to="/deck/universal"
            onClick={onCloseMobile}
            className="w-full flex items-center justify-between px-3.5 py-2.5 rounded-2xl text-xs transition-all cursor-pointer border text-slate-600 hover:text-purple-700 hover:bg-purple-50/80 border-transparent font-semibold group"
          >
            <div className="flex items-center gap-2.5">
              <BrainCircuit className="w-4 h-4 text-purple-600 group-hover:scale-110 transition-transform" />
              <span>Universal Deck</span>
            </div>

            <div className="flex items-center gap-1.5">
              {totalDue > 0 && (
                <span className="px-1.5 py-0.5 rounded-md text-[10px] font-mono font-bold bg-amber-100 text-amber-800 border border-amber-200/80">
                  {totalDue} due
                </span>
              )}
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-slate-100 text-slate-600 border border-slate-200/60 group-hover:bg-purple-100 group-hover:text-purple-700 group-hover:border-purple-200">
                {safeDecks.reduce((acc, d) => acc + (d?.cards?.length || 0), 0)}
              </span>
            </div>
          </Link>
        </div>

        {/* Courses List Quick Access */}
        {safeCourses.length > 0 && (
          <div className="px-3 pt-2">
            <div className="flex items-center justify-between px-3 pb-2">
              <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400">
                Local Courses ({safeCourses.length})
              </span>
            </div>

            <div className="space-y-0.5 max-h-32 overflow-y-auto pr-1 mb-2">
              {safeCourses.map((course: Course) => (
                <div key={course.id} className="w-full flex items-center justify-between px-3 py-1.5 rounded-xl text-xs transition-all border border-transparent hover:bg-indigo-50/80 group">
                  <Link
                    to={`/course/${course.id}`}
                    onClick={onCloseMobile}
                    className="flex-1 flex items-center gap-2.5 truncate cursor-pointer text-slate-600 hover:text-indigo-700 font-medium py-0.5"
                  >
                    <GraduationCap className="w-4 h-4 text-indigo-500 shrink-0" />
                    <span className="truncate">{course.title}</span>
                  </Link>
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      if (window.confirm('Are you sure you want to remove this course from your workspace?')) {
                        deleteCourse(course.id);
                      }
                    }}
                    className="opacity-0 group-hover:opacity-100 p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-100 rounded-lg transition-all cursor-pointer ml-1"
                    title="Remove Course"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Folders List Quick Access */}
        <div className="px-3 pt-2">
          <div className="flex items-center justify-between px-3 pb-2">
            <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400">
              Folders ({safeFolders.length})
            </span>
            <button
              onClick={onOpenNewFolder}
              className="text-slate-400 hover:text-blue-600 p-0.5 rounded hover:bg-blue-50 cursor-pointer"
              title="Create New Folder"
            >
              <Plus className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="space-y-0.5 max-h-48 overflow-y-auto pr-1">
            {safeFolders.map((folder) => {
              const isFolderActive = currentTab === 'decks' && activeFolderId === folder.id;
              const folderDecksCount = safeDecks.filter((d) => d.folderId === folder.id).length;

              return (
                <button
                  key={folder.id}
                  type="button"
                  onClick={() => {
                    onSelectFolder(folder.id);
                    if (onCloseMobile) onCloseMobile();
                  }}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs transition-all cursor-pointer border ${
                    isFolderActive
                      ? 'bg-blue-50 text-blue-700 border-blue-200/80 font-bold shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50/80 border-transparent font-medium'
                  }`}
                >
                  <div className="flex items-center gap-2.5 truncate">
                    <div
                      className="w-2.5 h-2.5 rounded-full shrink-0"
                      style={{ backgroundColor: folder.color || '#2563eb' }}
                    ></div>
                    <span className="truncate">{folder.name}</span>
                  </div>
                  <span className="text-[10px] font-mono text-slate-400 font-bold">
                    {folderDecksCount}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Bottom Widgets: Today's Queue & Streak */}
      <div className="p-4 border-t border-slate-100 space-y-3">
        {/* Due Today Mini-Widget */}
        <div className="bg-gradient-to-br from-blue-50 to-indigo-50/60 border border-blue-100 rounded-2xl p-3.5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[10px] font-extrabold uppercase tracking-wider text-blue-700">
              Daily SRS Queue
            </span>
            <span className="text-xs font-black font-mono text-blue-600 bg-white px-2 py-0.5 rounded-full border border-blue-200">
              {totalDue} due
            </span>
          </div>

          {totalDue > 0 ? (
            <Link
              to="/deck/universal"
              className="w-full inline-flex items-center justify-center gap-2 px-3 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-sm cursor-pointer"
            >
              <Play className="w-3 h-3 fill-current" />
              Study All Due Cards ({totalDue})
            </Link>
          ) : (
            <div className="text-[11px] text-blue-800 font-medium flex items-center gap-1.5">
              <span>✨ All caught up for today!</span>
            </div>
          )}
        </div>

        {/* Streak & AI Assistant Buttons */}
        <div className="flex items-center gap-2">
          <div className="flex-1 flex items-center gap-2 px-3 py-2 rounded-xl bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200/70 shadow-2xs">
            <Flame className="w-4 h-4 text-orange-500 fill-orange-500 animate-pulse" />
            <div className="flex items-baseline gap-1">
              <span className="text-xs font-black text-orange-600 font-mono">{stats.streak}</span>
              <span className="text-[10px] font-bold uppercase tracking-wider text-orange-600/80">Days</span>
            </div>
          </div>

          <button
            onClick={onOpenAskAi}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-gradient-to-r from-purple-50 to-indigo-50 hover:from-purple-100 text-purple-700 border border-purple-200 text-xs font-bold transition-all cursor-pointer"
            title="Ask AI Companion"
          >
            <Sparkles className="w-3.5 h-3.5 text-purple-600" />
            Ask AI
          </button>
        </div>
      </div>
    </aside>
  );
}
