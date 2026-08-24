import 'card_model.dart';

class Deck {
  final String id;
  String title;
  String? folderId;
  List<Flashcard> cards;
  final int createdAt;

  Deck({
    required this.id,
    required this.title,
    this.folderId,
    required this.cards,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  int get dueCardsCount => cards.where((c) => c.isDue).length;
  int get masteredCardsCount => cards.where((c) => c.isGraduated).length;
  int get totalCardsCount => cards.length;
  int get masteryRate => cards.isNotEmpty ? ((masteredCardsCount / cards.length) * 100).round() : 0;

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'] as String,
      title: json['title'] as String,
      folderId: json['folderId'] as String?,
      cards: (json['cards'] as List<dynamic>? ?? [])
          .map((c) => Flashcard.fromJson(c as Map<String, dynamic>, deckId: json['id']))
          .toList(),
      createdAt: json['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'folderId': folderId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'createdAt': createdAt,
    };
  }
}

class ReviewLog {
  final String id;
  final String deckId;
  final String cardId;
  final String grade;
  final int timestamp;

  ReviewLog({
    required this.id,
    required this.deckId,
    required this.cardId,
    required this.grade,
    required this.timestamp,
  });

  factory ReviewLog.fromJson(Map<String, dynamic> json) {
    return ReviewLog(
      id: json['id'] as String,
      deckId: json['deckId'] as String,
      cardId: json['cardId'] as String,
      grade: json['grade'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deckId': deckId,
      'cardId': cardId,
      'grade': grade,
      'timestamp': timestamp,
    };
  }
}

class TimeLog {
  final String id;
  final int date; // beginning of day timestamp
  final int durationSeconds;

  TimeLog({
    required this.id,
    required this.date,
    required this.durationSeconds,
  });

  factory TimeLog.fromJson(Map<String, dynamic> json) {
    return TimeLog(
      id: json['id'] as String,
      date: json['date'] as int,
      durationSeconds: json['durationSeconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'durationSeconds': durationSeconds,
    };
  }
}
