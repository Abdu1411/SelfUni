import React, { useState } from 'react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
} from 'recharts';
import { Activity, Brain, RotateCcw, Check, AlertTriangle, X, Layers, Clock, Zap, BookOpen } from 'lucide-react';
import { useDecks } from '../store';

export function ProgressDashboard() {
  const { decks, stats, resetAllStats } = useDecks();
  const safeDecks = Array.isArray(decks) ? decks : [];
  const { activityData = [], masteryData = [], weeklyVelocity = 0, totalStudyTimeToday = 0, totalStudyTimeWeek = 0 } = stats || {};

  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const [showSuccessToast, setShowSuccessToast] = useState(false);

  const totalCards = safeDecks.reduce((acc, d) => acc + (d?.cards?.length || 0), 0);
  const totalDue = safeDecks.reduce((acc, d) => acc + (d?.cards || []).filter(c => c.nextReview <= Date.now()).length, 0);

  const validMasteryDecks = (masteryData || []).filter(m => m.subject !== '---');
  const avgMastery = validMasteryDecks.length > 0 
    ? Math.round(validMasteryDecks.reduce((acc, curr) => acc + curr.level, 0) / validMasteryDecks.length)
    : 0;

  const handleConfirmReset = async () => {
    setIsResetting(true);
    try {
      await resetAllStats();
      setIsConfirmOpen(false);
      setShowSuccessToast(true);
      setTimeout(() => {
        setShowSuccessToast(false);
      }, 3500);
    } catch (err) {
      console.error('Failed to reset statistics:', err);
    } finally {
      setIsResetting(false);
    }
  };

  return (
    <section className="space-y-6 mb-10">
      {/* Top Section Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-200/80 shadow-2xs">
            <Activity className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-sm font-extrabold text-slate-900 uppercase tracking-wider">
              Study Analytics & Mastery
            </h2>
            <p className="text-xs text-slate-500 font-sans">Real-time spaced repetition velocity & algorithm retention</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {showSuccessToast && (
            <span className="inline-flex items-center gap-1 px-3 py-1.5 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-xl text-xs font-bold animate-fadeIn shadow-2xs">
              <Check className="w-3.5 h-3.5" />
              All statistics reset
            </span>
          )}
          <button
            onClick={() => setIsConfirmOpen(true)}
            className="inline-flex items-center gap-1.5 px-3.5 py-1.5 bg-white hover:bg-rose-50 text-slate-500 hover:text-rose-600 border border-slate-200 hover:border-rose-200 rounded-xl text-xs font-bold uppercase tracking-wider transition-all shadow-2xs cursor-pointer"
            title="Reset all streak, retention, and study velocity metrics"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            Reset Stats
          </button>
        </div>
      </div>

      {/* 5 Summary Stat Mini Tiles */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
        <div className="bg-white/90 rounded-2xl border border-slate-200/80 p-4 shadow-xs hover:border-blue-300 transition-all">
          <div className="flex items-center justify-between text-slate-500 mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider">Total Decks</span>
            <Layers className="w-4 h-4 text-blue-600" />
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-2xl font-extrabold font-mono text-slate-900">{decks.length}</span>
            <span className="text-xs text-slate-400 font-medium">decks</span>
          </div>
        </div>

        <div className="bg-white/90 rounded-2xl border border-slate-200/80 p-4 shadow-xs hover:border-indigo-300 transition-all">
          <div className="flex items-center justify-between text-slate-500 mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider">Flashcards</span>
            <BookOpen className="w-4 h-4 text-indigo-600" />
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-2xl font-extrabold font-mono text-slate-900">{totalCards}</span>
            <span className="text-xs text-slate-400 font-medium">cards</span>
          </div>
        </div>

        <div className="bg-white/90 rounded-2xl border border-slate-200/80 p-4 shadow-xs hover:border-cyan-300 transition-all">
          <div className="flex items-center justify-between text-slate-500 mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider">Due Today</span>
            <Clock className="w-4 h-4 text-cyan-600" />
          </div>
          <div className="flex items-baseline gap-1">
            <span className={`text-2xl font-extrabold font-mono ${totalDue > 0 ? 'text-blue-600' : 'text-slate-900'}`}>{totalDue}</span>
            <span className="text-xs text-slate-400 font-medium">due queue</span>
          </div>
        </div>

        <div className="bg-white/90 rounded-2xl border border-slate-200/80 p-4 shadow-xs hover:border-purple-300 transition-all">
          <div className="flex items-center justify-between text-slate-500 mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider">Avg Retention</span>
            <Brain className="w-4 h-4 text-purple-600" />
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-2xl font-extrabold font-mono text-slate-900">{avgMastery}%</span>
            <span className="text-xs text-slate-400 font-medium">mastery</span>
          </div>
        </div>

        <div className="bg-white/90 rounded-2xl border border-slate-200/80 p-4 shadow-xs hover:border-orange-300 transition-all">
          <div className="flex items-center justify-between text-slate-500 mb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider">Time Studied</span>
            <Clock className="w-4 h-4 text-orange-600" />
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-2xl font-extrabold font-mono text-slate-900">{Math.round(totalStudyTimeToday / 60)}</span>
            <span className="text-xs text-slate-400 font-medium">min today</span>
          </div>
        </div>
      </div>

      {/* Main Charts Row */}
      <div className="grid lg:grid-cols-2 gap-6">
        {/* Activity Chart */}
        <div className="bg-white/95 rounded-3xl shadow-[0_8px_30px_rgba(0,0,0,0.03)] border border-slate-200/90 p-6 backdrop-blur-md relative overflow-hidden group hover:border-blue-300 transition-all hover:shadow-[0_12px_36px_rgba(37,99,235,0.06)]">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-blue-500/10 to-cyan-500/10 text-blue-600 flex items-center justify-center border border-blue-200/60 shadow-xs">
                <Activity className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-xs text-slate-500 uppercase tracking-widest font-bold">Study Velocity</h3>
                <div className="flex items-baseline gap-1.5">
                  <span className="text-2xl font-extrabold text-slate-900 font-mono">{weeklyVelocity}</span>
                  <span className="text-xs text-slate-500 font-medium">cards / last 7 days</span>
                </div>
              </div>
            </div>
            <span className="px-2.5 py-1 rounded-full text-[10px] font-mono font-bold bg-blue-50 text-blue-700 border border-blue-200">
              Active Pulse
            </span>
          </div>
          
          <div className="h-52 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={activityData} margin={{ top: 5, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorCardsLight" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2563eb" stopOpacity={0.25}/>
                    <stop offset="95%" stopColor="#06b6d4" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis 
                  dataKey="day" 
                  stroke="#94a3b8" 
                  fontSize={11} 
                  tickLine={false} 
                  axisLine={false}
                  tickFormatter={(val) => val.toUpperCase()}
                />
                <YAxis 
                  stroke="#94a3b8" 
                  fontSize={11} 
                  tickLine={false} 
                  axisLine={false} 
                />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#ffffff', 
                    borderColor: '#e2e8f0', 
                    borderRadius: '16px', 
                    fontSize: '12px',
                    boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
                    color: '#0f172a'
                  }}
                  itemStyle={{ color: '#2563eb', fontWeight: 700 }}
                />
                <Area 
                  type="monotone" 
                  dataKey="cardsReviewed" 
                  stroke="#2563eb" 
                  strokeWidth={2.5}
                  fillOpacity={1} 
                  fill="url(#colorCardsLight)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Mastery Radar */}
        <div className="bg-white/95 rounded-3xl shadow-[0_8px_30px_rgba(0,0,0,0.03)] border border-slate-200/90 p-6 backdrop-blur-md relative overflow-hidden group hover:border-indigo-300 transition-all hover:shadow-[0_12px_36px_rgba(99,102,241,0.06)]">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-indigo-500/10 to-purple-500/10 text-indigo-600 flex items-center justify-center border border-indigo-200/60 shadow-xs">
                <Brain className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-xs text-slate-500 uppercase tracking-widest font-bold">Dart Algorithm Mastery</h3>
                <div className="flex items-baseline gap-1.5">
                  <span className="text-2xl font-extrabold text-slate-900 font-mono">{avgMastery}%</span>
                  <span className="text-xs text-slate-500 font-medium">retention score</span>
                </div>
              </div>
            </div>
            <span className="px-2.5 py-1 rounded-full text-[10px] font-mono font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
              SRS Retention
            </span>
          </div>
          
          <div className="h-52 w-full -mt-2">
            <ResponsiveContainer width="100%" height="100%">
              <RadarChart cx="50%" cy="50%" outerRadius="72%" data={masteryData}>
                <PolarGrid stroke="#f1f5f9" />
                <PolarAngleAxis 
                  dataKey="subject" 
                  tick={{ fill: '#64748b', fontSize: 10, fontWeight: 600 }}
                />
                <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                <Radar
                  name="Mastery Level"
                  dataKey="level"
                  stroke="#6366f1"
                  strokeWidth={2.5}
                  fill="#6366f1"
                  fillOpacity={0.25}
                />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#ffffff', 
                    borderColor: '#e2e8f0', 
                    borderRadius: '16px', 
                    fontSize: '12px',
                    boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.1)',
                    color: '#0f172a'
                  }}
                  itemStyle={{ color: '#6366f1', fontWeight: 700 }}
                />
              </RadarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Confirmation Modal */}
      {isConfirmOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-xs z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 max-w-md w-full p-6 animate-scaleIn">
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center shrink-0 border border-rose-200">
                <AlertTriangle className="w-5 h-5" />
              </div>
              <div className="flex-1">
                <h3 className="text-base font-bold text-slate-900">Reset All Statistics?</h3>
                <p className="text-xs text-slate-500 mt-1.5 leading-relaxed">
                  This will reset your <strong>Day Streak</strong>, <strong>Study Velocity</strong>, <strong>Retention Rate</strong>, and all card SRS repetitions back to initial state (0%). Deck contents and cards will NOT be deleted.
                </p>
              </div>
              <button
                onClick={() => setIsConfirmOpen(false)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex justify-end gap-3 mt-6">
              <button
                type="button"
                onClick={() => setIsConfirmOpen(false)}
                disabled={isResetting}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmReset}
                disabled={isResetting}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all shadow-md hover:shadow-lg disabled:opacity-50 inline-flex items-center gap-1.5"
              >
                {isResetting ? (
                  <>
                    <RotateCcw className="w-3.5 h-3.5 animate-spin" />
                    Resetting...
                  </>
                ) : (
                  'Yes, Reset Statistics'
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
