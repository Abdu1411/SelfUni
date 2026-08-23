import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../../models/lecture_model.dart';
import '../../models/folder_model.dart';
import '../../providers/deck_provider.dart';
import '../widgets/modals/import_course_modal.dart';
import '../widgets/modals/folder_modal.dart';
import '../widgets/modals/move_resource_modal.dart';
import 'lecture_player_view.dart';

class LiveLecturesView extends StatefulWidget {
  const LiveLecturesView({super.key});

  @override
  State<LiveLecturesView> createState() => _LiveLecturesViewState();
}

class _LiveLecturesViewState extends State<LiveLecturesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeFolderId;
  Lecture? _activePlayerLecture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _extractYtId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  void _openImportCourseModal(BuildContext context, {Folder? folder}) {
    showDialog(
      context: context,
      builder: (context) => ImportCourseModal(initialFolder: folder),
    );
  }

  void _openRenameFolderModal(BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (context) => FolderModal(
        initialName: folder.name,
        initialColor: folder.color,
        onSave: (name, color) {
          context.read<DeckProvider>().updateFolder(folder.id, name, color: color);
        },
      ),
    );
  }

  void _openMoveLessonModal(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) => MoveResourceModal(
        resourceId: lesson.id,
        isDeck: false,
      ),
    );
  }

  void _openEditLessonTitleModal(BuildContext context, Lesson lesson) {
    final controller = TextEditingController(text: lesson.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Color(0xFFF43F5E), size: 22),
            SizedBox(width: 8),
            Text('Edit Lecture Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Lecture Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != lesson.title) {
                final deckProvider = context.read<DeckProvider>();
                Navigator.of(ctx).pop();
                await deckProvider.renameLesson(lesson.id, newTitle);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lecture renamed to "$newTitle"'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Course Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete course folder "${folder.name}"? Video lectures will remain safely stored in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (_activeFolderId == folder.id) {
                setState(() => _activeFolderId = null);
              }
              final deckProvider = context.read<DeckProvider>();
              final matchingCourse = deckProvider.courses.where((c) => c.id == folder.id || c.title.toLowerCase() == folder.name.toLowerCase()).firstOrNull;
              if (matchingCourse != null) {
                deckProvider.deleteCourse(matchingCourse.id, deleteFolderToo: true);
              } else {
                deckProvider.deleteFolder(folder.id);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Course folder "${folder.name}" deleted.'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLesson(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Lecture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete "${lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<DeckProvider>().deleteLesson(lesson.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${lesson.title}".'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activePlayerLecture != null) {
      return LecturePlayerView(
        lecture: _activePlayerLecture!,
        onBack: () => setState(() => _activePlayerLecture = null),
      );
    }

    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;
    final allLessons = deckProvider.lessons;

    final videoLessons = allLessons.where((l) => !l.isNote && ((l.videoUrl != null && l.videoUrl!.isNotEmpty) || (l.sourceUrl != null && l.sourceUrl!.isNotEmpty))).toList();

    final filteredLessons = videoLessons.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return l.title.toLowerCase().contains(q) || l.topic.toLowerCase().contains(q);
    }).toList();

    // Prepare Display Folders: strictly user created / course folders
    final List<Folder> displayFolders = List<Folder>.from(folders.where((f) => f.id != 'unfiled'));

    // Dynamically include any course folders for existing video lessons so no imported lectures are ever hidden
    for (final lesson in filteredLessons) {
      if (lesson.topic.isNotEmpty &&
          lesson.topic != 'Unfiled' &&
          lesson.topic != 'General' &&
          !displayFolders.any((f) => f.id == lesson.folderId || f.name.toLowerCase() == lesson.topic.toLowerCase())) {
        displayFolders.add(Folder(
          id: lesson.folderId ?? 'folder_${lesson.topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: lesson.topic,
          color: '#3B82F6',
        ));
      }
    }

    final activeFolder = displayFolders.firstWhere(
      (f) => f.id == _activeFolderId,
      orElse: () => displayFolders.isNotEmpty ? displayFolders.first : Folder(id: '', name: 'Course Lectures'),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    
    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          _buildHeader(isMobile, activeFolder),
          const Divider(height: 1, color: AppColors.border),
          _buildSearchBar(isMobile),
          const Divider(height: 1, color: AppColors.border),
          
          Expanded(
            child: displayFolders.isEmpty && filteredLessons.isEmpty
              ? _buildEmptyState()
              : _activeFolderId == null
                  ? _buildFolderGrid(displayFolders, filteredLessons, isMobile, screenWidth)
                  : _buildVideoGrid(filteredLessons, activeFolder, isMobile, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, Folder activeFolder) {
    const pinkColor = Color(0xFFF43F5E);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_activeFolderId != null) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _activeFolderId = null),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.videocam_outlined, color: pinkColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _activeFolderId != null ? activeFolder.name : 'Live Lectures & Video Streams',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                          ),
                        ),
                        if (_activeFolderId != null && activeFolder.id != 'unfiled') ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                            onSelected: (val) {
                              if (val == 'rename') {
                                _openRenameFolderModal(context, activeFolder);
                              } else if (val == 'add') {
                                _openImportCourseModal(context, folder: activeFolder);
                              } else if (val == 'delete') {
                                _confirmDeleteFolder(context, activeFolder);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'add',
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Add Lecture Video'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Rename Course Folder'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete Course Folder', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeFolderId != null
                          ? 'Watch lectures, synchronized markdown notes, and extract automated AI flashcards.'
                          : 'Interactive video masterclasses with synchronized code notes and term breakdowns',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: () => _openImportCourseModal(context, folder: _activeFolderId != null ? activeFolder : null),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_activeFolderId != null ? 'ADD LECTURE' : 'ADD LIVE STREAM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openImportCourseModal(context, folder: _activeFolderId != null ? activeFolder : null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_activeFolderId != null ? 'ADD LECTURE' : 'ADD LIVE STREAM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search live streams and lectures...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          if (_activeFolderId != null) ...[
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _activeFolderId = null),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Courses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFolderGrid(List<Folder> displayFolders, List<Lesson> allVideoLessons, bool isMobile, double maxWidth) {
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 160,
      ),
      itemCount: displayFolders.length,
      itemBuilder: (context, index) {
        final folderObj = displayFolders[index];
        final folderLessons = allVideoLessons.where((l) => l.folderId == folderObj.id || l.topic.toLowerCase() == folderObj.name.toLowerCase()).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => setState(() => _activeFolderId = folderObj.id),
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallCard = constraints.maxHeight < 170 || constraints.maxWidth < 200;
                final double iconSize = isSmallCard ? 24 : 40;
                final double iconPadding = isSmallCard ? 10 : 20;
                final double topSpacer = isSmallCard ? 12 : 24;
                final double bottomSpacer = isSmallCard ? 8 : 16;
                final double titleSize = isSmallCard ? 13 : 16;
                final double contentPadding = isSmallCard ? 12 : 24;

                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: EdgeInsets.all(iconPadding),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(isSmallCard ? 12 : 20),
                              ),
                              child: Icon(Icons.folder_outlined, color: const Color(0xFFF43F5E), size: iconSize),
                            ),
                          ),
                          SizedBox(height: topSpacer),
                          Text(
                            folderObj.name,
                            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), height: 1.3),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (constraints.maxHeight >= 125) ...[
                            SizedBox(height: bottomSpacer),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${folderLessons.length} ${folderLessons.length == 1 ? 'lecture' : 'lectures'}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (folderObj.id != 'unfiled')
                      Positioned(
                        top: isSmallCard ? 4 : 12,
                        right: isSmallCard ? 4 : 12,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
                          padding: isSmallCard ? EdgeInsets.zero : const EdgeInsets.all(8),
                          constraints: isSmallCard ? const BoxConstraints(minWidth: 40) : null,
                          onSelected: (val) {
                            if (val == 'open') {
                              setState(() => _activeFolderId = folderObj.id);
                            } else if (val == 'add') {
                              _openImportCourseModal(context, folder: folderObj);
                            } else if (val == 'rename') {
                              _openRenameFolderModal(context, folderObj);
                            } else if (val == 'delete') {
                              _confirmDeleteFolder(context, folderObj);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text('Open Course Folder'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add',
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text('Add Lecture Video'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text('Rename Course Folder'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Delete Course Folder', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid(List<Lesson> allVideoLessons, Folder activeFolder, bool isMobile, double maxWidth) {
    int crossAxisCount = 1;
    if (maxWidth > 1400) {
      crossAxisCount = 4;
    } else if (maxWidth > 1000) {
      crossAxisCount = 3;
    } else if (maxWidth > 700) {
      crossAxisCount = 2;
    }

    final lessons = allVideoLessons.where((l) => l.folderId == activeFolder.id || l.topic.toLowerCase() == activeFolder.name.toLowerCase()).toList();

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 0.85,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final ytId = lesson.videoUrl != null ? _extractYtId(lesson.videoUrl!) : null;
        final thumbUrl = ytId != null ? 'https://img.youtube.com/vi/$ytId/mqdefault.jpg' : null;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    Container(
                      color: Colors.black,
                      width: double.infinity,
                      child: thumbUrl != null
                          ? Image.network(thumbUrl, fit: BoxFit.cover)
                          : const Center(child: Icon(Icons.ondemand_video, size: 48, color: Colors.white54)),
                    ),
                    Positioned.fill(
                      child: Container(color: Colors.black.withValues(alpha: 0.2)),
                    ),
                    Center(
                      child: FloatingActionButton.small(
                        onPressed: () => _playLesson(lesson, ytId, thumbUrl),
                        backgroundColor: const Color(0xFFF43F5E),
                        child: const Icon(Icons.play_arrow, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  lesson.topic.toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'watch') {
                                _playLesson(lesson, ytId, thumbUrl);
                              } else if (val == 'rename') {
                                _openEditLessonTitleModal(context, lesson);
                              } else if (val == 'move') {
                                _openMoveLessonModal(context, lesson);
                              } else if (val == 'delete') {
                                _confirmDeleteLesson(context, lesson);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'watch',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow, size: 16, color: Color(0xFFF43F5E)),
                                    SizedBox(width: 8),
                                    Text('Watch & Take Notes'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Edit Lecture Title'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'move',
                                child: Row(
                                  children: [
                                    Icon(Icons.drive_file_move_outlined, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Move to Course'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete Lecture', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: lesson.title,
                        child: Text(
                          lesson.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.35),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF94A3B8)),
                                tooltip: 'Edit Title',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openEditLessonTitleModal(context, lesson),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.drive_file_move_outlined, size: 16, color: Color(0xFF94A3B8)),
                                tooltip: 'Move to Course',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openMoveLessonModal(context, lesson),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                                tooltip: 'Delete Video',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteLesson(context, lesson),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _playLesson(lesson, ytId, thumbUrl),
                            icon: const Icon(Icons.play_arrow, size: 12),
                            label: const Text('Watch & Notes', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF1F2),
                              foregroundColor: const Color(0xFFF43F5E),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _playLesson(Lesson lesson, String? ytId, String? thumbUrl) {
    setState(() {
      _activePlayerLecture = Lecture(
        id: lesson.id,
        title: lesson.title,
        instructor: 'Course Lecturer',
        description: lesson.content,
        category: lesson.topic,
        videoId: lesson.videoUrl ?? lesson.sourceUrl ?? '',
        thumbnailUrl: thumbUrl ?? 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=600',
        status: LectureStatus.recorded,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(lesson.createdAt),
        durationMinutes: 45,
        attendeesCount: 0,
        timestamps: [
          LectureTimestamp(time: '00:00', seconds: 0, title: 'Introduction'),
        ],
        notesSummary: lesson.content,
        generatedFlashcards: [],
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'No Video Courses Added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import a course folder or attach YouTube masterclasses.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openImportCourseModal(context),
            icon: const Icon(Icons.cloud_download),
            label: const Text('Import Course'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
