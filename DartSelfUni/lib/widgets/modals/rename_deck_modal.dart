import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';

class RenameDeckModal extends StatefulWidget {
  final String deckId;
  final String currentTitle;

  const RenameDeckModal({
    super.key,
    required this.deckId,
    required this.currentTitle,
  });

  @override
  State<RenameDeckModal> createState() => _RenameDeckModalState();
}

class _RenameDeckModalState extends State<RenameDeckModal> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rename() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) {
      context.read<DeckProvider>().renameDeck(widget.deckId, title);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Rename Deck',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Deck Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _rename(),
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
                  onPressed: _rename,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Rename'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
