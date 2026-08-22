import React from 'react';
import { useNavigate } from 'react-router-dom';
import { BookOpen, Sparkles, Globe, Zap, ArrowLeft } from 'lucide-react';
import { LessonGenerator } from '../components/LessonGenerator';
import { Lesson } from '../types';

interface LessonGeneratorViewProps {
  onAddLesson: (lesson: Lesson) => Promise<void> | void;
  onNavigateTab: (tab: 'lessons') => void;
}

export function LessonGeneratorView({
  onAddLesson,
  onNavigateTab
}: LessonGeneratorViewProps) {
  const navigate = useNavigate();

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Header */}
      <section className="bg-white/95 rounded-3xl border border-slate-200/90 shadow-sm p-6 sm:p-8 backdrop-blur-md relative overflow-hidden">
        {/* Glow decoration */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-bl from-emerald-400/10 via-teal-400/5 to-transparent rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 border-b border-slate-100 pb-5 relative z-10">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 mb-1.5">
              <Globe className="w-3 h-3 text-emerald-600" />
              Multi-Source Synthesis
            </div>
            <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
              <BookOpen className="w-5 h-5 text-emerald-600" />
              CS Lecture Notes Generator
            </h1>
            <p className="text-xs text-slate-500 font-sans mt-0.5">
              Synthesize textbook-grade computer science notes, mathematical invariants (LaTeX), and Dart code from multiple sources
            </p>
          </div>

          <button
            type="button"
            onClick={() => onNavigateTab('lessons')}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all cursor-pointer self-start sm:self-auto"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            View All Notes
          </button>
        </div>

        {/* Generator Component */}
        <div className="animate-fadeIn">
          <LessonGenerator
            onLessonGenerated={(lesson) => {
              onAddLesson(lesson);
              navigate(`/lesson/${lesson.id}`);
            }}
          />
        </div>
      </section>
    </div>
  );
}
