import React, { useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  FolderGit2,
  FolderPlus,
  Plus,
  Play,
  Sliders,
  Edit2,
  Trash2,
  Folder as FolderIcon,
  Search,
  X,
  Layers,
  ArrowUpDown,
  Filter,
  MoveRight,
  BookOpen,
  Sparkles,
  FileText,
  Code,
  Tag,
  Eye,
  CheckCircle2,
  BrainCircuit
} from 'lucide-react';
import { Deck, Folder, Lesson, Card, CardType, ARCHETYPE_CONFIG } from '../types';
import { WorkspaceTab } from '../components/Sidebar';

interface DecksViewProps {
  decks: Deck[];
  folders: Folder[];
  lessons: Lesson[];
  activeFolderId: string | null;
  onSelectFolder: (folderId: string | null) => void;
  onOpenNewFolder: () => void;
  onOpenRenameFolder: (folder: Folder) => void;
  onOpenDeleteFolder: (folder: Folder) => void;
  onOpenMoveDeck: (deck: Deck) => void;
  onOpenRenameDeck: (deck: Deck) => void;
  onDeleteDeck: (deckId: string) => void;
  onOpenCustomStudy: (deckId: string) => void;
  onNavigateTab: (tab: WorkspaceTab) => void;
  onOpenBrowseDeckCards?: (deck: Deck) => void;
}

type SortOption = 'due' | 'cards' | 'name' | 'recent';
type SearchCategory = 'all' | 'decks' | 'cards' | 'notes' | 'pdfs' | 'folders';

export function DecksView({
  decks,
  folders,
  lessons,
  activeFolderId,
  onSelectFolder,
  onOpenNewFolder,
  onOpenRenameFolder,
  onOpenDeleteFolder,
  onOpenMoveDeck,
  onOpenRenameDeck,
  onDeleteDeck,
  onOpenCustomStudy,
  onNavigateTab,
  onOpenBrowseDeckCards
}: DecksViewProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchCategory, setSearchCategory] = useState<SearchCategory>('all');
  const [sortBy, setSortBy] = useState<SortOption>('due');
  const [viewScope, setViewScope] = useState<'folders' | 'all' | 'unfiled'>('folders');

  const safeDecks = Array.isArray(decks) ? decks : [];
  const safeFolders = Array.isArray(folders) ? folders : [];
  const safeLessons = Array.isArray(lessons) ? lessons : [];
  const currentFolder = safeFolders.find((f) => f.id === activeFolderId);

  const isSearching = searchQuery.trim().length > 0;
  const q = searchQuery.toLowerCase().trim();

  // 1. Universal Search Results Calculation
  const searchResults = useMemo(() => {
    if (!isSearching) {
      return {
        decks: [],
        cards: [],
        notes: [],
        pdfs: [],
        folders: [],
        total: 0
      };
    }

    // Matching Folders
    const matchingFolders = safeFolders.filter((f) =>
      f.name.toLowerCase().includes(q)
    );

    // Matching Decks (by title, folder name, or card content)
    const matchingDecks = safeDecks.filter((d) => {
      const parentF = safeFolders.find((f) => f.id === d.folderId);
      const titleMatch = (d.title || '').toLowerCase().includes(q);
      const folderMatch = (parentF?.name || '').toLowerCase().includes(q);
      const cardMatch = (d.cards || []).some(
        (c) =>
          (c.front || '').toLowerCase().includes(q) ||
          (c.back || '').toLowerCase().includes(q) ||
          (c.codeSnippet || '').toLowerCase().includes(q) ||
          (c.type || '').toLowerCase().includes(q)
      );
      return titleMatch || folderMatch || cardMatch;
    });

    // Deep Card Matching: list of individual matching cards
    const matchingCards: { card: Card; deck: Deck; matchReason: string }[] = [];
    safeDecks.forEach((d) => {
      (d.cards || []).forEach((c) => {
        const frontMatch = (c.front || '').toLowerCase().includes(q);
        const backMatch = (c.back || '').toLowerCase().includes(q);
        const codeMatch = (c.codeSnippet || '').toLowerCase().includes(q);
        const typeMatch = (c.type || '').toLowerCase().includes(q);

        if (frontMatch || backMatch || codeMatch || typeMatch) {
          let reason = 'Matched Question';
          if (backMatch && !frontMatch) reason = 'Matched Answer';
          else if (codeMatch) reason = 'Matched Code';
          else if (typeMatch) reason = `Archetype: ${c.type}`;

          matchingCards.push({ card: c, deck: d, matchReason: reason });
        }
      });
    });

    // Matching Notes (standard notes)
    const matchingNotes = safeLessons.filter(
      (l) =>
        !l.pdfUrl &&
        ((l.title || '').toLowerCase().includes(q) ||
          (l.topic || '').toLowerCase().includes(q) ||
          (l.content || '').toLowerCase().includes(q) ||
          (l.sources || []).some((s) => s.toLowerCase().includes(q)))
    );

    // Matching PDFs
    const matchingPDFs = safeLessons.filter(
      (l) =>
        Boolean(l.pdfUrl) &&
        ((l.title || '').toLowerCase().includes(q) ||
          (l.topic || '').toLowerCase().includes(q) ||
          (l.pdfFilename || '').toLowerCase().includes(q) ||
          (l.content || '').toLowerCase().includes(q))
    );

    const total =
      matchingDecks.length +
      matchingCards.length +
      matchingNotes.length +
      matchingPDFs.length +
      matchingFolders.length;

    return {
      decks: matchingDecks,
      cards: matchingCards,
      notes: matchingNotes,
      pdfs: matchingPDFs,
      folders: matchingFolders,
      total
    };
  }, [safeDecks, safeFolders, safeLessons, isSearching, q]);

  // Standard Filtered Decks (when not searching or inside regular folder navigation)
  const displayedDecks = useMemo(() => {
    let list = [...safeDecks];

    if (activeFolderId) {
      list = list.filter((d) => d.folderId === activeFolderId);
    } else if (viewScope === 'unfiled') {
      list = list.filter((d) => !d.folderId);
    } else if (viewScope === 'folders') {
      // In root folders view, we display unfiled decks below folder cards
      list = list.filter((d) => !d.folderId);
    }

    // Sorting
    list.sort((a, b) => {
      if (sortBy === 'due') {
        const aDue = (a.cards || []).filter((c) => c.nextReview <= Date.now()).length;
        const bDue = (b.cards || []).filter((c) => c.nextReview <= Date.now()).length;
        return bDue - aDue;
      }
      if (sortBy === 'cards') {
        return (b.cards?.length || 0) - (a.cards?.length || 0);
      }
      if (sortBy === 'name') {
        return (a.title || '').localeCompare(b.title || '');
      }
      if (sortBy === 'recent') {
        return (b.createdAt || 0) - (a.createdAt || 0);
      }
      return 0;
    });

    return list;
  }, [safeDecks, activeFolderId, viewScope, sortBy]);

  // Lessons inside active folder
  const folderLessons = useMemo(() => {
    if (!activeFolderId) return [];
    return (safeLessons || []).filter((l) => l.folderId === activeFolderId);
  }, [safeLessons, activeFolderId]);

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Top Header & Breadcrumb */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white/95 border border-slate-200/90 rounded-3xl p-5 sm:p-6 shadow-xs backdrop-blur-md">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold text-slate-400 mb-1">
            <button
              onClick={() => {
                onSelectFolder(null);
                setViewScope('folders');
                setSearchQuery('');
              }}
              className={`hover:text-blue-600 cursor-pointer ${!activeFolderId ? 'text-blue-600' : ''}`}
            >
              Library
            </button>
            {currentFolder && (
              <>
                <span>/</span>
                <span className="text-slate-800 flex items-center gap-1.5">
                  <div
                    className="w-2.5 h-2.5 rounded-full"
                    style={{ backgroundColor: currentFolder.color || '#2563eb' }}
                  ></div>
                  {currentFolder.name}
                </span>
              </>
            )}
          </div>

          <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2.5">
            <FolderGit2 className="w-6 h-6 text-blue-600" />
            {currentFolder ? currentFolder.name : 'Flashcard Decks & Folders'}
          </h1>
          <p className="text-xs text-slate-500 font-sans mt-0.5">
            {currentFolder
              ? `Manage decks, notes and documents organized inside "${currentFolder.name}"`
              : 'Search across all decks, flashcards, notes, PDFs and folders in your library'}
          </p>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          {currentFolder ? (
            <>
              <button
                onClick={() => onOpenRenameFolder(currentFolder)}
                className="inline-flex items-center gap-1.5 px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer"
              >
                <Edit2 className="w-3.5 h-3.5" />
                Rename Folder
              </button>
              <button
                onClick={() => onOpenDeleteFolder(currentFolder)}
                className="inline-flex items-center gap-1.5 px-3 py-2 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 rounded-xl text-xs font-bold transition-all cursor-pointer"
              >
                <Trash2 className="w-3.5 h-3.5" />
                Delete
              </button>
            </>
          ) : (
            <button
              onClick={onOpenNewFolder}
              className="inline-flex items-center gap-1.5 px-4 py-2.5 bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 rounded-xl text-xs font-bold transition-all cursor-pointer shadow-2xs"
            >
              <FolderPlus className="w-4 h-4" />
              New Folder
            </button>
          )}

          <button
            onClick={() => onNavigateTab('deck-generator')}
            className="inline-flex items-center gap-1.5 px-4 py-2.5 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-md cursor-pointer"
          >
            <Sparkles className="w-3.5 h-3.5" />
            Create Deck
          </button>
        </div>
      </div>

      {/* Filter and Search Controls */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-white/80 p-3 rounded-2xl border border-slate-200/80 shadow-2xs">
        {/* Universal Search Input */}
        <div className="relative flex-1 max-w-lg">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setSearchCategory('all');
            }}
            placeholder="Search anything: decks, cards, notes, PDFs, code, or folders..."
            className="w-full pl-9 pr-8 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-sans text-slate-800 placeholder-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        {/* View mode toggle & Sort (when not actively searching) */}
        {!isSearching && (
          <div className="flex items-center gap-2 self-end sm:self-auto flex-wrap">
            {!activeFolderId && (
              <div className="inline-flex p-0.5 bg-slate-100 border border-slate-200 rounded-xl">
                <button
                  onClick={() => setViewScope('folders')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                    viewScope === 'folders'
                      ? 'bg-white text-blue-600 shadow-2xs border border-slate-200/60'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  Folders View
                </button>
                <button
                  onClick={() => setViewScope('all')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                    viewScope === 'all'
                      ? 'bg-white text-blue-600 shadow-2xs border border-slate-200/60'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  All Decks ({safeDecks.length})
                </button>
              </div>
            )}

            {/* Sort Selector */}
            <div className="flex items-center gap-1.5 bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1 text-xs">
              <ArrowUpDown className="w-3.5 h-3.5 text-slate-400" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortOption)}
                className="bg-transparent text-slate-700 font-bold focus:outline-none cursor-pointer text-xs"
              >
                <option value="due">Most Due</option>
                <option value="cards">Most Cards</option>
                <option value="name">Title (A-Z)</option>
                <option value="recent">Recently Created</option>
              </select>
            </div>
          </div>
        )}
      </div>

      {/* ==================================================================== */}
      {/* 🚀 UNIVERSAL SEARCH RESULTS VIEW (Rendered when searching)            */}
      {/* ==================================================================== */}
      {isSearching ? (
        <div className="space-y-6 animate-fadeIn">
          {/* Search Summary & Category Tabs Bar */}
          <div className="bg-white/95 rounded-3xl border border-slate-200/90 p-4 sm:p-5 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-extrabold uppercase tracking-wider text-slate-400">Search Results for:</span>
                <span className="text-sm font-black text-blue-600 font-mono bg-blue-50 px-2.5 py-0.5 rounded-lg border border-blue-100">
                  "{searchQuery}"
                </span>
              </div>
              <p className="text-xs text-slate-500 font-sans mt-1">
                Found {searchResults.total} matches across decks, flashcards, notes, PDFs, and folders
              </p>
            </div>

            {/* Category Filter Pills */}
            <div className="flex items-center gap-1.5 flex-wrap">
              <button
                onClick={() => setSearchCategory('all')}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                  searchCategory === 'all'
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                All ({searchResults.total})
              </button>

              {searchResults.decks.length > 0 && (
                <button
                  onClick={() => setSearchCategory('decks')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1 ${
                    searchCategory === 'decks'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-blue-50 text-blue-700 hover:bg-blue-100'
                  }`}
                >
                  <Layers className="w-3 h-3" /> Decks ({searchResults.decks.length})
                </button>
              )}

              {searchResults.cards.length > 0 && (
                <button
                  onClick={() => setSearchCategory('cards')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1 ${
                    searchCategory === 'cards'
                      ? 'bg-amber-600 text-white shadow-xs'
                      : 'bg-amber-50 text-amber-700 hover:bg-amber-100'
                  }`}
                >
                  <Sparkles className="w-3 h-3" /> Cards ({searchResults.cards.length})
                </button>
              )}

              {searchResults.notes.length > 0 && (
                <button
                  onClick={() => setSearchCategory('notes')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1 ${
                    searchCategory === 'notes'
                      ? 'bg-emerald-600 text-white shadow-xs'
                      : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                  }`}
                >
                  <BookOpen className="w-3 h-3" /> Notes ({searchResults.notes.length})
                </button>
              )}

              {searchResults.pdfs.length > 0 && (
                <button
                  onClick={() => setSearchCategory('pdfs')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1 ${
                    searchCategory === 'pdfs'
                      ? 'bg-rose-600 text-white shadow-xs'
                      : 'bg-rose-50 text-rose-700 hover:bg-rose-100'
                  }`}
                >
                  <FileText className="w-3 h-3" /> PDFs ({searchResults.pdfs.length})
                </button>
              )}

              {searchResults.folders.length > 0 && (
                <button
                  onClick={() => setSearchCategory('folders')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1 ${
                    searchCategory === 'folders'
                      ? 'bg-purple-600 text-white shadow-xs'
                      : 'bg-purple-50 text-purple-700 hover:bg-purple-100'
                  }`}
                >
                  <FolderIcon className="w-3 h-3" /> Folders ({searchResults.folders.length})
                </button>
              )}
            </div>
          </div>

          {searchResults.total === 0 ? (
            <div className="bg-white/90 rounded-3xl border border-dashed border-slate-200 p-12 text-center">
              <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 flex items-center justify-center mx-auto mb-3">
                <Search className="w-6 h-6" />
              </div>
              <h3 className="text-sm font-bold text-slate-800">No matching materials found</h3>
              <p className="text-xs text-slate-500 font-sans mt-1 max-w-md mx-auto">
                No flashcards, decks, notes, PDFs or folders matched "{searchQuery}". Try a different keyword or create new materials.
              </p>
              <button
                onClick={() => setSearchQuery('')}
                className="mt-4 px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer"
              >
                Clear Search
              </button>
            </div>
          ) : (
            <div className="space-y-8">
              {/* 1. MATCHING DECKS */}
              {(searchCategory === 'all' || searchCategory === 'decks') && searchResults.decks.length > 0 && (
                <section className="space-y-3">
                  <div className="flex items-center gap-2">
                    <Layers className="w-4 h-4 text-blue-600" />
                    <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-700">
                      Matching Decks ({searchResults.decks.length})
                    </h2>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {searchResults.decks.map((deck) => {
                      const dueCards = (deck.cards || []).filter((c) => c.nextReview <= Date.now()).length;
                      const parentF = safeFolders.find((f) => f.id === deck.folderId);
                      const matchingCardsInDeck = (deck.cards || []).filter(
                        (c) =>
                          (c.front || '').toLowerCase().includes(q) ||
                          (c.back || '').toLowerCase().includes(q) ||
                          (c.codeSnippet || '').toLowerCase().includes(q)
                      ).length;

                      return (
                        <div
                          key={deck.id}
                          className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:border-blue-300 hover:shadow-md transition-all flex flex-col justify-between"
                        >
                          <div>
                            <div className="flex items-start justify-between gap-2 mb-2">
                              <h3 className="font-bold text-sm text-slate-900 line-clamp-1 italic">
                                {deck.title}
                              </h3>
                              {parentF && (
                                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-semibold bg-slate-100 text-slate-700 shrink-0">
                                  📁 {parentF.name}
                                </span>
                              )}
                            </div>

                            <p className="text-xs text-slate-500 font-sans mb-3">
                              {deck.cards.length} cards total • {dueCards} due
                            </p>

                            {matchingCardsInDeck > 0 && (
                              <div className="mb-3 px-2.5 py-1.5 bg-blue-50/80 rounded-xl border border-blue-100 text-[11px] text-blue-800 font-mono flex items-center gap-1.5">
                                <Sparkles className="w-3 h-3 text-blue-600 shrink-0" />
                                <span>{matchingCardsInDeck} matching cards inside</span>
                              </div>
                            )}
                          </div>

                          <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                            {onOpenBrowseDeckCards && (
                              <button
                                onClick={() => onOpenBrowseDeckCards(deck)}
                                className="text-xs font-semibold text-slate-500 hover:text-slate-900 cursor-pointer"
                              >
                                Browse Cards
                              </button>
                            )}
                            <Link
                              to={`/deck/${deck.id}`}
                              className="inline-flex items-center gap-1 px-3 py-1.5 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-bold transition-all shadow-2xs ml-auto"
                            >
                              <Play className="w-3 h-3 fill-current" /> Study Deck
                            </Link>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </section>
              )}

              {/* 2. MATCHING INDIVIDUAL FLASHCARDS */}
              {(searchCategory === 'all' || searchCategory === 'cards') && searchResults.cards.length > 0 && (
                <section className="space-y-3">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-amber-600" />
                    <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-700">
                      Matching Flashcards ({searchResults.cards.length})
                    </h2>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {searchResults.cards.slice(0, 12).map(({ card, deck, matchReason }, idx) => {
                      const archetypeMeta = ARCHETYPE_CONFIG[card.type as CardType] || ARCHETYPE_CONFIG.Concept;

                      return (
                        <div
                          key={card.id || idx}
                          className="bg-white/95 rounded-2xl border border-slate-200/90 p-4 shadow-xs hover:border-amber-300 transition-all flex flex-col justify-between space-y-3"
                        >
                          <div>
                            <div className="flex items-center justify-between gap-2 mb-2">
                              <div className="flex items-center gap-1.5">
                                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold ${archetypeMeta.bg} ${archetypeMeta.text} ${archetypeMeta.border} border`}>
                                  {archetypeMeta.icon} {card.type || 'Concept'}
                                </span>
                                <span className="text-[10px] font-mono text-slate-400 font-bold">
                                  {matchReason}
                                </span>
                              </div>

                              <span className="text-[11px] font-sans font-semibold text-slate-500 truncate max-w-[140px]" title={deck.title}>
                                🗂️ {deck.title}
                              </span>
                            </div>

                            <div className="space-y-1.5 font-sans">
                              <p className="text-xs font-bold text-slate-900 leading-snug line-clamp-2">
                                {card.front}
                              </p>
                              <p className="text-[11px] text-slate-600 line-clamp-2 leading-relaxed bg-slate-50 p-2 rounded-xl border border-slate-100">
                                {card.back}
                              </p>
                            </div>

                            {card.codeSnippet && (
                              <div className="mt-2 text-[10px] font-mono bg-slate-900 text-slate-200 p-2 rounded-lg truncate">
                                <code>{card.codeSnippet.split('\n')[0]}</code>
                              </div>
                            )}
                          </div>

                          <div className="pt-2 border-t border-slate-100 flex items-center justify-between">
                            <span className="text-[10px] font-mono text-slate-400">
                              Ease: {card.ease?.toFixed(1) || '2.5'} • Reps: {card.reps || 0}
                            </span>
                            <Link
                              to={`/deck/${deck.id}?filter=all`}
                              className="inline-flex items-center gap-1 text-xs font-bold text-amber-700 hover:text-amber-800"
                            >
                              Study in Deck <MoveRight className="w-3 h-3" />
                            </Link>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </section>
              )}

              {/* 3. MATCHING CS LECTURE NOTES */}
              {(searchCategory === 'all' || searchCategory === 'notes') && searchResults.notes.length > 0 && (
                <section className="space-y-3">
                  <div className="flex items-center gap-2">
                    <BookOpen className="w-4 h-4 text-emerald-600" />
                    <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-700">
                      Matching CS Lecture Notes ({searchResults.notes.length})
                    </h2>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {searchResults.notes.map((lesson) => (
                      <div
                        key={lesson.id}
                        className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:border-emerald-300 transition-all flex flex-col justify-between"
                      >
                        <div>
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 mb-2">
                            <BookOpen className="w-3 h-3" />
                            {lesson.topic}
                          </span>
                          <h3 className="font-bold text-sm text-slate-900 line-clamp-2 mb-2">{lesson.title}</h3>
                          <p className="text-xs text-slate-500 font-sans line-clamp-3 leading-relaxed">
                            {lesson.content.replace(/[#*`_$-]/g, '').slice(0, 120)}...
                          </p>
                        </div>
                        <div className="pt-3 mt-3 border-t border-slate-100 flex justify-end">
                          <Link
                            to={`/lesson/${lesson.id}`}
                            className="inline-flex items-center gap-1 text-xs font-bold text-emerald-600 hover:text-emerald-700"
                          >
                            Read Notes <MoveRight className="w-3 h-3" />
                          </Link>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* 4. MATCHING PDF DOCUMENTS */}
              {(searchCategory === 'all' || searchCategory === 'pdfs') && searchResults.pdfs.length > 0 && (
                <section className="space-y-3">
                  <div className="flex items-center gap-2">
                    <FileText className="w-4 h-4 text-rose-600" />
                    <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-700">
                      Matching PDF Documents ({searchResults.pdfs.length})
                    </h2>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {searchResults.pdfs.map((pdfDoc) => (
                      <div
                        key={pdfDoc.id}
                        className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:border-rose-300 transition-all flex flex-col justify-between"
                      >
                        <div>
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-rose-50 text-rose-700 border border-rose-200 mb-2">
                            <FileText className="w-3 h-3 text-rose-500" />
                            PDF ({pdfDoc.pdfPages || 1} pages)
                          </span>
                          <h3 className="font-bold text-sm text-slate-900 line-clamp-2 mb-2">{pdfDoc.title}</h3>
                          <p className="text-xs text-slate-500 font-sans line-clamp-2 leading-relaxed">
                            {pdfDoc.pdfFilename || 'Imported PDF Document'}
                          </p>
                        </div>
                        <div className="pt-3 mt-3 border-t border-slate-100 flex justify-end">
                          <Link
                            to={`/lesson/${pdfDoc.id}`}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 rounded-xl text-xs font-bold transition-all shadow-2xs"
                          >
                            View PDF & Notes <MoveRight className="w-3.5 h-3.5" />
                          </Link>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* 5. MATCHING FOLDERS */}
              {(searchCategory === 'all' || searchCategory === 'folders') && searchResults.folders.length > 0 && (
                <section className="space-y-3">
                  <div className="flex items-center gap-2">
                    <FolderIcon className="w-4 h-4 text-purple-600" />
                    <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-700">
                      Matching Folders ({searchResults.folders.length})
                    </h2>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {searchResults.folders.map((f) => (
                      <div
                        key={f.id}
                        onClick={() => {
                          onSelectFolder(f.id);
                          setSearchQuery('');
                        }}
                        className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:border-purple-300 transition-all flex items-center justify-between cursor-pointer group"
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className="w-10 h-10 rounded-xl flex items-center justify-center border shadow-2xs"
                            style={{
                              backgroundColor: `${f.color || '#9333ea'}15`,
                              borderColor: `${f.color || '#9333ea'}40`,
                              color: f.color || '#9333ea'
                            }}
                          >
                            <FolderIcon className="w-5 h-5 fill-current" />
                          </div>
                          <div>
                            <h3 className="font-bold text-sm text-slate-900 group-hover:text-purple-600 transition-colors">
                              {f.name}
                            </h3>
                            <span className="text-[11px] text-slate-400 font-sans">Click to open folder</span>
                          </div>
                        </div>
                        <MoveRight className="w-4 h-4 text-slate-400 group-hover:text-purple-600 transition-transform group-hover:translate-x-1" />
                      </div>
                    ))}
                  </div>
                </section>
              )}
            </div>
          )}
        </div>
      ) : (
        /* ==================================================================== */
        /* 📂 REGULAR FOLDER & DECK NAVIGATION VIEW                             */
        /* ==================================================================== */
        <div className="space-y-6">
          {/* Root Folder Cards Grid (when viewing root and folders mode is active) */}
          {!activeFolderId && viewScope === 'folders' && (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-400">
                  Folders ({safeFolders.length})
                </h2>
              </div>

              {safeFolders.length === 0 ? (
                <div className="bg-white/80 rounded-2xl border border-dashed border-slate-200 p-6 text-center">
                  <p className="text-xs text-slate-500 font-sans">No folders created yet.</p>
                  <button
                    onClick={onOpenNewFolder}
                    className="mt-2.5 inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 text-blue-600 border border-blue-200 rounded-xl text-xs font-bold hover:bg-blue-100 cursor-pointer"
                  >
                    <FolderPlus className="w-3.5 h-3.5" />
                    Create First Folder
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {safeFolders.map((folder) => {
                    const folderDecks = safeDecks.filter((d) => d.folderId === folder.id);
                    const folderDeckCards = folderDecks.reduce((acc, d) => acc + (d.cards?.length || 0), 0);
                    const folderDue = folderDecks.reduce(
                      (acc, d) => acc + (d.cards || []).filter((c) => c.nextReview <= Date.now()).length,
                      0
                    );
                    const folderLessonCount = (safeLessons || []).filter((l) => l.folderId === folder.id).length;

                    return (
                      <div
                        key={folder.id}
                        onClick={() => onSelectFolder(folder.id)}
                        className="group bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:shadow-md hover:border-blue-300 transition-all cursor-pointer flex flex-col justify-between"
                      >
                        <div className="flex items-start justify-between gap-3 mb-3">
                          <div className="flex items-center gap-3">
                            <div
                              className="w-10 h-10 rounded-xl flex items-center justify-center border shadow-2xs"
                              style={{
                                backgroundColor: `${folder.color || '#2563eb'}15`,
                                borderColor: `${folder.color || '#2563eb'}40`,
                                color: folder.color || '#2563eb'
                              }}
                            >
                              <FolderIcon className="w-5 h-5 fill-current" />
                            </div>
                            <div>
                              <h3 className="font-bold text-sm text-slate-900 group-hover:text-blue-600 transition-colors">
                                {folder.name}
                              </h3>
                              <span className="text-[11px] text-slate-500 font-sans">
                                {folderDecks.length} {folderDecks.length === 1 ? 'deck' : 'decks'}
                                {folderLessonCount > 0 ? ` • ${folderLessonCount} notes` : ''}
                              </span>
                            </div>
                          </div>

                          <div
                            onClick={(e) => e.stopPropagation()}
                            className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                            <button
                              onClick={() => onOpenRenameFolder(folder)}
                              className="p-1 text-slate-400 hover:text-blue-600 rounded-md hover:bg-blue-50 cursor-pointer"
                              title="Rename Folder"
                            >
                              <Edit2 className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => onOpenDeleteFolder(folder)}
                              className="p-1 text-slate-400 hover:text-rose-600 rounded-md hover:bg-rose-50 cursor-pointer"
                              title="Delete Folder"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </div>

                        <div className="pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
                          <span className="text-[11px] font-mono text-slate-500">
                            {folderDeckCards} cards total
                          </span>
                          {folderDue > 0 ? (
                            <span className="font-mono font-bold text-blue-600 text-[11px]">
                              {folderDue} due
                            </span>
                          ) : (
                            <span className="text-slate-400 text-[11px]">0 due</span>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* Decks Grid */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-400">
                {activeFolderId
                  ? `Decks in this Folder (${displayedDecks.length})`
                  : viewScope === 'folders'
                  ? `Unfiled Decks (${displayedDecks.length})`
                  : `All Decks (${displayedDecks.length})`}
              </h2>
            </div>

            {displayedDecks.length === 0 ? (
              <div className="bg-white/80 rounded-3xl border border-dashed border-slate-200 p-8 text-center">
                <h3 className="text-sm font-bold text-slate-800">No Decks Found</h3>
                <p className="text-xs text-slate-500 font-sans mt-1">
                  {activeFolderId
                    ? 'This folder does not contain any decks yet.'
                    : 'Create or generate your first flashcard deck in the Creation Studio.'}
                </p>
                <button
                  onClick={() => onNavigateTab('deck-generator')}
                  className="mt-4 inline-flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-xl text-xs font-bold hover:bg-blue-500 transition-all cursor-pointer shadow-md"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  Synthesize Deck
                </button>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {displayedDecks.map((deck) => {
                  const dueCards = (deck.cards || []).filter((c) => c.nextReview <= Date.now()).length;
                  const hasCards = (deck.cards || []).length > 0;
                  const parentFolder = safeFolders.find((f) => f.id === deck.folderId);
                  const studyUrl = dueCards > 0 ? `/deck/${deck.id}` : `/deck/${deck.id}?mode=custom&filter=all`;

                  return (
                    <div
                      key={deck.id}
                      className="group relative bg-white/95 rounded-3xl shadow-xs border border-slate-200/90 p-6 flex flex-col justify-between transition-all duration-300 hover:border-blue-300 hover:shadow-md hover:-translate-y-0.5"
                    >
                      <div>
                        <div className="flex justify-between items-start mb-3">
                          <h3 className="font-bold text-base text-slate-900 line-clamp-1 italic tracking-tight">
                            {deck.title}
                          </h3>
                          <div className="flex items-center gap-1 shrink-0 ml-2">
                            {onOpenBrowseDeckCards && (
                              <button
                                onClick={() => onOpenBrowseDeckCards(deck)}
                                className="text-slate-400 hover:text-blue-600 transition-colors p-1.5 rounded-lg hover:bg-blue-50 cursor-pointer"
                                title="Browse & Edit Flashcards"
                              >
                                <Layers className="w-4 h-4" />
                              </button>
                            )}
                            <button
                              onClick={() => onOpenRenameDeck(deck)}
                              className="text-slate-400 hover:text-blue-600 transition-colors p-1.5 rounded-lg hover:bg-blue-50 cursor-pointer"
                              title="Rename Deck"
                            >
                              <Edit2 className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => onOpenMoveDeck(deck)}
                              className="text-slate-400 hover:text-blue-600 transition-colors p-1.5 rounded-lg hover:bg-blue-50 cursor-pointer"
                              title="Move to Folder"
                            >
                              <FolderGit2 className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => onDeleteDeck(deck.id)}
                              className="text-slate-400 hover:text-rose-500 transition-colors p-1.5 rounded-lg hover:bg-rose-50 cursor-pointer"
                              title="Delete Deck"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </div>

                        {/* Folder Badge in All Decks view */}
                        {!activeFolderId && (
                          <div className="mb-4">
                            {parentFolder ? (
                              <span
                                onClick={() => onSelectFolder(parentFolder.id)}
                                className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-slate-100/90 text-slate-700 hover:bg-blue-50 hover:text-blue-600 cursor-pointer transition-all border border-slate-200/70"
                              >
                                <FolderIcon className="w-3.5 h-3.5 text-blue-500" />
                                {parentFolder.name}
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-slate-50 text-slate-400 border border-slate-200/60">
                                Unfiled
                              </span>
                            )}
                          </div>
                        )}

                        {/* Stats Bar */}
                        <div className="flex items-center gap-4 mb-3 p-3 bg-slate-50/70 rounded-2xl border border-slate-100">
                          <div className="text-xs flex flex-col flex-1">
                            <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold">Total</span>
                            <span className="font-mono font-bold text-slate-800 text-sm">{deck.cards.length} cards</span>
                          </div>
                          <div className="w-px h-7 bg-slate-200"></div>
                          <div className="text-xs flex flex-col flex-1">
                            <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold">Due Queue</span>
                            <span className={`font-mono font-bold text-sm ${dueCards > 0 ? 'text-blue-600' : 'text-slate-400'}`}>
                              {dueCards} cards
                            </span>
                          </div>
                        </div>

                        {/* 1-Click Archetype Study Pills */}
                        {hasCards && (
                          <div className="mb-4">
                            <span className="text-[9px] font-extrabold uppercase tracking-widest text-slate-400 block mb-1.5">
                              Study by Archetype:
                            </span>
                            <div className="flex flex-wrap items-center gap-1.5">
                              {(() => {
                                const counts: Record<string, number> = {};
                                deck.cards.forEach(c => {
                                  const t = c.type || 'Concept';
                                  counts[t] = (counts[t] || 0) + 1;
                                });
                                return Object.entries(counts).map(([type, count]) => {
                                  const meta = ARCHETYPE_CONFIG[type as CardType] || ARCHETYPE_CONFIG.Concept;
                                  return (
                                    <Link
                                      key={type}
                                      to={`/deck/${deck.id}?types=${type}&filter=all`}
                                      title={`Study ${count} ${meta.label} (${type}) cards in this deck`}
                                      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold ${meta.bg} ${meta.text} ${meta.border} border hover:scale-105 transition-transform shadow-2xs`}
                                    >
                                      <span>{meta.icon}</span>
                                      <span>{count}</span>
                                    </Link>
                                  );
                                });
                              })()}
                            </div>
                          </div>
                        )}
                      </div>

                      <div className="pt-3 border-t border-slate-100 flex gap-2">
                        {hasCards ? (
                          <>
                            <Link
                              to={studyUrl}
                              className="flex-1 inline-flex items-center justify-center gap-2 px-3.5 py-2.5 bg-gradient-to-r from-blue-600 via-indigo-600 to-blue-600 text-white rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-[0_4px_14px_rgba(37,99,235,0.25)] hover:shadow-[0_6px_18px_rgba(37,99,235,0.35)]"
                            >
                              <Play className="w-3.5 h-3.5 fill-current" />
                              {dueCards > 0 ? `Study (${dueCards})` : `Review All (${deck.cards.length})`}
                            </Link>
                            <button
                              onClick={() => onOpenCustomStudy(deck.id)}
                              className="px-3.5 py-2.5 bg-slate-50 hover:bg-slate-100 text-slate-500 hover:text-blue-600 border border-slate-200 rounded-xl transition-all shadow-2xs cursor-pointer"
                              title="Custom Study Options"
                            >
                              <Sliders className="w-4 h-4" />
                            </button>
                          </>
                        ) : (
                          <span className="w-full text-center py-2 text-xs font-sans text-slate-400">No cards in deck</span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* CS Lecture Notes inside this folder (if activeFolderId is set) */}
          {activeFolderId && folderLessons.length > 0 && (
            <div className="space-y-3 pt-6 border-t border-slate-200">
              <h2 className="text-xs font-extrabold uppercase tracking-wider text-slate-400">
                Lecture Notes & Materials in this Folder ({folderLessons.length})
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {folderLessons.map((lesson) => (
                  <div
                    key={lesson.id}
                    className="bg-white/95 rounded-2xl border border-slate-200/90 p-5 shadow-xs hover:border-emerald-300 transition-all flex flex-col justify-between"
                  >
                    <div>
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 mb-2">
                        {lesson.pdfUrl ? <FileText className="w-3 h-3 text-rose-500" /> : <BookOpen className="w-3 h-3" />}
                        {lesson.pdfUrl ? 'PDF Document' : lesson.topic}
                      </span>
                      <h3 className="font-bold text-sm text-slate-900 line-clamp-2 mb-2">{lesson.title}</h3>
                      <p className="text-xs text-slate-500 font-sans line-clamp-2">
                        {lesson.content.replace(/[#*`_$-]/g, '').slice(0, 80)}...
                      </p>
                    </div>
                    <div className="pt-3 mt-3 border-t border-slate-100 flex justify-end">
                      <Link
                        to={`/lesson/${lesson.id}`}
                        className="inline-flex items-center gap-1 text-xs font-bold text-emerald-600 hover:text-emerald-700"
                      >
                        {lesson.pdfUrl ? 'View PDF & Notes' : 'Read Notes'} <MoveRight className="w-3 h-3" />
                      </Link>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
