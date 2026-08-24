import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../models/folder_model.dart';
import '../../providers/deck_provider.dart';
import '../../views/study_session_view.dart';
import '../common/archetype_badge.dart';

class DueCardsReviewModal extends StatefulWidget {
  final String? folderId;
  final VoidCallback? onReviewCompleted;

  const DueCardsReviewModal({
    super.key,
    this.folderId,
    this.onReviewCompleted,
  });

  /// Static helper to display the Due Cards Review Modal
  static Future<void> show(
    BuildContext context, {
    String? folderId,
    VoidCallback? onReviewCompleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DueCardsReviewModal(
        folderId: folderId,
        onReviewCompleted: onReviewCompleted,
      ),
    );
  }

  @override
  State<DueCardsReviewModal> createState() => _DueCardsReviewModalState();
}

class _DueCardsReviewModalState extends State<DueCardsReviewModal> {
  int _tabIndex = 0; // 0 = Due (<60% / SRS Due), 1 = Mastered Cards (Graduated), 2 = All Cards
  String _searchQuery = '';
  CardType? _selectedArchetype;

  void _startStudySession(List<Flashcard> cards, String title) {
    if (cards.isEmpty) return;
    // Snapshot the queue so modifying SRS state doesn't mutate iteration
    final snapshot = List<Flashcard>.from(cards);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudySessionView(
          customSessionCards: snapshot,
          title: title,
          onComplete: () {
            Navigator.of(context).pop();
            setState(() {});
            widget.onReviewCompleted?.call();
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
        widget.onReviewCompleted?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;

    // Retrieve all active cards, optionally filtered by folderId
    List<Flashcard> allCards;
    if (widget.folderId != null) {
      final folderDecks = deckProvider.decks.where((d) => d.folderId == widget.folderId).toList();
      allCards = folderDecks.expand((d) => d.cards).toList();
    } else {
      allCards = deckProvider.decks.expand((d) => d.cards).toList();
      if (allCards.isEmpty && deckProvider.universalDeck != null) {
        allCards = deckProvider.universalDeck!.cards;
      }
    }

    final dueCards = allCards.where((c) => c.isDue).toList();
    final masteredCards = allCards.where((c) => c.isGraduated || c.masteryScore >= 90).toList();

    // Filter by search & archetype
    List<Flashcard> displayedList;
    if (_tabIndex == 0) {
      displayedList = dueCards;
    } else if (_tabIndex == 1) {
      displayedList = masteredCards;
    } else {
      displayedList = allCards;
    }

    if (_searchQuery.isNotEmpty) {
      displayedList = displayedList.where((c) =>
          c.front.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.back.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.type.stringValue.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    if (_selectedArchetype != null) {
      displayedList = displayedList.where((c) => c.type == _selectedArchetype).toList();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? screenWidth : 920,
        height: isMobile ? screenHeight * 0.92 : 780,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context, dueCards.length, masteredCards.length, allCards.length),

            // Top Stats & Quick Action Bar
            _buildActionBar(dueCards, masteredCards, allCards),

            // Search and Archetype Filter
            _buildSearchAndFilters(),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Main Content Area
            Expanded(
              child: displayedList.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: displayedList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final card = displayedList[index];
                        return _buildCardItem(card, folders, deckProvider.decks);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int dueCount, int masteredCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.style_outlined, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Flashcards Mastery & Due Review',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: dueCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: dueCount > 0 ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Text(
                        '$dueCount Due',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: dueCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Spaced repetition queue with consecutive graduation and decay immunity.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(List<Flashcard> dueCards, List<Flashcard> masteredCards, List<Flashcard> allCards) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton(0, 'Due Cards (${dueCards.length})', Icons.alarm, dueCards.isNotEmpty ? const Color(0xFFE11D48) : const Color(0xFF059669)),
              const SizedBox(width: 8),
              _buildTabButton(1, '🎓 Mastered (${masteredCards.length})', Icons.workspace_premium, const Color(0xFFD97706)),
              const SizedBox(width: 8),
              _buildTabButton(2, 'All Cards (${allCards.length})', Icons.style, const Color(0xFF2563EB)),
            ],
          ),

          // Primary Action Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_tabIndex == 0 && dueCards.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _startStudySession(dueCards, 'Due Cards Review (${dueCards.length})'),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text('Review All Due (${dueCards.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                )
              else if (_tabIndex == 1 && masteredCards.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _startStudySession(masteredCards, '🎓 Mastered Cards Review (${masteredCards.length})'),
                  icon: const Icon(Icons.workspace_premium, size: 16),
                  label: Text('Study Mastered (${masteredCards.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                )
              else if (allCards.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _startStudySession(allCards, 'Study All Cards (${allCards.length})'),
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: Text('Study All Cards (${allCards.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, Color activeColor) {
    final isSelected = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search front, back, or card archetype...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButton<CardType?>(
                value: _selectedArchetype,
                hint: const Text('All Types', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                items: [
                  const DropdownMenuItem<CardType?>(
                    value: null,
                    child: Text('All Archetypes', style: TextStyle(fontSize: 12)),
                  ),
                  ...CardType.values.map(
                    (t) => DropdownMenuItem<CardType?>(
                      value: t,
                      child: Text(t.stringValue, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedArchetype = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Flashcard card, List<Folder> folders, List<Deck> decks) {
    final isDue = card.isDue;
    final isGraduated = card.isGraduated;
    final mastery = card.masteryScore;

    Deck? parentDeck;
    if (card.deckId != null) {
      parentDeck = decks.where((d) => d.id == card.deckId).firstOrNull;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGraduated
              ? const Color(0xFFFDE68A)
              : (isDue ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
          width: (isDue || isGraduated) ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArchetypeBadge(type: card.type),
              const SizedBox(width: 8),
              if (isGraduated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎓', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 4),
                      Text(
                        'IMMUNE TO DECAY',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isDue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFE4E6)),
                  ),
                  child: const Text(
                    'DUE FOR REVIEW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE11D48),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const Spacer(),
              // Mastery Score Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isGraduated
                      ? const Color(0xFFFEF3C7)
                      : (mastery >= 60 ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isGraduated
                        ? const Color(0xFFF59E0B)
                        : (mastery >= 60 ? const Color(0xFFA7F3D0) : const Color(0xFFFFE4E6)),
                  ),
                ),
                child: Text(
                  isGraduated ? 'Mastered 100%' : '$mastery%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isGraduated
                        ? const Color(0xFF065F46)
                        : (mastery >= 60 ? const Color(0xFF059669) : const Color(0xFFE11D48)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Front Text
          Text(
            card.front,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // Back Preview
          Text(
            card.back,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Bottom Stats & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (parentDeck != null)
                    Text(
                      parentDeck.title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                    ),
                  Text(
                    'Interval: ${card.interval}d • Ease: ${card.ease.toStringAsFixed(1)} • Reps: ${card.reps}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  if (card.consecutiveCorrect > 0)
                    Text(
                      '• ${card.consecutiveCorrect}x streak',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _startStudySession([card], 'Study Card: ${card.front.length > 25 ? "${card.front.substring(0, 25)}..." : card.front}'),
                icon: Icon(isDue ? Icons.play_arrow : Icons.refresh, size: 13),
                label: Text(isDue ? 'Study Card' : 'Relearn', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDue ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _tabIndex == 0 ? Icons.check_circle_outline : Icons.style_outlined,
            size: 48,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            _tabIndex == 0
                ? 'All caught up on flashcards!'
                : (_tabIndex == 1 ? 'No graduated cards yet.' : 'No flashcards found.'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            _tabIndex == 0
                ? 'Great job! Cards with 2 consecutive correct answers graduate to Mastered.'
                : (_tabIndex == 1
                    ? 'Score good/easy consecutively during study sessions to graduate cards to Mastered!'
                    : 'Synthesize or add flashcards to start practicing.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
