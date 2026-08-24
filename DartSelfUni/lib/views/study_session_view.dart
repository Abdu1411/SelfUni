import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/ai_service.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../providers/deck_provider.dart';
import '../../core/utils/srs_engine.dart';
import '../../core/utils/cloze_parser.dart';
import '../widgets/common/archetype_badge.dart';
import '../widgets/common/markdown_view.dart';
import '../widgets/common/code_editor_widget.dart';
import '../widgets/common/pomodoro_timer_widget.dart';

class StudySessionView extends StatefulWidget {
  final Deck? deck;
  final String? deckId;
  final String? title;
  final List<Flashcard>? customSessionCards;
  final bool isRelearning;
  final VoidCallback? onComplete;

  const StudySessionView({
    super.key,
    this.deck,
    this.deckId,
    this.title,
    this.customSessionCards,
    this.isRelearning = false,
    this.onComplete,
  });

  @override
  State<StudySessionView> createState() => _StudySessionViewState();
}

class _StudySessionViewState extends State<StudySessionView> {
  late List<Flashcard> _dueCards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  String _currentCode = '';
  bool _isEvaluatingCode = false;
  String? _aiFeedback;

  @override
  void initState() {
    super.initState();
    if (widget.customSessionCards != null) {
      _dueCards = List.from(widget.customSessionCards!);
    } else if (widget.deck != null) {
      if (widget.isRelearning) {
        _dueCards = List.from(widget.deck!.cards);
      } else {
        _dueCards = widget.deck!.cards.where((c) => c.isDue).toList();
        _dueCards.sort((a, b) => a.nextReview.compareTo(b.nextReview));
      }
    } else {
      _dueCards = [];
    }
  }

  void _flipCard() async {
    final currentCard = _dueCards[_currentIndex];
    
    if (currentCard.type == CardType.implementation || currentCard.type == CardType.explain) {
      final cleanSubmission = _currentCode.trim();
      if (cleanSubmission.isEmpty || (currentCard.type == CardType.implementation && cleanSubmission == '// Write your code here')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentCard.type == CardType.implementation
                ? 'Please write your implementation code in the editor! (If stuck, write a comment like "// stuck" to see reference answer)'
                : 'Please write your explanation in the text field!'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }

      setState(() {
        _isEvaluatingCode = true;
      });
      
      try {
        final result = currentCard.type == CardType.implementation
            ? await AIService().evaluateCode(
                prompt: currentCard.front,
                code: _currentCode,
              )
            : await AIService().evaluateExplanation(
                prompt: currentCard.front,
                explanation: _currentCode,
              );
        if (mounted) {
          setState(() {
            _aiFeedback = '### AI Grade: ${result['grade']}\n\n${result['feedback']}';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _aiFeedback = 'Error evaluating submission: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isEvaluatingCode = false;
            _isFlipped = true;
          });
        }
      }
    } else {
      setState(() {
        _isFlipped = true;
      });
    }
  }

  void _gradeCard(Grade grade) async {
    if (_currentIndex >= _dueCards.length) return;

    final currentCard = _dueCards[_currentIndex];
    final updatedCard = SRSEngine.calculateNextReview(currentCard, grade);

    if (!currentCard.isGraduated && updatedCard.isGraduated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎓 Card Graduated to Mastered! (Immune to decay)'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Update in provider and sync to local storage
    final resolvedDeckId = widget.deck?.id ?? (widget.deckId != 'universal' && widget.deckId != 'custom' ? widget.deckId : null) ?? currentCard.deckId;
    await context.read<DeckProvider>().updateCard(resolvedDeckId, updatedCard);
    
    if (!mounted) return;
    await context.read<DeckProvider>().logReview(resolvedDeckId ?? 'universal', updatedCard.id, grade.name);
    if (!mounted) return;

    if (grade == Grade.again) {
      // Re-queue card to be reviewed again in this session
      setState(() {
        _dueCards.add(updatedCard);
        _currentIndex++;
        _isFlipped = false;
        _currentCode = '';
        _aiFeedback = null;
        _isEvaluatingCode = false;
      });
    } else {
      if (_currentIndex < _dueCards.length - 1) {
        setState(() {
          _currentIndex++;
          _isFlipped = false;
          _currentCode = '';
          _aiFeedback = null;
          _isEvaluatingCode = false;
        });
      } else {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dueCards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: widget.onComplete ?? () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.title ?? widget.deck?.title ?? 'Study Session',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 72, color: AppColors.success),
                ),
                const SizedBox(height: 24),
                const Text(
                  'All Caught Up!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have reviewed all due cards in "${widget.title ?? widget.deck?.title ?? 'this session'}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                () {
                  final totalSessionCards = widget.customSessionCards ?? widget.deck?.cards ?? [];
                  final masteredCount = totalSessionCards.where((c) => c.isGraduated).length;
                  if (masteredCount > 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          '🎓 $masteredCount Mastered Cards in this collection',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }(),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if ((widget.deck != null && widget.deck!.cards.isNotEmpty) || (widget.customSessionCards != null && widget.customSessionCards!.isNotEmpty))
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _dueCards = List.from(widget.customSessionCards ?? widget.deck!.cards);
                            _currentIndex = 0;
                            _isFlipped = false;
                            _currentCode = '';
                            _aiFeedback = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Relearn All Cards Now', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: widget.onComplete ?? () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Return to Library', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentCard = _dueCards[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: widget.onComplete ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title ?? widget.deck?.title ?? 'Study Session',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          const PomodoroTimerWidget(),
          const SizedBox(width: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '${_currentIndex + 1} / ${_dueCards.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 32.0),
                child: Column(
                  children: [
                    SizedBox(height: isMobile ? 16 : 32),
                    
                    // Card Content
                    Expanded(
                      child: Card(
                        elevation: 6,
                        shadowColor: (ArchetypeConfig.configs[currentCard.type]?.color ?? Colors.black).withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: ArchetypeConfig.configs[currentCard.type]?.borderColor ?? AppColors.border,
                            width: 2,
                          ),
                        ),
                        color: ArchetypeConfig.configs[currentCard.type]?.backgroundColor.withValues(alpha: 0.6) ?? Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card Header (Archetype & Resource Link)
                              Row(
                                children: [
                                  ArchetypeBadge(type: currentCard.type),
                                  const SizedBox(width: 8),
                                  if (currentCard.isGraduated)
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
                                          Text('🎓', style: TextStyle(fontSize: 10)),
                                          SizedBox(width: 4),
                                          Text(
                                            'MASTERED',
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
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        '${currentCard.consecutiveCorrect}/2 to Master',
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (currentCard.sourceUrl != null && currentCard.sourceUrl!.isNotEmpty) ...[
                                    ActionChip(
                                      avatar: const Icon(Icons.open_in_new, size: 13, color: AppColors.primary),
                                      label: const Text('Resource'),
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      onPressed: () async {
                                        final uri = Uri.parse(currentCard.sourceUrl!);
                                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (currentCard.codeSnippet != null)
                                    const Icon(Icons.code, color: AppColors.textSecondary),
                                ],
                              ),
                              SizedBox(height: isMobile ? 16 : 32),
                              
                              // Scrollable content area
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Front of card
                                      _buildFrontContent(currentCard),
                                      
                                      // Back of card
                                      if (_isFlipped) ...[
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 24.0),
                                          child: Divider(color: AppColors.border, thickness: 2),
                                        ),
                                        _buildBackContent(currentCard),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isMobile ? 16 : 32),
                    
                    // Controls
                    SizedBox(
                      height: isMobile ? 64 : 80,
                      child: _isFlipped 
                          ? Row(
                              children: [
                                _buildGradeButton(
                                  'Again',
                                  SRSEngine.getIntervalLabel(currentCard, Grade.again),
                                  AppColors.error,
                                  () => _gradeCard(Grade.again),
                                  isMobile,
                                ),
                                SizedBox(width: isMobile ? 8 : 16),
                                _buildGradeButton(
                                  'Good',
                                  SRSEngine.getIntervalLabel(currentCard, Grade.good),
                                  AppColors.success,
                                  () => _gradeCard(Grade.good),
                                  isMobile,
                                ),
                                SizedBox(width: isMobile ? 8 : 16),
                                _buildGradeButton(
                                  'Easy',
                                  SRSEngine.getIntervalLabel(currentCard, Grade.easy),
                                  AppColors.primary,
                                  () => _gradeCard(Grade.easy),
                                  isMobile,
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isEvaluatingCode ? null : _flipCard,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.textPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isEvaluatingCode 
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                    : Text('Show Answer', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                    ),
                    SizedBox(height: isMobile ? 24 : 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontContent(Flashcard card) {
    String text = card.front;
    if (card.type == CardType.cloze) {
      text = _isFlipped ? ClozeParser.formatClozeAnswer(text) : ClozeParser.formatClozeQuestion(text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownView(data: text),
        if (card.imageUrl != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: card.imageUrl!.startsWith('http')
                  ? Image.network(card.imageUrl!, fit: BoxFit.contain, width: double.infinity)
                  : Image.file(File(card.imageUrl!), fit: BoxFit.contain, width: double.infinity),
            ),
          ),
        ],
        if (!_isFlipped && card.type == CardType.implementation) ...[
          const SizedBox(height: 24),
          const Text('Your Implementation:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          CodeEditorWidget(
            initialCode: '// Write your code here\n',
            readOnly: false,
            onChanged: (val) {
              _currentCode = val;
            },
          ),
        ],
        if (!_isFlipped && card.type == CardType.explain) ...[
          const SizedBox(height: 24),
          const Text('Your Explanation:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              maxLines: 8,
              onChanged: (val) {
                _currentCode = val;
              },
              style: const TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Type your explanation here...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBackContent(Flashcard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_aiFeedback != null) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('AI Evaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                MarkdownView(data: _aiFeedback!),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
        ],
        MarkdownView(data: card.back),
        if (card.codeSnippet != null) ...[
          const SizedBox(height: 24),
          const Text('Reference Implementation:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          CodeEditorWidget(
            initialCode: card.codeSnippet!,
            readOnly: true,
          ),
        ],
      ],
    );
  }

  Widget _buildGradeButton(String label, String intervalLabel, Color color, VoidCallback onPressed, bool isMobile) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: isMobile ? 14 : 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              intervalLabel,
              style: TextStyle(fontSize: isMobile ? 11 : 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
