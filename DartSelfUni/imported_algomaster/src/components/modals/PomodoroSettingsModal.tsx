import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { X, Clock, Coffee, Brain } from 'lucide-react';
import { usePomodoro } from '../../context/PomodoroContext';

interface PomodoroSettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function PomodoroSettingsModal({ isOpen, onClose }: PomodoroSettingsModalProps) {
  const { settings, updateSettings } = usePomodoro();
  
  const [session, setSession] = useState(settings.sessionLength);
  const [shortBreak, setShortBreak] = useState(settings.shortBreakLength);
  const [longBreak, setLongBreak] = useState(settings.longBreakLength);
  const [cycles, setCycles] = useState(settings.cyclesUntilLongBreak);

  if (!isOpen) return null;

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    updateSettings({
      sessionLength: session,
      shortBreakLength: shortBreak,
      longBreakLength: longBreak,
      cyclesUntilLongBreak: cycles
    });
    onClose();
  };

  return createPortal(
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl border border-slate-200 max-w-sm w-full p-6 animate-scaleIn">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center border border-orange-200 shadow-2xs">
              <Clock className="w-4 h-4" />
            </div>
            <h3 className="text-base font-bold text-slate-900">Timer Settings</h3>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSave} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="flex items-center gap-1.5 text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                <Brain className="w-3 h-3" /> Session (min)
              </label>
              <input
                type="number"
                min="1"
                max="120"
                required
                value={session}
                onChange={(e) => setSession(Number(e.target.value))}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-slate-800 text-sm font-sans"
              />
            </div>
            <div>
              <label className="flex items-center gap-1.5 text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                <Coffee className="w-3 h-3" /> Short Break (min)
              </label>
              <input
                type="number"
                min="1"
                max="60"
                required
                value={shortBreak}
                onChange={(e) => setShortBreak(Number(e.target.value))}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 text-slate-800 text-sm font-sans"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="flex items-center gap-1.5 text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                <Coffee className="w-3 h-3 text-emerald-500" /> Long Break (min)
              </label>
              <input
                type="number"
                min="1"
                max="60"
                required
                value={longBreak}
                onChange={(e) => setLongBreak(Number(e.target.value))}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 text-slate-800 text-sm font-sans"
              />
            </div>
            <div>
              <label className="flex items-center gap-1.5 text-[10px] text-slate-500 uppercase tracking-widest font-bold mb-1.5">
                Cycles
              </label>
              <input
                type="number"
                min="1"
                max="10"
                required
                value={cycles}
                onChange={(e) => setCycles(Number(e.target.value))}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-slate-500/20 focus:border-slate-500 text-slate-800 text-sm font-sans"
              />
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-slate-100 mt-6">
            <button
              type="submit"
              className="px-5 py-2.5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl text-xs font-bold transition-all shadow-md cursor-pointer"
            >
              Save Settings
            </button>
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
}
