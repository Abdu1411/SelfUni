enum LectureStatus { live, upcoming, recorded }

class TranscriptSegment {
  final int startSeconds;
  final String timeText; // e.g. "02:15"
  final String speaker;
  final String text;

  TranscriptSegment({
    required this.startSeconds,
    required this.timeText,
    required this.speaker,
    required this.text,
  });
}

class LectureTimestamp {
  final String time; // e.g. "04:15"
  final int seconds;
  final String title;

  LectureTimestamp({
    required this.time,
    required this.seconds,
    required this.title,
  });

  factory LectureTimestamp.fromJson(Map<String, dynamic> json) {
    return LectureTimestamp(
      time: json['time'] ?? '00:00',
      seconds: json['seconds'] ?? 0,
      title: json['title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'seconds': seconds,
        'title': title,
      };
}

class LectureChatMessage {
  final String id;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isInstructor;
  final bool isQuestion;

  LectureChatMessage({
    required this.id,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isInstructor = false,
    this.isQuestion = false,
  });
}

class Lecture {
  final String id;
  final String title;
  final String instructor;
  final String description;
  final String category;
  final String videoId; // YouTube video ID or URL
  final String thumbnailUrl;
  final LectureStatus status;
  final DateTime scheduledAt;
  final int durationMinutes;
  final int attendeesCount;
  final List<LectureTimestamp> timestamps;
  final String notesSummary;
  final List<Map<String, String>> generatedFlashcards;

  Lecture({
    required this.id,
    required this.title,
    required this.instructor,
    required this.description,
    required this.category,
    required this.videoId,
    required this.thumbnailUrl,
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.attendeesCount,
    required this.timestamps,
    required this.notesSummary,
    required this.generatedFlashcards,
  });
}
