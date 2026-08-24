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
        color: Color(0xFF162238),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
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
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
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
