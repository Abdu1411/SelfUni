import '../../models/card_model.dart';

enum Grade {
  again,
  good,
  easy
}

class SRSEngine {
  static int getIntervalDays(Flashcard card, Grade grade) {
    int interval = card.interval;
    double ease = card.ease;
    int reps = card.reps;

    if (grade == Grade.again) {
      return 1;
    } else if (grade == Grade.good) {
      reps += 1;
      if (reps == 1) {
        return 1;
      } else if (reps == 2) {
        return 6;
      } else {
        return (interval * ease).round();
      }
    } else if (grade == Grade.easy) {
      reps += 1;
      ease += 0.15;
      if (reps == 1) {
        return 4;
      } else {
        return (interval * ease * 1.3).round();
      }
    }
    return 1;
  }

  static String getIntervalLabel(Flashcard card, Grade grade) {
    final days = getIntervalDays(card, grade);
    if (grade == Grade.again) {
      return '< 1m (1d)';
    }
    if (days < 1) {
      return '1d';
    } else if (days < 30) {
      return '${days}d';
    } else if (days < 365) {
      final months = (days / 30).toStringAsFixed(days % 30 == 0 ? 0 : 1);
      return '${months}mo';
    } else {
      final years = (days / 365).toStringAsFixed(1);
      return '${years}y';
    }
  }

  static Flashcard calculateNextReview(Flashcard card, Grade grade) {
    final now = DateTime.now().millisecondsSinceEpoch;
    int interval = card.interval;
    double ease = card.ease;
    int reps = card.reps;

    if (grade == Grade.again) {
      reps = 0;
      interval = 1; // 1 day
      ease = (ease - 0.2).clamp(1.3, double.infinity);
    } else if (grade == Grade.good) {
      reps += 1;
      if (reps == 1) {
        interval = 1;
      } else if (reps == 2) {
        interval = 6;
      } else {
        interval = (interval * ease).round();
      }
    } else if (grade == Grade.easy) {
      reps += 1;
      ease += 0.15;
      if (reps == 1) {
        interval = 4;
      } else {
        interval = (interval * ease * 1.3).round();
      }
    }

    // Convert interval days to milliseconds for next review
    final nextReview = now + (interval * 24 * 60 * 60 * 1000);

    return card.copyWith(
      interval: interval,
      ease: ease,
      reps: reps,
      nextReview: nextReview,
    );
  }
}

