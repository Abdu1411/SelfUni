// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/pomodoro_provider.dart';
import '../modals/auth_modal.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const TopBar({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final pomodoro = context.watch<PomodoroProvider>();
    
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Pomodoro Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pomodoro.isActive 
                  ? AppColors.primary.withValues(alpha: 0.2) 
                  : AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: pomodoro.isActive ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: pomodoro.isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${(pomodoro.timeRemaining ~/ 60).toString().padLeft(2, '0')}:${(pomodoro.timeRemaining % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.bold,
                    color: pomodoro.isActive ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => pomodoro.toggleTimer(),
                  child: Icon(
                    pomodoro.isActive ? Icons.pause : Icons.play_arrow,
                    size: 20,
                    color: pomodoro.isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => pomodoro.resetTimer(),
                  child: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // API Key Settings
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Settings (API Key)',
          ),
          
          const SizedBox(width: 16),
          
          // User Avatar / Auth Button
          ElevatedButton.icon(
            onPressed: () {
              showDialog(context: context, builder: (_) => const AuthModal());
            },
            icon: const Icon(Icons.person, size: 18),
            label: const Text('Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
