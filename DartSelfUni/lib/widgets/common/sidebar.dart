import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';
import '../../models/course_model.dart';
import '../../views/custom_study_view.dart';

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
    
    // Calculate total due
    final now = DateTime.now().millisecondsSinceEpoch;
    int totalDue = 0;
    int totalCards = 0;
    for (var deck in deckProvider.decks) {
      totalCards += deck.cards.length;
      totalDue += deck.cards.where((c) => c.nextReview <= now).length;
    }

    final activeFolderIds = deckProvider.folders.map((f) => f.id).toSet();
    final activeCourseTitles = deckProvider.courses.map((c) => c.title.toLowerCase()).toSet();

    final activeLessons = deckProvider.lessons.where((l) {
      if (!l.isNote) return false;
      final hasFolder = l.folderId != null && l.folderId != 'unfiled' && activeFolderIds.contains(l.folderId);
      final hasCourse = activeCourseTitles.contains(l.topic.toLowerCase());
      return hasFolder || hasCourse;
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
                      SizedBox(height: 4),
                      Text(
                        'Dart & CS Accelerator',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8792A2),
                          fontFamily: 'monospace',
                        ),
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
                _buildSectionLabel('WORKSPACE'),
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
                
                _buildSectionLabel('LOCAL COURSES (${deckProvider.courses.length})', padding: EdgeInsets.zero),
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
                    _buildSectionLabel('FOLDERS (${deckProvider.folders.length})', padding: EdgeInsets.zero),
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
                      const Text(
                        'DAILY SRS QUEUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
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
                      onPressed: totalDue > 0 ? () => onSelectTab(WorkspaceTab.decks) : null,
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
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, {EdgeInsetsGeometry? padding}) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.0,
        ),
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
                  if (val == 'delete') {
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
