import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../modals/auth_modal.dart';
import 'pomodoro_timer_widget.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const TopBar({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
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
          const PomodoroTimerWidget(),
          
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
