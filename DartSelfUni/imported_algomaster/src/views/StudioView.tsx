import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Sparkles,
  Bot,
  BookOpen,
  PenTool,
  ChevronDown,
  Check,
  Zap,
  Layers,
  ArrowRight
} from 'lucide-react';
import { AICardGenerator } from '../components/AICardGenerator';
import { LessonGenerator } from '../components/LessonGenerator';
import { ManualCardCreator } from '../components/ManualCardCreator';
import { Deck, Folder, Lesson, Card } from '../types';

interface StudioViewProps {
  decks: Deck[];
  folders: Folder[];
  onAddDeck: (deck: Deck) => Promise<void> | void;
  onAddCardToDeck: (deckId: string, card: Card) => Promise<void> | void;
  onAddLesson: (lesson: Lesson) => Promise<void> | void;
}

export function StudioView({
  decks,
  folders,
  onAddDeck,
  onAddCardToDeck,
  onAddLesson
}: StudioViewProps) {
  const navigate = useNavigate();
  const [creationTab, setCreationTab] = useState<'ai' | 'lesson' | 'manual'>('ai');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const creationOptions = [
    {
      id: 'ai' as const,
      label: 'AI Deck Synthesizer',
      description: 'Synthesize 30-card decks with AI across 9 archetypes',
      icon: Bot,
      iconColor: 'text-blue-600',
      iconBg: 'bg-blue-50 border-blue-200',
      activeText: 'text-blue-600',
      badge: 'Dart & Algorithms'
    },
    {
      id: 'lesson' as const,
      label: 'CS Lecture Notes',
      description: 'Generate professor-grade CS notes, code blocks & markdown',
      icon: BookOpen,
      iconColor: 'text-emerald-600',
      iconBg: 'bg-emerald-50 border-emerald-200',
      activeText: 'text-emerald-600',
      badge: 'Lecture Notes'
    },
    {
      id: 'manual' as const,
      label: 'Manual Card Forge',
      description: 'Craft flashcards with custom front, back, type & code',
      icon: PenTool,
      iconColor: 'text-amber-600',
      iconBg: 'bg-amber-50 border-amber-200',
      activeText: 'text-amber-600',
      badge: 'Custom Card'
    }
  ];

  const currentOption = creationOptions.find((opt) => opt.id === creationTab) || creationOptions[0];
  const CurrentIcon = currentOption.icon;

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Studio Header & Mode Switcher */}
      <section className="bg-white/95 rounded-3xl border border-slate-200/90 shadow-sm p-6 sm:p-8 backdrop-blur-md relative overflow-hidden">
        {/* Glow decoration */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-bl from-blue-400/10 via-emerald-400/5 to-transparent rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 border-b border-slate-100 pb-5 relative z-10">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-blue-50 text-blue-700 border border-blue-200 mb-1.5">
              <Zap className="w-3 h-3 text-blue-600" />
              Content Generation Hub
            </div>
            <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-blue-600" />
              AlgoMaster Creation Studio
            </h1>
            <p className="text-xs text-slate-500 font-sans mt-0.5">
              Synthesize full 30-card decks with AI, generate structured CS notes, or craft flashcards manually
            </p>
          </div>

          {/* Mode Dropdown Selector */}
          <div className="relative self-start sm:self-auto" ref={dropdownRef}>
            <button
              type="button"
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="inline-flex items-center gap-3 px-4 py-2.5 bg-white hover:bg-slate-50 text-slate-800 border border-slate-200/90 hover:border-slate-300 rounded-2xl text-xs font-bold uppercase tracking-wider transition-all shadow-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500/20"
              aria-expanded={isDropdownOpen}
            >
              <div className={`w-6 h-6 rounded-lg ${currentOption.iconBg} flex items-center justify-center border shadow-2xs`}>
                <CurrentIcon className={`w-3.5 h-3.5 ${currentOption.iconColor}`} />
              </div>
              <span className="font-extrabold">{currentOption.label}</span>
              <ChevronDown className={`w-3.5 h-3.5 text-slate-400 transition-transform duration-200 ${isDropdownOpen ? 'rotate-180 text-blue-600' : ''}`} />
            </button>

            {/* Dropdown Options List */}
            {isDropdownOpen && (
              <div className="absolute right-0 mt-2 w-72 sm:w-80 bg-white/98 backdrop-blur-xl border border-slate-200/90 rounded-2xl shadow-xl z-30 p-2 animate-fadeIn space-y-1">
                <div className="px-2.5 py-1.5 border-b border-slate-100 mb-1">
                  <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400">Select Studio Mode</span>
                </div>
                {creationOptions.map((option) => {
                  const Icon = option.icon;
                  const isSelected = creationTab === option.id;
                  return (
                    <button
                      key={option.id}
                      type="button"
                      onClick={() => {
                        setCreationTab(option.id);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full flex items-center justify-between p-2.5 rounded-xl text-left transition-all cursor-pointer ${
                        isSelected
                          ? 'bg-slate-50 border border-slate-200/70 shadow-2xs'
                          : 'hover:bg-slate-50/80 border border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-xl ${option.iconBg} flex items-center justify-center border shadow-2xs shrink-0`}>
                          <Icon className={`w-4 h-4 ${option.iconColor}`} />
                        </div>
                        <div>
                          <span className={`text-xs font-bold ${isSelected ? option.activeText : 'text-slate-800'}`}>
                            {option.label}
                          </span>
                          <p className="text-[11px] text-slate-500 font-sans leading-tight mt-0.5">
                            {option.description}
                          </p>
                        </div>
                      </div>
                      {isSelected && (
                        <div className="w-5 h-5 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 border border-blue-200 ml-2">
                          <Check className="w-3 h-3" />
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Selected Tab Generator Component */}
        <div className="animate-fadeIn">
          {creationTab === 'ai' && (
            <AICardGenerator
              onDeckGenerated={(deck) => onAddDeck(deck)}
              onLessonGenerated={(lesson) => {
                onAddLesson(lesson);
                navigate(`/lesson/${lesson.id}`);
              }}
            />
          )}
          {creationTab === 'lesson' && (
            <LessonGenerator
              onLessonGenerated={(lesson) => {
                onAddLesson(lesson);
                navigate(`/lesson/${lesson.id}`);
              }}
            />
          )}
          {creationTab === 'manual' && (
            <ManualCardCreator
              decks={decks}
              onAddDeck={onAddDeck}
              onAddCard={onAddCardToDeck}
            />
          )}
        </div>
      </section>
    </div>
  );
}
