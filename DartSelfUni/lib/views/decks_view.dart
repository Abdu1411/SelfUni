import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';
import '../../models/deck_model.dart';
import '../../models/folder_model.dart';
import '../../models/card_model.dart';
import '../../models/lesson_model.dart';
import '../widgets/modals/rename_deck_modal.dart';
import '../widgets/modals/move_resource_modal.dart';
import '../widgets/modals/deck_cards_modal.dart';
import '../widgets/modals/folder_modal.dart';
import '../widgets/modals/due_cards_review_modal.dart';
import 'study_session_view.dart';
import 'pdf_viewer_view.dart';
import 'lesson_detail_view.dart';

class DecksView extends StatefulWidget {
  const DecksView({super.key});

  @override
  State<DecksView> createState() => _DecksViewState();
}

class _DecksViewState extends State<DecksView> {
  int _viewMode = 0; // 0: Divided Sections (All), 1: Folders Only, 2: Decks Only
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFolderId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNewFolderModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FolderModal(
        onSave: (name, color) {
          context.read<DeckProvider>().addFolder(name, color: color);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;
    final decks = deckProvider.decks;
    final courses = deckProvider.courses;
    
    // Ensure all app folders (including any course folders) are represented in the list
    final List<Folder> allAppFolders = List<Folder>.from(folders);
    for (var c in courses) {
      if (!allAppFolders.any((f) => f.name.toLowerCase() == c.title.toLowerCase() || f.id == c.id)) {
        allAppFolders.add(Folder(id: c.id, name: c.title, color: '#3B82F6'));
      }
    }

    // Filtering and ascending sorting
    final filteredFolders = allAppFolders.where((f) => _searchQuery.isEmpty || f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filteredDecks = decks.where((d) => 
        (_searchQuery.isEmpty || d.title.toLowerCase().contains(_searchQuery.toLowerCase())) &&
        (_selectedFolderId == null || d.folderId == _selectedFolderId)
    ).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    
    final filteredLessons = deckProvider.lessons.where((l) => 
        l.isNote &&
        (_searchQuery.isEmpty || l.title.toLowerCase().contains(_searchQuery.toLowerCase()) || l.topic.toLowerCase().contains(_searchQuery.toLowerCase())) &&
        (_selectedFolderId == null ? false : l.folderId == _selectedFolderId)
    ).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final folderNotes = filteredLessons.where((l) => l.pdfUrl == null || l.pdfUrl!.isEmpty).toList();
    final folderPdfs = filteredLessons.where((l) => l.pdfUrl != null && l.pdfUrl!.isNotEmpty).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    
    Folder? selectedFolder;
    if (_selectedFolderId != null) {
      selectedFolder = allAppFolders.where((f) => f.id == _selectedFolderId).firstOrNull;
    }

    return Container(
      color: const Color(0xFF0B132B),
      child: Column(
        children: [
          _buildHeader(selectedFolder, isMobile),
          const Divider(height: 1, color: AppColors.border),
          _buildSearchBar(decks.length, allAppFolders.length, isMobile),
          const Divider(height: 1, color: AppColors.border),
          
          Expanded(
            child: _selectedFolderId != null
                ? _buildFolderThreeColumnsView(
                    decks: filteredDecks,
                    notes: folderNotes,
                    pdfs: folderPdfs,
                    isMobile: isMobile,
                    maxWidth: screenWidth,
                  )
                : _buildMainViewBody(filteredFolders, filteredDecks, deckProvider, isMobile, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildMainViewBody(List<Folder> folders, List<Deck> decks, DeckProvider deckProvider, bool isMobile, double maxWidth) {
    if (_viewMode == 1) {
      // Folders Only
      return _buildFoldersGrid(folders, deckProvider, isMobile, maxWidth);
    } else if (_viewMode == 2) {
      // Decks Only
      return _buildAllDecksGrid(decks, isMobile, maxWidth);
    }

    // ViewMode 0: Divided Sections (Section 1: Folders, Section 2: Decks)
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Folders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0x223B82F6), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.folder_outlined, color: Color(0xFF3B82F6), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FOLDERS & COURSES (${folders.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                ],
              ),
              if (folders.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _viewMode = 1),
                  child: const Text('View All Folders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (folders.isEmpty)
            _buildEmptySectionCard('No Folders Found', 'Create a new folder to organize your decks and notes.')
          else
            _buildFoldersLayout(folders, deckProvider, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 24),

          // Section 2: Flashcard Decks & Note-Generated Decks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0x22F43F5E), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.style_outlined, color: Color(0xFFF43F5E), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FLASHCARD DECKS & NOTE DECKS (${decks.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                ],
              ),
              if (decks.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _viewMode = 2),
                  child: const Text('View All Decks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E))),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (decks.isEmpty)
            _buildEmptySectionCard('No Decks Found', 'Generate flashcards from notes, PDFs, or AI Generate.')
          else
            _buildDecksLayout(decks, isMobile, maxWidth),
        ],
      ),
    );
  }

  Widget _buildEmptySectionCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3B5C)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, String folderId, String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text('Are you sure you want to delete "$folderName"?\n\nDecks and notes inside will remain safe in your library (unfiled).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<DeckProvider>().deleteFolder(folderId);
              setState(() {
                _selectedFolderId = null;
                _viewMode = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Folder "$folderName" deleted successfully.'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete Folder'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDeckProgress(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Color(0xFF3B82F6), size: 24),
            SizedBox(width: 8),
            Text('Reset Review Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text('Are you sure you want to reset review progress for "${deck.title}"?\n\nAll ${deck.cards.length} cards will be scheduled as new due cards immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<DeckProvider>().resetDeckProgress(deck.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reset review progress for "${deck.title}".'), backgroundColor: AppColors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Reset Progress'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Folder? selectedFolder, bool isMobile) {
    final allDecks = context.read<DeckProvider>().decks;
    final allCards = selectedFolder != null
        ? allDecks.where((d) => d.folderId == selectedFolder.id).expand((d) => d.cards).toList()
        : (context.read<DeckProvider>().universalDeck?.cards ?? allDecks.expand((d) => d.cards).toList());
    final dueCount = allCards.where((c) => c.isDue).length;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 16 : 28, isMobile ? 16 : 32, 16),
      color: const Color(0xFF0B132B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Red Due Review Pill Button
                  ElevatedButton.icon(
                    onPressed: () => DueCardsReviewModal.show(
                      context,
                      folderId: selectedFolder?.id,
                      onReviewCompleted: () => setState(() {}),
                    ),
                    icon: const Icon(Icons.access_time_filled, size: 16),
                    label: Text(
                      dueCount > 0 ? 'DUE REVIEW ($dueCount)' : 'DUE REVIEW',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => DueCardsReviewModal.show(
                      context,
                      folderId: selectedFolder?.id,
                      onReviewCompleted: () => setState(() {}),
                    ),
                    icon: const Icon(Icons.style, size: 16),
                    label: const Text(
                      'STUDY ALL CARDS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0x6638BDF8)),
                      backgroundColor: const Color(0x3338BDF8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),

              // Title
              Text(
                selectedFolder?.name ?? 'Library',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
              ),

              // New Folder Pill Button
              ElevatedButton.icon(
                onPressed: () => _openNewFolderModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'New Folder',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                  shadowColor: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int totalDecks, int totalFolders, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
      color: const Color(0xFF0B132B),
      child: isMobile
          ? Column(
              children: [
                _buildSearchInput(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_selectedFolderId == null) _buildSegmentedControl(totalDecks, totalFolders) else const SizedBox(),
                  ],
                )
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchInput()),
                const SizedBox(width: 24),
                if (_selectedFolderId == null) ...[
                  _buildSegmentedControl(totalDecks, totalFolders),
                ],
              ],
            ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3B5C)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search decks, folders, notes...',
          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(int totalDecks, int totalFolders) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton(0, 'Divided Sections', Icons.view_agenda_outlined),
          _buildSegmentButton(1, 'Folders ($totalFolders)', Icons.folder_outlined),
          _buildSegmentButton(2, 'Decks ($totalDecks)', Icons.style_outlined),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersGrid(List<Folder> folders, DeckProvider deckProvider, bool isMobile, double maxWidth) {
    if (folders.isEmpty) return _buildEmptyState('No Folders Added', 'Create a new folder to organize your decks.');

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      child: _buildFolderGrid(folders, maxWidth, deckProvider),
    );
  }

  Widget _buildFolderGrid(List<Folder> folders, double maxWidth, DeckProvider deckProvider) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 85,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final folderDecks = deckProvider.decks.where((d) => d.folderId == folder.id).toList();
        final totalCards = folderDecks.fold<int>(0, (sum, d) => sum + d.cards.length);
        
        final colorHex = (folder.color ?? '#3B82F6').replaceAll('#', '');
        final baseColor = Color(int.parse('FF$colorHex', radix: 16));

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF162238),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A3B5C)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFolderId = folder.id;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: baseColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.folder, color: baseColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            folder.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${folderDecks.length} decks • $totalCards cards',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      onSelected: (val) {
                        if (val == 'shuffle') {
                          final allCards = folderDecks.expand((d) => d.cards).toList();
                          if (allCards.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No flashcards found in folder "${folder.name}".')),
                            );
                            return;
                          }
                          final shuffledCards = List<Flashcard>.from(allCards)..shuffle();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudySessionView(
                                customSessionCards: shuffledCards,
                                title: 'Shuffled - ${folder.name}',
                                deckId: folder.id,
                              ),
                            ),
                          );
                        } else if (val == 'open') {
                          setState(() => _selectedFolderId = folder.id);
                        } else if (val == 'rename') {
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
                        } else if (val == 'delete') {
                          _confirmDeleteFolder(context, folder.id, folder.name);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'shuffle',
                          child: Row(
                            children: [
                              Icon(Icons.shuffle, size: 16, color: Color(0xFF38BDF8)),
                              SizedBox(width: 8),
                              Text('Shuffle & Study'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.folder_open, size: 16, color: Color(0xFFCBD5E1)),
                              SizedBox(width: 8),
                              Text('Open Folder'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: Color(0xFFCBD5E1)),
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

  Widget _buildFoldersLayout(List<Folder> folders, DeckProvider deckProvider, bool isMobile, double maxWidth) {
    return _buildFolderGrid(folders, maxWidth, deckProvider);
  }

  Widget _buildAllDecksGrid(List<Deck> decks, bool isMobile, double maxWidth) {
    if (decks.isEmpty) return _buildEmptyState('No Decks Found', 'Generate flashcard decks from notes or create them in AI Generate.');

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      child: _buildDecksLayout(decks, isMobile, maxWidth),
    );
  }

  Widget _buildDecksLayout(List<Deck> decks, bool isMobile, double maxWidth) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 135,
      ),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        return _buildDeckCard(context, decks[index], isMobile);
      },
    );
  }

  Widget _buildDeckCard(BuildContext context, Deck deck, bool isMobile) {
    final dueCards = deck.dueCardsCount;
    final totalCards = deck.totalCardsCount;
    final masteredCards = deck.masteredCardsCount;
    final masteryRate = deck.masteryRate;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3B5C)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x4438BDF8)),
                      ),
                      child: const Text(
                        'DECK',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      onSelected: (val) {
                        if (val == 'shuffle') {
                          if (deck.cards.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deck "${deck.title}" has no flashcards.')),
                            );
                            return;
                          }
                          final shuffledCards = List<Flashcard>.from(deck.cards)..shuffle();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudySessionView(
                                deck: deck,
                                customSessionCards: shuffledCards,
                                title: 'Shuffled - ${deck.title}',
                              ),
                            ),
                          );
                        } else if (val == 'relearn') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudySessionView(deck: deck, isRelearning: true),
                            ),
                          );
                        } else if (val == 'reset_progress') {
                          _confirmResetDeckProgress(context, deck);
                        } else if (val == 'view_cards') {
                          showDialog(context: context, builder: (context) => DeckCardsModal(deck: deck));
                        } else if (val == 'rename') {
                          showDialog(context: context, builder: (context) => RenameDeckModal(deckId: deck.id, currentTitle: deck.title));
                        } else if (val == 'move') {
                          showDialog(context: context, builder: (context) => MoveResourceModal(resourceId: deck.id, isDeck: true));
                        } else if (val == 'delete') {
                          context.read<DeckProvider>().deleteDeck(deck.id);
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
                          value: 'relearn',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('Relearn Deck (All Cards)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'reset_progress',
                          child: Row(
                            children: [
                              Icon(Icons.restart_alt, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('Reset Review Progress'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'view_cards',
                          child: Row(
                            children: [
                              Icon(Icons.style_outlined, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('View Flashcards'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('Rename Deck'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move_outlined, size: 16, color: Color(0xFF475569)),
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
                              Text('Delete Deck', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  deck.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalCards Cards • $masteryRate% ($masteredCards 🎓)',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dueCards > 0 ? const Color(0x33F43F5E) : const Color(0x3310B981),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: dueCards > 0 ? const Color(0x66F43F5E) : const Color(0x6610B981)),
                  ),
                  child: Text(
                    dueCards > 0 ? '$dueCards due' : 'Caught up',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: dueCards > 0 ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudySessionView(
                          deck: deck,
                          isRelearning: dueCards == 0,
                        ),
                      ),
                    );
                  },
                  icon: Icon(dueCards > 0 ? Icons.play_arrow : Icons.refresh, size: 12),
                  label: Text(dueCards > 0 ? 'Study' : 'Relearn', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dueCards > 0 ? const Color(0xFFF43F5E) : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderThreeColumnsView({
    required List<Deck> decks,
    required List<Lesson> notes,
    required List<Lesson> pdfs,
    required bool isMobile,
    required double maxWidth,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style_outlined, size: 18, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                'FLASHCARD DECKS (${decks.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (decks.isEmpty)
            _buildEmptySectionCard('No Decks in this Folder', 'Create or move flashcard decks here.')
          else
            _buildDecksLayout(decks, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                'LECTURE NOTES (${notes.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notes.isEmpty)
            _buildEmptySectionCard('No Lecture Notes in this Folder', 'Write or import markdown notes here.')
          else
            _buildNotesGrid(notes, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFF43F5E)),
              const SizedBox(width: 8),
              Text(
                'PDF DOCUMENTS (${pdfs.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pdfs.isEmpty)
            _buildEmptySectionCard('No PDFs in this Folder', 'Import PDF files to associate them with this folder.')
          else
            _buildNotesGrid(pdfs, isMobile, maxWidth),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(List<Lesson> lessons, bool isMobile, double maxWidth) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 85,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final isPdf = lesson.pdfUrl != null || lesson.pdfFilename != null;

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
              onTap: () {
                if (isPdf) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfViewerView(lesson: lesson, onNavigateBack: () => Navigator.of(context).maybePop()),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonDetailView(lesson: lesson, onNavigateBack: () => Navigator.of(context).maybePop()),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(isPdf ? Icons.picture_as_pdf : Icons.article_outlined, size: 14, color: isPdf ? const Color(0xFFF43F5E) : const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.content.replaceAll(RegExp(r'#+\s*'), ''),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_outlined, size: 64, color: Color(0xFF64748B)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
