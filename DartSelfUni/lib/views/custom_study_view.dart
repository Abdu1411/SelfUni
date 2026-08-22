import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../providers/deck_provider.dart';
import 'study_session_view.dart';

class CustomStudyView extends StatefulWidget {
  const CustomStudyView({super.key});

  @override
  State<CustomStudyView> createState() => _CustomStudyViewState();
}

class _CustomStudyViewState extends State<CustomStudyView> {
  String? _selectedDeckId;
  CardType? _selectedType;
  bool _ignoreSchedule = true;

  void _startCustomStudy() {
    final provider = context.read<DeckProvider>();
    List<Flashcard> customSessionCards = [];

    if (_selectedDeckId != null) {
      final deck = provider.decks.where((d) => d.id == _selectedDeckId).firstOrNull;
      if (deck != null) {
        customSessionCards.addAll(deck.cards);
      }
    } else {
      // All decks
      for (var d in provider.decks) {
        customSessionCards.addAll(d.cards);
      }
    }

    if (_selectedType != null) {
      customSessionCards = customSessionCards.where((c) => c.type == _selectedType).toList();
    }

    if (!_ignoreSchedule) {
      final now = DateTime.now().millisecondsSinceEpoch;
      customSessionCards = customSessionCards.where((c) => c.nextReview <= now).toList();
    }

    if (customSessionCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards match your custom criteria.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudySessionView(
          deckId: _selectedDeckId ?? 'custom',
          customSessionCards: customSessionCards,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = context.watch<DeckProvider>().decks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Custom Study', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure Custom Session',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Study outside of your normal spaced-repetition schedule by filtering exactly what you want to learn right now.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              
              // Deck Selector
              const Text('Target Deck', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _selectedDeckId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Decks')),
                  ...decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))),
                ],
                onChanged: (val) => setState(() => _selectedDeckId = val),
              ),
              const SizedBox(height: 24),
              
              // Archetype Selector
              const Text('Filter by Archetype', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<CardType?>(
                initialValue: _selectedType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  ...CardType.values.map((t) {
                    final config = ArchetypeConfig.configs[t]!;
                    return DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(config.icon, size: 16),
                          const SizedBox(width: 8),
                          Text(config.label),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedType = val),
              ),
              const SizedBox(height: 24),
              
              // Schedule Toggle
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ignore Schedule', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  subtitle: const Text('Study cards even if they are not due yet.'),
                  activeThumbColor: AppColors.primary,
                  value: _ignoreSchedule,
                  onChanged: (val) => setState(() => _ignoreSchedule = val),
                ),
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startCustomStudy,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START CUSTOM SESSION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
