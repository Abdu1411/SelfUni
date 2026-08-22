import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';

class MoveResourceModal extends StatefulWidget {
  final String resourceId;
  final bool isDeck; // true for deck, false for lesson

  const MoveResourceModal({
    super.key,
    required this.resourceId,
    required this.isDeck,
  });

  @override
  State<MoveResourceModal> createState() => _MoveResourceModalState();
}

class _MoveResourceModalState extends State<MoveResourceModal> {
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    // Pre-select current folder if any
    final provider = context.read<DeckProvider>();
    if (widget.isDeck) {
      final deck = provider.decks.where((d) => d.id == widget.resourceId).firstOrNull;
      _selectedFolderId = deck?.folderId;
    } else {
      final lesson = provider.lessons.where((l) => l.id == widget.resourceId).firstOrNull;
      _selectedFolderId = lesson?.folderId;
    }
  }

  void _move() {
    if (widget.isDeck) {
      context.read<DeckProvider>().moveDeckToFolder(widget.resourceId, _selectedFolderId);
    } else {
      context.read<DeckProvider>().moveLessonToFolder(widget.resourceId, _selectedFolderId);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<DeckProvider>().folders;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Move Resource',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String?>(
              initialValue: _selectedFolderId,
              decoration: const InputDecoration(
                labelText: 'Select Folder',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No Folder (Root)'),
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
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _move,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Move'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
