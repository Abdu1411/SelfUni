import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/folder_model.dart';
import '../../providers/deck_provider.dart';

class CreateNoteModal extends StatefulWidget {
  final String? initialFolderId;

  const CreateNoteModal({super.key, this.initialFolderId});

  /// Static helper to display the modal dialog and return a Map of the created note's metadata
  static Future<Map<String, String?>?> show(
    BuildContext context, {
    String? initialFolderId,
  }) {
    return showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CreateNoteModal(initialFolderId: initialFolderId),
    );
  }

  @override
  State<CreateNoteModal> createState() => _CreateNoteModalState();
}

class _CreateNoteModalState extends State<CreateNoteModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _topicController;
  String? _selectedFolderId;
  bool _isTopicManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    _selectedFolderId = widget.initialFolderId;

    String initialTopic = 'General';
    if (_selectedFolderId != null && _selectedFolderId != 'unfiled') {
      final deckProvider = context.read<DeckProvider>();
      final matchingFolder = deckProvider.folders
          .where((f) => f.id == _selectedFolderId)
          .firstOrNull;
      if (matchingFolder != null) {
        initialTopic = matchingFolder.name;
      }
    }
    _topicController = TextEditingController(text: initialTopic);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;

    // Filter out unfiled folder to display only course/topic folders
    final displayFolders = folders.where((f) => f.id != 'unfiled').toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.note_add_outlined,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Note',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure details for your new document',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Note Title
              const Text(
                'Note Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 14),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., Lecture 1: Graph Representations',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF10B981)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a note title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Topic / Subject
              const Text(
                'Subject / Topic',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _topicController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g., Algorithms',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF10B981)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) {
                  _isTopicManuallyEdited = true;
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a subject or topic';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Target Folder
              const Text(
                'Course Folder',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedFolderId == 'unfiled'
                    ? null
                    : _selectedFolderId,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF10B981)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('📁 Unfiled / General Library'),
                  ),
                  ...displayFolders.map((f) {
                    return DropdownMenuItem<String>(
                      value: f.id,
                      child: Text('📁 ${f.name}'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedFolderId = val;
                    if (!_isTopicManuallyEdited) {
                      if (val == null) {
                        _topicController.text = 'General';
                      } else {
                        final folderName = displayFolders
                            .firstWhere(
                              (f) => f.id == val,
                              orElse: () => Folder(id: '', name: 'General'),
                            )
                            .name;
                        _topicController.text = folderName;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 32),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.of(context).pop({
                          'title': _titleController.text.trim(),
                          'topic': _topicController.text.trim(),
                          'folderId': _selectedFolderId ?? 'unfiled',
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Create Note',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
