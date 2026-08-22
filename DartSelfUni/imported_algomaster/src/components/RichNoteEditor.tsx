import React, { useState, useRef, useEffect, useCallback } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import {
  Upload,
  Save,
  BookOpen,
  Check,
  Loader2,
  PenLine,
  Eye,
  Sparkles,
  Code2,
  Lightbulb,
  Sigma,
  Maximize2
} from 'lucide-react';
import { MarkdownCodeRenderer } from '../components/CodeBlock';

interface RichNoteEditorProps {
  content: string;
  onChange: (content: string) => void;
  onStartTyping?: () => void;
  onExportToLesson?: (currentContent: string) => void;
  customHeightClass?: string;
}

export const RichNoteEditor: React.FC<RichNoteEditorProps> = ({
  content,
  onChange,
  onStartTyping,
  onExportToLesson,
  customHeightClass = 'h-[500px] sm:h-[600px]'
}) => {
  const [isEditMode, setIsEditMode] = useState(true);
  const [draft, setDraft] = useState(content);
  const [saveStatus, setSaveStatus] = useState<'idle' | 'saving' | 'saved'>('idle');
  const fileInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const debounceTimerRef = useRef<any>(null);
  const draftRef = useRef(draft);
  draftRef.current = draft;

  // Keep draft in sync if external content changes and not editing
  useEffect(() => {
    if (!isEditMode) {
      setDraft(content);
    }
  }, [content, isEditMode]);

  // Debounced auto-save function
  const triggerAutoSave = useCallback((newText: string) => {
    setSaveStatus('saving');
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    debounceTimerRef.current = setTimeout(() => {
      onChange(newText);
      setSaveStatus('saved');
      setTimeout(() => {
        setSaveStatus('idle');
      }, 2000);
    }, 600);
  }, [onChange]);

  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  // Flush any pending auto-save on unmount
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
        debounceTimerRef.current = null;
        try {
          onChangeRef.current(draftRef.current);
        } catch { /* ignore */ }
      }
    };
  }, []);

  const handleToggle = () => {
    if (isEditMode) {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
      onChange(draft);
      setSaveStatus('saved');
      setTimeout(() => setSaveStatus('idle'), 1500);
    }
    setIsEditMode(!isEditMode);
  };

  const handleManualSave = () => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }
    onChange(draft);
    setSaveStatus('saved');
    setTimeout(() => setSaveStatus('idle'), 1500);
  };

  const insertSnippet = (snippet: string) => {
    const textarea = textareaRef.current;
    if (!textarea) {
      const updated = draft + snippet;
      setDraft(updated);
      triggerAutoSave(updated);
      return;
    }

    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const prev = draft;
    const updated = prev.substring(0, start) + snippet + prev.substring(end);
    setDraft(updated);
    triggerAutoSave(updated);

    setTimeout(() => {
      textarea.focus();
      textarea.selectionStart = textarea.selectionEnd = start + snippet.length;
    }, 50);
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const form = new FormData();
    form.append('file', file);
    try {
      setSaveStatus('saving');
      const res = await fetch('/api/media/upload', {
        method: 'POST',
        body: form,
      });
      const data = await res.json();
      if (data.url) {
        const markdownImg = `\n![${file.name}](${data.url})\n`;
        const updated = draft + markdownImg;
        setDraft(updated);
        onChange(updated);
        setSaveStatus('saved');
        setTimeout(() => setSaveStatus('idle'), 2000);
      }
    } catch (err) {
      console.error('Upload failed', err);
      setSaveStatus('idle');
    }
  };

  const openFileDialog = () => {
    fileInputRef.current?.click();
  };

  const linesCount = draft.split('\n').length;
  const wordCount = draft.trim() ? draft.trim().split(/\s+/).length : 0;

  return (
    <div className={`rounded-3xl border border-slate-200/90 bg-white/98 p-5 sm:p-6 shadow-sm backdrop-blur-md flex flex-col transition-all ${customHeightClass}`}>
      {/* Editor Header Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 mb-3.5 border-b border-slate-100 pb-3.5 shrink-0">
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={handleToggle}
            className={`px-3.5 py-1.5 text-xs font-bold rounded-xl flex items-center gap-1.5 transition-all cursor-pointer shadow-2xs ${
              isEditMode
                ? 'bg-emerald-600 text-white shadow-emerald-500/20 hover:bg-emerald-500'
                : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
            }`}
          >
            {isEditMode ? (
              <>
                <Eye className="w-3.5 h-3.5" /> Preview Markdown
              </>
            ) : (
              <>
                <PenLine className="w-3.5 h-3.5" /> Edit Live Notes
              </>
            )}
          </button>

          {isEditMode && (
            <>
              <button
                type="button"
                onClick={openFileDialog}
                className="px-3 py-1.5 text-xs bg-slate-100 rounded-xl hover:bg-slate-200 text-slate-700 flex items-center gap-1.5 font-bold transition-colors cursor-pointer"
                title="Attach image or screenshot"
              >
                <Upload className="w-3.5 h-3.5 text-slate-500" /> Image
              </button>

              <button
                type="button"
                onClick={handleManualSave}
                className="px-3 py-1.5 text-xs bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl flex items-center gap-1.5 font-bold transition-colors cursor-pointer"
              >
                <Save className="w-3.5 h-3.5 text-slate-500" /> Save
              </button>
              <input type="file" ref={fileInputRef} style={{ display: 'none' }} onChange={handleFileChange} />
            </>
          )}

          {/* Auto-save Status Indicator */}
          {saveStatus === 'saving' && (
            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-amber-600 bg-amber-50 px-2.5 py-1 rounded-lg border border-amber-200 animate-pulse">
              <Loader2 className="w-3 h-3 animate-spin text-amber-500" />
              Auto-saving...
            </span>
          )}

          {saveStatus === 'saved' && (
            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
              <Check className="w-3 h-3 text-emerald-600" />
              Saved
            </span>
          )}
        </div>

        {onExportToLesson && (
          <button
            type="button"
            onClick={() => onExportToLesson(draft)}
            className="px-3.5 py-1.5 text-xs bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 rounded-xl font-bold flex items-center gap-1.5 transition-all shadow-2xs cursor-pointer ml-auto"
            title="Export these notes into a standalone CS Lecture Note"
          >
            <BookOpen className="w-3.5 h-3.5" />
            Export to Lesson
          </button>
        )}
      </div>

      {/* Quick Snippet Tools (when editing) */}
      {isEditMode && (
        <div className="flex flex-wrap items-center gap-1.5 mb-3 pb-2.5 border-b border-slate-100 shrink-0">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mr-1">Insert:</span>
          <button
            type="button"
            onClick={() => insertSnippet('\n```dart\n// Code snippet\nvoid main() {\n  \n}\n```\n')}
            className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-50 hover:bg-emerald-50 text-slate-700 hover:text-emerald-700 border border-slate-200 hover:border-emerald-200 rounded-lg text-[11px] font-mono font-bold transition-all cursor-pointer"
            title="Insert Dart Code block"
          >
            <Code2 className="w-3 h-3 text-blue-500" />
            <span>Dart Code</span>
          </button>

          <button
            type="button"
            onClick={() => insertSnippet('\n> 💡 **Key Takeaway / Invariant:** \n')}
            className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-50 hover:bg-amber-50 text-slate-700 hover:text-amber-800 border border-slate-200 hover:border-amber-200 rounded-lg text-[11px] font-mono font-bold transition-all cursor-pointer"
            title="Insert Callout Insight"
          >
            <Lightbulb className="w-3 h-3 text-amber-500" />
            <span>Key Insight</span>
          </button>

          <button
            type="button"
            onClick={() => insertSnippet(' $O(N \\log N)$ ')}
            className="inline-flex items-center gap-1 px-2.5 py-1 bg-slate-50 hover:bg-purple-50 text-slate-700 hover:text-purple-800 border border-slate-200 hover:border-purple-200 rounded-lg text-[11px] font-mono font-bold transition-all cursor-pointer"
            title="Insert Big-O LaTeX Formula"
          >
            <Sigma className="w-3 h-3 text-purple-500" />
            <span>$O(N)$ Math</span>
          </button>
        </div>
      )}

      {/* Main Scrollable Content Area */}
      <div className="flex-1 flex flex-col min-h-0 relative">
        {isEditMode ? (
          <div className="flex-1 flex flex-col min-h-0">
            <textarea
              ref={textareaRef}
              value={draft}
              onChange={e => {
                const val = e.target.value;
                setDraft(val);
                onStartTyping?.();
                triggerAutoSave(val);
              }}
              onFocus={() => onStartTyping?.()}
              placeholder="Type lecture notes, insights, algorithms, and timestamps ($O(N \log N)$)... Scrollable and auto-saves continuously."
              className={`w-full flex-1 p-4 font-mono text-xs sm:text-sm leading-relaxed text-slate-800 bg-slate-50/80 border border-slate-200 rounded-2xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 focus:bg-white transition-all shadow-inner overflow-y-auto resize-none custom-scrollbar`}
            />
          </div>
        ) : (
          <div className={`flex-1 overflow-y-auto p-4 bg-slate-50/40 rounded-2xl border border-slate-100 prose prose-sm max-w-none font-sans leading-relaxed custom-scrollbar`}>
            <ReactMarkdown
              remarkPlugins={[remarkGfm, remarkMath]}
              rehypePlugins={[rehypeKatex]}
              components={{ code: MarkdownCodeRenderer }}
            >
              {draft || '*No notes taken yet. Click "Edit Live Notes" to start writing.*'}
            </ReactMarkdown>
          </div>
        )}
      </div>

      {/* Footer Info & Stats */}
      <div className="flex items-center justify-between text-[11px] text-slate-400 font-sans px-1 pt-3 border-t border-slate-100 mt-2 shrink-0">
        <span className="truncate">
          💡 <em>Continuous auto-save active • Scroll anytime to review past notes</em>
        </span>
        <div className="flex items-center gap-3 shrink-0 font-mono text-[11px]">
          <span>{linesCount} lines</span>
          <span>•</span>
          <span>{wordCount} words</span>
        </div>
      </div>
    </div>
  );
};
