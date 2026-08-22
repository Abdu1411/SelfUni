import React, { useState, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import {
  BookOpen,
  ArrowLeft,
  Calendar,
  ExternalLink,
  Copy,
  Check,
  Zap,
  Trash2,
  Edit3,
  Loader2,
  Layers,
  Sparkles,
  Share2,
  Folder as FolderIcon,
  Info,
  AlertTriangle,
  Lightbulb,
  CheckCircle2,
  FileText,
  PenTool,
  ChevronDown,
  ChevronUp,
  Timer,
  Clock,
  Play,
  Pause,
  Scissors,
  Sliders,
  RotateCcw
} from 'lucide-react';
import { useDecks } from '../store';
import { MarkdownCodeRenderer } from '../components/CodeBlock';
import { YouTubeEmbed, YouTubePlayerHandle } from '../components/YouTubeEmbed';
import { PDFViewer } from '../components/PDFViewer';
import { RichNoteEditor } from '../components/RichNoteEditor';
import { ManualCardCreator } from '../components/ManualCardCreator';
import { Deck, Card, Lesson } from '../types';
import { useActiveView } from '../context/ActiveViewContext';

export function LessonView() {
  const { lessonId } = useParams<{ lessonId: string }>();
  const navigate = useNavigate();
  const { lessons, folders, decks, deleteLesson, updateLesson, addLesson, addDeck, updateDeck, addFolder, addCardToDeck } = useDecks();
  const { setActiveResource } = useActiveView();

  const lesson = lessons.find((l) => l.id === lessonId);
  const parentFolder = folders.find((f) => f.id === lesson?.folderId);

  const [copied, setCopied] = useState(false);
  const [isSynthesizingCards, setIsSynthesizingCards] = useState(false);
  const [isScrubbingLesson, setIsScrubbingLesson] = useState(false);
  const [isEditingTitle, setIsEditingTitle] = useState(false);
  const [editTitleValue, setEditTitleValue] = useState('');
  const [isCardCreatorOpen, setIsCardCreatorOpen] = useState(false);
  const playerRef = useRef<YouTubePlayerHandle>(null);

  // Associated deck & card presence check
  const associatedDeck = React.useMemo(() => {
    if (!lesson) return null;
    const cleanTitle = lesson.title
      .replace(/^\[Live\]\s*/i, '')
      .replace(/^CS Note:\s*/i, '')
      .replace(/\s*\(SRS Cards\)/i, '')
      .trim()
      .toLowerCase();

    return decks.find((d) => {
      const dTitle = d.title.toLowerCase().replace(/\s*\(srs cards\)/i, '').trim();
      if (!dTitle) return false;
      return (
        dTitle === cleanTitle ||
        dTitle.includes(cleanTitle) ||
        cleanTitle.includes(dTitle) ||
        (lesson.topic && lesson.topic.toLowerCase() !== 'computer science' && dTitle.includes(lesson.topic.toLowerCase())) ||
        (lesson.folderId && d.folderId === lesson.folderId && (dTitle.includes(cleanTitle) || cleanTitle.includes(dTitle)))
      );
    });
  }, [decks, lesson]);

  const hasFlashcards = Boolean(associatedDeck && (associatedDeck.cards?.length ?? 0) > 0);

  // Video time tracking & persistent resume
  const savedStartTime = React.useMemo(() => {
    if (!lessonId) return 0;
    try {
      const local = localStorage.getItem(`yt_progress_${lessonId}`);
      if (local) {
        const parsed = parseFloat(local);
        if (!isNaN(parsed) && parsed > 0) return Math.floor(parsed);
      }
    } catch { /* ignore */ }
    return lesson?.lastWatchedTime ? Math.floor(lesson.lastWatchedTime) : 0;
  }, [lessonId, lesson?.lastWatchedTime]);

  const [videoCurrentTime, setVideoCurrentTime] = useState<number>(savedStartTime);
  const [videoPauseTime, setVideoPauseTime] = useState<number>(savedStartTime);
  const lastSavedTimeRef = useRef<number>(savedStartTime);

  const handleTimeUpdate = (currentTime: number) => {
    const rounded = Math.floor(currentTime);
    setVideoCurrentTime(rounded);

    // Persist progress to localStorage every 2s
    if (Math.abs(rounded - lastSavedTimeRef.current) >= 2) {
      lastSavedTimeRef.current = rounded;
      if (lessonId) {
        try {
          localStorage.setItem(`yt_progress_${lessonId}`, String(rounded));
        } catch { /* ignore */ }
      }
      // Persist to database every 5s
      if (lesson && Math.abs(rounded - (lesson.lastWatchedTime || 0)) >= 5) {
        updateLesson({ ...lesson, lastWatchedTime: rounded });
      }
    }
  };

  const handleVideoPause = (currentTime: number) => {
    const rounded = Math.floor(currentTime);
    if (rounded > 0) {
      setVideoPauseTime(rounded);
      lastSavedTimeRef.current = rounded;
      if (lessonId) {
        try {
          localStorage.setItem(`yt_progress_${lessonId}`, String(rounded));
        } catch { /* ignore */ }
      }
      if (lesson) {
        updateLesson({ ...lesson, lastWatchedTime: rounded });
      }
    }
  };

  const handleRestartVideo = () => {
    playerRef.current?.seekTo(0);
    setVideoCurrentTime(0);
    lastSavedTimeRef.current = 0;
    if (lessonId) {
      try {
        localStorage.setItem(`yt_progress_${lessonId}`, '0');
      } catch { /* ignore */ }
    }
    if (lesson) {
      updateLesson({ ...lesson, lastWatchedTime: 0 });
    }
  };

  React.useEffect(() => {
    if (lesson) {
      setActiveResource({
        title: lesson.title,
        type: 'lesson',
        contextText: `CURRENT CS LECTURE NOTE VIEWED BY USER:
Title: ${lesson.title}
Subject/Topic: ${lesson.topic}
Sources & Citations: ${lesson.sources?.join(', ') || lesson.sourceUrl || 'N/A'}

FULL NOTE CONTENT:
${lesson.content}`,
        suggestedPrompts: [
          `Summarize the key algorithmic concepts in "${lesson.title}"`,
          'Explain the time complexity and systems trade-offs',
          'Quiz me on this lesson with 3 conceptual questions',
          'Provide an advanced Dart pattern implementation'
        ]
      });
    }
    return () => setActiveResource(null);
  }, [lesson, setActiveResource]);

  if (!lesson) {
    return (
      <div className="max-w-4xl mx-auto py-16 px-4 text-center">
        <div className="w-16 h-16 rounded-3xl bg-slate-100 border border-slate-200 flex items-center justify-center mx-auto mb-4 text-slate-400">
          <BookOpen className="w-8 h-8" />
        </div>
        <h2 className="text-xl font-bold text-slate-800 mb-2">Lesson Not Found</h2>
        <p className="text-sm text-slate-500 mb-6">This lecture note may have been deleted or moved.</p>
        <Link
          to="/"
          className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-bold text-xs shadow-md transition-all"
        >
          <ArrowLeft className="w-4 h-4" /> Return to Dashboard
        </Link>
      </div>
    );
  }

  const handleCopyMarkdown = async () => {
    if (lesson) {
      await navigator.clipboard.writeText(lesson.content);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleDelete = async () => {
    if (window.confirm('Are you sure you want to delete this lecture note?')) {
      await deleteLesson(lesson.id);
      navigate(lesson.folderId ? `/?tab=decks&folder=${lesson.folderId}` : (lesson.videoUrl ? '/?tab=live' : '/?tab=lessons'));
    }
  };

  const handleSaveTitle = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editTitleValue.trim()) return;
    await updateLesson({ ...lesson, title: editTitleValue.trim() });
    setIsEditingTitle(false);
  };

  const handleExportToLesson = async (customContent?: string) => {
    try {
      const contentToExport = customContent || lesson.content;
      const cleanTitle = lesson.title.replace(/^\[Live\]\s*/i, '').trim();
      const newLessonId = Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
      const titleToUse = cleanTitle.startsWith('CS Note:') ? cleanTitle : `CS Note: ${cleanTitle}`;
      const newLesson: Lesson = {
        id: newLessonId,
        title: titleToUse,
        topic: lesson.topic,
        content: contentToExport,
        sources: [lesson.videoUrl ? `Video Lecture: ${lesson.title}` : (lesson.pdfUrl ? `PDF: ${lesson.pdfFilename || lesson.title}` : lesson.title)],
        folderId: lesson.folderId,
        createdAt: Date.now(),
      };
      await addLesson(newLesson);

      alert(`✅ Successfully exported to standalone CS Lesson Note: "${newLesson.title}"!`);
      navigate(`/lesson/${newLesson.id}`);
    } catch (err) {
      console.error('Export to lesson failed:', err);
      alert('Failed to export to lesson.');
    }
  };

  const handleScrubLesson = async () => {
    setIsScrubbingLesson(true);
    try {
      const promptText = lesson.videoUrl
        ? `Video lecture title: "${lesson.title}". Video URL: ${lesson.videoUrl}.\nExisting Student Notes:\n${lesson.content}`
        : (lesson.pdfUrl ? `PDF Document: "${lesson.pdfFilename || lesson.title}".\nNotes:\n${lesson.content}` : lesson.content);

      const targetUrl = lesson.videoUrl || lesson.pdfUrl;

      const res = await fetch('/api/generate-lesson', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          topic: lesson.title,
          url: targetUrl,
          urls: targetUrl ? [targetUrl] : [],
          rawText: promptText
        }),
      });

      if (!res.ok) {
        const errJson = await res.json().catch(() => null);
        throw new Error(errJson?.error || `Server error (${res.status}): Failed to generate lesson`);
      }

      const data = await res.json();
      if (data && data.content) {
        const fullNewContent = `${data.content}\n\n---\n\n## 📝 Student Real-time Notes\n${lesson.content}`;
        await updateLesson({
          ...lesson,
          content: fullNewContent,
          title: data.title || lesson.title,
          topic: data.topic || lesson.topic,
        });
        setActiveResource({
          title: lesson.title,
          type: 'lesson',
          contextText: fullNewContent,
        });
        alert('🎉 Successfully generated structured Professor-grade CS Lecture Notes!');
      } else {
        alert('AI did not return content. Please check your notes.');
      }
    } catch (err: any) {
      console.error('Failed to scrub lesson:', err);
      alert(`Lesson generation failed: ${err.message || 'Please check your API key.'}`);
    } finally {
      setIsScrubbingLesson(false);
    }
  };

  const handleSynthesizeFlashcards = async () => {
    setIsSynthesizingCards(true);
    try {
      let targetDeck = decks.find((d) => d.title.toLowerCase().includes(lesson.title.toLowerCase()) || d.title.toLowerCase().includes(lesson.topic.toLowerCase()));

      let deckIdToUse = targetDeck?.id;

      if (!deckIdToUse) {
        const cleanTitle = lesson.title.replace(/^\[Live\]\s*/i, '').trim();
        const newDeckId = Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
        const newDeck: Deck = {
          id: newDeckId,
          title: `${cleanTitle} (SRS Cards)`,
          cards: [],
          folderId: lesson.folderId,
          createdAt: Date.now(),
        };
        await addDeck(newDeck);
        deckIdToUse = newDeck.id;
      }

      const targetUrl = lesson.videoUrl || lesson.pdfUrl;

      const res = await fetch('/api/generate-deck', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          topic: lesson.title,
          url: targetUrl,
          urls: targetUrl ? [targetUrl] : [],
          rawText: lesson.content,
          count: 8,
        }),
      });

      if (!res.ok) {
        const errJson = await res.json().catch(() => null);
        throw new Error(errJson?.error || `Server error (${res.status}): Failed to generate cards`);
      }

      const data = await res.json();
      const generatedCards = Array.isArray(data) ? data : ((data && data.cards) || []);

      if (generatedCards.length > 0) {
        for (const cardData of generatedCards) {
          const cardId = Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
          const newCard: Card = {
            id: cardId,
            type: cardData.type || 'Concept',
            front: cardData.front,
            back: cardData.back,
            codeSnippet: cardData.codeSnippet,
            nextReview: Date.now(),
            interval: 1,
            ease: 2.5,
            reps: 0,
          };
          await addCardToDeck(deckIdToUse, newCard);
        }
        alert(`🎉 Successfully synthesized ${generatedCards.length} active recall flashcards into deck!`);
      } else {
        alert('AI did not return any cards. Try refining your notes.');
      }
    } catch (err: any) {
      console.error('Failed to synthesize flashcards:', err);
      alert(`Synthesis failed: ${err.message || 'Please check your API key.'}`);
    } finally {
      setIsSynthesizingCards(false);
    }
  };

  const formatTimestamp = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleInsertTimestamp = () => {
    const timeSec = playerRef.current?.getCurrentTime() || videoCurrentTime || 0;
    const stampText = `\n\n⏱️ **[${formatTimestamp(timeSec)}]** `;
    const updated = (lesson.content || '') + stampText;
    updateLesson({ ...lesson, content: updated });
    setActiveResource({
      title: lesson.title,
      type: 'lesson',
      contextText: updated,
    });
  };

  const hasVideo = Boolean(lesson.videoUrl);
  const hasPDF = Boolean(lesson.pdfUrl);
  const isDualPane = hasVideo || hasPDF;

  return (
    <div className={`${isDualPane ? 'max-w-[1720px]' : 'max-w-4xl'} mx-auto py-6 px-4 sm:px-6 lg:px-8 transition-all`}>
      {/* Top Header Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <Link
          to={lesson.folderId ? `/?tab=decks&folder=${lesson.folderId}` : (hasVideo ? '/?tab=live' : '/?tab=lessons')}
          className="inline-flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-900 transition-colors group cursor-pointer"
        >
          <ArrowLeft className="w-4 h-4 transition-transform group-hover:-translate-x-1" />
          {parentFolder
            ? `Back to 📁 ${parentFolder.name}`
            : (hasVideo ? 'Back to Live Lectures' : (hasPDF ? 'Back to Documents & Lessons' : 'Back to Lecture Notes'))}
        </Link>

        <div className="flex flex-wrap items-center gap-2">
          {hasVideo && (
            <button
              onClick={() => handleExportToLesson()}
              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 rounded-xl text-xs font-bold shadow-2xs transition-all cursor-pointer"
              title="Export as a standalone CS Lecture Note in the Lessons tab"
            >
              <BookOpen className="w-3.5 h-3.5" />
              Export to Lesson
            </button>
          )}

          <button
            onClick={handleCopyMarkdown}
            className="inline-flex items-center gap-1.5 px-3.5 py-1.5 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 rounded-xl text-xs font-semibold shadow-2xs transition-all cursor-pointer"
            title="Copy entire markdown note"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5 text-slate-500" />}
            {copied ? 'Copied' : 'Copy Markdown'}
          </button>

          <button
            onClick={handleDelete}
            className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-xl transition-all border border-transparent hover:border-rose-200 cursor-pointer"
            title="Delete lecture note"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Lesson Header Hero Card */}
      <div className="bg-white/95 rounded-3xl shadow-[0_8px_30px_rgba(0,0,0,0.04)] border border-slate-200/90 p-5 sm:p-6 backdrop-blur-md mb-6 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-br from-emerald-500/10 via-teal-500/5 to-transparent rounded-full blur-3xl pointer-events-none"></div>

        <div className="relative z-10 space-y-3">
          {/* Badges row */}
          <div className="flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-full text-xs font-bold font-mono">
              <BookOpen className="w-3.5 h-3.5" />
              {lesson.topic}
            </span>

            {hasPDF && (
              <span className="inline-flex items-center gap-1 px-3 py-1 bg-rose-50 text-rose-700 border border-rose-200 rounded-full text-xs font-semibold font-mono">
                <FileText className="w-3.5 h-3.5" />
                PDF Document ({lesson.pdfPages || 1} pages)
              </span>
            )}

            {parentFolder && (
              <span className="inline-flex items-center gap-1 px-3 py-1 bg-slate-100 text-slate-700 border border-slate-200 rounded-full text-xs font-semibold">
                <FolderIcon className="w-3.5 h-3.5 text-blue-500" />
                {parentFolder.name}
              </span>
            )}

            <span className="inline-flex items-center gap-1 text-[11px] font-mono text-slate-400 ml-auto">
              <Calendar className="w-3 h-3" />
              {new Date(lesson.createdAt).toLocaleDateString(undefined, {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
              })}
            </span>
          </div>

          {/* Title row */}
          {isEditingTitle ? (
            <form onSubmit={handleSaveTitle} className="flex items-center gap-2">
              <input
                type="text"
                autoFocus
                value={editTitleValue}
                onChange={(e) => setEditTitleValue(e.target.value)}
                className="flex-1 px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-lg font-extrabold text-slate-900 focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
              />
              <button
                type="submit"
                className="px-4 py-2 bg-emerald-600 text-white rounded-xl text-xs font-bold shadow-sm"
              >
                Save
              </button>
              <button
                type="button"
                onClick={() => setIsEditingTitle(false)}
                className="px-3 py-2 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold"
              >
                Cancel
              </button>
            </form>
          ) : (
            <div className="flex items-start justify-between gap-3">
              <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight leading-snug">
                {lesson.title}
              </h1>
              <button
                onClick={() => {
                  setEditTitleValue(lesson.title);
                  setIsEditingTitle(true);
                }}
                className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100 transition-colors shrink-0"
                title="Edit title"
              >
                <Edit3 className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* Multiple Sources & Media References */}
          {(() => {
            const allSources: string[] = Array.isArray(lesson.sources) && lesson.sources.length > 0
              ? lesson.sources
              : (lesson.sourceUrl ? [lesson.sourceUrl] : []);

            if (allSources.length === 0) return null;

            return (
              <div className="p-3 bg-slate-50/80 rounded-2xl border border-slate-200/70 space-y-2">
                <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700 uppercase tracking-wider">
                  <BookOpen className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Synthesized Sources ({allSources.length})</span>
                </div>
                <div className="flex flex-wrap gap-2">
                  {allSources.map((src, i) => {
                    const isUrl = src.startsWith('http://') || src.startsWith('https://');
                    if (isUrl) {
                      let displayDomain = src;
                      try {
                        displayDomain = new URL(src).hostname.replace('www.', '');
                      } catch {}
                      return (
                        <a
                          key={i}
                          href={src}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-emerald-50 text-slate-700 hover:text-emerald-700 border border-slate-200 hover:border-emerald-300 rounded-xl text-xs font-mono font-medium transition-all shadow-2xs group max-w-full"
                          title={src}
                        >
                          <ExternalLink className="w-3 h-3 text-slate-400 group-hover:text-emerald-600 shrink-0" />
                          <span className="truncate max-w-xs">{displayDomain}</span>
                        </a>
                      );
                    }
                    return (
                      <span
                        key={i}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white text-slate-700 border border-slate-200 rounded-xl text-xs font-sans font-medium shadow-2xs"
                      >
                        <FileText className="w-3 h-3 text-emerald-600" />
                        {src}
                      </span>
                    );
                  })}
                </div>
              </div>
            );
          })()}

          {/* Quick Action: Convert to Flashcards (Shown only when NO flashcards exist yet for this lesson/topic) */}
          {!isDualPane && (
            hasFlashcards ? (
              <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-indigo-50/50 -mx-5 sm:-mx-6 -mb-5 sm:-mb-6 p-4 rounded-b-3xl border-t border-indigo-100/80">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-xs shadow-2xs">
                    <Layers className="w-4 h-4" />
                  </div>
                  <div>
                    <p className="text-xs font-bold text-slate-800">
                      {associatedDeck!.cards.length} Active Recall Flashcards Ready
                    </p>
                    <p className="text-[11px] text-slate-500">
                      Linked Deck: <span className="font-semibold text-indigo-700">{associatedDeck!.title}</span>
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <Link
                    to={`/deck/${associatedDeck!.id}`}
                    className="inline-flex items-center justify-center gap-1.5 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-sm transition-all cursor-pointer whitespace-nowrap"
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    Study Deck ({associatedDeck!.cards.length})
                  </Link>
                </div>
              </div>
            ) : (
              <div className="pt-2 border-t border-slate-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
                <p className="text-xs text-slate-500">
                  Turn these lecture notes into active recall flashcards to memorize with spaced repetition.
                </p>

                <button
                  onClick={() => handleSynthesizeFlashcards()}
                  disabled={isSynthesizingCards}
                  className="inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-md transition-all disabled:opacity-50 cursor-pointer whitespace-nowrap"
                >
                  {isSynthesizingCards ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Generating Flashcards...
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4 text-amber-300" />
                      Synthesize SRS Flashcards
                    </>
                  )}
                </button>
              </div>
            )
          )}
        </div>
      </div>

      {/* Main Workspace Layout */}
      {isDualPane ? (
        /* Side-by-Side Dual Pane Layout for Video / PDF & Notes */
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">
          {/* Left Column: Media Viewer (Video or PDF) */}
          <div className="xl:col-span-7 2xl:col-span-7 space-y-5">
            {hasVideo && (
              <div className="bg-white/98 rounded-3xl p-4 sm:p-5 shadow-md border border-slate-200/90 space-y-4 backdrop-blur-md">
                <YouTubeEmbed
                  ref={playerRef}
                  videoUrl={lesson.videoUrl!}
                  initialStartTime={savedStartTime}
                  onPause={handleVideoPause}
                  onTimeUpdate={handleTimeUpdate}
                />

                {/* Video Toolbar: Timestamp, Progress & Actions */}
                <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-slate-100">
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={handleInsertTimestamp}
                      className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-slate-100 hover:bg-rose-50 text-slate-800 hover:text-rose-700 border border-slate-200 hover:border-rose-200 rounded-xl text-xs font-bold font-mono transition-all cursor-pointer shadow-2xs"
                      title="Insert current video timestamp into notes"
                    >
                      <Timer className="w-4 h-4 text-rose-500" />
                      <span>+ Timestamp [{formatTimestamp(videoCurrentTime)}]</span>
                    </button>

                    {videoCurrentTime > 5 && (
                      <button
                        type="button"
                        onClick={handleRestartVideo}
                        className="inline-flex items-center gap-1 px-2.5 py-2 bg-slate-50 hover:bg-slate-100 text-slate-500 hover:text-slate-700 border border-slate-200 rounded-xl text-xs font-semibold transition-all cursor-pointer shadow-2xs"
                        title="Restart video from 00:00"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>Restart</span>
                      </button>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-2 ml-auto">
                    <button
                      type="button"
                      onClick={handleScrubLesson}
                      disabled={isScrubbingLesson || isSynthesizingCards}
                      className="inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-sm transition-all disabled:opacity-50 cursor-pointer active:scale-95 whitespace-nowrap"
                      title="Generate structured professor-grade lecture notes from this video lecture"
                    >
                      {isScrubbingLesson ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          Generating...
                        </>
                      ) : (
                        <>
                          <BookOpen className="w-4 h-4" />
                          Generate CS Lesson
                        </>
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={handleSynthesizeFlashcards}
                      disabled={isSynthesizingCards || isScrubbingLesson}
                      className="inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-gradient-to-r from-rose-600 via-rose-500 to-pink-600 hover:from-rose-500 hover:to-pink-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-sm transition-all disabled:opacity-50 cursor-pointer active:scale-95 whitespace-nowrap"
                      title="Make 8 active recall flashcards from this lecture"
                    >
                      {isSynthesizingCards ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          Making...
                        </>
                      ) : (
                        <>
                          <Sparkles className="w-4 h-4 text-amber-300" />
                          Make Flashcards
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            )}

            {hasPDF && (
              <div className="space-y-4">
                <PDFViewer
                  pdfUrl={lesson.pdfUrl!}
                  filename={lesson.pdfFilename || lesson.title}
                  pageCount={lesson.pdfPages}
                />

                {/* PDF Action Toolbar */}
                <div className="bg-white/98 rounded-3xl p-4 shadow-sm border border-slate-200/90 flex flex-wrap items-center justify-between gap-3 backdrop-blur-md">
                  <div className="flex items-center gap-2 text-xs font-mono font-bold text-slate-700">
                    <FileText className="w-4 h-4 text-rose-500" />
                    <span>{lesson.pdfFilename || 'Imported PDF Document'}</span>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 ml-auto">
                    <button
                      type="button"
                      onClick={handleScrubLesson}
                      disabled={isScrubbingLesson || isSynthesizingCards}
                      className="inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-sm transition-all disabled:opacity-50 cursor-pointer active:scale-95 whitespace-nowrap"
                      title="Synthesize structured study guide from this PDF"
                    >
                      {isScrubbingLesson ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          Generating...
                        </>
                      ) : (
                        <>
                          <BookOpen className="w-4 h-4" />
                          Generate CS Lesson
                        </>
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={handleSynthesizeFlashcards}
                      disabled={isSynthesizingCards || isScrubbingLesson}
                      className="inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-gradient-to-r from-rose-600 via-rose-500 to-pink-600 hover:from-rose-500 hover:to-pink-500 text-white font-bold rounded-xl text-xs uppercase tracking-wider shadow-sm transition-all disabled:opacity-50 cursor-pointer active:scale-95 whitespace-nowrap"
                      title="Make flashcards from this PDF"
                    >
                      {isSynthesizingCards ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          Making...
                        </>
                      ) : (
                        <>
                          <Sparkles className="w-4 h-4 text-amber-300" />
                          Make Flashcards
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* In-Lesson Flashcard Forge */}
            <div className="bg-white/98 rounded-3xl shadow-sm border border-slate-200/90 p-5 backdrop-blur-md">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center border border-amber-200/80 shadow-2xs">
                    <PenTool className="w-4 h-4" />
                  </div>
                  <div>
                    <h2 className="text-xs text-slate-900 uppercase tracking-wider font-extrabold">
                      Create Flashcards from this {hasPDF ? 'PDF Document' : 'Lecture'}
                    </h2>
                    <p className="text-[11px] text-slate-500 font-sans">
                      Craft Concept, Complexity, Cloze, or Dart Code cards while studying
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => setIsCardCreatorOpen(!isCardCreatorOpen)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200 rounded-xl text-xs font-bold transition-all shadow-2xs cursor-pointer"
                >
                  {isCardCreatorOpen ? (
                    <>
                      <ChevronUp className="w-3.5 h-3.5" /> Collapse
                    </>
                  ) : (
                    <>
                      <PenTool className="w-3.5 h-3.5" /> Open Forge
                    </>
                  )}
                </button>
              </div>

              {isCardCreatorOpen && (
                <div className="mt-4 pt-4 border-t border-slate-100 animate-fadeIn">
                  <ManualCardCreator
                    decks={decks}
                    onAddDeck={addDeck}
                    onAddCard={addCardToDeck}
                  />
                </div>
              )}
            </div>
          </div>

          {/* Right Column: Large Interactive Note-Taking Studio */}
          <div className="xl:col-span-5 2xl:col-span-5 space-y-4">
            <RichNoteEditor
              content={lesson.content}
              customHeightClass="h-[600px] sm:h-[700px] xl:h-[800px] 2xl:h-[850px]"
              onStartTyping={() => {
                playerRef.current?.pause();
                const t = playerRef.current?.getCurrentTime() || 0;
                if (t > 0) {
                  setVideoPauseTime(Math.round(t));
                }
              }}
              onExportToLesson={hasVideo || hasPDF ? handleExportToLesson : undefined}
              onChange={async (newContent) => {
                await updateLesson({ ...lesson, content: newContent });
                setActiveResource({
                  title: lesson.title,
                  type: 'lesson',
                  contextText: newContent,
                });
              }}
            />
          </div>
        </div>
      ) : (
        /* Standard Single-Column CS Lecture Note Document View */
        <div className="space-y-8">
          <RichNoteEditor
            content={lesson.content}
            onChange={async (newContent) => {
              await updateLesson({ ...lesson, content: newContent });
              setActiveResource({
                title: lesson.title,
                type: 'lesson',
                contextText: newContent,
              });
            }}
          />

          {/* In-Lesson Flashcard Forge */}
          <div className="bg-white/95 rounded-3xl shadow-[0_8px_30px_rgba(0,0,0,0.04)] border border-slate-200/90 p-6 backdrop-blur-md">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-2xl bg-amber-50 text-amber-700 flex items-center justify-center border border-amber-200/80 shadow-2xs">
                  <PenTool className="w-4 h-4" />
                </div>
                <div>
                  <h2 className="text-sm text-slate-900 uppercase tracking-wider font-extrabold flex items-center gap-2">
                    Create Flashcards from this Lecture
                  </h2>
                  <p className="text-xs text-slate-500 font-sans">
                    Craft Concept, Complexity, Cloze, Pattern, or Code implementation cards while studying
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setIsCardCreatorOpen(!isCardCreatorOpen)}
                className="inline-flex items-center gap-1.5 px-4 py-2 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200 rounded-xl text-xs font-bold transition-all shadow-2xs cursor-pointer"
              >
                {isCardCreatorOpen ? (
                  <>
                    <ChevronUp className="w-3.5 h-3.5" /> Collapse Forge
                  </>
                ) : (
                  <>
                    <PenTool className="w-3.5 h-3.5" /> Open Flashcard Forge
                  </>
                )}
              </button>
            </div>

            {isCardCreatorOpen && (
              <div className="mt-6 pt-6 border-t border-slate-100 animate-fadeIn">
                <ManualCardCreator
                  decks={decks}
                  onAddDeck={addDeck}
                  onAddCard={addCardToDeck}
                />
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}