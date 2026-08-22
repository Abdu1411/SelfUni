import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/folder_model.dart';
import '../../providers/deck_provider.dart';
import 'folder_modal.dart';

class SelectFolderModal extends StatefulWidget {
  final String? initialFolderId;
  final String title;
  final String description;

  const SelectFolderModal({
    super.key,
    this.initialFolderId,
    this.title = 'Choose Destination Folder',
    this.description = 'A destination folder is mandatory to organize your AI-generated materials.',
  });

  /// Static convenience helper to show this dialog and return the selected folderId
  static Future<String?> show(
    BuildContext context, {
    String? initialFolderId,
    String title = 'Choose Destination Folder',
    String description = 'A destination folder is mandatory to organize your AI-generated materials.',
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SelectFolderModal(
        initialFolderId: initialFolderId,
        title: title,
        description: description,
      ),
    );
  }

  @override
  State<SelectFolderModal> createState() => _SelectFolderModalState();
}

class _SelectFolderModalState extends State<SelectFolderModal> {
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _openCreateFolder() async {
    final deckProvider = context.read<DeckProvider>();
    final newFolder = await showDialog<Folder>(
      context: context,
      builder: (ctx) => FolderModal(
        onSave: (name, color) async {
          final folder = await deckProvider.addFolder(name, color: color);
          if (ctx.mounted) Navigator.of(ctx).pop(folder);
        },
      ),
    );

    if (newFolder != null && mounted) {
      setState(() {
        _selectedFolderId = newFolder.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;

    // If initial is not in list and list has elements, default to first or keep
    if (_selectedFolderId == null && folders.isNotEmpty) {
      _selectedFolderId = folders.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_special, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Destination Folder Required',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.description,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),

            if (folders.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    const Text(
                      'No folders exist yet.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create your first course folder to proceed with AI generation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openCreateFolder,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Folder Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'SELECT TARGET FOLDER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, idx) {
                      final f = folders[idx];
                      final isSelected = _selectedFolderId == f.id;
                      final folderColor = _parseColor(f.color ?? '#2563eb');

                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                        leading: Icon(Icons.folder, color: folderColor, size: 22),
                        title: Text(
                          f.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                            : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
                        onTap: () {
                          setState(() {
                            _selectedFolderId = f.id;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openCreateFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: AppColors.primary),
                  label: const Text(
                    '+ Create New Folder',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedFolderId == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedFolderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm & Generate', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
