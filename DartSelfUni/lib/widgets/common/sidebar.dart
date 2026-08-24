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

class Sidebar extends StatefulWidget {
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
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ScrollController _coursesScrollController = ScrollController();
  final ScrollController _foldersScrollController = ScrollController();

  @override
  void dispose() {
    _coursesScrollController.dispose();
    _foldersScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final pomodoro = context.watch<PomodoroProvider>();
    final minutes = (pomodoro.timeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (pomodoro.timeRemaining % 60).toString().padLeft(2, '0');
    final pomodoroTime = '$minutes:$seconds';
    
    // Calculate total due globally using the Universal Deck
    final universalCards = deckProvider.universalDeck?.cards ?? [];
    final dueCardsList = universalCards.where((c) => c.isDue).toList();
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
        color: Color(0xFF0B132B),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
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
                      colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'SRS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
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
          
          const Divider(height: 1, color: Color(0xFF1E293B)),
          
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
                          color: Color(0xFFA855F7), // Purple accent
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Custom Study',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        if (totalDue > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x33F59E0B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x66F59E0B)),
                            ),
                            child: Text(
                              '$totalDue due',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            totalCards.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Scrollbar(
                    controller: _coursesScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _coursesScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...deckProvider.courses.map((course) => _buildCourseItem(course, context)),
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
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel('FOLDERS (${deckProvider.folders.length})', pomodoroTime, pomodoro.isActive, padding: EdgeInsets.zero),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: widget.onOpenNewFolder,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Scrollbar(
                    controller: _foldersScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _foldersScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...deckProvider.folders.map((folder) {
                            final itemsInFolder = deckProvider.decks.where((d) => d.folderId == folder.id).length + 
                                                  deckProvider.lessons.where((l) => l.folderId == folder.id).length;
                            return _buildFolderItem(folder.name, folder.color, itemsInFolder, folder.id, context);
                          }),
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
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom SRS Queue Widget
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF162238),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A3B5C)),
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
                              color: Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: pomodoro.isActive ? const Color(0x3338BDF8) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 9,
                                  color: pomodoro.isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  pomodoroTime,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: pomodoro.isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
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
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x6638BDF8)),
                        ),
                        child: Text(
                          '$totalDue due',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
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
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A),
                        disabledBackgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.3),
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
                  side: const BorderSide(color: Color(0xFF2A3B5C), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0xFF162238),
                  foregroundColor: const Color(0xFFCBD5E1),
                  elevation: 0,
                ),
                icon: const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF38BDF8)),
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
              color: Color(0xFF64748B),
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
    final isActive = widget.currentTab == tab;
    return InkWell(
      onTap: () => widget.onSelectTab(tab),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0x4438BDF8) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            if (badge != null && badge != '0')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0x3338BDF8) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? const Color(0x6638BDF8) : Colors.transparent,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
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
      onTap: () => widget.onSelectCourse(course),
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
    final isActive = widget.activeFolderId == id && id != null;
    Color dotColor;
    try {
      dotColor = Color(int.parse((colorHex ?? '#3B82F6').replaceAll('#', 'FF'), radix: 16));
    } catch (e) {
      dotColor = const Color(0xFF3B82F6);
    }
    
    return InkWell(
      onTap: () => widget.onSelectFolder(id),
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
  late Map<String, String> _customStyles;

  final Map<String, List<String>> _colorOptions = {
    'bg': ['#FFFFFF', '#F8FAFC', '#F1F5F9', '#FAF9F6', '#FFFDF5', '#F5F5DC', '#0F172A', '#0D1117', '#1E1E1E', '#0B132B'],
    'text': ['#000000', '#1A1A1A', '#1E293B', '#475569', '#FFFFFF', '#CBD5E1', '#E2E8F0', '#FBBF24', '#38BDF8', '#839496'],
    'link': ['#1A5276', '#0969DA', '#2563EB', '#3B82F6', '#8B5CF6', '#10B981', '#F59E0B', '#EF4444', '#EC4899', '#58A6FF'],
    'border': ['#D0CEC4', '#D0D7DE', '#E2E8F0', '#CBD5E1', '#30363D', '#475569', '#334155', '#1A5276', '#073642', '#00000000'],
  };

  final Map<String, String> _colorNames = {
    '#FFFFFF': 'Pure White',
    '#F8FAFC': 'Slate 50',
    '#F1F5F9': 'Slate 100',
    '#FAF9F6': 'Warm Ivory',
    '#FFFDF5': 'Paper Linen',
    '#F5F5DC': 'Classic Beige',
    '#0F172A': 'Slate 900',
    '#0D1117': 'GitHub Dark',
    '#1E1E1E': 'VS Code Dark',
    '#0B132B': 'Midnight Blue',
    
    '#000000': 'Solid Black',
    '#1A1A1A': 'Charcoal Black',
    '#1E293B': 'Deep Slate',
    '#475569': 'Cool Grey',
    '#CBD5E1': 'Silver Text',
    
    '#1A5276': 'Deep Academic Blue',
    '#0969DA': 'GitHub Blue',
    '#2563EB': 'Indigo Accent',
    '#3B82F6': 'Vibrant Blue',
    '#8B5CF6': 'Royal Purple',
    '#10B981': 'Emerald Green',
    '#F59E0B': 'Warm Amber',
    '#EF4444': 'Ruby Red',
    '#EC4899': 'Magenta Pink',
    '#58A6FF': 'Sky Blue',
    
    '#D0CEC4': 'Academic Muted Line',
    '#D0D7DE': 'GitHub Border',
    '#E2E8F0': 'Soft Line',
    '#30363D': 'Dark Border',
    '#00000000': 'No Border',
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DeckProvider>(context, listen: false);
    _customStyles = Map<String, String>.from(provider.customThemeStyles);
    if (!_customStyles.containsKey('bg')) _customStyles['bg'] = '#FFFFFF';
    if (!_customStyles.containsKey('text')) _customStyles['text'] = '#1A1A1A';
    if (!_customStyles.containsKey('link')) _customStyles['link'] = '#1A5276';
    if (!_customStyles.containsKey('border')) _customStyles['border'] = '#D0D7DE';
    if (!_customStyles.containsKey('font_size')) _customStyles['font_size'] = '16';
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
    final currentBg = _getColorFromHex(_customStyles['bg'] ?? '#FFFFFF');
    final currentText = _getColorFromHex(_customStyles['text'] ?? '#1A1A1A');
    final currentLink = _getColorFromHex(_customStyles['link'] ?? '#1A5276');
    final currentBorder = _getColorFromHex(_customStyles['border'] ?? '#D0D7DE');
    final currentFontSize = (double.tryParse(_customStyles['font_size'] ?? '16') ?? 16.0).clamp(12.0, 36.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                        child: const Icon(Icons.palette_outlined, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Style My Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Custom styling & CSS stylesheet import',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
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
                  // 1. Import CSS Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.code, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Import from CSS Stylesheet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Load background, typography, borders, and colors directly from any .css file',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _importStylesFromCssFile,
                          icon: const Icon(Icons.file_open_outlined, size: 15),
                          label: const Text('Import CSS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Real-time Live Preview Card
                  const Text(
                    'LIVE NOTE PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: currentBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: currentBorder == Colors.transparent ? const Color(0xFFCBD5E1) : currentBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: currentBorder == Colors.transparent ? currentLink : currentBorder,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            '1. Foundations of Mathematical Reasoning',
                            style: TextStyle(
                              fontSize: (currentFontSize + 2).clamp(14.0, 38.0),
                              fontWeight: FontWeight.bold,
                              color: currentLink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Mathematics extends beyond calculation; it is the systematic determination of which assertions are true and which are false.',
                          style: TextStyle(
                            fontSize: currentFontSize,
                            color: currentText,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Reference: ',
                              style: TextStyle(fontSize: currentFontSize * 0.9, color: currentText.withValues(alpha: 0.8)),
                            ),
                            Text(
                              'https://selfuni.org/math-notes',
                              style: TextStyle(
                                fontSize: currentFontSize * 0.9,
                                color: currentLink,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // 3. Custom Color Pickers
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

                  // 4. Font Size Slider
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '${_customStyles['font_size'] ?? '16'} px',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: currentFontSize,
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
                      await provider.setNoteTheme('Custom Theme');
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
                  content: Text('⚠️ No valid style rules (e.g. background-color, color, font-size) found in the selected CSS file.'),
                  backgroundColor: Colors.amber,
                ),
              );
            }
            return;
          }

          setState(() {
            parsed.forEach((key, val) {
              _customStyles[key] = val;
            });
          });

          if (mounted) {
            final details = parsed.entries.map((e) => '${e.key}: ${e.value}').join(', ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎨 Styles imported successfully ($details)'),
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
    
    // 3. Parse selector blocks & variables
    final Map<String, String> variables = {};
    final List<Map<String, dynamic>> parsedBlocks = [];
    
    final blockRegex = RegExp(r'([^{]+)\{([^}]+)\}');
    final matches = blockRegex.allMatches(cleanCss);
    
    for (final match in matches) {
      final selectors = match.group(1)!.trim().toLowerCase();
      final declarations = match.group(2)!.trim();
      
      final decRegex = RegExp(r'([^:]+):([^;]+);?');
      final decMatches = decRegex.allMatches(declarations);
      
      final Map<String, String> ruleMap = {};
      for (final decMatch in decMatches) {
        final key = decMatch.group(1)!.trim().toLowerCase();
        final val = decMatch.group(2)!.trim();
        ruleMap[key] = val;
        
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
      final varRegex = RegExp(r'var\((--[^,)]+)(?:,\s*([^)]+))?\)');
      var match = varRegex.firstMatch(resolved);
      int iterations = 0;
      while (match != null && iterations < 5) {
        final varName = match.group(1)!.trim();
        final fallback = match.group(2)?.trim();
        if (variables.containsKey(varName)) {
          resolved = resolved.replaceFirst(match.group(0)!, variables[varName]!);
        } else if (fallback != null) {
          resolved = resolved.replaceFirst(match.group(0)!, fallback);
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
      
      final resolvedRules = <String, String>{};
      ruleMap.forEach((k, v) {
        resolvedRules[k] = resolveValue(v);
      });
      
      // If selector contains 'body' or 'html' or ':root'
      if (selectors.contains('body') || selectors.contains('html') || selectors.contains(':root') || selectors.contains('main') || selectors.contains('.markdown') || selectors.contains('.note')) {
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
          final fs = _extractFontSize(resolvedRules['font-size']!);
          if (fs != null) styles['font_size'] = fs;
        }
      }
      
      // If selector contains 'a'
      if (selectors.split(',').any((s) => s.trim() == 'a' || s.trim().startsWith('a:') || s.trim().contains('.link'))) {
        if (resolvedRules.containsKey('color')) {
          final link = _extractHexColor(resolvedRules['color']!);
          if (link != null) styles['link'] = link;
        }
      }
      
      // If selector contains border colors
      if (selectors.contains('h1') || selectors.contains('h2') || selectors.contains('h3') || selectors.contains('hr') || selectors.contains('blockquote') || selectors.contains('.border') || selectors.contains('table') || selectors.contains('pre')) {
        if (resolvedRules.containsKey('border-color')) {
          final border = _extractHexColor(resolvedRules['border-color']!);
          if (border != null) styles['border'] = border;
        } else if (resolvedRules.containsKey('border-bottom-color')) {
          final border = _extractHexColor(resolvedRules['border-bottom-color']!);
          if (border != null) styles['border'] = border;
        } else if (resolvedRules.containsKey('border-left-color')) {
          final border = _extractHexColor(resolvedRules['border-left-color']!);
          if (border != null) styles['border'] = border;
        } else if (resolvedRules.containsKey('border')) {
          final hex = _extractHexColor(resolvedRules['border']!);
          if (hex != null) styles['border'] = hex;
        } else if (resolvedRules.containsKey('border-bottom')) {
          final hex = _extractHexColor(resolvedRules['border-bottom']!);
          if (hex != null) styles['border'] = hex;
        } else if (resolvedRules.containsKey('border-left')) {
          final hex = _extractHexColor(resolvedRules['border-left']!);
          if (hex != null) styles['border'] = hex;
        }
      }
    }
    
    // 5. Fallback check on standard root variables if not yet resolved
    if (!styles.containsKey('bg')) {
      for (final k in ['--bg', '--background', '--page-bg', '--background-color', '--canvas-default']) {
        if (variables.containsKey(k)) {
          final color = _extractHexColor(resolveValue(variables[k]!));
          if (color != null) { styles['bg'] = color; break; }
        }
      }
    }
    if (!styles.containsKey('text')) {
      for (final k in ['--text', '--color', '--foreground', '--fg', '--text-color', '--fg-default']) {
        if (variables.containsKey(k)) {
          final color = _extractHexColor(resolveValue(variables[k]!));
          if (color != null) { styles['text'] = color; break; }
        }
      }
    }
    if (!styles.containsKey('link')) {
      for (final k in ['--link', '--accent', '--primary', '--link-color', '--accent-color', '--fg-accent']) {
        if (variables.containsKey(k)) {
          final color = _extractHexColor(resolveValue(variables[k]!));
          if (color != null) { styles['link'] = color; break; }
        }
      }
    }
    if (!styles.containsKey('border')) {
      for (final k in ['--border', '--border-color', '--border-default', '--line-color', '--divider']) {
        if (variables.containsKey(k)) {
          final color = _extractHexColor(resolveValue(variables[k]!));
          if (color != null) { styles['border'] = color; break; }
        }
      }
    }
    if (!styles.containsKey('font_size')) {
      for (final k in ['--font-size', '--base-font-size', '--text-size']) {
        if (variables.containsKey(k)) {
          final fs = _extractFontSize(resolveValue(variables[k]!));
          if (fs != null) { styles['font_size'] = fs; break; }
        }
      }
    }
    
    return styles;
  }

  String? _extractHexColor(String cssValue) {
    final clean = cssValue.trim().toLowerCase();

    // 1. Hex match
    final hexRegex = RegExp(r'#([0-9a-f]{3,8})');
    final hexMatch = hexRegex.firstMatch(clean);
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

    // 2. rgb / rgba match: rgb(26, 82, 118)
    final rgbMatch = RegExp(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(clean);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1)!) ?? 0;
      final g = int.tryParse(rgbMatch.group(2)!) ?? 0;
      final b = int.tryParse(rgbMatch.group(3)!) ?? 0;
      String toHex(int val) => val.clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${toHex(r)}${toHex(g)}${toHex(b)}';
    }

    // 3. Named colors
    const namedColors = {
      'white': '#ffffff',
      'black': '#000000',
      'transparent': '#00000000',
      'red': '#ef4444',
      'blue': '#3b82f6',
      'green': '#10b981',
      'gray': '#64748b',
      'grey': '#64748b',
      'amber': '#f59e0b',
      'purple': '#8b5cf6',
      'beige': '#f5f5dc',
    };
    for (final entry in namedColors.entries) {
      if (clean == entry.key || clean.startsWith('${entry.key} ')) {
        return entry.value;
      }
    }

    return null;
  }

  String? _extractFontSize(String cssValue) {
    final clean = cssValue.trim().toLowerCase();

    // 1. Pixel values: 30px
    final pxMatch = RegExp(r'([\d.]+)\s*px').firstMatch(clean);
    if (pxMatch != null) {
      final val = double.tryParse(pxMatch.group(1)!);
      if (val != null) {
        return val.clamp(12.0, 36.0).round().toString();
      }
    }

    // 2. Point values: 14pt (1pt ~= 1.333px)
    final ptMatch = RegExp(r'([\d.]+)\s*pt').firstMatch(clean);
    if (ptMatch != null) {
      final val = double.tryParse(ptMatch.group(1)!);
      if (val != null) {
        return (val * 1.333).clamp(12.0, 36.0).round().toString();
      }
    }

    // 3. Rem / em values: 1.5rem (base 16px)
    final remMatch = RegExp(r'([\d.]+)\s*r?em').firstMatch(clean);
    if (remMatch != null) {
      final val = double.tryParse(remMatch.group(1)!);
      if (val != null) {
        return (val * 16.0).clamp(12.0, 36.0).round().toString();
      }
    }

    // 4. Raw digits
    final digitMatch = RegExp(r'(\d+)').firstMatch(clean);
    if (digitMatch != null) {
      final val = double.tryParse(digitMatch.group(1)!);
      if (val != null) {
        return val.clamp(12.0, 36.0).round().toString();
      }
    }

    return null;
  }
}
