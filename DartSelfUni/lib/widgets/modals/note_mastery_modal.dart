import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/note_mastery_storage_service.dart';
import '../../models/note_mastery_model.dart';

class NoteMasteryModal extends StatefulWidget {
  final String noteKey;
  final String noteTitle;
  final String noteContent;
  final VoidCallback? onMasteryUpdated;

  const NoteMasteryModal({
    super.key,
    required this.noteKey,
    required this.noteTitle,
    required this.noteContent,
    this.onMasteryUpdated,
  });

  @override
  State<NoteMasteryModal> createState() => _NoteMasteryModalState();
}

enum _QuizStep { loading, active, evaluated, summary }

class _NoteMasteryModalState extends State<NoteMasteryModal> {
  final AIService _aiService = AIService();
  final NoteMasteryStorageService _storageService = NoteMasteryStorageService();
  final TextEditingController _answerController = TextEditingController();

  _QuizStep _currentStep = _QuizStep.loading;
  NoteMasteryModel? _mastery;

  List<MasteryQuestionModel> _activeQuestions = [];
  int _currentIndex = 0;
  bool _isReviewingMissed = false;

  bool _isSubmitting = false;
  Map<String, dynamic>? _lastEvaluation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeQuizSession();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initializeQuizSession({bool forceNew = false}) async {
    setState(() {
      _currentStep = _QuizStep.loading;
      _errorMessage = null;
    });

    try {
      _mastery = await _storageService.getNoteMastery(widget.noteKey);
      if (!mounted) return;

      // Check if there are previously failed questions
      final missed = _mastery?.incorrectQuestions ?? [];

      if (!forceNew && missed.isNotEmpty) {
        // Prioritize missed questions from previous attempts
        _isReviewingMissed = true;
        _activeQuestions = List.from(missed);
      } else {
        _isReviewingMissed = false;
        // Generate fresh questions from AI
        final generated = await _aiService.generateMasteryQuestions(
          noteContent: widget.noteContent,
          count: 3,
        );
        if (!mounted) return;

        _activeQuestions = generated.map((q) {
          return MasteryQuestionModel(
            id: 'q_${DateTime.now().microsecondsSinceEpoch}_${q['question'].hashCode}',
            question: q['question'] ?? '',
            idealAnswer: q['idealAnswer'] ?? '',
          );
        }).toList();
      }

      if (_activeQuestions.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not generate questions from this note. Please add more content to your note.';
          });
        }
        return;
      }

      _currentIndex = 0;
      _answerController.clear();
      _lastEvaluation = null;

      if (mounted) {
        setState(() {
          _currentStep = _QuizStep.active;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error setting up quiz session: $e';
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final userAnswer = _answerController.text.trim();
    if (userAnswer.isEmpty || _currentIndex >= _activeQuestions.length) return;

    final currentQuestion = _activeQuestions[_currentIndex];

    setState(() {
      _isSubmitting = true;
    });

    try {
      final eval = await _aiService.gradeMasteryAnswer(
        question: currentQuestion.question,
        idealAnswer: currentQuestion.idealAnswer,
        userAnswer: userAnswer,
      );
      if (!mounted) return;

      final isCorrect = eval['isCorrect'] == true;
      currentQuestion.lastUserAnswer = userAnswer;
      currentQuestion.isCorrect = isCorrect;
      currentQuestion.lastAnsweredAt = DateTime.now();
      currentQuestion.feedback = eval['feedback']?.toString();

      _lastEvaluation = eval;
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _currentStep = _QuizStep.evaluated;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _lastEvaluation = {
            'isCorrect': userAnswer.length >= 20,
            'feedback': 'Answer recorded.',
            'idealComparison': currentQuestion.idealAnswer,
          };
          _currentStep = _QuizStep.evaluated;
        });
      }
    }
  }

  void _nextQuestion() async {
    if (_currentIndex + 1 < _activeQuestions.length) {
      setState(() {
        _currentIndex++;
        _answerController.clear();
        _lastEvaluation = null;
        _currentStep = _QuizStep.active;
      });
    } else {
      // Quiz complete! Merge and save to storage
      await _saveCompletedSession();
      if (!mounted) return;
      setState(() {
        _currentStep = _QuizStep.summary;
      });
      widget.onMasteryUpdated?.call();
    }
  }

  Future<void> _saveCompletedSession() async {
    final allQuestionsMap = <String, MasteryQuestionModel>{};

    // Include existing questions
    if (_mastery != null) {
      for (final q in _mastery!.questions) {
        allQuestionsMap[q.id] = q;
      }
    }

    // Overwrite / add active questions with latest results
    for (final q in _activeQuestions) {
      allQuestionsMap[q.id] = q;
    }

    final correctCount = _activeQuestions.where((q) => q.isCorrect).length;
    final sessionScore = _activeQuestions.isNotEmpty
        ? ((correctCount / _activeQuestions.length) * 100).round()
        : 0;

    int consecutive = _mastery?.consecutiveHighScores ?? 0;
    final wasGraduated = _mastery?.isGraduated ?? false;

    if (sessionScore >= 90) {
      consecutive++;
    } else if (!wasGraduated) {
      consecutive = 0;
    }

    final bool isNowGraduated = wasGraduated || (consecutive >= 2);

    final updatedMastery = NoteMasteryModel(
      noteKey: widget.noteKey,
      questions: allQuestionsMap.values.toList(),
      lastReviewedAt: DateTime.now(),
      consecutiveHighScores: consecutive,
      isGraduated: isNowGraduated,
    );

    _mastery = updatedMastery;
    await _storageService.saveNoteMastery(updatedMastery);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.65).clamp(380.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Top Header
            _buildHeader(context),
            const Divider(height: 1, color: AppColors.border),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final currentScore = _mastery?.effectiveMasteryPercentage ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology, color: Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.noteTitle.isNotEmpty ? 'Mastery: ${widget.noteTitle}' : 'Note Mastery Quiz',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _isReviewingMissed ? 'Reviewing questions from previous session' : 'Active Recall & AI Evaluation',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Mastery percentage pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getMasteryColor(currentScore).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getMasteryColor(currentScore).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 14, color: _getMasteryColor(currentScore)),
                const SizedBox(width: 4),
                Text(
                  '$currentScore% Mastery',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getMasteryColor(currentScore),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE11D48)),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _initializeQuizSession(forceNew: true),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    switch (_currentStep) {
      case _QuizStep.loading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3.5, color: Color(0xFF4F46E5)),
                ),
                SizedBox(height: 20),
                Text(
                  'Preparing Mastery Quiz...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 6),
                Text(
                  'Analyzing notes and generating active recall questions...',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );

      case _QuizStep.active:
        return _buildActiveQuizStep();

      case _QuizStep.evaluated:
        return _buildEvaluatedStep();

      case _QuizStep.summary:
        return _buildSummaryStep();
    }
  }

  Widget _buildActiveQuizStep() {
    if (_currentIndex >= _activeQuestions.length) return const SizedBox();
    final question = _activeQuestions[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress & step header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isReviewingMissed ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isReviewingMissed ? '🔁 Missed Concept' : 'Question ${_currentIndex + 1} of ${_activeQuestions.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _isReviewingMissed ? const Color(0xFFD97706) : const Color(0xFF4F46E5),
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${_currentIndex + 1} / ${_activeQuestions.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _activeQuestions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              _isReviewingMissed ? const Color(0xFFD97706) : const Color(0xFF4F46E5),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 20),

        // Question Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline, size: 20, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Typed Answer Area
        const Text(
          'Your Answer / Explanation:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _answerController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Type your detailed answer, explanation, or key invariants here...',
              contentPadding: EdgeInsets.all(14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitAnswer,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_isSubmitting ? 'AI Evaluating...' : 'Submit Answer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEvaluatedStep() {
    if (_currentIndex >= _activeQuestions.length) return const SizedBox();
    final question = _activeQuestions[_currentIndex];
    final isCorrect = question.isCorrect;
    final feedback = question.feedback ?? _lastEvaluation?['feedback'] ?? '';
    final ideal = _lastEvaluation?['idealComparison'] ?? question.idealAnswer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verdict Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isCorrect ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect ? 'Concept Mastered! 🎉' : 'Needs Review 💡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCorrect
                          ? 'You demonstrated strong comprehension of this concept.'
                          : 'This question will be saved and prioritized on your next mastery check.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isCorrect ? const Color(0xFF047857) : const Color(0xFFBE123C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Feedback Card
        if (feedback.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4F46E5)),
                    SizedBox(width: 6),
                    Text('AI Tutor Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(feedback, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Benchmark / Key Reference Points
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text('Ideal Benchmark Answer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ],
              ),
              const SizedBox(height: 8),
              Text(ideal, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF064E3B))),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Next Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _nextQuestion,
              icon: Icon(
                _currentIndex + 1 < _activeQuestions.length ? Icons.arrow_forward : Icons.celebration,
                size: 16,
              ),
              label: Text(_currentIndex + 1 < _activeQuestions.length ? 'Next Question' : 'Complete Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    final finalScore = _mastery?.effectiveMasteryPercentage ?? 0;
    final totalQuestions = _mastery?.questions.length ?? _activeQuestions.length;
    final masteredCount = _mastery?.questions.where((q) => q.isCorrect).length ??
        _activeQuestions.where((q) => q.isCorrect).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getMasteryColor(finalScore).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$finalScore%',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: _getMasteryColor(finalScore),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          finalScore >= 80
              ? 'Outstanding Mastery! 🏆'
              : (finalScore >= 50 ? 'Great Progress! 📈' : 'Keep Practicing! 💪'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Mastered $masteredCount of $totalQuestions core concepts for this note.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        if (_mastery?.isGraduated == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF3C7), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
            ),
            child: const Row(
              children: [
                Text('🎓', style: TextStyle(fontSize: 26)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Graduated to Mastered Notes!',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Scored ≥90% consecutively. This note is now permanently mastered and exempt from time decay.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Questions List Review
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeQuestions.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) {
              final q = _activeQuestions[index];
              return ListTile(
                leading: Icon(
                  q.isCorrect ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: q.isCorrect ? const Color(0xFF10B981) : const Color(0xFFD97706),
                  size: 20,
                ),
                title: Text(
                  q.question,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  q.isCorrect ? 'Mastered' : 'Saved for next review',
                  style: TextStyle(
                    fontSize: 11,
                    color: q.isCorrect ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _initializeQuizSession(forceNew: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Practice New Questions'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  Color _getMasteryColor(int score) {
    if (score >= 80) return const Color(0xFF059669); // Emerald
    if (score >= 50) return const Color(0xFFD97706); // Amber
    return const Color(0xFF64748B); // Slate
  }
}
