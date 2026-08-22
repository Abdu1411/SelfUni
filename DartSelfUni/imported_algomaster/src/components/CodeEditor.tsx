import React, { useRef } from 'react';
import Prism from 'prismjs';
import 'prismjs/components/prism-clike';
import 'prismjs/components/prism-dart';

interface CodeEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  minHeight?: string;
  language?: string;
}

export function CodeEditor({
  value = '',
  onChange,
  placeholder = '// Write your Dart algorithm implementation here...',
  minHeight = '200px',
  language = 'dart',
}: CodeEditorProps) {
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const preRef = useRef<HTMLPreElement | null>(null);

  // Sync scroll between textarea and syntax highlight layer
  const handleScroll = () => {
    if (textareaRef.current && preRef.current) {
      preRef.current.scrollTop = textareaRef.current.scrollTop;
      preRef.current.scrollLeft = textareaRef.current.scrollLeft;
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    const textarea = textareaRef.current;
    if (!textarea) return;

    if (e.key === 'Tab') {
      e.preventDefault();
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const spaces = '  '; // 2 spaces

      const currentVal = value || '';
      const newValue = currentVal.substring(0, start) + spaces + currentVal.substring(end);
      onChange(newValue);

      // Restore cursor position after state update
      requestAnimationFrame(() => {
        if (textareaRef.current) {
          textareaRef.current.selectionStart = textareaRef.current.selectionEnd = start + spaces.length;
        }
      });
    }
  };

  const getHighlightedHtml = () => {
    const codeVal = value || '';
    try {
      const grammar = Prism?.languages?.[language] || Prism?.languages?.dart || Prism?.languages?.clike;
      if (grammar && codeVal) {
        return Prism.highlight(codeVal, grammar, language);
      }
    } catch {
      // fallback
    }
    // Escape HTML for plain text
    return codeVal
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  };

  return (
    <div
      className="relative w-full rounded-xl font-mono text-sm leading-relaxed overflow-hidden bg-slate-900 border border-slate-700/80 focus-within:border-blue-500 focus-within:ring-2 focus-within:ring-blue-500/20 transition-all cursor-text shadow-sm"
      style={{ minHeight }}
      onClick={() => {
        if (textareaRef.current && document.activeElement !== textareaRef.current) {
          textareaRef.current.focus();
        }
      }}
    >
      {/* Background Syntax Highlight Layer */}
      <pre
        ref={(el) => {
          preRef.current = el;
        }}
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 m-0 p-4 font-mono text-sm leading-relaxed overflow-auto whitespace-pre-wrap break-words text-slate-200"
        style={{
          fontFamily: '"JetBrains Mono", "Fira Code", Menlo, Monaco, Consolas, monospace',
          tabSize: 2,
        }}
        dangerouslySetInnerHTML={{
          __html: getHighlightedHtml() + ((value || '').endsWith('\n') ? '<br />' : ''),
        }}
      />

      {/* Foreground Transparent Editable Textarea */}
      <textarea
        ref={(el) => {
          textareaRef.current = el;
        }}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        onScroll={handleScroll}
        placeholder={placeholder}
        spellCheck={false}
        autoCapitalize="off"
        autoComplete="off"
        autoCorrect="off"
        className="relative z-10 w-full h-full min-h-[inherit] m-0 p-4 font-mono text-sm leading-relaxed bg-transparent text-transparent caret-cyan-400 selection:bg-blue-600/40 selection:text-white resize-none outline-none border-none whitespace-pre-wrap break-words placeholder:text-slate-500 block"
        style={{
          fontFamily: '"JetBrains Mono", "Fira Code", Menlo, Monaco, Consolas, monospace',
          tabSize: 2,
          minHeight,
          WebkitTextFillColor: 'transparent',
        }}
      />
    </div>
  );
}
