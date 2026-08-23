import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import 'package:media_kit/media_kit.dart';

import 'core/services/storage_service.dart';
import 'core/constants/app_colors.dart';
import 'providers/deck_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/active_view_provider.dart';

import 'widgets/common/sidebar.dart';
import 'widgets/common/top_bar.dart';
import 'widgets/modals/folder_modal.dart';
import 'widgets/modals/ask_ai_modal.dart';

import 'views/dashboard_view.dart';
import 'views/decks_view.dart';
import 'views/lessons_view.dart';
import 'views/live_lectures_view.dart';
import 'views/studio_view.dart';
import 'views/community_view.dart';
import 'views/course_viewer_view.dart';
import 'models/course_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const AlgoMasterApp());
}

class AlgoMasterApp extends StatelessWidget {
  const AlgoMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DeckProvider()),
          ChangeNotifierProxyProvider<DeckProvider, PomodoroProvider>(
            create: (context) => PomodoroProvider(context.read<DeckProvider>()),
            update: (context, deckProvider, previous) => previous ?? PomodoroProvider(deckProvider),
          ),
          ChangeNotifierProvider(create: (_) => ActiveViewProvider()),
        ],
        child: MaterialApp(
          title: 'AlgoMaster SRS',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            useMaterial3: true,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: const MainLayout(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  WorkspaceTab _currentTab = WorkspaceTab.dashboard;
  bool _isAiModalOpen = false;

  @override
  void initState() {
    super.initState();
  }

  void _handleTabSelected(WorkspaceTab tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (context) => const SettingsModal(),
    );
  }

  void _openNewFolderModal() {
    showDialog(
      context: context,
      builder: (context) => FolderModal(
        onSave: (name, color) {
          context.read<DeckProvider>().addFolder(name, color: color);
        },
      ),
    );
  }


  void _openCourseViewer(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CourseViewerView(
          course: course,
          onNavigateBack: () => Navigator.of(context).maybePop(),
          onGenerateFlashcards: () => _handleTabSelected(WorkspaceTab.studio),
        ),
      ),
    );
  }

  void _toggleAiModal() {
    setState(() {
      _isAiModalOpen = !_isAiModalOpen;
    });
  }

  Widget _buildCurrentView() {
    switch (_currentTab) {
      case WorkspaceTab.dashboard:
        return DashboardView(
          onNavigateToDecks: () => _handleTabSelected(WorkspaceTab.decks),
          onNavigateToLessons: () => _handleTabSelected(WorkspaceTab.lessons),
          onNavigateToSynthesizer: () => _handleTabSelected(WorkspaceTab.studio),
        );
      case WorkspaceTab.decks:
        return const DecksView();
      case WorkspaceTab.lessons:
        return LessonsView(
          onNavigateToLessonGenerator: () => _handleTabSelected(WorkspaceTab.studio),
        );
      case WorkspaceTab.live:
        return const LiveLecturesView();
      case WorkspaceTab.studio:
        return StudioView(
          onNavigateBack: () => _handleTabSelected(WorkspaceTab.dashboard),
        );
      case WorkspaceTab.community:
        return const CommunityView();
      default:
        return Center(
          child: Text('View not implemented yet: $_currentTab'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    final mainContent = Column(
      children: [
        if (!isMobile) TopBar(onOpenSettings: _openSettingsModal),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildCurrentView(),
              ),
              
              // Floating Ask AI Button
              Positioned(
                right: 24,
                bottom: 24,
                child: FloatingActionButton(
                  onPressed: _toggleAiModal,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.psychology, color: Colors.white),
                ),
              ),
              
              // Sliding AI Modal & Backdrop
              if (_isAiModalOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleAiModal,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: isMobile ? 320 : 450,
                  child: AskAiModal(onClose: _toggleAiModal),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AlgoMaster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.white,
          elevation: 1,
          actions: [
            // Minimal Pomodoro for AppBar
            Consumer<PomodoroProvider>(
              builder: (context, pomodoro, _) {
                return IconButton(
                  icon: Icon(
                    pomodoro.isActive ? Icons.timer : Icons.timer_outlined,
                    color: pomodoro.isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: pomodoro.toggleTimer,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
              onPressed: _openSettingsModal,
            ),
          ],
        ),
        drawer: Drawer(
          child: Sidebar(
            currentTab: _currentTab,
            activeFolderId: null,
            onSelectTab: (tab) {
              _handleTabSelected(tab);
              Navigator.of(context).maybePop();
            },
            onSelectFolder: (id) {},
            onSelectCourse: (course) {
              Navigator.of(context).maybePop();
              _openCourseViewer(course);
            },
            onOpenNewFolder: _openNewFolderModal,
            onOpenAskAi: () {
              Navigator.of(context).maybePop();
              _toggleAiModal();
            },
          ),
        ),
        body: mainContent,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            currentTab: _currentTab,
            activeFolderId: null,
            onSelectTab: _handleTabSelected,
            onSelectFolder: (id) {},
            onSelectCourse: _openCourseViewer,
            onOpenNewFolder: _openNewFolderModal,
            onOpenAskAi: _toggleAiModal,
          ),
          Expanded(child: mainContent),
        ],
      ),
    );
  }
}

class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key});

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _workController = TextEditingController();
  final TextEditingController _shortBreakController = TextEditingController();
  final TextEditingController _longBreakController = TextEditingController();
  final TextEditingController _sessionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    final pomodoro = context.read<PomodoroProvider>();
    _workController.text = (pomodoro.workDuration ~/ 60).toString();
    _shortBreakController.text = (pomodoro.shortBreakDuration ~/ 60).toString();
    _longBreakController.text = (pomodoro.longBreakDuration ~/ 60).toString();
    _sessionsController.text = pomodoro.sessionsBeforeLongBreak.toString();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('deepseek_api_key');
    if (key != null) {
      _apiKeyController.text = key;
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', _apiKeyController.text.trim());

    final workVal = int.tryParse(_workController.text) ?? 25;
    final shortVal = int.tryParse(_shortBreakController.text) ?? 5;
    final longVal = int.tryParse(_longBreakController.text) ?? 15;
    final sessionsVal = int.tryParse(_sessionsController.text) ?? 4;

    if (mounted) {
      context.read<PomodoroProvider>().updateDurations(
        work: workVal,
        shortBreak: shortVal,
        longBreak: longVal,
        sessionsBeforeLong: sessionsVal,
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _workController.dispose();
    _shortBreakController.dispose();
    _longBreakController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    try {
      final jsonString = await StorageService().generateBackupJson();
      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: 'algomaster_backup.json',
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (uri != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup exported successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result.isNotEmpty) {
        final platformFile = result.first;
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          final jsonString = await file.readAsString();
          if (mounted) {
            await context.read<DeckProvider>().restoreBackup(jsonString);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup imported and applied successfully!')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DeepSeek API Key', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Required for generating flashcards and notes.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text('Pomodoro Timer Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _workController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Work (m)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _shortBreakController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Short (m)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _longBreakController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Long (m)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _sessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cycles',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text('Data Backup', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Export your decks, lessons, and statistics to a JSON file.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportData,
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importData,
                      icon: const Icon(Icons.upload),
                      label: const Text('Restore'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
