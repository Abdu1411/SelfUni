import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/deck_provider.dart';
import '../../models/card_model.dart';
import '../widgets/modals/due_notes_review_modal.dart';
import '../widgets/modals/due_cards_review_modal.dart';
import 'study_session_view.dart';
import '../widgets/charts/dashboard_charts.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onNavigateToDecks;
  final VoidCallback onNavigateToLessons;
  final VoidCallback onNavigateToSynthesizer;

  const DashboardView({
    super.key,
    required this.onNavigateToDecks,
    required this.onNavigateToLessons,
    required this.onNavigateToSynthesizer,
  });

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final stats = deckProvider.getStats();
    
    final decksCount = deckProvider.decks.length;
    final totalCards = deckProvider.decks.fold<int>(0, (sum, deck) => sum + deck.cards.length);
    final reviewsDue = deckProvider.decks.fold<int>(0, (sum, deck) {
      return sum + deck.cards.where((c) => c.isDue).length;
    });

    final allUniversalCards = deckProvider.universalDeck?.cards ?? [];
    final dueUniversalCards = allUniversalCards.where((c) => c.isDue).toList();
    final dueUniversalCount = dueUniversalCards.length;
    final masteredUniversalCount = allUniversalCards.where((c) => c.isGraduated).length;

    void startUniversalStudy() {
      final univDeck = deckProvider.universalDeck;
      if (univDeck == null || univDeck.cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cards in your Universal Deck yet. Synthesize cards from your lessons to start studying!'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }

      DueCardsReviewModal.show(context);
    }
    
    final lessonsCount = deckProvider.lessons.where((l) => l.isNote).length;
    final foldersCount = deckProvider.folders.length;

    final isMobile = MediaQuery.of(context).size.width < 1000;
        
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar
          Row(
            children: [
              const Text(
                'Study Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Color(0xFF94A3B8)),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF38BDF8), size: 20),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Mesh Gradient Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF818CF8), Color(0xFFA78BFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  reviewsDue.toString(),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cards Due for Review',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: startUniversalStudy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Start Session',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.4), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.4), shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 3 Stat KPI Cards
          Row(
            children: [
              Expanded(child: _buildDarkKpiCard('Cards:', totalCards.toString(), 'Total')),
              const SizedBox(width: 12),
              Expanded(child: _buildDarkKpiCard('Due Today:', reviewsDue.toString(), '')),
              const SizedBox(width: 12),
              Expanded(child: _buildDarkKpiCard('Retention:', '92%', 'Avg')),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts Row
          if (isMobile)
            Column(
              children: [
                WeeklyVelocityChart(activityData: stats.activityData),
                const SizedBox(height: 16),
                MasteryChart(masteryData: stats.masteryData),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: WeeklyVelocityChart(activityData: stats.activityData)),
                const SizedBox(width: 20),
                Expanded(child: MasteryChart(masteryData: stats.masteryData)),
              ],
            ),
          
          const SizedBox(height: 32),
          
          // Archetype Grid Section (Universal Deck)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF162238),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2A3B5C)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '🎯 Study by Note Archetype',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: startUniversalStudy,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x3338BDF8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x6638BDF8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              dueUniversalCount > 0
                                  ? 'Study Universal Deck ($dueUniversalCount Due • $totalCards Cards)'
                                  : 'Study Universal Deck ($masteredUniversalCount 🎓 Mastered • $totalCards Cards)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Target specific cognitive skills across all cards: time complexity proofs, Cloze blanks, or algorithm tracing.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                _buildArchetypeGrid(context: context, deckProvider: deckProvider, isMobile: isMobile),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Recent Activity Section
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecentDecksSection(deckProvider),
                const SizedBox(height: 32),
                _buildRecentNotesSection(context, deckProvider),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentDecksSection(deckProvider)),
                const SizedBox(width: 24),
                Expanded(child: _buildRecentNotesSection(context, deckProvider)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDarkKpiCard(String label, String value, String suffix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF162238),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3B5C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  suffix,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader({
    required int reviewsDue,
    required int totalDecks,
    required int totalCards,
    required int totalNotes,
    required int totalFolders,
    required VoidCallback onStartReview,
    required VoidCallback onCreate,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'SM-2 Spaced Repetition Engine',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isMobile) ...[
            Text(
              'You have $reviewsDue cards due for review today',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'Review these cards to reinforce your memory and maintain long-term algorithm mastery.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: reviewsDue > 0 ? onStartReview : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text('START REVIEW ($reviewsDue)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('CREATION STUDIO'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $reviewsDue cards due for review today',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Review these cards to reinforce your memory and maintain long-term algorithm mastery.',
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: reviewsDue > 0 ? onStartReview : null,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text('START REVIEW ($reviewsDue)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('CREATION STUDIO', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroStat('TOTAL DECKS', totalDecks.toString()),
              _buildHeroStat('TOTAL FLASHCARDS', totalCards.toString()),
              _buildHeroStat('LECTURE NOTES', totalNotes.toString()),
              _buildHeroStat('FOLDERS ORGANIZED', totalFolders.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF64748B)),
          label: Text(actionLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticCard(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Widget child,
  }) {
    return Container(
      height: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: const Color(0xFF64748B), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text(badgeText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildArchetypeGrid({
    required BuildContext context,
    required DeckProvider deckProvider,
    required bool isMobile,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Universal Deck: master persistent list
    final allUniversalCards = deckProvider.universalDeck?.cards ?? [];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 2.5 : 1.75,
      ),
      itemCount: CardType.values.length,
      itemBuilder: (context, index) {
        final type = CardType.values[index];
        final config = ArchetypeConfig.configs[type]!;
        
        final matchingCards = allUniversalCards.where((c) => c.type == type).toList();
        final dueCards = matchingCards.where((c) => c.nextReview <= now).toList();
        final totalCount = matchingCards.length;
        final dueCount = dueCards.length;

        void startStudy() {
          if (totalCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No ${config.label} cards in your Universal Deck yet. Synthesize cards in AI Generate to practice this archetype.'),
                backgroundColor: AppColors.primary,
              ),
            );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudySessionView(
                deckId: 'universal',
                title: '${config.label} Cards (${dueCount > 0 ? '$dueCount Due' : '$totalCount Cards'})',
                customSessionCards: dueCount > 0 ? dueCards : matchingCards,
                isRelearning: dueCount == 0,
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: startStudy,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: config.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: config.borderColor),
                        ),
                        child: Icon(config.icon, size: 18, color: config.color),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: dueCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: dueCount > 0 ? const Color(0xFFFECACA) : const Color(0xFFDCFCE7)),
                        ),
                        child: Text(
                          dueCount > 0 ? '$dueCount due' : 'All caught up',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: dueCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            config.label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: config.backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type.stringValue.toUpperCase(),
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: config.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalCount ${totalCount == 1 ? 'card' : 'cards'} in Universal Deck',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: startStudy,
                      icon: Icon(dueCount > 0 ? Icons.play_arrow : Icons.refresh, size: 14),
                      label: Text(
                        totalCount == 0
                            ? 'No Cards (0)'
                            : dueCount > 0
                                ? 'Study Due ($dueCount)'
                                : 'Relearn All ($totalCount)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: totalCount == 0
                            ? const Color(0xFFF1F5F9)
                            : dueCount > 0
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFF3B82F6),
                        foregroundColor: totalCount == 0 ? const Color(0xFF94A3B8) : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentDecksSection(DeckProvider deckProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.layers, size: 18, color: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                Text('RECENT FLASHCARD DECKS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ],
            ),
            TextButton(
              onPressed: onNavigateToDecks,
              child: const Row(
                children: [
                  Text('View All (3)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...deckProvider.decks.take(3).map((deck) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final dueCount = deck.cards.where((c) => c.nextReview <= now).length;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF162238),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3B5C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder, size: 10, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('Mathematics for Computer Science', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text('$dueCount due', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(deck.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onNavigateToDecks,
                        icon: const Icon(Icons.play_arrow, size: 14),
                        label: const Text('Study Due', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0x3338BDF8),
                          foregroundColor: const Color(0xFF38BDF8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const Icon(Icons.tune, size: 16, color: Color(0xFF64748B)),
                  ],
                )
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentNotesSection(BuildContext context, DeckProvider deckProvider) {
    final DateFormat formatter = DateFormat('MMM dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book, size: 18, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('RECENT CS NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              ],
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => DueNotesReviewModal.show(context),
                  icon: const Icon(Icons.psychology, size: 14),
                  label: const Text('Due Notes Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0x33F43F5E),
                    foregroundColor: const Color(0xFFF43F5E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onNavigateToLessons,
                  child: Row(
                    children: [
                      Text('All (${deckProvider.lessons.where((l) => l.isNote).length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...deckProvider.lessons.where((l) => l.isNote).take(3).map((lesson) {
          final dateStr = formatter.format(DateTime.fromMillisecondsSinceEpoch(lesson.createdAt));
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF162238),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3B5C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x3310B981),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x6610B981)),
                        ),
                        child: Text(
                          lesson.title.replaceAll(' ', '-').toLowerCase(),
                          style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lesson.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.content.length > 80 ? '${lesson.content.substring(0, 80)}...' : lesson.content,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
