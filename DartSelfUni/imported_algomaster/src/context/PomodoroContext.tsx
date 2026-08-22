import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { useDecks } from '../store';

export type PomodoroMode = 'session' | 'shortBreak' | 'longBreak';

export interface PomodoroSettings {
  sessionLength: number; // in minutes
  shortBreakLength: number;
  longBreakLength: number;
  cyclesUntilLongBreak: number;
}

interface PomodoroContextType {
  mode: PomodoroMode;
  timeLeft: number;
  isRunning: boolean;
  cyclesCompleted: number;
  settings: PomodoroSettings;
  toggleTimer: () => void;
  skip: () => void;
  reset: () => void;
  updateSettings: (newSettings: Partial<PomodoroSettings>) => void;
}

const DEFAULT_SETTINGS: PomodoroSettings = {
  sessionLength: 45,
  shortBreakLength: 20,
  longBreakLength: 35,
  cyclesUntilLongBreak: 3,
};

const PomodoroContext = createContext<PomodoroContextType | null>(null);

export const usePomodoro = () => {
  const context = useContext(PomodoroContext);
  if (!context) throw new Error('usePomodoro must be used within a PomodoroProvider');
  return context;
};

export const PomodoroProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { logStudyTime } = useDecks();
  const [settings, setSettings] = useState<PomodoroSettings>(() => {
    const saved = localStorage.getItem('pomodoro_settings');
    return saved ? { ...DEFAULT_SETTINGS, ...JSON.parse(saved) } : DEFAULT_SETTINGS;
  });

  const [mode, setMode] = useState<PomodoroMode>('session');
  const [timeLeft, setTimeLeft] = useState(settings.sessionLength * 60);
  const [isRunning, setIsRunning] = useState(false);
  const [cyclesCompleted, setCyclesCompleted] = useState(0);

  const modeRef = useRef(mode);
  const timeLeftRef = useRef(timeLeft);
  const settingsRef = useRef(settings);
  const cyclesCompletedRef = useRef(cyclesCompleted);
  const logStudyTimeRef = useRef(logStudyTime);

  useEffect(() => {
    modeRef.current = mode;
    timeLeftRef.current = timeLeft;
    settingsRef.current = settings;
    cyclesCompletedRef.current = cyclesCompleted;
    logStudyTimeRef.current = logStudyTime;
  }, [mode, timeLeft, settings, cyclesCompleted, logStudyTime]);

  const switchMode = () => {
    const currentMode = modeRef.current;
    const currentCycles = cyclesCompletedRef.current;
    const s = settingsRef.current;

    if (currentMode === 'session') {
      logStudyTimeRef.current(s.sessionLength * 60);
      
      const newCycles = currentCycles + 1;
      setCyclesCompleted(newCycles);
      
      if (newCycles % s.cyclesUntilLongBreak === 0) {
        setMode('longBreak');
        setTimeLeft(s.longBreakLength * 60);
      } else {
        setMode('shortBreak');
        setTimeLeft(s.shortBreakLength * 60);
      }
    } else {
      setMode('session');
      setTimeLeft(s.sessionLength * 60);
    }
  };

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (isRunning) {
      interval = setInterval(() => {
        if (timeLeftRef.current > 0) {
          setTimeLeft(prev => prev - 1);
        } else {
          switchMode();
        }
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isRunning]);

  const toggleTimer = () => setIsRunning(prev => !prev);
  
  const skip = () => {
    switchMode();
  };
  
  const reset = () => {
    setIsRunning(false);
    setMode('session');
    setTimeLeft(settings.sessionLength * 60);
    setCyclesCompleted(0);
  };
  
  const updateSettings = (newSettings: Partial<PomodoroSettings>) => {
    const updated = { ...settings, ...newSettings };
    setSettings(updated);
    localStorage.setItem('pomodoro_settings', JSON.stringify(updated));
    if (!isRunning) {
      if (mode === 'session') setTimeLeft(updated.sessionLength * 60);
      else if (mode === 'shortBreak') setTimeLeft(updated.shortBreakLength * 60);
      else setTimeLeft(updated.longBreakLength * 60);
    }
  };

  return (
    <PomodoroContext.Provider value={{
      mode, timeLeft, isRunning, cyclesCompleted, settings,
      toggleTimer, skip, reset, updateSettings
    }}>
      {children}
    </PomodoroContext.Provider>
  );
};
