import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../providers/deck_provider.dart';

class ExportFlashcardsModal extends StatefulWidget {
  final List<Flashcard> cards;
  final String defaultDeckTitle;
  final String? defaultFolderId;

  const ExportFlashcardsModal({
    super.key,
    required this.cards,
    required this.defaultDeckTitle,
    this.defaultFolderId,
  });

  @override
  State<ExportFlashcardsModal> createState() => _ExportFlashcardsModalState();
}

class _ExportFlashcardsModalState extends State<ExportFlashcardsModal> {
  int _exportMode = 0; // 0 = New Deck, 1 = Existing Deck
  late TextEditingController _deckTitleController;
  late TextEditingController _newFolderNameController;
  String? _selectedFolderId;
  String? _selectedExistingDeckId;
  bool _createNewFolder = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _deckTitleController = TextEditingController(text: widget.defaultDeckTitle);
    _newFolderNameController = TextEditingController();
    _selectedFolderId = widget.defaultFolderId;
  }

  @override
  void dispose() {
    _deckTitleController.dispose();
    _newFolderNameController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    if (widget.cards.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final deckProvider = context.read<DeckProvider>();

      if (_exportMode == 0) {
        // Mode 0: Create New Deck
        final title = _deckTitleController.text.trim();
        if (title.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a deck title.'), backgroundColor: AppColors.error),
          );
          setState(() => _isSaving = false);
          return;
        }

        String? folderId = _selectedFolderId;
        if (_createNewFolder && _newFolderNameController.text.trim().isNotEmpty) {
          final newFolder = await deckProvider.addFolder(_newFolderNameController.text.trim());
          folderId = newFolder.id;
        }

        final newDeck = Deck(
          id: 'deck_exp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          folderId: folderId,
          cards: List.from(widget.cards),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );

        await deckProvider.addDeck(newDeck);

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully exported ${widget.cards.length} cards to new deck "${newDeck.title}"!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Mode 1: Append to Existing Deck
        if (_selectedExistingDeckId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an existing deck.'), backgroundColor: AppColors.error),
          );
          setState(() => _isSaving = false);
          return;
        }

        for (var card in widget.cards) {
          await deckProvider.addCardToDeck(_selectedExistingDeckId!, card);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${widget.cards.length} flashcards to existing deck!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;
    final decks = deckProvider.decks;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(24),
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.style, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Export Flashcards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Save ${widget.cards.length} cards to Decks & Folders section', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Destination Tabs
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Create New Deck')),
                    selected: _exportMode == 0,
                    onSelected: (selected) => setState(() => _exportMode = 0),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _exportMode == 0 ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Add to Existing Deck')),
                    selected: _exportMode == 1,
                    onSelected: (selected) => setState(() => _exportMode = 1),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _exportMode == 1 ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_exportMode == 0) ...[
              // Mode 0: Create New Deck Form
              TextField(
                controller: _deckTitleController,
                decoration: const InputDecoration(
                  labelText: 'Deck Title',
                  hintText: 'e.g. Masterclass: Dynamic Programming Deck',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Assign to Folder:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: () => setState(() => _createNewFolder = !_createNewFolder),
                    icon: Icon(_createNewFolder ? Icons.folder : Icons.create_new_folder_outlined, size: 16),
                    label: Text(_createNewFolder ? 'Select Existing' : '+ New Folder'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_createNewFolder) ...[
                TextField(
                  controller: _newFolderNameController,
                  decoration: const InputDecoration(
                    labelText: 'New Folder Name',
                    hintText: 'e.g. Algorithms & Data Structures',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder_open),
                  ),
                ),
              ] else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedFolderId,
                  decoration: const InputDecoration(
                    labelText: 'Target Folder',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('📁 Unfiled (No Folder)')),
                    ...folders.map((f) => DropdownMenuItem(value: f.id, child: Text('📁 ${f.name}'))),
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
              ],
            ] else ...[
              // Mode 1: Add to Existing Deck Dropdown
              if (decks.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No existing decks found. Please select "Create New Deck" instead.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ] else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedExistingDeckId,
                  decoration: const InputDecoration(
                    labelText: 'Select Deck',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.style_outlined),
                  ),
                  items: decks.map((d) => DropdownMenuItem(value: d.id, child: Text('🎴 ${d.title} (${d.cards.length} cards)'))).toList(),
                  onChanged: (val) => setState(() => _selectedExistingDeckId = val),
                ),
              ],
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleExport,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(_isSaving ? 'Exporting...' : 'Export ${widget.cards.length} Cards'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
