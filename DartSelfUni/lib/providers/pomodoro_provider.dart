import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deck_provider.dart';

enum PomodoroMode { work, shortBreak, longBreak }

class PomodoroProvider extends ChangeNotifier {
  final DeckProvider deckProvider;

  bool _isActive = false;
  int _timeRemaining = 25 * 60; // 25 mins
  int _workDuration = 25 * 60;
  int _shortBreakDuration = 5 * 60;
  int _longBreakDuration = 15 * 60;
  int _sessionsBeforeLongBreak = 4;
  
  PomodoroMode _mode = PomodoroMode.work;
  int _completedSessions = 0;
  Timer? _timer;

  PomodoroProvider(this.deckProvider) {
    loadSettings();
  }

  bool get isActive => _isActive;
  int get timeRemaining => _timeRemaining;
  PomodoroMode get mode => _mode;
  int get completedSessions => _completedSessions;
  
  int get workDuration => _workDuration;
  int get shortBreakDuration => _shortBreakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get sessionsBeforeLongBreak => _sessionsBeforeLongBreak;

  void updateDurations({required int work, required int shortBreak, required int longBreak, required int sessionsBeforeLong}) {
    _workDuration = work * 60;
    _shortBreakDuration = shortBreak * 60;
    _longBreakDuration = longBreak * 60;
    _sessionsBeforeLongBreak = sessionsBeforeLong;
    
    // Always pause the active timer and reset remaining time to the new duration
    // so changes are instantly reflected on the top bar timer.
    pauseTimer();
    _timeRemaining = _getDurationForMode(_mode);
    
    notifyListeners();
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoro_work', _workDuration ~/ 60);
    await prefs.setInt('pomodoro_short', _shortBreakDuration ~/ 60);
    await prefs.setInt('pomodoro_long', _longBreakDuration ~/ 60);
    await prefs.setInt('pomodoro_sessions_long', _sessionsBeforeLongBreak);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final work = prefs.getInt('pomodoro_work');
    final short = prefs.getInt('pomodoro_short');
    final long = prefs.getInt('pomodoro_long');
    final sessionsLong = prefs.getInt('pomodoro_sessions_long');
    if (work != null) _workDuration = work * 60;
    if (short != null) _shortBreakDuration = short * 60;
    if (long != null) _longBreakDuration = long * 60;
    if (sessionsLong != null) _sessionsBeforeLongBreak = sessionsLong;
    
    if (!_isActive) {
      _timeRemaining = _getDurationForMode(_mode);
    }
    notifyListeners();
  }

  void toggleTimer() {
    if (_isActive) {
      pauseTimer();
    } else {
      startTimer();
    }
  }

  void startTimer() {
    _isActive = true;
    notifyListeners();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        // Log study time every minute while in work mode
        if (_mode == PomodoroMode.work && _timeRemaining % 60 == 0) {
          deckProvider.logStudyTime(60);
        }
        notifyListeners();
      } else {
        _handleTimerComplete();
      }
    });
  }

  void pauseTimer() {
    _isActive = false;
    _timer?.cancel();
    notifyListeners();
  }

  void resetTimer() {
    pauseTimer();
    _timeRemaining = _getDurationForMode(_mode);
    notifyListeners();
  }

  void setMode(PomodoroMode newMode) {
    pauseTimer();
    _mode = newMode;
    _timeRemaining = _getDurationForMode(newMode);
    notifyListeners();
  }

  void _handleTimerComplete() {
    pauseTimer();
    
    // Play sound notification here if needed
    
    if (_mode == PomodoroMode.work) {
      _completedSessions++;
      if (_completedSessions % _sessionsBeforeLongBreak == 0) {
        setMode(PomodoroMode.longBreak);
      } else {
        setMode(PomodoroMode.shortBreak);
      }
    } else {
      setMode(PomodoroMode.work);
    }
  }

  int _getDurationForMode(PomodoroMode mode) {
    switch (mode) {
      case PomodoroMode.work:
        return _workDuration;
      case PomodoroMode.shortBreak:
        return _shortBreakDuration;
      case PomodoroMode.longBreak:
        return _longBreakDuration;
    }
  }
}
