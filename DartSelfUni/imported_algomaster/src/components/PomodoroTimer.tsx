import React, { useState } from 'react';
import { Play, Pause, SkipForward, Settings, Brain, Coffee } from 'lucide-react';
import { usePomodoro } from '../context/PomodoroContext';
import { PomodoroSettingsModal } from './modals/PomodoroSettingsModal';

export function PomodoroTimer() {
  const { mode, timeLeft, isRunning, toggleTimer, skip, cyclesCompleted, settings } = usePomodoro();
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const getModeIcon = () => {
    if (mode === 'session') return <Brain className="w-3.5 h-3.5" />;
    return <Coffee className="w-3.5 h-3.5" />;
  };

  const getModeColor = () => {
    if (mode === 'session') return 'text-orange-600 bg-orange-50 border-orange-200/80';
    if (mode === 'shortBreak') return 'text-emerald-600 bg-emerald-50 border-emerald-200/80';
    return 'text-blue-600 bg-blue-50 border-blue-200/80';
  };

  return (
    <>
      <div className={`flex items-center h-8 rounded-xl border shadow-2xs transition-all ${getModeColor()}`}>
        <div className="flex items-center gap-1.5 px-3 h-full border-r border-inherit opacity-90">
          {getModeIcon()}
          <span className="font-mono text-xs font-extrabold tracking-tight">{formatTime(timeLeft)}</span>
          <span className="text-[9px] font-bold opacity-60 ml-1">
            {cyclesCompleted % settings.cyclesUntilLongBreak}/{settings.cyclesUntilLongBreak}
          </span>
        </div>
        
        <div className="flex items-center h-full px-1">
          <button
            onClick={toggleTimer}
            className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-black/5 transition-colors cursor-pointer"
            title={isRunning ? "Pause" : "Start"}
          >
            {isRunning ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 ml-0.5" />}
          </button>
          <button
            onClick={skip}
            className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-black/5 transition-colors cursor-pointer"
            title="Skip"
          >
            <SkipForward className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => setIsSettingsOpen(true)}
            className="w-7 h-7 flex items-center justify-center rounded-lg hover:bg-black/5 transition-colors cursor-pointer ml-1"
            title="Settings"
          >
            <Settings className="w-3 h-3 opacity-70" />
          </button>
        </div>
      </div>

      <PomodoroSettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
      />
    </>
  );
}
