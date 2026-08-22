import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/deck_model.dart';
import '../../providers/deck_provider.dart';
import '../common/archetype_badge.dart';
import 'edit_card_modal.dart';

class DeckCardsModal extends StatelessWidget {
  final Deck deck;

  const DeckCardsModal({super.key, required this.deck});

  @override
  Widget build(BuildContext context) {
    // We use context.select to only rebuild when the specific deck's cards change
    final currentDeck = context.select<DeckProvider, Deck?>(
      (provider) => provider.decks.where((d) => d.id == deck.id).firstOrNull,
    );

    if (currentDeck == null) return const SizedBox();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cards in ${currentDeck.title}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: currentDeck.cards.isEmpty
                  ? const Center(child: Text('No cards in this deck.'))
                  : ListView.separated(
                      itemCount: currentDeck.cards.length,
                      separatorBuilder: (context, index) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final card = currentDeck.cards[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          leading: ArchetypeBadge(type: card.type, showLabel: false, size: 20),
                          title: Text(
                            card.front,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                'Due: ${DateTime.fromMillisecondsSinceEpoch(card.nextReview).toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              if (card.imageUrl != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.image, size: 14, color: AppColors.textSecondary),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => EditCardModal(deckId: deck.id, card: card),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                                onPressed: () {
                                  context.read<DeckProvider>().deleteCardFromDeck(deck.id, card.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
