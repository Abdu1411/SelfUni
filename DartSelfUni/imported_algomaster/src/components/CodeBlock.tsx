import React, { useState } from 'react';
import Prism from 'prismjs';
import 'prismjs/components/prism-clike';
import 'prismjs/components/prism-javascript';
import 'prismjs/components/prism-typescript';
import 'prismjs/components/prism-dart';
import 'prismjs/components/prism-python';
import 'prismjs/components/prism-java';
import 'prismjs/components/prism-c';
import 'prismjs/components/prism-cpp';
import 'prismjs/components/prism-json';
import 'prismjs/components/prism-bash';
import 'prismjs/components/prism-sql';
import 'prismjs/components/prism-markdown';
import { Check, Copy, Code2 } from 'lucide-react';

interface CodeBlockProps {
  code: string;
  language?: string;
  showLineNumbers?: boolean;
}

export function CodeBlock({
  code,
  language = 'dart',
  showLineNumbers = true
}: CodeBlockProps) {
  const [copied, setCopied] = useState(false);
  const codeString = (code || '').trim();

  const handleCopy = () => {
    if (!codeString) return;
    navigator.clipboard.writeText(codeString);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const normalizedLang = language.toLowerCase();
  let highlighted = codeString;
  try {
    const grammar =
      Prism?.languages?.[normalizedLang] ||
      Prism?.languages?.dart ||
      Prism?.languages?.clike ||
      Prism?.languages?.javascript;
    if (grammar && codeString) {
      highlighted = Prism.highlight(codeString, grammar, normalizedLang);
    }
  } catch {
    // fallback to unhighlighted text
  }

  const lines = codeString.split('\n');

  // File extension helper
  const getFilename = (lang: string) => {
    switch (lang.toLowerCase()) {
      case 'dart':
        return 'solution.dart';
      case 'python':
      case 'py':
        return 'solution.py';
      case 'typescript':
      case 'ts':
        return 'solution.ts';
      case 'javascript':
      case 'js':
        return 'solution.js';
      case 'cpp':
      case 'c++':
        return 'solution.cpp';
      case 'java':
        return 'Solution.java';
      case 'bash':
      case 'sh':
        return 'terminal.sh';
      case 'json':
        return 'data.json';
      case 'sql':
        return 'query.sql';
      default:
        return `${lang}.src`;
    }
  };

  return (
    <div className="my-5 rounded-2xl overflow-hidden border border-slate-700/90 bg-[#0d1117] shadow-xl font-mono text-xs not-prose">
      {/* Editor Window Titlebar */}
      <div className="flex items-center justify-between px-4 py-2.5 bg-[#161b22] border-b border-slate-700/80 select-none">
        <div className="flex items-center gap-2.5">
          <div className="flex items-center gap-1.5">
            <div className="w-2.5 h-2.5 rounded-full bg-rose-500/80"></div>
            <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80"></div>
            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500/80"></div>
          </div>
          <div className="flex items-center gap-1.5 text-slate-300 font-mono text-[11px]">
            <Code2 className="w-3.5 h-3.5 text-blue-400" />
            <span className="text-slate-400 font-semibold">{getFilename(normalizedLang)}</span>
          </div>
          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wider bg-blue-500/10 text-blue-400 border border-blue-500/20">
            {normalizedLang.toUpperCase()}
          </span>
        </div>

        <button
          type="button"
          onClick={handleCopy}
          className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-[11px] font-sans font-semibold transition-all cursor-pointer border border-slate-700 shadow-xs"
          title="Copy code"
        >
          {copied ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
          <span>{copied ? 'Copied' : 'Copy'}</span>
        </button>
      </div>

      {/* Editor Code Area */}
      <div className="p-4 overflow-x-auto flex leading-relaxed text-slate-200">
        {showLineNumbers && (
          <div className="select-none pr-4 text-slate-600 text-right font-mono text-xs border-r border-slate-800/80 shrink-0">
            {lines.map((_, i) => (
              <div key={i} className="leading-relaxed">{i + 1}</div>
            ))}
          </div>
        )}
        <pre className="pl-4 font-mono text-xs overflow-x-auto whitespace-pre !bg-transparent !p-0 !m-0 flex-1 leading-relaxed">
          <code
            dangerouslySetInnerHTML={{ __html: highlighted }}
            className={`language-${normalizedLang}`}
          />
        </pre>
      </div>
    </div>
  );
}

// ReactMarkdown custom renderer for code elements
export function MarkdownCodeRenderer({ node, className, children, ...props }: any) {
  const match = /language-(\w+)/.exec(className || '');
  const codeContent = String(children || '').replace(/\n$/, '');
  const isMultiLine = codeContent.includes('\n');

  if (!match && !isMultiLine) {
    return (
      <code className="px-1.5 py-0.5 mx-0.5 rounded-md bg-slate-100 text-blue-700 font-mono text-[12px] font-semibold border border-slate-200" {...props}>
        {children}
      </code>
    );
  }

  const language = match ? match[1] : 'dart';
  return <CodeBlock code={codeContent} language={language} />;
}
