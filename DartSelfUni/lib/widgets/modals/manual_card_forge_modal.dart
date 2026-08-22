import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../common/code_editor_widget.dart';

class ManualCardForgeModal extends StatefulWidget {
  final Function(Flashcard, String) onForge;
  final List<Deck> decks;

  const ManualCardForgeModal({
    super.key,
    required this.onForge,
    required this.decks,
  });

  @override
  State<ManualCardForgeModal> createState() => _ManualCardForgeModalState();
}

class _ManualCardForgeModalState extends State<ManualCardForgeModal> {
  late String _selectedDeckId;
  CardType _selectedType = CardType.concept;
  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _backController = TextEditingController();
  String _codeSnippet = '';

  @override
  void initState() {
    super.initState();
    _selectedDeckId = widget.decks.isNotEmpty ? widget.decks.first.id : '';
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  void _handleForge() {
    if (_frontController.text.trim().isEmpty) return;

    final card = Flashcard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: _selectedType,
      front: _frontController.text.trim(),
      back: _backController.text.trim(),
      codeSnippet: _codeSnippet.isNotEmpty ? _codeSnippet : null,
      nextReview: DateTime.now().millisecondsSinceEpoch,
      interval: 1,
      ease: 2.5,
      reps: 0,
    );
    widget.onForge(card, _selectedDeckId);
    Navigator.of(context).pop();
  }

  Widget _buildLabelRow(IconData icon, String label, {String? trailingText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Consolas',
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Outer Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Icon(Icons.edit_note, color: Colors.orange.shade700, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CREATE FLASHCARDS FROM THIS LECTURE',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Craft Concept, Complexity, Cloze, or Dart Code cards while studying',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.keyboard_arrow_up, color: Colors.orange.shade700, size: 18),
                      label: Text('Collapse', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange.shade200),
                        backgroundColor: Colors.orange.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              
              // Inner Card
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Inner Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Icon(Icons.edit_note, color: Colors.orange.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'MANUAL DART CARD FORGE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                '9 Note Types',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Craft custom Dart algorithm flashcards across 9 note archetypes with syntax highlighting, clozes, and code snippets.',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),

                        // TARGET DECK
                        _buildLabelRow(Icons.layers_outlined, 'TARGET DECK'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDeckId.isNotEmpty ? _selectedDeckId : null,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                              items: widget.decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title, style: const TextStyle(fontSize: 14)))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDeckId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // NOTE TYPE
                        _buildLabelRow(Icons.local_offer_outlined, 'NOTE TYPE (CARD ARCHETYPE)'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CardType>(
                              value: _selectedType,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                              items: CardType.values.map((t) {
                                final config = ArchetypeConfig.configs[t]!;
                                return DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(config.icon, size: 16, color: config.color),
                                      const SizedBox(width: 8),
                                      Text('${config.label} ("${config.description.split(" ").first}")', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade50.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.yellow.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.help_outline, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Understand the core algorithmic concept and mechanics in Dart.',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // FRONT
                        _buildLabelRow(Icons.question_answer_outlined, 'FRONT (PROMPT / DART QUESTION)'),
                        TextField(
                          controller: _frontController,
                          maxLines: 3,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: "Why does Dart's SplayTreeMap provide O(log N) amortized operations?",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // CODE SNIPPET
                        _buildLabelRow(Icons.code, 'FRONT DART CODE SNIPPET (OPTIONAL)', trailingText: 'Dart 3.x IDE'),
                        SizedBox(
                          height: 120,
                          child: CodeEditorWidget(
                            initialCode: _codeSnippet,
                            onChanged: (val) => _codeSnippet = val,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // BACK
                        _buildLabelRow(Icons.notes, 'BACK (DART ANSWER / SOLUTION)'),
                        TextField(
                          controller: _backController,
                          maxLines: 4,
                          minLines: 3,
                          decoration: InputDecoration(
                            hintText: "Because splay trees rotate accessed elements to the root, optimizing for temporal locality.",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // FORGE BUTTON
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD180), Color(0xFFFFAB40)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _handleForge,
                            icon: const Icon(Icons.edit_note, color: Colors.white),
                            label: Text(
                              'FORGE DART CARD (${_selectedType.name.toUpperCase()})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
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
