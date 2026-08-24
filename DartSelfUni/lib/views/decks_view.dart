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
    
    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          _buildHeader(isMobile, allAppFolders),
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
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.folder_outlined, color: Color(0xFF3B82F6), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FOLDERS & COURSES (${folders.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
                  ),
                ],
              ),
              if (folders.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _viewMode = 1),
                  child: const Text('View All Folders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (folders.isEmpty)
            _buildEmptySectionCard('No Folders Found', 'Create a new folder to organize your decks and notes.')
          else
            _buildFoldersLayout(folders, deckProvider, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),

          // Section 2: Flashcard Decks & Note-Generated Decks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.style_outlined, color: Color(0xFFF43F5E), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FLASHCARD DECKS & NOTE DECKS (${decks.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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

  Widget _buildHeader(bool isMobile, List<Folder> folders) {
    Folder? selectedFolder;
    if (_selectedFolderId != null) {
      selectedFolder = folders.where((f) => f.id == _selectedFolderId).firstOrNull;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedFolderId != null) ...[
                InkWell(
                  onTap: () => setState(() {
                    _selectedFolderId = null;
                    _viewMode = 0;
                  }),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: Color(0xFF3B82F6)),
                      SizedBox(width: 4),
                      Text('Back to Library', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ] else
                const Text('Library', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
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
                        const Icon(Icons.create_new_folder_outlined, color: Color(0xFF3B82F6), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFolder?.name ?? 'Flashcard Decks & Folders',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedFolder != null 
                          ? 'View and organize decks, notes, and PDFs inside this folder' 
                          : 'Search across all decks, flashcards, notes, PDFs and folders in your library',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                () {
                  final allDecks = context.read<DeckProvider>().decks;
                  final allCards = selectedFolder != null
                      ? allDecks.where((d) => d.folderId == selectedFolder!.id).expand((d) => d.cards).toList()
                      : (context.read<DeckProvider>().universalDeck?.cards ?? allDecks.expand((d) => d.cards).toList());
                  final dueCount = allCards.where((c) => c.isDue).length;

                  return Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => DueCardsReviewModal.show(
                          context,
                          folderId: selectedFolder?.id,
                          onReviewCompleted: () => setState(() {}),
                        ),
                        icon: const Icon(Icons.psychology, size: 18),
                        label: Text(
                          dueCount > 0 ? 'DUE REVIEW ($dueCount)' : 'DUE REVIEW',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dueCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
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
                        label: const Text('STUDY ALL CARDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (selectedFolder != null) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => FolderModal(
                                initialName: selectedFolder!.name,
                                initialColor: selectedFolder.color,
                                onSave: (name, color) {
                                  context.read<DeckProvider>().updateFolder(selectedFolder!.id, name, color: color);
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            backgroundColor: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDeleteFolder(context, selectedFolder!.id, selectedFolder.name),
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: Color(0xFFFECDD3)),
                            backgroundColor: const Color(0xFFFFF1F2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => _openNewFolderModal(context),
                          icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                          label: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B82F6),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  );
                }(),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 16),
            if (selectedFolder != null) ...[
              () {
                final Folder folder = selectedFolder!;
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
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
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          backgroundColor: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteFolder(context, folder.id, folder.name),
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          backgroundColor: const Color(0xFFFFF1F2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                );
              }(),
            ]
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openNewFolderModal(context),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                      label: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchBar(int totalDecks, int totalFolders, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 16),
      color: Colors.white,
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
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search anything: decks, cards, notes, PDFs, code, or folders...',
          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
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
        maxCrossAxisExtent: 400,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 140,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final folderDecks = deckProvider.decks.where((d) => d.folderId == folder.id).toList();
        final folderLessons = deckProvider.lessons.where((l) => l.isNote && l.folderId == folder.id).toList();
        
        int totalCards = 0;
        for (var deck in folderDecks) {
          totalCards += deck.cards.length;
        }

        final isRed = index % 3 == 0;
        final iconColor = isRed ? const Color(0xFFF43F5E) : const Color(0xFF3B82F6);
        final bgColor = isRed ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
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
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallCard = constraints.maxHeight < 125 || constraints.maxWidth < 220;
                  final double contentPadding = isSmallCard ? 10 : 20;
                  final double iconPadding = isSmallCard ? 8 : 12;
                  final double iconSize = isSmallCard ? 18 : 24;
                  final double horizontalSpacer = isSmallCard ? 8 : 16;
                  final double titleSize = isSmallCard ? 12 : 15;
                  final double subtextSize = isSmallCard ? 8 : 10;
                  final double verticalSpacer = isSmallCard ? 4 : 8;
                  final double bottomPadding = isSmallCard ? 6 : 12;
                  final double bottomFontSize = isSmallCard ? 8 : 9;

                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(contentPadding),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(iconPadding),
                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(isSmallCard ? 10 : 14)),
                                child: Icon(Icons.folder, color: iconColor, size: iconSize),
                              ),
                              SizedBox(width: horizontalSpacer),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      folder.name,
                                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), height: 1.2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (constraints.maxHeight >= 120) ...[
                                      SizedBox(height: verticalSpacer),
                                      Text(
                                        '${folderDecks.length} ${folderDecks.length == 1 ? 'deck' : 'decks'} • ${folderLessons.length} notes & docs',
                                        style: TextStyle(fontSize: subtextSize, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
                                padding: isSmallCard ? EdgeInsets.zero : const EdgeInsets.all(8),
                                constraints: isSmallCard ? const BoxConstraints(minWidth: 40) : null,
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
                                        Icon(Icons.shuffle, size: 16, color: Color(0xFF3B82F6)),
                                        SizedBox(width: 8),
                                        Text('Shuffle & Study'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Row(
                                      children: [
                                        Icon(Icons.folder_open, size: 16, color: Color(0xFF475569)),
                                        SizedBox(width: 8),
                                        Text('Open Folder'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: contentPadding * 1.2, vertical: bottomPadding),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$totalCards flashcards total'.toUpperCase(),
                              style: TextStyle(fontSize: bottomFontSize, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            Icon(Icons.arrow_forward_ios, size: isSmallCard ? 8 : 12, color: const Color(0xFF94A3B8)),
                          ],
                        ),
                      )
                    ],
                  );
                },
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
        maxCrossAxisExtent: 380,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 236,
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
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEE2E2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FLASHCARD DECK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
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
                const SizedBox(height: 12),
                Text(
                  deck.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalCards Cards • $masteryRate% Mastered • $masteredCards 🎓',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dueCards > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: dueCards > 0 ? const Color(0xFFFECACA) : const Color(0xFFDCFCE7)),
                  ),
                  child: Text(
                    dueCards > 0 ? '$dueCards due' : 'All caught up!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: dueCards > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
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
                  icon: Icon(dueCards > 0 ? Icons.play_arrow : Icons.refresh, size: 14),
                  label: Text(dueCards > 0 ? 'Study Deck' : 'Relearn Deck', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dueCards > 0 ? const Color(0xFFF43F5E) : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          // Section 1: Flashcard Decks in Folder
          Row(
            children: [
              const Icon(Icons.style_outlined, size: 18, color: Color(0xFFF43F5E)),
              const SizedBox(width: 8),
              Text(
                'FLASHCARD DECKS (${decks.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (decks.isEmpty)
            _buildEmptySectionCard('No Decks in this Folder', 'Move existing decks or generate new decks into this folder.')
          else
            _buildDecksLayout(decks, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),

          // Section 2: Notes in Folder
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                'LECTURE NOTES (${notes.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notes.isEmpty)
            _buildEmptySectionCard('No Notes in this Folder', 'Generate notes from lectures or create notes in this folder.')
          else
            _buildNotesGrid(notes, isMobile, maxWidth),

          const SizedBox(height: 36),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),

          // Section 3: PDFs in Folder
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFE11D48)),
              const SizedBox(width: 8),
              Text(
                'PDF DOCUMENTS (${pdfs.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
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
    int crossAxisCount = 1;
    if (maxWidth > 1200) {
      crossAxisCount = 3;
    } else if (maxWidth > 800) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.4,
      ),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final isPdf = lesson.pdfUrl != null || lesson.pdfFilename != null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isPdf ? Icons.picture_as_pdf : Icons.article_outlined, size: 16, color: isPdf ? const Color(0xFFE11D48) : const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        lesson.content.replaceAll(RegExp(r'#+\s*'), ''),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          const Icon(Icons.folder_open_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
