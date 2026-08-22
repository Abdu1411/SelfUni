import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams, useLocation } from 'react-router-dom';
import {
  Plus,
  Link2,
  BookOpen,
  Loader2,
  Sparkles,
  Code2,
  FolderGit2,
  Trash2,
  Globe,
  Video,
  FileText,
  ChevronDown,
  ChevronUp
} from 'lucide-react';
import { Card, Deck, Lesson } from '../types';
import { useDecks } from '../store';

interface AICardGeneratorProps {
  onDeckGenerated: (deck: Deck) => void;
  onLessonGenerated?: (lesson: Lesson) => void;
}

export function AICardGenerator({ onDeckGenerated, onLessonGenerated }: AICardGeneratorProps) {
  const navigate = useNavigate();
  const { folders, addLesson, addFolder } = useDecks();
  const [searchParams] = useSearchParams();
  const location = useLocation();
  const state = location.state as { sourceText?: string; courseName?: string } | null;
  const [urls, setUrls] = useState<string[]>(['']);
  const [topic, setTopic] = useState(searchParams.get('topic') || '');
  const [rawText, setRawText] = useState(state?.sourceText || '');
  const [showRawTextInput, setShowRawTextInput] = useState(!!state?.sourceText);
  const [isGeneratingDeck, setIsGeneratingDeck] = useState(false);
  const [isGeneratingLesson, setIsGeneratingLesson] = useState(false);
  const [selectedFolderId, setSelectedFolderId] = useState<string>('');

  const AUTO_CREATE_FOLDER_ID = 'auto-create-course-folder';

  useEffect(() => {
    if (state?.courseName) {
      const existing = folders.find(f => f.name === state.courseName);
      if (existing) {
        setSelectedFolderId(existing.id);
      } else if (!selectedFolderId) {
        setSelectedFolderId(AUTO_CREATE_FOLDER_ID);
      }
    }
  }, [state?.courseName, folders, selectedFolderId]);

  const handleAddUrl = () => {
    setUrls(prev => [...prev, '']);
  };

  const handleUrlChange = (index: number, val: string) => {
    setUrls(prev => {
      const updated = [...prev];
      updated[index] = val;
      return updated;
    });
  };

  const handleRemoveUrl = (index: number) => {
    setUrls(prev => prev.filter((_, i) => i !== index));
  };

  const isBusy = isGeneratingDeck || isGeneratingLesson;
  const hasAnyInput = topic.trim() || urls.some(u => u.trim()) || rawText.trim();

  // 1. Generate Flashcards Deck
  const handleGenerateDeck = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const validUrls = urls.map(u => u.trim()).filter(Boolean);
    if (!validUrls.length && !topic.trim() && !rawText.trim()) return;

    setIsGeneratingDeck(true);
    try {
      const response = await fetch('/api/generate-deck', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          urls: validUrls,
          url: validUrls[0] || undefined,
          rawText: rawText.trim() || undefined,
          topic: topic.trim() || undefined
        })
      });
      
      const responseText = await response.text();
      let data: any = null;
      try {
        data = responseText ? JSON.parse(responseText) : [];
      } catch (parseErr) {
        throw new Error(
          response.ok 
            ? 'Server returned invalid response format.' 
            : `Server error (${response.status}): ${responseText.slice(0, 150)}`
        );
      }

      if (!response.ok) {
        throw new Error((data && data.error) || `Generation failed with status ${response.status}`);
      }

      const generatedCards = Array.isArray(data) ? data : (data && data.cards) || [];
      if (!generatedCards.length) {
        throw new Error('AI generated 0 cards. Please specify a more detailed Dart topic or valid URLs.');
      }
      
      const now = Date.now();

      let defaultTitle = 'New CS Deck';
      if (topic.trim()) {
        defaultTitle = topic.trim();
      } else if (validUrls[0]) {
        try {
          defaultTitle = new URL(validUrls[0]).hostname;
        } catch {
          defaultTitle = 'Synthesized Deck';
        }
      }

      let finalFolderId = selectedFolderId;
      if (finalFolderId === AUTO_CREATE_FOLDER_ID && state?.courseName) {
        const newFolder = await addFolder(state.courseName);
        finalFolderId = newFolder.id;
      }

      const newDeck: Deck = {
        id: crypto.randomUUID(),
        title: defaultTitle,
        folderId: finalFolderId || undefined,
        createdAt: now,
        cards: generatedCards.map((c: any) => ({
          ...c,
          id: crypto.randomUUID(),
          nextReview: now,
          interval: 0,
          ease: 2.5,
          reps: 0
        })) as Card[]
      };

      onDeckGenerated(newDeck);
      setUrls(['']);
      setTopic('');
      setRawText('');
      setShowRawTextInput(false);
    } catch (error: any) {
      console.error(error);
      alert(`Failed to generate deck: ${error.message}`);
    } finally {
      setIsGeneratingDeck(false);
    }
  };

  // 2. Generate CS Lesson Note (using the exact same prompt / synthesis endpoint)
  const handleGenerateLesson = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const validUrls = urls.map(u => u.trim()).filter(Boolean);
    if (!validUrls.length && !topic.trim() && !rawText.trim()) return;

    setIsGeneratingLesson(true);
    try {
      const response = await fetch('/api/generate-lesson', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          urls: validUrls,
          url: validUrls[0] || undefined,
          rawText: rawText.trim() || undefined,
          topic: topic.trim() || undefined
        })
      });

      const responseText = await response.text();
      let data: any = null;
      try {
        data = responseText ? JSON.parse(responseText) : {};
      } catch (parseErr) {
        throw new Error(
          response.ok 
            ? 'Server returned invalid response format.' 
            : `Server error (${response.status}): ${responseText.slice(0, 150)}`
        );
      }

      if (!response.ok) {
        throw new Error(data.error || `Generation failed with status ${response.status}`);
      }

      if (!data.content || !data.title) {
        throw new Error('AI was unable to generate lecture notes. Please try different sources or topics.');
      }

      const sourcesList = data.sources && Array.isArray(data.sources) && data.sources.length > 0
        ? data.sources
        : validUrls;

      let finalFolderId = selectedFolderId;
      if (finalFolderId === AUTO_CREATE_FOLDER_ID && state?.courseName) {
        const newFolder = await addFolder(state.courseName);
        finalFolderId = newFolder.id;
      }

      const newLesson: Lesson = {
        id: crypto.randomUUID(),
        title: data.title,
        topic: data.topic || topic.trim() || 'Computer Science',
        sourceUrl: validUrls[0] || undefined,
        sources: sourcesList.length > 0 ? sourcesList : undefined,
        content: data.content,
        folderId: finalFolderId || undefined,
        createdAt: Date.now()
      };

      if (onLessonGenerated) {
        onLessonGenerated(newLesson);
      } else {
        await addLesson(newLesson);
        navigate(`/lesson/${newLesson.id}`);
      }

      setUrls(['']);
      setTopic('');
      setRawText('');
      setShowRawTextInput(false);
    } catch (error: any) {
      console.error(error);
      alert(`Failed to generate lecture note: ${error.message}`);
    } finally {
      setIsGeneratingLesson(false);
    }
  };

  return (
    <section className="bg-white/90 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.04)] border border-slate-200/80 p-7 backdrop-blur-md relative overflow-hidden group hover:border-blue-300 transition-all hover:shadow-[0_8px_30px_rgba(37,99,235,0.06)]">
      {/* Decorative ambient background */}
      <div className="absolute -top-20 -right-20 w-56 h-56 bg-gradient-to-br from-blue-500/10 to-cyan-500/10 rounded-full blur-2xl pointer-events-none"></div>
      
      <div className="max-w-2xl relative z-10">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200 shadow-2xs">
            <Sparkles className="w-4 h-4" />
          </div>
          <div>
            <h1 className="text-base font-extrabold tracking-tight text-slate-900 uppercase italic">
              AI Multi-Source Synthesizer
            </h1>
          </div>
          <span className="ml-auto px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-blue-50 text-blue-600 border border-blue-200">
            Flashcards & Lessons
          </span>
        </div>
        <p className="text-xs text-slate-500 mb-6 font-sans">
          Provide a topic, documentation URLs, or YouTube video lecture links to generate either a 30-card spaced repetition deck or a comprehensive professor-grade study lesson.
        </p>
        
        <form onSubmit={handleGenerateDeck} className="space-y-4">
          <div className="relative">
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Computer Science Topic or Algorithm Title
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none text-slate-400">
                <Code2 className="w-4 h-4" />
              </div>
              <input
                type="text"
                placeholder="e.g. Binary Search Trees, Graph BFS, Operating Systems"
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                className="w-full pl-9 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs"
              />
            </div>
          </div>

          {/* Multiple Source URLs */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                <Globe className="w-3.5 h-3.5 text-blue-600" />
                Source URLs (Documentation, Articles, GitHub, YouTube Lectures)
              </label>
              <button
                type="button"
                onClick={handleAddUrl}
                className="inline-flex items-center gap-1 text-[11px] font-bold text-blue-600 hover:text-blue-700 transition-colors cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                Add Source URL
              </button>
            </div>

            <div className="space-y-2">
              {urls.map((u, idx) => (
                <div key={idx} className="flex items-center gap-2">
                  <div className="relative flex-1">
                    <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none text-slate-400">
                      <Link2 className="w-3.5 h-3.5" />
                    </div>
                    <input
                      type="url"
                      placeholder={`Source ${idx + 1} URL (e.g. https://youtube.com/watch?v=... or https://dart.dev)`}
                      value={u}
                      onChange={(e) => handleUrlChange(idx, e.target.value)}
                      className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs"
                    />
                  </div>
                  {urls.length > 1 && (
                    <button
                      type="button"
                      onClick={() => handleRemoveUrl(idx)}
                      className="p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-colors cursor-pointer"
                      title="Remove source"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Expandable Raw Text / Video Transcript Input */}
          <div>
            <button
              type="button"
              onClick={() => setShowRawTextInput(!showRawTextInput)}
              className="inline-flex items-center gap-1.5 text-[11px] font-bold text-slate-600 hover:text-blue-600 transition-colors cursor-pointer bg-slate-50 hover:bg-slate-100 px-3 py-1.5 rounded-lg border border-slate-200"
            >
              <Video className="w-3.5 h-3.5 text-purple-600" />
              <span>{showRawTextInput ? 'Hide Lecture Transcript Box' : '+ Paste Video Lecture Transcript / Raw Notes'}</span>
              {showRawTextInput ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
            </button>

            {showRawTextInput && (
              <div className="mt-2.5 space-y-1.5 animate-fadeIn">
                <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-purple-600" />
                  Pasted Video Lecture Transcript or Notes
                </label>
                <textarea
                  value={rawText}
                  onChange={(e) => setRawText(e.target.value)}
                  placeholder="Paste lecture video subtitles, timestamped transcripts, book snippets, or lecture slide notes here..."
                  rows={4}
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-mono text-xs focus:bg-white focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-all placeholder:text-slate-400 resize-y"
                />
              </div>
            )}
          </div>

          {folders.length > 0 && (
            <div>
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center gap-1.5">
                <FolderGit2 className="w-3.5 h-3.5 text-blue-600" /> Target Folder (Optional)
              </label>
              <select
                value={selectedFolderId}
                onChange={(e) => setSelectedFolderId(e.target.value)}
                className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-sans text-xs focus:bg-white focus:border-blue-500 focus:outline-none transition-all cursor-pointer"
              >
                <option value="">📁 Unfiled (No Folder)</option>
                {state?.courseName && !folders.find(f => f.name === state.courseName) && (
                  <option value={AUTO_CREATE_FOLDER_ID}>📁 {state.courseName} (Auto-create)</option>
                )}
                {folders.map(f => (
                  <option key={f.id} value={f.id}>
                    📁 {f.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Action Buttons: Generate Cards & Generate Lesson */}
          <div className="pt-3 border-t border-slate-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-3">
            {/* Generate Lesson Note Button */}
            <button
              type="button"
              onClick={handleGenerateLesson}
              disabled={isBusy || !hasAnyInput}
              className="px-5 py-2.5 h-[42px] bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl transition-all shadow-[0_4px_16px_rgba(16,185,129,0.25)] hover:shadow-[0_6px_20px_rgba(16,185,129,0.35)] text-xs uppercase tracking-wider disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none inline-flex items-center justify-center gap-2 whitespace-nowrap cursor-pointer"
              title="Generate comprehensive professor-grade CS lecture notes from these sources"
            >
              {isGeneratingLesson ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Synthesizing Lesson Notes...
                </>
              ) : (
                <>
                  <BookOpen className="w-4 h-4" />
                  Generate CS Lesson
                </>
              )}
            </button>

            {/* Synthesize Flashcards Button */}
            <button
              type="submit"
              disabled={isBusy || !hasAnyInput}
              className="px-6 py-2.5 h-[42px] bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold rounded-xl transition-all shadow-[0_4px_16px_rgba(37,99,235,0.3)] hover:shadow-[0_6px_20px_rgba(37,99,235,0.4)] text-xs uppercase tracking-widest disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none inline-flex items-center justify-center gap-2 whitespace-nowrap cursor-pointer"
              title="Synthesize 30-card spaced repetition deck from these sources"
            >
              {isGeneratingDeck ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Synthesizing 30 Cards...
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Synthesize 30 Cards
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}
