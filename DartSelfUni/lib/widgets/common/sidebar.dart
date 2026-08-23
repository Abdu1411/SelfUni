import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';
import '../../models/course_model.dart';
import '../../models/card_model.dart';
import '../../views/custom_study_view.dart';
import '../../views/study_session_view.dart';
import '../../providers/pomodoro_provider.dart';

enum WorkspaceTab {
  dashboard,
  decks,
  lessons,
  live,
  deckGenerator, // Keeping for backward compatibility or removing it
  lessonGenerator,
  studio,
  community
}

class Sidebar extends StatelessWidget {
  final WorkspaceTab currentTab;
  final String? activeFolderId;
  final ValueChanged<WorkspaceTab> onSelectTab;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<Course> onSelectCourse;
  final VoidCallback onOpenNewFolder;
  final VoidCallback onOpenAskAi;

  const Sidebar({
    super.key,
    required this.currentTab,
    required this.activeFolderId,
    required this.onSelectTab,
    required this.onSelectFolder,
    required this.onSelectCourse,
    required this.onOpenNewFolder,
    required this.onOpenAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final pomodoro = context.watch<PomodoroProvider>();
    final minutes = (pomodoro.timeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (pomodoro.timeRemaining % 60).toString().padLeft(2, '0');
    final pomodoroTime = '$minutes:$seconds';
    
    // Calculate total due globally using the Universal Deck
    final now = DateTime.now().millisecondsSinceEpoch;
    final universalCards = deckProvider.universalDeck?.cards ?? [];
    final dueCardsList = universalCards.where((c) => c.nextReview <= now || c.reps == 0).toList();
    dueCardsList.sort((a, b) => a.nextReview.compareTo(b.nextReview));
    final totalDue = dueCardsList.length;
    final totalCards = universalCards.length;

    final activeFolderIds = deckProvider.folders.map((f) => f.id).toSet();
    final activeCourseTitles = deckProvider.courses.map((c) => c.title.toLowerCase()).toSet();

    final activeLessons = deckProvider.lessons.where((l) {
      if (!l.isNote) return false;
      final hasFolder = l.folderId != null && l.folderId != 'unfiled' && activeFolderIds.contains(l.folderId);
      final hasCourse = activeCourseTitles.contains(l.topic.toLowerCase());
      final isUnfiled = l.folderId == null || l.folderId == 'unfiled' || !activeFolderIds.contains(l.folderId);
      return hasFolder || hasCourse || isUnfiled;
    }).toList();

    final activeLiveLectures = deckProvider.lessons.where((l) {
      if (l.isNote) return false;
      final hasFolder = l.folderId != null && l.folderId != 'unfiled' && activeFolderIds.contains(l.folderId);
      final hasCourse = activeCourseTitles.contains(l.topic.toLowerCase());
      return (hasFolder || hasCourse) && ((l.videoUrl != null && l.videoUrl!.isNotEmpty) || (l.sourceUrl != null && l.sourceUrl!.isNotEmpty));
    }).toList();

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B5998), Color(0xFF1E88E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ALGOMASTER',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'SRS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00B4D8), // Light cyan/blue
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.border),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                _buildSectionLabel('WORKSPACE', pomodoroTime, pomodoro.isActive),
                _buildNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Dashboard',
                  tab: WorkspaceTab.dashboard,
                ),
                _buildNavItem(
                  icon: Icons.layers_outlined,
                  label: 'Decks & Folders',
                  tab: WorkspaceTab.decks,
                  badge: deckProvider.decks.length.toString(),
                ),
                _buildNavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Notes & PDFs',
                  tab: WorkspaceTab.lessons,
                  badge: activeLessons.length.toString(),
                ),
                _buildNavItem(
                  icon: Icons.videocam_outlined,
                  label: 'Live Lectures',
                  tab: WorkspaceTab.live,
                  badge: activeLiveLectures.length.toString(),
                ),
                
                // Adjusted based on prompt to combine into AI Generate
                _buildNavItem(
                  icon: Icons.auto_awesome,
                  label: 'AI Generate',
                  tab: WorkspaceTab.studio,
                ),
                
                const SizedBox(height: 16),
                
                // Custom Study
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomStudyView(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: Color(0xFF9C27B0), // Purple accent
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Custom Study',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                        if (totalDue > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              '$totalDue due',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            totalCards.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _buildSectionLabel('LOCAL COURSES (${deckProvider.courses.length})', pomodoroTime, pomodoro.isActive, padding: EdgeInsets.zero),
                const SizedBox(height: 8),
                ...deckProvider.courses.map((course) => _buildCourseItem(course, context)),
                
                // Fallback courses if empty to match initial state
                if (deckProvider.courses.isEmpty) ...[
                  _buildCourseItem(
                    Course(
                      id: 'crs_linear_algebra',
                      title: 'Linear Algebra',
                      description: 'Gilbert Strang MIT 18.06 Linear Algebra course.',
                      instructors: ['Prof. Gilbert Strang'],
                      modules: [
                        CourseModule(
                          id: 'mod_1',
                          title: 'Lectures',
                          items: [
                            CourseItem(
                              id: 'item_1',
                              title: 'Lecture 1: The Geometry of Linear Equations',
                              type: 'video',
                              path: 'https://www.youtube.com/watch?v=7UJ4CFRGd-U',
                            ),
                          ],
                        ),
                      ],
                    ),
                    context,
                  ),
                  _buildCourseItem(
                    Course(
                      id: 'crs_math_cs',
                      title: 'Mathematics for Computer Science',
                      description: 'MIT 6.042J Discrete Mathematics and Computer Science Foundations.',
                      instructors: ['Prof. Albert Meyer'],
                      modules: [
                        CourseModule(
                          id: 'mod_1',
                          title: 'Foundations',
                          items: [
                            CourseItem(
                              id: 'item_1',
                              title: 'Lecture 1: Proofs and Logic',
                              type: 'video',
                              path: 'https://www.youtube.com/watch?v=L3LMbpZIKhQ',
                            ),
                          ],
                        ),
                      ],
                    ),
                    context,
                  ),
                  _buildCourseItem(
                    Course(
                      id: 'crs_algorithms',
                      title: 'Design and Analysis of Algorithms',
                      description: 'MIT 6.046J Advanced Algorithms.',
                      instructors: ['Prof. Erik Demaine'],
                      modules: [
                        CourseModule(
                          id: 'mod_1',
                          title: 'Algorithms',
                          items: [
                            CourseItem(
                              id: 'item_1',
                              title: 'Lecture 1: Dynamic Programming & Intervals',
                              type: 'video',
                              path: 'https://www.youtube.com/watch?v=r4-c9fl7vG4',
                            ),
                          ],
                        ),
                      ],
                    ),
                    context,
                  ),
                ],
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel('FOLDERS (${deckProvider.folders.length})', pomodoroTime, pomodoro.isActive, padding: EdgeInsets.zero),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: onOpenNewFolder,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...deckProvider.folders.map((folder) {
                  final itemsInFolder = deckProvider.decks.where((d) => d.folderId == folder.id).length + 
                                        deckProvider.lessons.where((l) => l.folderId == folder.id).length;
                  return _buildFolderItem(folder.name, folder.color, itemsInFolder, folder.id, context);
                }),
                
                // Fallback folders if empty to match screenshot
                if (deckProvider.folders.isEmpty) ...[
                  _buildFolderItem('Introduction to Algorithms design ...', '#3B82F6', 0, null, context),
                  _buildFolderItem('Recursion', '#EF4444', 1, null, context),
                  _buildFolderItem('Linear Algebra MIT', '#3B82F6', 0, null, context),
                  _buildFolderItem('Multivariable Calculus MIT', '#3B82F6', 0, null, context),
                  _buildFolderItem('Algorithms', '#3B82F6', 0, null, context),
                  _buildFolderItem('Single Variable calculus MIT', '#3B82F6', 0, null, context),
                ],
              ],
            ),
          ),
          
          // Bottom SRS Queue Widget
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'DAILY SRS QUEUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: pomodoro.isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 9,
                                  color: pomodoro.isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  pomodoroTime,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: pomodoro.isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '$totalDue due',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: totalDue > 0
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StudySessionView(
                                    customSessionCards: dueCardsList,
                                    title: 'Daily SRS Queue',
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5998),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF3B5998).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(
                        'STUDY ALL DUE CARDS ($totalDue)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Style Notes Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _showNoteStyleModal(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF475569),
                  elevation: 0,
                ),
                icon: const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF2563EB)),
                label: const Text(
                  'STYLE MY NOTES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteStyleModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const NoteStyleDialog(),
    );
  }

  Widget _buildSectionLabel(String text, String pomodoroTime, bool isActive, {EdgeInsetsGeometry? padding}) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required WorkspaceTab tab,
    String? badge,
  }) {
    final isActive = currentTab == tab;
    return InkWell(
      onTap: () => onSelectTab(tab),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFDBEAFE) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF4A5568),
                ),
              ),
            ),
            if (badge != null && badge != '0')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? const Color(0xFFBFDBFE) : Colors.transparent,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCourseItem(Course course, BuildContext context) {
    return InkWell(
      onTap: () => onSelectCourse(course),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.school_outlined, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                course.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (course.modules.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${course.modules.fold<int>(0, (sum, m) => sum + m.items.length)}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (val) {
                if (val == 'delete') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                          SizedBox(width: 8),
                          Text('Delete Course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text('Are you sure you want to delete course "${course.title}" and its course folder?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            context.read<DeckProvider>().deleteCourse(course.id, deleteFolderToo: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Course "${course.title}" deleted.'), backgroundColor: AppColors.success),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                      SizedBox(width: 8),
                      Text('Delete Course & Folder', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(String name, String? colorHex, int count, String? id, BuildContext context) {
    final isActive = activeFolderId == id && id != null;
    Color dotColor;
    try {
      dotColor = Color(int.parse((colorHex ?? '#3B82F6').replaceAll('#', 'FF'), radix: 16));
    } catch (e) {
      dotColor = const Color(0xFF3B82F6);
    }
    
    return InkWell(
      onTap: () => onSelectFolder(id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? const Color(0xFF1E293B) : const Color(0xFF4A5568),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            if (id != null) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'shuffle') {
                    final allDecks = context.read<DeckProvider>().decks;
                    final folderDecks = allDecks.where((d) => d.id != 'universal' && d.folderId == id).toList();
                    final allCards = folderDecks.expand((d) => d.cards).toList();
                    if (allCards.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No flashcards found in folder "$name".')),
                      );
                      return;
                    }
                    final shuffledCards = List<Flashcard>.from(allCards)..shuffle();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudySessionView(
                          customSessionCards: shuffledCards,
                          title: 'Shuffled - $name',
                          deckId: id,
                        ),
                      ),
                    );
                  } else if (val == 'delete') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                            SizedBox(width: 8),
                            Text('Delete Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text('Are you sure you want to delete folder "$name"? Decks and notes inside will be unfiled.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.read<DeckProvider>().deleteFolder(id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Folder "$name" deleted.'), backgroundColor: AppColors.success),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'shuffle',
                    child: Row(
                      children: [
                        Icon(Icons.shuffle, size: 16, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text('Shuffle & Study'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                        SizedBox(width: 8),
                        Text('Delete Folder', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoteStyleDialog extends StatefulWidget {
  const NoteStyleDialog({super.key});

  @override
  State<NoteStyleDialog> createState() => _NoteStyleDialogState();
}

class _NoteStyleDialogState extends State<NoteStyleDialog> {
  late String _selectedTheme;
  late Map<String, String> _customStyles;

  final List<String> _themePresets = [
    'GitHub Light',
    'GitHub Dark',
    'Solarized Dark',
    'Soft Sepia',
    'Custom Theme'
  ];

  final Map<String, List<String>> _colorOptions = {
    'bg': ['#FFFFFF', '#F8FAFC', '#F1F5F9', '#FFFDF5', '#F5F5DC', '#0F172A', '#0D1117', '#1E1E1E', '#0B132B'],
    'text': ['#000000', '#1E293B', '#475569', '#FFFFFF', '#CBD5E1', '#E2E8F0', '#FBBF24', '#38BDF8', '#839496'],
    'link': ['#0969DA', '#2563EB', '#3B82F6', '#8B5CF6', '#10B981', '#F59E0B', '#EF4444', '#EC4899', '#58A6FF'],
    'border': ['#D0D7DE', '#E2E8F0', '#CBD5E1', '#30363D', '#475569', '#334155', '#F59E0B', '#073642', '#00000000'],
  };

  final Map<String, String> _colorNames = {
    '#FFFFFF': 'White',
    '#F8FAFC': 'Slate 50',
    '#F1F5F9': 'Slate 100',
    '#FFFDF5': 'Paper',
    '#F5F5DC': 'Beige',
    '#0F172A': 'Slate 900',
    '#0D1117': 'GH Dark',
    '#1E1E1E': 'VS Code',
    '#0B132B': 'Midnight',
    
    '#000000': 'Black',
    '#1E293B': 'Charcoal',
    '#475569': 'Grey',
    '#CBD5E1': 'Silver',
    
    '#0969DA': 'GH Blue',
    '#2563EB': 'Indigo',
    '#3B82F6': 'Blue',
    '#8B5CF6': 'Purple',
    '#10B981': 'Emerald',
    '#F59E0B': 'Amber',
    '#EF4444': 'Red',
    '#EC4899': 'Pink',
    '#58A6FF': 'Sky Blue',
    
    '#D0D7DE': 'GH Border',
    '#E2E8F0': 'Soft Line',
    '#30363D': 'GH Dark Line',
    '#00000000': 'None',
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DeckProvider>(context, listen: false);
    _selectedTheme = provider.noteTheme;
    _customStyles = Map<String, String>.from(provider.customThemeStyles);
  }

  Color _getColorFromHex(String hex) {
    if (hex == '#00000000') return Colors.transparent;
    try {
      var h = hex.replaceAll('#', '').trim();
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeckProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.palette, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Style My Notes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'THEME PRESETS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preset cards grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _themePresets.map((presetName) {
                      final isSelected = _selectedTheme == presetName;
                      
                      Color cardBg = Colors.white;
                      Color cardText = const Color(0xFF24292F);
                      Color cardLink = const Color(0xFF0969DA);
                      Color cardBorder = const Color(0xFFD0D7DE);

                      if (presetName == 'GitHub Light') {
                        cardBg = const Color(0xFFFFFFFF);
                        cardText = const Color(0xFF24292F);
                        cardLink = const Color(0xFF0969DA);
                        cardBorder = const Color(0xFFD0D7DE);
                      } else if (presetName == 'GitHub Dark') {
                        cardBg = const Color(0xFF0D1117);
                        cardText = const Color(0xFFC9D1D9);
                        cardLink = const Color(0xFF58A6FF);
                        cardBorder = const Color(0xFF30363D);
                      } else if (presetName == 'Solarized Dark') {
                        cardBg = const Color(0xFF002B36);
                        cardText = const Color(0xFF839496);
                        cardLink = const Color(0xFF2AA198);
                        cardBorder = const Color(0xFF073642);
                      } else if (presetName == 'Soft Sepia') {
                        cardBg = const Color(0xFFFBF0D9);
                        cardText = const Color(0xFF433422);
                        cardLink = const Color(0xFF8C6239);
                        cardBorder = const Color(0xFFE6D8B8);
                      } else {
                        // Custom Theme Preview from current styles
                        cardBg = _getColorFromHex(_customStyles['bg'] ?? '#ffffff');
                        cardText = _getColorFromHex(_customStyles['text'] ?? '#24292f');
                        cardLink = _getColorFromHex(_customStyles['link'] ?? '#0969da');
                        cardBorder = _getColorFromHex(_customStyles['border'] ?? '#d0d7de');
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTheme = presetName;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 165,
                          height: 90,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : cardBorder,
                              width: isSelected ? 2.5 : 1.2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        presetName.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? const Color(0xFF2563EB) : cardText.withValues(alpha: 0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF2563EB)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Abc notes content',
                                      style: TextStyle(fontSize: 10, color: cardText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'https://link.com',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: cardLink,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Custom theme parameters
                  if (_selectedTheme == 'Custom Theme') ...[
                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CUSTOM STYLING CONTROLS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _importStylesFromCssFile,
                          icon: const Icon(Icons.file_open, size: 14),
                          label: const Text('Import CSS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildCustomColorSection(
                      title: 'Background Color',
                      type: 'bg',
                    ),
                    const SizedBox(height: 20),

                    _buildCustomColorSection(
                      title: 'Text Color',
                      type: 'text',
                    ),
                    const SizedBox(height: 20),

                    _buildCustomColorSection(
                      title: 'Link / Accent Color',
                      type: 'link',
                    ),
                    const SizedBox(height: 20),

                    _buildCustomColorSection(
                      title: 'Border Color',
                      type: 'border',
                    ),
                    const SizedBox(height: 20),

                    // Font Size Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Font Size',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '${_customStyles['font_size'] ?? '16'} px',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: (double.tryParse(_customStyles['font_size'] ?? '16') ?? 16.0).clamp(12.0, 36.0),
                          min: 12.0,
                          max: 36.0,
                          divisions: 24,
                          activeColor: const Color(0xFF2563EB),
                          inactiveColor: const Color(0xFFE2E8F0),
                          onChanged: (val) {
                            setState(() {
                              _customStyles['font_size'] = val.round().toString();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Footer actions
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                   ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      await provider.setNoteTheme(_selectedTheme);
                      await provider.setCustomThemeStyles(_customStyles);
                      if (mounted) {
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('✨ Note styles updated successfully!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Apply Style', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomColorSection({
    required String title,
    required String type,
  }) {
    final colors = _colorOptions[type] ?? [];
    final selectedVal = _customStyles[type] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((hex) {
            final isColorSelected = selectedVal.toUpperCase() == hex.toUpperCase();
            final itemColor = _getColorFromHex(hex);
            final colorName = _colorNames[hex] ?? hex;

            return Tooltip(
              message: colorName,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _customStyles[type] = hex;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: itemColor == Colors.transparent ? Colors.white : itemColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isColorSelected 
                          ? const Color(0xFF2563EB) 
                          : (hex == '#FFFFFF' || hex == '#00000000' ? const Color(0xFFCBD5E1) : Colors.transparent),
                      width: isColorSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      if (isColorSelected)
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                    ],
                  ),
                  child: Center(
                    child: hex == '#00000000'
                        ? const Icon(Icons.close, size: 16, color: Colors.red)
                        : (isColorSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: itemColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _importStylesFromCssFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['css'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        if (await file.exists()) {
          final content = await file.readAsString();
          final parsed = parseCssToThemeStyles(content);
          
          if (parsed.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ No valid style rules (e.g. background-color, color) found in the selected CSS file.'),
                  backgroundColor: Colors.amber,
                ),
              );
            }
            return;
          }

          setState(() {
            _selectedTheme = 'Custom Theme';
            parsed.forEach((key, val) {
              _customStyles[key] = val;
            });
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎨 Styles imported successfully from CSS file!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing CSS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String stripMediaQueries(String css) {
    final buffer = StringBuffer();
    int i = 0;
    while (i < css.length) {
      if (i < css.length - 6 && css.substring(i, i + 6) == '@media') {
        // Find the start of the media query block
        int braceCount = 0;
        int j = i;
        while (j < css.length) {
          if (css[j] == '{') {
            braceCount++;
            j++;
            break;
          }
          j++;
        }
        // Consume nested blocks until the media query's closing brace is found
        while (j < css.length && braceCount > 0) {
          if (css[j] == '{') {
            braceCount++;
          } else if (css[j] == '}') {
            braceCount--;
          }
          j++;
        }
        i = j;
      } else {
        buffer.write(css[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  Map<String, String> parseCssToThemeStyles(String cssContent) {
    final Map<String, String> styles = {};
    
    // 1. Clean comments
    var cleanCss = cssContent.replaceAll(RegExp(r'\/\*[\s\S]*?\*\/'), '');
    
    // 2. Strip media queries to ignore overrides (like print or mobile rules)
    cleanCss = stripMediaQueries(cleanCss);
    
    // 3. Parse selector blocks, e.g. body { ... }
    final blockRegex = RegExp(r'([^{]+)\{([^}]+)\}');
    final matches = blockRegex.allMatches(cleanCss);
    
    final Map<String, String> variables = {};
    final List<Map<String, dynamic>> parsedBlocks = [];
    
    for (final match in matches) {
      final selectors = match.group(1)!.trim().toLowerCase();
      final declarations = match.group(2)!.trim();
      
      // Parse declaration list, e.g. background-color: #ffffff; color: #333;
      final decRegex = RegExp(r'([^:]+):([^;]+);?');
      final decMatches = decRegex.allMatches(declarations);
      
      final Map<String, String> ruleMap = {};
      for (final decMatch in decMatches) {
        final key = decMatch.group(1)!.trim();
        final val = decMatch.group(2)!.trim();
        ruleMap[key] = val;
        
        // If it's a CSS variable declaration (starts with --)
        if (key.startsWith('--')) {
          variables[key] = val;
        }
      }
      
      parsedBlocks.add({
        'selectors': selectors,
        'rules': ruleMap,
      });
    }
    
    // Helper to resolve var(--variable-name) in values
    String resolveValue(String val) {
      var resolved = val;
      final varRegex = RegExp(r'var\((--[^)]+)\)');
      var match = varRegex.firstMatch(resolved);
      int iterations = 0;
      // Loop to resolve nested vars up to 5 levels
      while (match != null && iterations < 5) {
        final varName = match.group(1)!.trim();
        if (variables.containsKey(varName)) {
          resolved = resolved.replaceFirst(match.group(0)!, variables[varName]!);
        } else {
          break;
        }
        match = varRegex.firstMatch(resolved);
        iterations++;
      }
      return resolved;
    }
    
    // 4. Extract styles from parsed blocks
    for (final block in parsedBlocks) {
      final selectors = block['selectors'] as String;
      final ruleMap = block['rules'] as Map<String, String>;
      
      // Resolve variables in this block's rules
      final resolvedRules = <String, String>{};
      ruleMap.forEach((k, v) {
        resolvedRules[k] = resolveValue(v);
      });
      
      // If selector contains 'body' or 'html'
      if (selectors.contains('body') || selectors.contains('html')) {
        if (resolvedRules.containsKey('background-color')) {
          final bg = _extractHexColor(resolvedRules['background-color']!);
          if (bg != null) styles['bg'] = bg;
        } else if (resolvedRules.containsKey('background')) {
          final bg = _extractHexColor(resolvedRules['background']!);
          if (bg != null) styles['bg'] = bg;
        }
        if (resolvedRules.containsKey('color')) {
          final text = _extractHexColor(resolvedRules['color']!);
          if (text != null) styles['text'] = text;
        }
        if (resolvedRules.containsKey('font-size')) {
          final fontSizeStr = RegExp(r'(\d+)').firstMatch(resolvedRules['font-size']!)?.group(1);
          if (fontSizeStr != null) {
            final fs = double.tryParse(fontSizeStr);
            if (fs != null) {
              styles['font_size'] = fs.clamp(12.0, 36.0).round().toString();
            }
          }
        }
      }
      
      // If selector contains 'a' (specifically 'a' or 'a:link' etc.)
      if (selectors.split(',').any((s) => s.trim() == 'a' || s.trim().startsWith('a:'))) {
        if (resolvedRules.containsKey('color')) {
          final link = _extractHexColor(resolvedRules['color']!);
          if (link != null) styles['link'] = link;
        }
      }
      
      // If selector contains border colors
      if (selectors.contains('h1') || selectors.contains('h2') || selectors.contains('hr') || selectors.contains('.border') || selectors.contains('border')) {
        if (resolvedRules.containsKey('border-color')) {
          final border = _extractHexColor(resolvedRules['border-color']!);
          if (border != null) styles['border'] = border;
        } else if (resolvedRules.containsKey('border-bottom-color')) {
          final border = _extractHexColor(resolvedRules['border-bottom-color']!);
          if (border != null) styles['border'] = border;
        } else if (resolvedRules.containsKey('border')) {
          final hex = _extractHexColor(resolvedRules['border']!);
          if (hex != null) styles['border'] = hex;
        } else if (resolvedRules.containsKey('border-bottom')) {
          final hex = _extractHexColor(resolvedRules['border-bottom']!);
          if (hex != null) styles['border'] = hex;
        }
      }
    }
    
    return styles;
  }

  String? _extractHexColor(String cssValue) {
    final hexRegex = RegExp(r'#([0-9a-fA-F]{3,8})');
    final hexMatch = hexRegex.firstMatch(cssValue);
    if (hexMatch != null) {
      String hex = hexMatch.group(0)!;
      if (hex.length == 4) {
        final r = hex[1];
        final g = hex[2];
        final b = hex[3];
        return '#$r$r$g$g$b$b';
      }
      return hex;
    }
    return null;
  }
}
