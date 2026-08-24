import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/note_mastery_storage_service.dart';
import '../../providers/deck_provider.dart';
import '../../models/lesson_model.dart';
import '../../models/folder_model.dart';
import '../../models/note_mastery_model.dart';
import '../widgets/modals/folder_modal.dart';
import '../widgets/modals/move_resource_modal.dart';
import '../widgets/modals/create_note_modal.dart';
import '../widgets/modals/due_notes_review_modal.dart';
import '../widgets/modals/note_mastery_modal.dart';
import 'lesson_detail_view.dart';
import 'pdf_viewer_view.dart';

class LessonsView extends StatefulWidget {
  final VoidCallback onNavigateToLessonGenerator;
  
  const LessonsView({super.key, required this.onNavigateToLessonGenerator});

  @override
  State<LessonsView> createState() => _LessonsViewState();
}

class _LessonsViewState extends State<LessonsView> {
  String _searchQuery = '';
  int _selectedFilter = 0; // 0: All, 1: PDFs, 2: Notes Only
  String? _activeFolderId;

  final NoteMasteryStorageService _masteryStorage = NoteMasteryStorageService();
  Map<String, int> _noteMasteryScores = {};
  Map<String, NoteMasteryModel> _masteryModels = {};

  @override
  void initState() {
    super.initState();
    _loadMasteries();
  }

  Future<void> _loadMasteries() async {
    final models = await _masteryStorage.loadAllMasteries();
    final scores = await _masteryStorage.getAllEffectiveMasteryScores();
    if (mounted) {
      setState(() {
        _masteryModels = models;
        _noteMasteryScores = scores;
      });
    }
  }

  Color _getMasteryColor(int score) {
    if (score >= 80) return const Color(0xFF059669); // Emerald
    if (score >= 60) return const Color(0xFF10B981); // Green
    if (score >= 40) return const Color(0xFFD97706); // Amber
    return const Color(0xFFE11D48); // Rose / Red
  }

  Future<void> _handleImportPdf() async {
    if (!mounted) return;
    final deckProvider = context.read<DeckProvider>();

    String? targetFolderId = _activeFolderId;

    if (targetFolderId == null) {
      final folders = deckProvider.folders;
      if (folders.isEmpty) {
        // Automatically create a default folder
        final newFolder = await deckProvider.addFolder('Imported PDFs', color: '#3B82F6');
        targetFolderId = newFolder.id;
        setState(() => _activeFolderId = newFolder.id);
      } else {
        // Let them select an existing folder or create a new one
        final selected = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Choose Target Folder'),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Select which course folder to place the imported PDFs in:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ),
                  ...folders.map((f) {
                    final colorHex = f.color?.replaceAll('#', '') ?? '3B82F6';
                    final colorVal = int.tryParse('0xFF$colorHex') ?? 0xFF3B82F6;
                    return ListTile(
                      leading: Icon(Icons.folder, color: Color(colorVal)),
                      title: Text(f.name),
                      onTap: () => Navigator.of(ctx).pop(f.id),
                    );
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder, color: Color(0xFF10B981)),
                    title: const Text('Create New Folder...', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.of(ctx).pop('create'),
                  ),
                ],
              ),
            ),
          ),
        );

        if (selected == null) return;

        if (selected == 'create') {
          if (!mounted) return;
          // Open new folder modal
          Folder? newFolder;
          await showDialog(
            context: context,
            builder: (ctx) => FolderModal(
              onSave: (name, color) async {
                newFolder = await deckProvider.addFolder(name, color: color);
              },
            ),
          );
          if (newFolder == null) return;
          targetFolderId = newFolder!.id;
          setState(() => _activeFolderId = newFolder!.id);
        } else {
          targetFolderId = selected;
          setState(() => _activeFolderId = selected);
        }
      }
    }

    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import PDFs'),
        content: const Text('Choose how you would like to import your PDF documents:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(ctx).pop('files'),
            icon: const Icon(Icons.insert_drive_file),
            label: const Text('Select PDF Files'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(ctx).pop('folder'),
            icon: const Icon(Icons.folder),
            label: const Text('Select Folder (Bulk)'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    List<File> pdfFiles = [];

    if (choice == 'files') {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result.isNotEmpty) {
        for (final f in result) {
          if (f.path != null) {
            pdfFiles.add(File(f.path!));
          }
        }
      }
    } else if (choice == 'folder') {
      final directoryPath = await FilePicker.getDirectoryPath();
      if (directoryPath != null) {
        final dir = Directory(directoryPath);
        if (await dir.exists()) {
          final list = dir.listSync(recursive: false);
          for (final entity in list) {
            if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
              pdfFiles.add(entity);
            }
          }
        }
      }
    }

    if (pdfFiles.isNotEmpty) {
      Lesson? lastLesson;
      int successCount = 0;

      for (final file in pdfFiles) {
        final path = file.path;
        final filename = file.path.split(Platform.pathSeparator).last;
        final lesson = await deckProvider.importPdfLesson(path, filename);
        if (lesson != null) {
          successCount++;
          // Assign to target folder
          lesson.folderId = targetFolderId;
          await deckProvider.updateLesson(lesson);
          lastLesson = lesson;
        }
      }

      if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $successCount PDF(s) into folder'),
            backgroundColor: AppColors.success,
          ),
        );

        if (successCount == 1 && lastLesson != null && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PdfViewerView(
              lesson: lastLesson!,
              onNavigateBack: () => Navigator.of(context).maybePop(),
            ),
          ));
        }
      }
    }
  }

  Future<void> _handleCreateNote() async {
    if (!mounted) return;
    
    final result = await CreateNoteModal.show(
      context,
      initialFolderId: _activeFolderId,
    );

    if (result == null || !mounted) return;

    final title = result['title'] as String;
    final topic = result['topic'] as String;
    final folderId = result['folderId'] as String;

    final deckProvider = context.read<DeckProvider>();
    final newId = 'note_${const Uuid().v4()}';
    
    final newLesson = Lesson(
      id: newId,
      title: title,
      topic: topic,
      content: '# $title\n\nStart writing your notes here...',
      folderId: folderId,
      isNote: true,
    );

    await deckProvider.addLesson(newLesson);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note "$title" created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonDetailView(
            lesson: newLesson,
            isEditing: true,
            onNavigateBack: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }
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

  void _openNewFolderModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FolderModal(
        onSave: (name, color) async {
          await context.read<DeckProvider>().addFolder(name, color: color);
        },
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
            Text('Delete Note Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete "${folder.name}" notes folder? Note files will remain stored in your library.'),
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
                deckProvider.deleteFolder(folder.id, deleteDecksInside: true);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Folder "${folder.name}" deleted.'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
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

  void _confirmDeleteLesson(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Note Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete note "${lesson.title}"?'),
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
    final deckProvider = context.watch<DeckProvider>();
    final allLessons = deckProvider.lessons;
    final folders = deckProvider.folders;

    // Filter by search & type
    List<Lesson> filteredLessons = allLessons.where((l) {
      if (!l.isNote) return false;
      if (_searchQuery.isNotEmpty &&
          !l.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !l.topic.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedFilter == 1) {
        return l.pdfUrl != null || l.pdfFilename != null;
      }
      if (_selectedFilter == 2) {
        return l.pdfUrl == null && l.pdfFilename == null;
      }
      if (_selectedFilter == 3) {
        final m = _masteryModels[l.id] ?? _masteryModels[l.title];
        final score = _noteMasteryScores[l.id] ?? _noteMasteryScores[l.title] ?? 0;
        return (m?.isGraduated ?? false) || score >= 90;
      }
      return true;
    }).toList();

    // Prepare Display Folders
    final List<Folder> displayFolders = folders.where((f) => f.id != 'unfiled').toList();

    // Add virtual General / Unfiled folder if there are any unfiled notes
    final hasUnfiledNotes = allLessons.any((l) => l.isNote && (l.folderId == null || l.folderId == 'unfiled' || !folders.any((f) => f.id == l.folderId)));
    if (hasUnfiledNotes) {
      displayFolders.add(Folder(
        id: 'unfiled',
        name: 'General / Unfiled Notes',
        color: '#64748B',
      ));
    }

    final activeFolder = displayFolders.firstWhere(
      (f) => f.id == _activeFolderId,
      orElse: () => displayFolders.isNotEmpty ? displayFolders.first : Folder(id: '', name: 'Course Notes'),
    );

    int totalPdfs = allLessons.where((l) => l.isNote && (l.pdfUrl != null || l.pdfFilename != null)).length;
    int totalMastered = allLessons.where((l) {
      if (!l.isNote) return false;
      if (l.isFromLocalCourse(deckProvider.courses, deckProvider.folders)) return false;
      final m = _masteryModels[l.id] ?? _masteryModels[l.title];
      final score = _noteMasteryScores[l.id] ?? _noteMasteryScores[l.title] ?? 0;
      return (m?.isGraduated ?? false) || score >= 90;
    }).length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1000;
    
    return Container(
      color: const Color(0xFF0B132B),
      child: Column(
        children: [
          _buildHeader(isMobile, activeFolder, filteredLessons, deckProvider),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          _buildFilterBar(filteredLessons.length, totalPdfs, totalMastered, isMobile),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          Expanded(
            child: displayFolders.isEmpty && filteredLessons.isEmpty
              ? _buildEmptyState()
              : _activeFolderId == null
                  ? _buildFolderGrid(displayFolders, filteredLessons, isMobile, screenWidth)
                  : _buildLessonGrid(filteredLessons, activeFolder, isMobile, screenWidth, deckProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, Folder activeFolder, List<Lesson> filteredLessons, DeckProvider deckProvider) {
    final dueCount = filteredLessons
        .where((l) => l.isNote && !l.isFromLocalCourse(deckProvider.courses, deckProvider.folders) && (_noteMasteryScores[l.id] ?? _noteMasteryScores[l.title] ?? 0) < 60)
        .length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      color: const Color(0xFF162238),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Library', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
              Text(
                _activeFolderId != null ? activeFolder.name : 'Lecture Notes & Documents',
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _activeFolderId = null),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.menu_book, color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _activeFolderId != null ? activeFolder.name : 'CS Notes & PDF Documents',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeFolderId != null
                          ? 'Course-specific markdown notes, synchronized lecture transcriptions, and PDF documents.'
                          : 'View imported PDF documents, professor-grade CS notes, and take dual-pane notes side-by-side',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      // DUE NOTES REVIEW BUTTON
                      ElevatedButton.icon(
                        onPressed: () async {
                          await DueNotesReviewModal.show(
                            context,
                            folderId: _activeFolderId,
                            onMasteryChanged: _loadMasteries,
                          );
                          _loadMasteries();
                        },
                        icon: const Icon(Icons.psychology, size: 18),
                        label: Text(
                          dueCount > 0 ? 'DUE REVIEW ($dueCount)' : 'DUE REVIEW',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dueCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openNewFolderModal(context),
                      icon: const Icon(Icons.create_new_folder, size: 18),
                      label: const Text('CREATE FOLDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _handleCreateNote,
                      icon: const Icon(Icons.note_add, size: 18),
                      label: const Text('CREATE NOTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _handleImportPdf,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('IMPORT PDFS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToLessonGenerator,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('GENERATE NOTES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await DueNotesReviewModal.show(
                      context,
                      folderId: _activeFolderId,
                      onMasteryChanged: _loadMasteries,
                    );
                    _loadMasteries();
                  },
                  icon: const Icon(Icons.psychology, size: 16),
                  label: Text(
                    dueCount > 0 ? 'DUE ($dueCount)' : 'DUE',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dueCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openNewFolderModal(context),
                  icon: const Icon(Icons.create_new_folder, size: 16),
                  label: const Text('FOLDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _handleCreateNote,
                  icon: const Icon(Icons.note_add, size: 16),
                  label: const Text('NOTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _handleImportPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('IMPORT PDFS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onNavigateToLessonGenerator,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFilterBar(int totalCount, int pdfCount, int masteredCount, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
      color: const Color(0xFF162238),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3B5C)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search notes and documents...',
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
            _buildSegmentedFilter(totalCount, pdfCount, masteredCount),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _activeFolderId = null),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Folders'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: const BorderSide(color: Color(0xFF2A3B5C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter(int totalCount, int pdfCount, int masteredCount) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3B5C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterButton('All ($totalCount)', 0, null),
          Container(width: 1, color: const Color(0xFF2A3B5C)),
          _buildFilterButton('PDFs ($pdfCount)', 1, Icons.picture_as_pdf),
          Container(width: 1, color: const Color(0xFF2A3B5C)),
          _buildFilterButton('Notes Only', 2, null),
          Container(width: 1, color: const Color(0xFF2A3B5C)),
          _buildFilterButton('🎓 Mastered ($masteredCount)', 3, null),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, int index, IconData? icon) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        color: isSelected ? const Color(0xFF2A3B5C) : Colors.transparent,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFFF43F5E)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderGrid(List<Folder> displayFolders, List<Lesson> allLessons, bool isMobile, double maxWidth) {
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 85,
      ),
      itemCount: displayFolders.length,
      itemBuilder: (context, index) {
        final folderObj = displayFolders[index];
        final folderLessons = allLessons.where((l) => l.isNote && l.folderId == folderObj.id).toList();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF162238),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A3B5C)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _activeFolderId = folderObj.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0x2210B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_outlined, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            folderObj.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${folderLessons.length} ${folderLessons.length == 1 ? 'doc' : 'docs'}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (folderObj.id != 'unfiled')
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40),
                        onSelected: (val) {
                          if (val == 'open') {
                            setState(() => _activeFolderId = folderObj.id);
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
                                Text('Open Notes Folder'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                SizedBox(width: 8),
                                Text('Rename Folder'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete Folder', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonGrid(List<Lesson> allLessons, Folder activeFolder, bool isMobile, double maxWidth, DeckProvider deckProvider) {
    final lessons = allLessons.where((l) {
      if (activeFolder.id == 'unfiled') {
        return l.folderId == null || l.folderId == 'unfiled' || !deckProvider.folders.any((f) => f.id == l.folderId);
      }
      return l.folderId == activeFolder.id;
    }).toList();

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 145,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        return _buildLessonCard(context, lessons[index], deckProvider);
      },
    );
  }

  Widget _buildEmptyState([String? title, String? subtitle]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.note_alt_outlined, size: 48, color: Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(
            title ?? 'No Notes or PDFs Found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'Import PDFs or create new Markdown notes to start studying.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, Lesson lesson, DeckProvider deckProvider) {
    final DateFormat formatter = DateFormat('MMM dd');
    final dateStr = formatter.format(DateTime.fromMillisecondsSinceEpoch(lesson.createdAt));
    final isPdf = lesson.pdfUrl != null || lesson.pdfFilename != null;
    final masteryModel = _masteryModels[lesson.id] ?? _masteryModels[lesson.title];
    final bool isGraduated = masteryModel?.isGraduated ?? false;
    final int score = _noteMasteryScores[lesson.id] ?? _noteMasteryScores[lesson.title] ?? 0;
    final Color masteryColor = isGraduated ? const Color(0xFF10B981) : _getMasteryColor(score);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGraduated ? const Color(0xFFF59E0B) : const Color(0xFF2A3B5C),
          width: isGraduated ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (lesson.pdfUrl != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PdfViewerView(
                  lesson: lesson,
                  onNavigateBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LessonDetailView(
                  lesson: lesson,
                  onNavigateBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            constraints: const BoxConstraints(maxWidth: 120),
                            decoration: BoxDecoration(
                              color: isPdf ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isPdf ? const Color(0xFFFFE4E6) : const Color(0xFFDCFCE7)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isPdf ? Icons.picture_as_pdf : Icons.article_outlined, size: 10, color: isPdf ? const Color(0xFFE11D48) : const Color(0xFF16A34A)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    isPdf ? 'PDF' : lesson.topic.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: isPdf ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              await showDialog(
                                context: context,
                                builder: (ctx) => NoteMasteryModal(
                                  noteKey: lesson.id,
                                  noteTitle: lesson.title,
                                  noteContent: lesson.content.isNotEmpty
                                      ? lesson.content
                                      : (lesson.pdfFilename != null ? 'Study notes for ${lesson.title} (${lesson.pdfFilename})' : lesson.topic),
                                  onMasteryUpdated: _loadMasteries,
                                ),
                              );
                              _loadMasteries();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isGraduated ? const Color(0xFFFEF3C7) : masteryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isGraduated ? const Color(0xFFF59E0B) : masteryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isGraduated)
                                    const Text('🎓', style: TextStyle(fontSize: 9))
                                  else
                                    Icon(Icons.psychology, size: 10, color: masteryColor),
                                  const SizedBox(width: 2),
                                  Text(
                                    isGraduated ? '100%' : '$score%',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: isGraduated ? const Color(0xFF065F46) : masteryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                    onSelected: (val) {
                      if (val == 'move') {
                        _openMoveLessonModal(context, lesson);
                      } else if (val == 'delete') {
                        _confirmDeleteLesson(context, lesson);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Move to Folder'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete Note', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lesson.title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  lesson.content.replaceAll(RegExp(r'#+\s*'), ''),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      Text(
                        isPdf ? 'PDF' : 'Read',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPdf ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward,
                        size: 10,
                        color: isPdf ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
