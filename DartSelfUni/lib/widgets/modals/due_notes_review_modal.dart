import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/note_mastery_storage_service.dart';
import '../../models/folder_model.dart';
import '../../models/lesson_model.dart';
import '../../providers/deck_provider.dart';
import 'note_mastery_modal.dart';

class DueNotesReviewModal extends StatefulWidget {
  final String? folderId;
  final VoidCallback? onMasteryChanged;

  const DueNotesReviewModal({
    super.key,
    this.folderId,
    this.onMasteryChanged,
  });

  /// Static helper to display the Due Notes Review Modal
  static Future<void> show(
    BuildContext context, {
    String? folderId,
    VoidCallback? onMasteryChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DueNotesReviewModal(
        folderId: folderId,
        onMasteryChanged: onMasteryChanged,
      ),
    );
  }

  @override
  State<DueNotesReviewModal> createState() => _DueNotesReviewModalState();
}

class _DueNotesReviewModalState extends State<DueNotesReviewModal> {
  final NoteMasteryStorageService _storageService = NoteMasteryStorageService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _dueNotes = [];
  List<Map<String, dynamic>> _masteredNotes = [];
  Map<String, int> _allScores = {};
  int _tabIndex = 0; // 0 = Due (<60%), 1 = Mastered Notes (Graduated / >=90%), 2 = All Notes

  @override
  void initState() {
    super.initState();
    _loadDueNotes();
  }

  Future<void> _loadDueNotes({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final deckProvider = context.read<DeckProvider>();
    final lessons = deckProvider.lessons.where((l) {
      final isReviewable = l.isNote ||
          l.pdfUrl != null ||
          l.pdfFilename != null ||
          l.content.trim().isNotEmpty;
      if (!isReviewable) return false;
      if (l.isFromLocalCourse(deckProvider.courses, deckProvider.folders)) return false;
      if (widget.folderId != null && widget.folderId != 'unfiled') {
        return l.folderId == widget.folderId;
      }
      return true;
    }).toList();

    final due = await _storageService.getDueNotes(
      lessons,
      threshold: 60,
      courses: deckProvider.courses,
      folders: deckProvider.folders,
    );
    final mastered = await _storageService.getMasteredNotes(
      lessons,
      courses: deckProvider.courses,
      folders: deckProvider.folders,
    );
    final allScores = await _storageService.getAllEffectiveMasteryScores();

    if (mounted) {
      setState(() {
        _dueNotes = due;
        _masteredNotes = mastered;
        _allScores = allScores;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onMasteryChanged?.call();
      });
    }
  }

  Future<void> _startQuizForNote(Lesson lesson) async {
    final noteKey = lesson.id;
    await showDialog(
      context: context,
      builder: (ctx) => NoteMasteryModal(
        noteKey: noteKey,
        noteTitle: lesson.title,
        noteContent: lesson.content.isNotEmpty
            ? lesson.content
            : (lesson.pdfFilename != null ? 'Study notes for ${lesson.title} (${lesson.pdfFilename})' : lesson.topic),
        onMasteryUpdated: () {
          _loadDueNotes();
        },
      ),
    );
    _loadDueNotes();
  }

  Future<void> _startSequentialReview() async {
    if (_dueNotes.isEmpty) return;

    // Use a static snapshot of all due notes so all notes are reviewed sequentially
    final queue = List<Map<String, dynamic>>.from(_dueNotes);

    for (int i = 0; i < queue.length; i++) {
      if (!mounted) break;
      final item = queue[i];
      final Lesson lesson = item['lesson'] as Lesson;

      await showDialog(
        context: context,
        builder: (ctx) => NoteMasteryModal(
          noteKey: lesson.id,
          noteTitle: lesson.title,
          noteContent: lesson.content.isNotEmpty
              ? lesson.content
              : (lesson.pdfFilename != null ? 'Study notes for ${lesson.title} (${lesson.pdfFilename})' : lesson.topic),
          onMasteryUpdated: () {
            _loadDueNotes();
          },
        ),
      );

      await _loadDueNotes();
    }
  }

  Color _getMasteryColor(int score) {
    if (score >= 80) return const Color(0xFF059669); // Emerald
    if (score >= 60) return const Color(0xFF10B981); // Green
    if (score >= 40) return const Color(0xFFD97706); // Amber
    return const Color(0xFFE11D48); // Rose / Red
  }

  String _getStatusLabel(Map<String, dynamic> item) {
    final score = item['score'] as int;
    final isDecayed = item['isDecayed'] as bool;
    final isUnattempted = item['isUnattempted'] as bool;

    if (isDecayed && score == 0) {
      return '🚨 Retention Decayed (0%)';
    }
    if (isUnattempted) {
      return '⏳ Unreviewed (0%)';
    }
    if (score < 40) {
      return '⚠️ Low Mastery ($score%)';
    }
    return '⚡ Needs Practice ($score%)';
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();
    final folders = deckProvider.folders;
    final allLessons = deckProvider.lessons.where((l) {
      if (!l.isNote) return false;
      if (widget.folderId != null && widget.folderId != 'unfiled') {
        return l.folderId == widget.folderId;
      }
      return true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: const Icon(Icons.psychology, color: Color(0xFFE11D48), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Due Notes Mastery Review',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _dueNotes.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _dueNotes.isNotEmpty ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Text(
                                '${_dueNotes.length} Due (<60%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _dueNotes.isNotEmpty ? const Color(0xFFE11D48) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Active recall review queue for notes with retention below 60% or decayed over time.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Metrics Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DUE FOR QUIZ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            '${_dueNotes.length} notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _dueNotes.isNotEmpty ? const Color(0xFFE11D48) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 28, width: 1, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MASTERED NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            const SizedBox(height: 2),
                            Text(
                              '${_masteredNotes.length} notes',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 28, width: 1, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LIBRARY TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              '${allLessons.length} notes',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Tabs & Sequential Action Row
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Due Notes (${_dueNotes.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: _tabIndex == 0,
                        selectedColor: const Color(0xFFFEF2F2),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: _tabIndex == 0 ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                        ),
                        side: BorderSide(
                          color: _tabIndex == 0 ? const Color(0xFFFECDD3) : Colors.transparent,
                        ),
                        onSelected: (val) => setState(() => _tabIndex = 0),
                      ),
                      ChoiceChip(
                        label: Text('🎓 Mastered Notes (${_masteredNotes.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: _tabIndex == 1,
                        selectedColor: const Color(0xFFECFDF5),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: _tabIndex == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        side: BorderSide(
                          color: _tabIndex == 1 ? const Color(0xFFA7F3D0) : Colors.transparent,
                        ),
                        onSelected: (val) => setState(() => _tabIndex = 1),
                      ),
                      ChoiceChip(
                        label: Text('All Notes (${allLessons.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: _tabIndex == 2,
                        selectedColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: _tabIndex == 2 ? AppColors.primary : const Color(0xFF64748B),
                        ),
                        side: BorderSide(
                          color: _tabIndex == 2 ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                        ),
                        onSelected: (val) => setState(() => _tabIndex = 2),
                      ),
                    ],
                  ),
                  if (_dueNotes.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _startSequentialReview,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Review All Due', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Note Cards List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _tabIndex == 0
                        ? _buildDueNotesList(folders)
                        : _tabIndex == 1
                            ? _buildMasteredNotesList(folders)
                            : _buildAllNotesList(allLessons, folders),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDueNotesList(List<Folder> folders) {
    if (_dueNotes.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF10B981)),
              const SizedBox(height: 12),
              const Text(
                'All Notes Mastered!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Every note in your CS library has ≥ 60% active recall retention. Memory curve is optimal!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _dueNotes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _dueNotes[index];
        final Lesson lesson = item['lesson'] as Lesson;
        final int score = item['score'] as int;
        final folder = folders.where((f) => f.id == lesson.folderId).firstOrNull;

        return _buildNoteReviewCard(
          lesson: lesson,
          score: score,
          folderName: folder?.name ?? 'General Notes',
          statusText: _getStatusLabel(item),
          isDue: true,
        );
      },
    );
  }

  Widget _buildMasteredNotesList(List<Folder> folders) {
    if (_masteredNotes.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎓', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'No Mastered Notes Yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
              ),
              SizedBox(height: 6),
              Text(
                'Score ≥90% consecutively on active recall quizzes to graduate notes to permanent Mastered status (exempt from decay)!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _masteredNotes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _masteredNotes[index];
        final Lesson lesson = item['lesson'] as Lesson;
        final int score = item['score'] as int;
        final bool isGraduated = item['isGraduated'] as bool? ?? false;
        final folder = folders.where((f) => f.id == lesson.folderId).firstOrNull;

        return _buildNoteReviewCard(
          lesson: lesson,
          score: score,
          folderName: folder?.name ?? 'General Notes',
          statusText: isGraduated ? '🎓 Mastered (Immune to Decay)' : 'Mastered (≥90%)',
          isDue: false,
          isGraduated: isGraduated,
        );
      },
    );
  }

  Widget _buildAllNotesList(List<Lesson> allLessons, List<Folder> folders) {
    if (allLessons.isEmpty) {
      return const Center(
        child: Text('No notes found in your library.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return ListView.separated(
      itemCount: allLessons.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final lesson = allLessons[index];
        final score = _allScores[lesson.id] ?? _allScores[lesson.title] ?? 0;
        final folder = folders.where((f) => f.id == lesson.folderId).firstOrNull;
        final isDue = score < 60;

        return _buildNoteReviewCard(
          lesson: lesson,
          score: score,
          folderName: folder?.name ?? 'General Notes',
          statusText: isDue ? 'Due for Review (<60%)' : 'Mastered (≥60%)',
          isDue: isDue,
        );
      },
    );
  }

  Widget _buildNoteReviewCard({
    required Lesson lesson,
    required int score,
    required String folderName,
    required String statusText,
    required bool isDue,
    bool isGraduated = false,
  }) {
    final masteryColor = isGraduated ? const Color(0xFF059669) : _getMasteryColor(score);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGraduated
              ? const Color(0xFFF59E0B)
              : (isDue ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
          width: (isDue || isGraduated) ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isGraduated
                ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                : (isDue
                    ? const Color(0xFFE11D48).withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mastery Score Circle / Gauge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGraduated
                  ? const Color(0xFFFEF3C7)
                  : masteryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isGraduated
                    ? const Color(0xFFF59E0B)
                    : masteryColor.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Center(
              child: isGraduated
                  ? const Text('🎓', style: TextStyle(fontSize: 20))
                  : Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: masteryColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Note Info & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lesson.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGraduated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 10, color: Color(0xFFD97706)),
                            SizedBox(width: 2),
                            Text(
                              'IMMUNE TO DECAY',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        folderName,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ),
                    if (lesson.pdfUrl != null || lesson.pdfFilename != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFE4E6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 10, color: Color(0xFFE11D48)),
                            SizedBox(width: 2),
                            Text(
                              'PDF NOTES',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFE11D48)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isGraduated
                              ? const Color(0xFF059669)
                              : (isDue ? const Color(0xFFE11D48) : const Color(0xFF059669)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (score / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isGraduated ? const Color(0xFF059669) : masteryColor,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Quiz Action Button
          ElevatedButton.icon(
            onPressed: () => _startQuizForNote(lesson),
            icon: const Icon(Icons.psychology, size: 16),
            label: Text(
              isDue ? 'Quiz Now' : 'Re-Quiz',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDue
                  ? const Color(0xFFE11D48)
                  : (isGraduated ? const Color(0xFF059669) : AppColors.primary),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
