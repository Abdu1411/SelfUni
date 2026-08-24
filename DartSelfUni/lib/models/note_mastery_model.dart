class MasteryQuestionModel {
  final String id;
  final String question;
  final String idealAnswer;
  String? lastUserAnswer;
  bool isCorrect;
  DateTime? lastAnsweredAt;
  String? feedback;

  MasteryQuestionModel({
    required this.id,
    required this.question,
    required this.idealAnswer,
    this.lastUserAnswer,
    this.isCorrect = false,
    this.lastAnsweredAt,
    this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'idealAnswer': idealAnswer,
        'lastUserAnswer': lastUserAnswer,
        'isCorrect': isCorrect,
        'lastAnsweredAt': lastAnsweredAt?.toIso8601String(),
        'feedback': feedback,
      };

  factory MasteryQuestionModel.fromJson(Map<String, dynamic> json) =>
      MasteryQuestionModel(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        question: json['question'] as String? ?? '',
        idealAnswer: json['idealAnswer'] as String? ?? '',
        lastUserAnswer: json['lastUserAnswer'] as String?,
        isCorrect: json['isCorrect'] as bool? ?? false,
        lastAnsweredAt: json['lastAnsweredAt'] != null
            ? DateTime.tryParse(json['lastAnsweredAt'])
            : null,
        feedback: json['feedback'] as String?,
      );
}

class NoteMasteryModel {
  final String noteKey;
  final List<MasteryQuestionModel> questions;
  DateTime lastReviewedAt;
  final int consecutiveHighScores;
  final bool isGraduated;

  NoteMasteryModel({
    required this.noteKey,
    required this.questions,
    required this.lastReviewedAt,
    this.consecutiveHighScores = 0,
    this.isGraduated = false,
  });

  /// Calculates the effective mastery percentage (0 - 100%) taking into account time decay.
  /// If the note has graduated to Mastered (consecutive >=90%), it is immune to time decay.
  /// Otherwise, if it has been more than 7 days (168 hours) since the last review, mastery falls to 0%.
  int get effectiveMasteryPercentage {
    if (questions.isEmpty) return 0;

    // If graduated to Mastered, it is exempt from time decay
    if (isGraduated) {
      return rawMasteryPercentage;
    }

    final correctCount = questions.where((q) => q.isCorrect).length;
    final baseRatio = correctCount / questions.length;
    if (baseRatio == 0) return 0;

    final now = DateTime.now();
    final elapsedHours = now.difference(lastReviewedAt).inHours;

    // Decay parameters: 7 days = 168 hours
    const maxRetentionHours = 168.0;
    if (elapsedHours >= maxRetentionHours) {
      return 0;
    }

    // Within 24 hours: full retention (factor = 1.0)
    // Between 24h and 168h: linear forgetting curve decay down to 0.0
    double decayFactor = 1.0;
    if (elapsedHours > 24) {
      decayFactor = (maxRetentionHours - elapsedHours) / (maxRetentionHours - 24);
      decayFactor = decayFactor.clamp(0.0, 1.0);
    }

    final effective = (baseRatio * 100.0 * decayFactor).round();
    return effective.clamp(0, 100);
  }

  /// Raw mastery percentage based purely on correct/total questions (without time decay).
  int get rawMasteryPercentage {
    if (questions.isEmpty) return 0;
    final correctCount = questions.where((q) => q.isCorrect).length;
    return ((correctCount / questions.length) * 100.0).round().clamp(0, 100);
  }

  /// Questions that were answered incorrectly in previous attempts.
  List<MasteryQuestionModel> get incorrectQuestions =>
      questions.where((q) => !q.isCorrect).toList();

  NoteMasteryModel copyWith({
    String? noteKey,
    List<MasteryQuestionModel>? questions,
    DateTime? lastReviewedAt,
    int? consecutiveHighScores,
    bool? isGraduated,
  }) {
    return NoteMasteryModel(
      noteKey: noteKey ?? this.noteKey,
      questions: questions ?? this.questions,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      consecutiveHighScores: consecutiveHighScores ?? this.consecutiveHighScores,
      isGraduated: isGraduated ?? this.isGraduated,
    );
  }

  Map<String, dynamic> toJson() => {
        'noteKey': noteKey,
        'questions': questions.map((q) => q.toJson()).toList(),
        'lastReviewedAt': lastReviewedAt.toIso8601String(),
        'consecutiveHighScores': consecutiveHighScores,
        'isGraduated': isGraduated,
      };

  factory NoteMasteryModel.fromJson(Map<String, dynamic> json) => NoteMasteryModel(
        noteKey: json['noteKey'] as String? ?? '',
        questions: (json['questions'] as List<dynamic>?)
                ?.map((e) => MasteryQuestionModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastReviewedAt: json['lastReviewedAt'] != null
            ? DateTime.tryParse(json['lastReviewedAt']) ?? DateTime.now()
            : DateTime.now(),
        consecutiveHighScores: json['consecutiveHighScores'] as int? ?? 0,
        isGraduated: json['isGraduated'] as bool? ?? false,
      );
}
