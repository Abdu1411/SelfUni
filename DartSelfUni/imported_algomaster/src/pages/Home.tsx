import React, { useState, useMemo, useEffect } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { useDecks } from '../store';
import { Deck, Folder, Lesson, Card } from '../types';
import { useActiveView } from '../context/ActiveViewContext';

// Navigation & Layout Components
import { Sidebar, WorkspaceTab } from '../components/Sidebar';
import { TopBar } from '../components/TopBar';
import { AskAIModal } from '../components/AskAIModal';

// Dedicated Workspace Views
import { DashboardView } from '../views/DashboardView';
import { DecksView } from '../views/DecksView';
import { LessonsView } from '../views/LessonsView';
import { LiveLecturesView } from '../views/LiveLecturesView';
import { StudioView } from '../views/StudioView';
import { DeckGeneratorView } from '../views/DeckGeneratorView';
import { LessonGeneratorView } from '../views/LessonGeneratorView';

// Reusable Modals
import { FolderModal } from '../components/modals/FolderModal';
import { DeleteFolderModal } from '../components/modals/DeleteFolderModal';
import { MoveResourceModal } from '../components/modals/MoveResourceModal';
import { RenameDeckModal } from '../components/modals/RenameDeckModal';
import { LiveLectureModal } from '../components/modals/LiveLectureModal';
import { CustomStudyModal } from '../components/CustomStudyModal';
import { DeckCardsModal } from '../components/modals/DeckCardsModal';
import { ImportPDFModal } from '../components/modals/ImportPDFModal';
import { ImportCourseModal } from '../components/modals/ImportCourseModal';

const EMPTY_ARRAY: any[] = [];

export function Home() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { setActiveResource } = useActiveView();

  const {
    decks,
    folders,
    lessons,
    addDeck,
    deleteDeck,
    renameDeck,
    updateCard,
    addCardToDeck,
    deleteCardFromDeck,
    addFolder,
    updateFolder,
    deleteFolder,
    moveDeckToFolder,
    addLesson,
    addLessonsBulk,
    deleteLesson,
    moveLessonToFolder
  } = useDecks();

  const safeDecks = Array.isArray(decks) ? decks : EMPTY_ARRAY;
  const safeFolders = Array.isArray(folders) ? folders : EMPTY_ARRAY;
  const safeLessons = Array.isArray(lessons) ? lessons : EMPTY_ARRAY;

  // Parse view from URL params (with backwards compatibility for ?view=all, ?view=lessons, ?view=live, ?view=folders)
  const tabParam = searchParams.get('tab');
  const viewParam = searchParams.get('view');
  const activeFolderId = searchParams.get('folder');

  const currentTab: WorkspaceTab = useMemo(() => {
    if (tabParam) {
      if (
        tabParam === 'decks' ||
        tabParam === 'lessons' ||
        tabParam === 'live' ||
        tabParam === 'deck-generator' ||
        tabParam === 'lesson-generator' ||
        tabParam === 'studio' ||
        tabParam === 'dashboard'
      ) {
        return tabParam as WorkspaceTab;
      }
    }
    if (activeFolderId) return 'decks';
    if (viewParam === 'all' || viewParam === 'folders' || viewParam === 'decks') return 'decks';
    if (viewParam === 'lessons') return 'lessons';
    if (viewParam === 'live') return 'live';
    if (viewParam === 'deck-generator' || viewParam === 'studio') return 'deck-generator';
    if (viewParam === 'lesson-generator') return 'lesson-generator';
    return 'dashboard';
  }, [tabParam, viewParam, activeFolderId]);

  // Mobile sidebar state
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);

  // Modals state
  const [isAskAiOpen, setIsAskAiOpen] = useState(false);
  const [isNewFolderOpen, setIsNewFolderOpen] = useState(false);
  const [folderToEdit, setFolderToEdit] = useState<Folder | null>(null);
  const [folderToDelete, setFolderToDelete] = useState<Folder | null>(null);

  const [deckToMove, setDeckToMove] = useState<Deck | null>(null);
  const [lessonToMove, setLessonToMove] = useState<Lesson | null>(null);
  const [deckToRename, setDeckToRename] = useState<Deck | null>(null);
  const [deckToBrowseCards, setDeckToBrowseCards] = useState<Deck | null>(null);
  const [isLiveModalOpen, setIsLiveModalOpen] = useState(false);
  const [isImportPDFOpen, setIsImportPDFOpen] = useState(false);
  const [isImportCourseOpen, setIsImportCourseOpen] = useState(false);

  const [isCustomModalOpen, setIsCustomModalOpen] = useState(false);
  const [selectedDeckForCustom, setSelectedDeckForCustom] = useState<string>('all');

  // Provide AI Context
  useEffect(() => {
    setActiveResource({
      title: 'AlgoMaster SRS Workspace',
      type: 'dashboard',
      contextText: `CURRENT WORKSPACE SUMMARY:
Current Tab: ${currentTab}
Total Decks: ${safeDecks.length}
Total Cards: ${safeDecks.reduce((acc, d) => acc + (d.cards?.length || 0), 0)}
Folders (${safeFolders.length}): ${safeFolders.map((f) => f.name).join(', ') || 'None'}
Lecture Notes (${safeLessons.length}): ${safeLessons.map((l) => `"${l.title}" [${l.topic}]`).join('\n') || 'None'}`,
      suggestedPrompts: [
        'What should I study next according to my SM-2 queue?',
        'Suggest a Dart algorithm topic to synthesize cards for',
        'Help me structure a study plan across my folders',
        'Generate a practice quiz based on all my decks'
      ]
    });
    return () => setActiveResource(null);
  }, [safeDecks, safeFolders, safeLessons, currentTab, setActiveResource]);

  // Navigation handlers
  const handleSelectTab = (tab: WorkspaceTab) => {
    if (tab === 'dashboard') {
      setSearchParams({});
    } else {
      setSearchParams({ tab });
    }
  };

  const handleSelectFolder = (folderId: string | null) => {
    if (folderId) {
      setSearchParams({ tab: 'decks', folder: folderId });
    } else {
      setSearchParams({ tab: 'decks' });
    }
  };

  const handleOpenCustomStudy = (deckId: string = 'all') => {
    setSelectedDeckForCustom(deckId);
    setIsCustomModalOpen(true);
  };

  // Folder actions
  const handleCreateOrUpdateFolder = async (name: string, color?: string) => {
    if (folderToEdit) {
      await updateFolder(folderToEdit.id, name, color);
      setFolderToEdit(null);
    } else {
      const newFolder = await addFolder(name, color);
      handleSelectFolder(newFolder.id);
    }
  };

  const handleConfirmDeleteFolder = async (deleteContents: boolean) => {
    if (!folderToDelete) return;
    await deleteFolder(folderToDelete.id, deleteContents);
    setFolderToDelete(null);
    if (activeFolderId === folderToDelete.id) {
      handleSelectFolder(null);
    }
  };

  // Move actions
  const handleConfirmMoveDeck = async (targetFolderId?: string) => {
    if (!deckToMove) return;
    await moveDeckToFolder(deckToMove.id, targetFolderId);
    setDeckToMove(null);
  };

  const handleConfirmMoveLesson = async (targetFolderId?: string) => {
    if (!lessonToMove) return;
    await moveLessonToFolder(lessonToMove.id, targetFolderId);
    setLessonToMove(null);
  };

  // Rename Deck
  const handleConfirmRenameDeck = async (deckId: string, newTitle: string) => {
    await renameDeck(deckId, newTitle);
    setDeckToRename(null);
  };

  // Live Lecture creation
  const handleCreateLiveLecture = async (lectureData: {
    title: string;
    topic: string;
    videoUrl: string;
    folderId?: string;
  }) => {
    const newLesson: Lesson = {
      id: crypto.randomUUID(),
      title: lectureData.title,
      topic: lectureData.topic,
      videoUrl: lectureData.videoUrl,
      folderId: lectureData.folderId,
      content: `# ${lectureData.title}\n\nLive course video notes on **${lectureData.topic}**.\n\n### Key Concepts Covered:\n- Overview & Motivation\n- Core Invariants & Complexity\n- Implementation Walkthrough\n`,
      createdAt: Date.now()
    };
    await addLesson(newLesson);
    navigate(`/lesson/${newLesson.id}`);
  };

  // Bulk HTML Course Import
  const handleBulkCreateLiveLectures = async (courseName: string, lectures: { title: string; url: string }[]) => {
    // 1. Create the folder (course)
    const newFolder = await addFolder(courseName);

    // 2. Create the lessons
    const now = Date.now();
    const newLessons: Lesson[] = lectures.map(lec => ({
      id: crypto.randomUUID(),
      title: lec.title,
      topic: courseName,
      videoUrl: lec.url,
      folderId: newFolder.id,
      content: `# ${lec.title}\n\nBulk imported lecture from ${courseName}.\n\n### Video Link:\n[Watch Lecture](${lec.url})`,
      createdAt: now
    }));

    await addLessonsBulk(newLessons);
    
    // Navigate to the newly created folder view in lessons tab
    setSearchParams({ tab: 'lessons', folder: newFolder.id });
  };

  return (
    <div className="min-h-screen flex bg-[#F8FAFC]">
      {/* Collapsible Workspace Sidebar */}
      <Sidebar
        currentTab={currentTab}
        activeFolderId={activeFolderId}
        onSelectTab={handleSelectTab}
        onSelectFolder={handleSelectFolder}
        onOpenNewFolder={() => {
          setFolderToEdit(null);
          setIsNewFolderOpen(true);
        }}
        onOpenAskAi={() => setIsAskAiOpen(true)}
        isMobileOpen={isMobileSidebarOpen}
        onCloseMobile={() => setIsMobileSidebarOpen(false)}
      />

      {/* Mobile Sidebar Overlay Backdrop */}
      {isMobileSidebarOpen && (
        <div
          onClick={() => setIsMobileSidebarOpen(false)}
          className="fixed inset-0 bg-slate-900/50 backdrop-blur-xs z-40 lg:hidden"
        ></div>
      )}

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        <TopBar
          currentTab={currentTab}
          onToggleMobileSidebar={() => setIsMobileSidebarOpen(!isMobileSidebarOpen)}
          onOpenAskAi={() => setIsAskAiOpen(true)}
          onOpenNewFolder={() => {
            setFolderToEdit(null);
            setIsNewFolderOpen(true);
          }}
          onOpenLiveModal={() => setIsLiveModalOpen(true)}
          onOpenImportCourse={() => setIsImportCourseOpen(true)}
          onNavigateTab={handleSelectTab}
        />

        <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8">
          {currentTab === 'dashboard' && (
            <DashboardView
              decks={safeDecks}
              folders={safeFolders}
              lessons={safeLessons}
              onOpenCustomStudy={handleOpenCustomStudy}
              onNavigateTab={handleSelectTab}
            />
          )}

          {currentTab === 'decks' && (
            <DecksView
              decks={safeDecks}
              folders={safeFolders}
              lessons={safeLessons}
              activeFolderId={activeFolderId}
              onSelectFolder={handleSelectFolder}
              onOpenNewFolder={() => {
                setFolderToEdit(null);
                setIsNewFolderOpen(true);
              }}
              onOpenRenameFolder={(f) => {
                setFolderToEdit(f);
                setIsNewFolderOpen(true);
              }}
              onOpenDeleteFolder={(f) => setFolderToDelete(f)}
              onOpenMoveDeck={(d) => setDeckToMove(d)}
              onOpenRenameDeck={(d) => setDeckToRename(d)}
              onDeleteDeck={(id) => deleteDeck(id)}
              onOpenCustomStudy={handleOpenCustomStudy}
              onNavigateTab={handleSelectTab}
              onOpenBrowseDeckCards={(d) => setDeckToBrowseCards(d)}
            />
          )}

          {currentTab === 'lessons' && (
            <LessonsView
              lessons={safeLessons}
              folders={safeFolders}
              onOpenMoveLesson={(l) => setLessonToMove(l)}
              onDeleteLesson={(id) => deleteLesson(id)}
              onNavigateTab={handleSelectTab}
              onOpenImportPDF={() => setIsImportPDFOpen(true)}
            />
          )}

          {currentTab === 'live' && (
            <LiveLecturesView
              lessons={safeLessons}
              folders={safeFolders}
              activeFolderId={activeFolderId}
              onOpenCreateLive={() => setIsLiveModalOpen(true)}
              onOpenMoveLesson={(l) => setLessonToMove(l)}
              onDeleteLesson={(id) => deleteLesson(id)}
              onOpenRenameFolder={(f) => {
                setFolderToEdit(f);
                setIsNewFolderOpen(true);
              }}
              onOpenDeleteFolder={(f) => setFolderToDelete(f)}
            />
          )}

          {(currentTab === 'deck-generator' || currentTab === 'studio') && (
            <DeckGeneratorView
              decks={safeDecks}
              folders={safeFolders}
              onAddDeck={addDeck}
              onAddCardToDeck={addCardToDeck}
            />
          )}

          {currentTab === 'lesson-generator' && (
            <LessonGeneratorView
              onAddLesson={addLesson}
              onNavigateTab={handleSelectTab}
            />
          )}
        </main>
      </div>

      {/* Global Modals */}
      <FolderModal
        isOpen={isNewFolderOpen}
        onClose={() => {
          setIsNewFolderOpen(false);
          setFolderToEdit(null);
        }}
        onSubmit={handleCreateOrUpdateFolder}
        initialFolder={folderToEdit}
      />

      <DeleteFolderModal
        folder={folderToDelete}
        onClose={() => setFolderToDelete(null)}
        onConfirm={handleConfirmDeleteFolder}
      />

      <MoveResourceModal
        isOpen={!!deckToMove}
        onClose={() => setDeckToMove(null)}
        title="Move Flashcard Deck"
        itemTitle={deckToMove?.title || ''}
        itemType="deck"
        currentFolderId={deckToMove?.folderId}
        folders={safeFolders}
        onMove={handleConfirmMoveDeck}
      />

      <MoveResourceModal
        isOpen={!!lessonToMove}
        onClose={() => setLessonToMove(null)}
        title="Move Lecture Note"
        itemTitle={lessonToMove?.title || ''}
        itemType="lesson"
        currentFolderId={lessonToMove?.folderId}
        folders={safeFolders}
        onMove={handleConfirmMoveLesson}
      />

      <RenameDeckModal
        deck={deckToRename}
        onClose={() => setDeckToRename(null)}
        onRename={handleConfirmRenameDeck}
      />

      <LiveLectureModal
        isOpen={isLiveModalOpen}
        onClose={() => setIsLiveModalOpen(false)}
        folders={safeFolders}
        onCreate={handleCreateLiveLecture}
        onBulkCreate={handleBulkCreateLiveLectures}
      />

      <ImportPDFModal
        isOpen={isImportPDFOpen}
        onClose={() => setIsImportPDFOpen(false)}
        folders={safeFolders}
        onAddLesson={addLesson}
      />

      <ImportCourseModal
        isOpen={isImportCourseOpen}
        onClose={() => setIsImportCourseOpen(false)}
      />

      <CustomStudyModal
        isOpen={isCustomModalOpen}
        onClose={() => setIsCustomModalOpen(false)}
        decks={safeDecks}
        initialDeckId={selectedDeckForCustom}
      />

      <DeckCardsModal
        deck={deckToBrowseCards ? safeDecks.find(d => d.id === deckToBrowseCards.id) || deckToBrowseCards : null}
        isOpen={!!deckToBrowseCards}
        onClose={() => setDeckToBrowseCards(null)}
        onUpdateCard={(deckId, updatedCard) => updateCard(deckId, updatedCard)}
        onDeleteCard={(deckId, cardId) => deleteCardFromDeck(deckId, cardId)}
        onAddCard={(deckId, newCard) => addCardToDeck(deckId, newCard)}
      />

      <AskAIModal
        isOpen={isAskAiOpen}
        onClose={() => setIsAskAiOpen(false)}
      />
    </div>
  );
}
