import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lecture_model.dart';
import '../../models/card_model.dart';
import '../../providers/deck_provider.dart';
import '../../core/services/ai_lecture_generator_service.dart';
import '../../widgets/common/rich_note_editor.dart';
import '../../widgets/common/archetype_badge.dart';
import '../../widgets/common/adaptive_video_player_widget.dart';
import '../../widgets/modals/export_flashcards_modal.dart';
import '../../widgets/modals/manual_card_forge_modal.dart';
import '../../widgets/modals/export_note_modal.dart';

class LecturePlayerView extends StatefulWidget {
  final Lecture lecture;
  final VoidCallback onBack;

  const LecturePlayerView({
    super.key,
    required this.lecture,
    required this.onBack,
  });

  @override
  State<LecturePlayerView> createState() => _LecturePlayerViewState();
}

class _LecturePlayerViewState extends State<LecturePlayerView> {
  bool _isPlaying = true;
  double _currentPositionSeconds = 120.0;
  bool _isGeneratingAICards = false;
  int _videoFlex = 3;
  int _notesFlex = 3;
  late String _noteContent;
  late List<Flashcard> _activeFlashcards;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _noteContent = widget.lecture.notesSummary.isNotEmpty
        ? widget.lecture.notesSummary
        : '# ${widget.lecture.title}\n\nStart typing notes side-by-side with the lecture video...';

    _activeFlashcards = widget.lecture.generatedFlashcards.map((fc) {
      return Flashcard(
        id: 'card_${DateTime.now().microsecondsSinceEpoch}_${fc['front'].hashCode}',
        type: CardTypeExtension.fromString(fc['type'] ?? 'Concept'),
        front: fc['front'] ?? '',
        back: fc['back'] ?? '',
        codeSnippet: fc['codeSnippet'],
        nextReview: DateTime.now().millisecondsSinceEpoch,
        interval: 1,
        ease: 2.5,
        reps: 0,
      );
    }).toList();

    _startPlaybackTimer();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          if (_currentPositionSeconds < (widget.lecture.durationMinutes * 60)) {
            _currentPositionSeconds += 1.0;
          } else {
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    
    // Auto-save draft on exit
    try {
      final deckProvider = context.read<DeckProvider>();
      final existingLesson = deckProvider.lessons.where((l) => l.id == widget.lecture.id).firstOrNull;
      if (existingLesson != null) {
        existingLesson.content = _noteContent;
        deckProvider.updateLesson(existingLesson);
      }
    } catch (_) {}
    
    super.dispose();
  }

  void _openExportNoteModal() {
    if (_noteContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cannot export empty notes. Please write something first!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final videoUrl = widget.lecture.videoId.isNotEmpty
        ? (widget.lecture.videoId.startsWith('http')
            ? widget.lecture.videoId
            : 'https://www.youtube.com/watch?v=${widget.lecture.videoId}')
        : null;

    showDialog(
      context: context,
      builder: (context) => ExportNoteModal(
        noteContent: _noteContent,
        defaultTitle: widget.lecture.title,
        defaultTopic: widget.lecture.category,
        videoUrl: videoUrl,
      ),
    );
  }

  bool get _hasNotes {
    final trimmed = _noteContent.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('# ') && trimmed.contains('Start typing notes side-by-side')) return false;
    return true;
  }

  Future<void> _generateAIFlashcardsFromVideo() async {
    setState(() => _isGeneratingAICards = true);
    try {
      final generated = await AILectureGeneratorService.generateFlashcardsFromVideo(
        lecture: widget.lecture,
        notesText: _noteContent,
        startTimeSeconds: _currentPositionSeconds,
        endTimeSeconds: _currentPositionSeconds + 300,
        count: 9,
      );

      setState(() {
        _activeFlashcards.addAll(generated);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ AI generated ${generated.length} high-yield flashcards from lecture video!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Generation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAICards = false);
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      builder: (context) => ExportFlashcardsModal(
        cards: _activeFlashcards,
        defaultDeckTitle: '${widget.lecture.title} (Deck)',
      ),
    );
  }

  void _openSRSModal() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                width: 500,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.style_outlined, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'SRS Flashcards Manager',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_activeFlashcards.length} Flashcards Generated',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: (_hasNotes && !_isGeneratingAICards)
                                    ? () async {
                                        setModalState(() => _isGeneratingAICards = true);
                                        try {
                                          await _generateAIFlashcardsFromVideo();
                                        } finally {
                                          setModalState(() => _isGeneratingAICards = false);
                                        }
                                      }
                                    : null,
                                icon: _isGeneratingAICards
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.auto_awesome, size: 14),
                                label: Text(_isGeneratingAICards ? 'Synthesizing...' : 'AI Generate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _activeFlashcards.isEmpty
                                    ? null
                                    : () {
                                        Navigator.of(context).pop();
                                        _openExportModal();
                                      },
                                icon: const Icon(Icons.folder_special_outlined, size: 14),
                                label: const Text('Export Deck'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_activeFlashcards.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No flashcards created yet. Click "AI Generate" to create cards from your notes!',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _activeFlashcards.length,
                            itemBuilder: (context, index) {
                              final card = _activeFlashcards[index];
                              final config = ArchetypeConfig.configs[card.type] ?? ArchetypeConfig.configs[CardType.concept]!;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: config.borderColor, width: 1),
                                ),
                                color: config.backgroundColor.withValues(alpha: 0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          ArchetypeBadge(type: card.type, size: 11),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _activeFlashcards.removeAt(index);
                                              });
                                              setModalState(() {});
                                            },
                                            tooltip: 'Remove card',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Q: ${card.front}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text('A: ${card.back}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openManualCardForge() {
    final decks = context.read<DeckProvider>().decks;
    showDialog(
      context: context,
      builder: (context) => ManualCardForgeModal(
        decks: decks,
        onForge: (card, deckId) {
          setState(() {
            _activeFlashcards.add(card);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lecture = widget.lecture;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top Header Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Lectures',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (lecture.status == LectureStatus.live) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              lecture.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Instructor: ${lecture.instructor} • ${lecture.category}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (lecture.status == LectureStatus.live) ...[
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${lecture.attendeesCount} watching', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
                // Layout Ratio Switcher
                if (screenWidth >= 900) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Theater Mode (Large Video)',
                          child: InkWell(
                            onTap: () => setState(() { _videoFlex = 4; _notesFlex = 2; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoFlex == 4 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.video_call, size: 14, color: _videoFlex == 4 ? Colors.white : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('Theater', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _videoFlex == 4 ? Colors.white : AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Balanced Mode (50/50 Split)',
                          child: InkWell(
                            onTap: () => setState(() { _videoFlex = 3; _notesFlex = 3; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoFlex == 3 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.vertical_split, size: 14, color: _videoFlex == 3 ? Colors.white : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('50/50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _videoFlex == 3 ? Colors.white : AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Notes Focus (Large Notes)',
                          child: InkWell(
                            onTap: () => setState(() { _videoFlex = 2; _notesFlex = 4; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoFlex == 2 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note, size: 14, color: _videoFlex == 2 ? Colors.white : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _videoFlex == 2 ? Colors.white : AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Player Area & Sidebar Split Layout
          Expanded(
            child: screenWidth < 900
                ? Column(
                    children: [
                      // Video Player Area
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdaptiveVideoPlayerWidget(
                                key: ValueKey('player_${lecture.id}_${lecture.videoId}'),
                                videoUrl: lecture.videoId.startsWith('http')
                                    ? lecture.videoId
                                    : 'https://www.youtube.com/watch?v=${lecture.videoId}',
                                thumbnailUrl: lecture.thumbnailUrl,
                                onPlayToggled: () => setState(() => _isPlaying = !_isPlaying),
                              ),
                              const SizedBox(height: 16),
                              // Redesigned Manual Card Forge Banner
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openManualCardForge,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Icon(
                                              Icons.draw_outlined,
                                              color: Color(0xFFB45309),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'CREATE FLASHCARDS FROM THIS LECTURE',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                SizedBox(height: 3),
                                                Text(
                                                  'Craft Concept, Complexity, Cloze, or Dart Code cards while studying',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          OutlinedButton.icon(
                                            onPressed: _openManualCardForge,
                                            icon: const Icon(Icons.draw_outlined, size: 16, color: Color(0xFFB45309)),
                                            label: const Text(
                                              'Open Forge',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFFFBEB),
                                              side: const BorderSide(color: Color(0xFFFDE68A)),
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      // Notes Editor
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit_note, size: 18, color: Color(0xFF10B981)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Live Notes Editor',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: RichNoteEditor(
                                    initialContent: _noteContent,
                                    title: lecture.title,
                                    onChanged: (newContent) {
                                      _noteContent = newContent;
                                    },
                                    onExportToNotes: _openExportNoteModal,
                                    onSRS: _openSRSModal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Main Video Player & Details (Flex Dynamic)
                      Expanded(
                        flex: _videoFlex,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Adaptive Video Player Component
                              AdaptiveVideoPlayerWidget(
                                key: ValueKey('player_${lecture.id}_${lecture.videoId}'),
                                videoUrl: lecture.videoId.startsWith('http')
                                    ? lecture.videoId
                                    : 'https://www.youtube.com/watch?v=${lecture.videoId}',
                                thumbnailUrl: lecture.thumbnailUrl,
                                onPlayToggled: () => setState(() => _isPlaying = !_isPlaying),
                              ),
                              const SizedBox(height: 24),
                              // Redesigned Manual Card Forge Banner
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openManualCardForge,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Icon(
                                              Icons.draw_outlined,
                                              color: Color(0xFFB45309),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'CREATE FLASHCARDS FROM THIS LECTURE',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                SizedBox(height: 3),
                                                Text(
                                                  'Craft Concept, Complexity, Cloze, or Dart Code cards while studying',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          OutlinedButton.icon(
                                            onPressed: _openManualCardForge,
                                            icon: const Icon(Icons.draw_outlined, size: 16, color: Color(0xFFB45309)),
                                            label: const Text(
                                              'Open Forge',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFFFBEB),
                                              side: const BorderSide(color: Color(0xFFFDE68A)),
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      // Right Sidebar (Flex Dynamic)
                      Expanded(
                        flex: _notesFlex,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(left: BorderSide(color: AppColors.border)),
                          ),
                          child: Column(
                            children: [
                              // Note Actions Bar
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit_note, size: 18, color: Color(0xFF10B981)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Live Notes Editor',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: RichNoteEditor(
                                    initialContent: _noteContent,
                                    title: lecture.title,
                                    onChanged: (newContent) {
                                      _noteContent = newContent;
                                    },
                                    onExportToNotes: _openExportNoteModal,
                                    onSRS: _openSRSModal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
