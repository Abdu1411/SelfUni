import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../../models/course_model.dart';
import '../../core/services/notes_storage_service.dart';
import '../../providers/deck_provider.dart';

class ExportNoteModal extends StatefulWidget {
  final String noteContent;
  final String defaultTitle;
  final String defaultTopic;
  final String? videoUrl;
  final String? defaultFolderId;

  const ExportNoteModal({
    super.key,
    required this.noteContent,
    required this.defaultTitle,
    required this.defaultTopic,
    this.videoUrl,
    this.defaultFolderId,
  });

  @override
  State<ExportNoteModal> createState() => _ExportNoteModalState();
}

class _ExportNoteModalState extends State<ExportNoteModal> {
  late TextEditingController _titleController;
  late TextEditingController _topicController;
  late TextEditingController _newFolderNameController;
  String? _selectedFolderId;
  bool _createNewFolder = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
    _topicController = TextEditingController(text: widget.defaultTopic);
    _newFolderNameController = TextEditingController();
    _selectedFolderId = widget.defaultFolderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _newFolderNameController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note title.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final deckProvider = context.read<DeckProvider>();

      String? folderId = _selectedFolderId;
      if (_createNewFolder && _newFolderNameController.text.trim().isNotEmpty) {
        final newFolder = await deckProvider.addFolder(_newFolderNameController.text.trim());
        folderId = newFolder.id;
      }

      final topic = _topicController.text.trim().isNotEmpty
          ? _topicController.text.trim()
          : 'Lecture Notes';

      final newLesson = Lesson(
        id: 'lesson_exp_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        topic: topic,
        content: widget.noteContent,
        folderId: folderId,
        videoUrl: widget.videoUrl,
        isNote: true,
      );

      await deckProvider.addLesson(newLesson);

      // Append notes to the master markdown file for the course/subject
      try {
        await NotesStorageService.appendNoteToClass(
          className: topic,
          lectureTitle: title,
          noteContent: widget.noteContent,
        );
      } catch (_) {}

      // Find the matching course and add to modules
      try {
        final matchingCourse = deckProvider.courses.where((c) {
          if (c.id == folderId) return true;
          if (folderId != null) {
            final folderName = deckProvider.folders.where((f) => f.id == folderId).firstOrNull?.name;
            if (folderName != null && c.title.toLowerCase() == folderName.toLowerCase()) return true;
          }
          if (c.title.toLowerCase() == topic.toLowerCase()) return true;
          return false;
        }).firstOrNull;

        if (matchingCourse != null) {
          CourseModule? targetModule;
          for (var module in matchingCourse.modules) {
            if (module.items.any((item) => item.path == widget.videoUrl || item.fileKey == widget.videoUrl)) {
              targetModule = module;
              break;
            }
          }
          if (targetModule == null) {
            if (matchingCourse.modules.isNotEmpty) {
              targetModule = matchingCourse.modules.first;
            } else {
              targetModule = CourseModule(
                id: 'mod_notes_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Lecture Notes',
                items: [],
              );
              matchingCourse.modules.add(targetModule);
            }
          }
          targetModule.items.add(
            CourseItem(
              id: newLesson.id,
              title: title,
              type: 'html',
              description: 'Notes exported from video lecture.',
            ),
          );
          await deckProvider.updateCourse(matchingCourse);
        }
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Note "$title" exported to Notes section successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.drive_file_move_outlined, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Note to Notes Section',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Save your lecture notes to the Notes & PDFs library',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 20),

            // Form Fields
            const Text(
              'NOTE TITLE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Binary Search & Lower Bound Invariants',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'TOPIC / SUBJECT AREA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Data Structures & Algorithms',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Folder Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TARGET FOLDER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                TextButton(
                  onPressed: () => setState(() => _createNewFolder = !_createNewFolder),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(
                    _createNewFolder ? 'Select Existing' : '+ New Folder',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_createNewFolder)
              TextField(
                controller: _newFolderNameController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter new folder name...',
                  prefixIcon: const Icon(Icons.create_new_folder_outlined, size: 18, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _selectedFolderId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Folder (Root Library)'),
                  ),
                  ...folders.map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(f.name),
                  )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedFolderId = val;
                  });
                },
              ),

            const SizedBox(height: 24),

            // Modal Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleExport,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isSaving ? 'Exporting...' : 'Export to Notes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
