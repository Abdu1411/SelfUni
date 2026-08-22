import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pomodoro_provider.dart';

class PomodoroTimerWidget extends StatelessWidget {
  final bool compact;

  const PomodoroTimerWidget({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pomodoro = context.watch<PomodoroProvider>();
    final minutes = (pomodoro.timeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (pomodoro.timeRemaining % 60).toString().padLeft(2, '0');
    final formattedTime = '$minutes:$seconds';

    Color activeColor;
    String modeLabel;
    switch (pomodoro.mode) {
      case PomodoroMode.work:
        activeColor = AppColors.primary;
        modeLabel = 'Focus';
        break;
      case PomodoroMode.shortBreak:
        activeColor = AppColors.success;
        modeLabel = 'Short Break';
        break;
      case PomodoroMode.longBreak:
        activeColor = AppColors.warning;
        modeLabel = 'Long Break';
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pomodoro.isActive ? activeColor.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pomodoro.isActive ? activeColor : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 16,
              color: pomodoro.isActive ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              formattedTime,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: pomodoro.isActive ? activeColor : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => pomodoro.toggleTimer(),
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                pomodoro.isActive ? Icons.pause : Icons.play_arrow,
                size: 18,
                color: pomodoro.isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: pomodoro.isActive 
            ? activeColor.withValues(alpha: 0.12) 
            : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pomodoro.isActive ? activeColor.withValues(alpha: 0.8) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Mode: $modeLabel',
            child: Icon(
              Icons.timer_outlined,
              size: 18,
              color: pomodoro.isActive ? activeColor : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedTime,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: pomodoro.isActive ? activeColor : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: pomodoro.isActive ? 'Pause Timer' : 'Start Timer',
            child: InkWell(
              onTap: () => pomodoro.toggleTimer(),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(
                  pomodoro.isActive ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: pomodoro.isActive ? activeColor : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Reset Timer',
            child: InkWell(
              onTap: () => pomodoro.resetTimer(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(
                  Icons.refresh,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
