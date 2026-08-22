import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/deck_model.dart';
import 'package:provider/provider.dart';
import '../../providers/deck_provider.dart';

class CommunityView extends StatefulWidget {
  const CommunityView({super.key});

  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _sampleCommunityDecks = [
    {
      'title': 'Data Structures & Algorithms Essentials',
      'cards': [
        {'id': 'c1', 'front': 'What is the time complexity of QuickSort average case?', 'back': 'O(n log n)'},
        {'id': 'c2', 'front': 'What is a Binary Search Tree property?', 'back': 'Left node < root < right node'},
      ]
    },
    {
      'title': 'Flutter & Dart Mastery',
      'cards': [
        {'id': 'c3', 'front': 'What is StatelessWidget vs StatefulWidget?', 'back': 'Stateless is immutable; Stateful maintains mutable state.'},
        {'id': 'c4', 'front': 'What does setState() do?', 'back': 'Notifies the framework that the internal state has changed.'},
      ]
    },
    {
      'title': 'System Design Fundamentals',
      'cards': [
        {'id': 'c5', 'front': 'What is Load Balancing?', 'back': 'Distributing network traffic across multiple servers.'},
      ]
    }
  ];

  Future<void> _downloadDeck(Map<String, dynamic> deckData) async {
    setState(() => _isLoading = true);
    try {
      final String newDeckId = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> localDeckData = Map<String, dynamic>.from(deckData);
      localDeckData['id'] = newDeckId;
      
      final deck = Deck.fromJson(localDeckData);
      final deckProvider = context.read<DeckProvider>();
      await deckProvider.addDeck(deck);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck downloaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download deck: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Community Hub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Discover and download decks curated by other learners.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              itemCount: _sampleCommunityDecks.length,
              itemBuilder: (context, index) {
                final deckData = _sampleCommunityDecks[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deckData['title'] ?? 'Untitled', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(deckData['cards'] as List?)?.length ?? 0} Cards', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ElevatedButton.icon(
                              onPressed: () => _downloadDeck(deckData),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.background,
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
