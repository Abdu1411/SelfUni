import React, { useState } from 'react';
import {
  BookOpen,
  Link2,
  Sparkles,
  Loader2,
  FolderGit2,
  FileText,
  Plus,
  Trash2,
  Layers,
  Video,
  FileCode,
  Globe
} from 'lucide-react';
import { useDecks } from '../store';
import { Lesson } from '../types';

interface LessonGeneratorProps {
  onLessonGenerated: (lesson: Lesson) => void;
}

export function LessonGenerator({ onLessonGenerated }: LessonGeneratorProps) {
  const { folders } = useDecks();
  const [topic, setTopic] = useState('');
  const [urls, setUrls] = useState<string[]>(['']);
  const [rawText, setRawText] = useState('');
  const [showRawTextInput, setShowRawTextInput] = useState(false);
  const [selectedFolderId, setSelectedFolderId] = useState<string>('');
  const [isGenerating, setIsGenerating] = useState(false);

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

  const handleGenerate = async (e: React.FormEvent) => {
    e.preventDefault();
    const validUrls = urls.map(u => u.trim()).filter(Boolean);
    if (!validUrls.length && !topic.trim() && !rawText.trim()) return;

    setIsGenerating(true);
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

      const newLesson: Lesson = {
        id: crypto.randomUUID(),
        title: data.title,
        topic: data.topic || topic.trim() || 'Computer Science',
        sourceUrl: validUrls[0] || undefined,
        sources: sourcesList.length > 0 ? sourcesList : undefined,
        content: data.content,
        folderId: selectedFolderId || undefined,
        createdAt: Date.now()
      };

      onLessonGenerated(newLesson);
      setUrls(['']);
      setTopic('');
      setRawText('');
      setShowRawTextInput(false);
    } catch (error: any) {
      console.error(error);
      alert(`Failed to generate lecture note: ${error.message}`);
    } finally {
      setIsGenerating(false);
    }
  };

  const hasAnyInput = topic.trim() || urls.some(u => u.trim()) || rawText.trim();

  return (
    <section className="bg-white/90 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.04)] border border-slate-200/80 p-7 backdrop-blur-md relative overflow-hidden group hover:border-emerald-300 transition-all hover:shadow-[0_8px_30px_rgba(16,185,129,0.06)]">
      {/* Decorative ambient background */}
      <div className="absolute -top-20 -right-20 w-56 h-56 bg-gradient-to-br from-emerald-500/10 to-teal-500/10 rounded-full blur-2xl pointer-events-none"></div>

      <div className="max-w-2xl relative z-10">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-200 shadow-2xs">
            <BookOpen className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-base font-extrabold tracking-tight text-slate-900 uppercase italic">
              Multi-Source CS Lecture Notes Synthesizer
            </h2>
          </div>
          <span className="ml-auto px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
            Multi-Media & Docs
          </span>
        </div>

        <p className="text-xs text-slate-500 mb-6 font-sans leading-relaxed">
          Combine multiple web articles, YouTube video lecture transcripts, GitHub code docs, or raw textbook notes into one unified, professor-grade CS study lecture with LaTeX math and IDE code blocks.
        </p>

        <form onSubmit={handleGenerate} className="space-y-4">
          {/* Main Topic Field */}
          <div className="relative">
            <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
              Topic or Lecture Title (Optional / Override)
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none text-slate-400">
                <FileText className="w-4 h-4" />
              </div>
              <input
                type="text"
                placeholder="e.g. Self-Balancing Trees, Memory Hierarchy & CPU Cache Lines"
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                className="w-full pl-9 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs"
              />
            </div>
          </div>

          {/* Multiple Source URLs */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                <Globe className="w-3.5 h-3.5 text-emerald-600" />
                Source URLs (Articles, Documentation, Repositories, Blogs)
              </label>
              <button
                type="button"
                onClick={handleAddUrl}
                className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-600 hover:text-emerald-700 transition-colors cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                Add Another URL
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
                      placeholder={`Source ${idx + 1} URL (e.g. https://en.wikipedia.org/... or article)`}
                      value={u}
                      onChange={(e) => handleUrlChange(idx, e.target.value)}
                      className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs"
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

          {/* Expandable Pasted Raw Text / Video Transcript Input */}
          <div>
            {!showRawTextInput ? (
              <button
                type="button"
                onClick={() => setShowRawTextInput(true)}
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-emerald-700 py-1 cursor-pointer transition-colors"
              >
                <FileCode className="w-3.5 h-3.5 text-emerald-600" />
                + Include Pasted Video Transcripts / Lecture Notes
              </button>
            ) : (
              <div className="space-y-1.5 animate-fadeIn pt-1">
                <div className="flex items-center justify-between">
                  <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold flex items-center gap-1.5">
                    <Video className="w-3.5 h-3.5 text-emerald-600" />
                    Pasted Video Transcript / Supplementary Notes
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setShowRawTextInput(false);
                      setRawText('');
                    }}
                    className="text-[11px] text-slate-400 hover:text-slate-600 cursor-pointer"
                  >
                    Hide
                  </button>
                </div>
                <textarea
                  rows={4}
                  placeholder="Paste lecture video transcript, textbook excerpts, slide transcripts, or additional notes here..."
                  value={rawText}
                  onChange={(e) => setRawText(e.target.value)}
                  className="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all text-slate-800 placeholder-slate-400 font-sans text-xs leading-relaxed"
                />
              </div>
            )}
          </div>

          {/* Folder Destination Selector */}
          {folders.length > 0 && (
            <div>
              <label className="block text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5 flex items-center gap-1.5">
                <FolderGit2 className="w-3.5 h-3.5 text-emerald-600" /> Target Folder (Optional)
              </label>
              <select
                value={selectedFolderId}
                onChange={(e) => setSelectedFolderId(e.target.value)}
                className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-sans text-xs focus:bg-white focus:border-emerald-500 focus:outline-none transition-all cursor-pointer"
              >
                <option value="">📁 Unfiled (No Folder)</option>
                {folders.map(f => (
                  <option key={f.id} value={f.id}>
                    📁 {f.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Submit Action Button */}
          <div className="pt-2 flex justify-end">
            <button
              type="submit"
              disabled={isGenerating || !hasAnyInput}
              className="w-full sm:w-auto px-7 py-2.5 h-[42px] bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold rounded-xl transition-all shadow-[0_4px_16px_rgba(16,185,129,0.3)] hover:shadow-[0_6px_20px_rgba(16,185,129,0.4)] text-xs uppercase tracking-widest disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none inline-flex items-center justify-center gap-2 whitespace-nowrap cursor-pointer"
            >
              {isGenerating ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Synthesizing Multi-Source Notes...
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Synthesize Master Lecture Note
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}
