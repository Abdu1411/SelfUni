import 'package:flutter/material.dart';

enum CardType {
  concept,
  complexity,
  pattern,
  cloze,
  comparison,
  trace,
  invariant,
  debugging,
  implementation,
  explain
}

extension CardTypeExtension on CardType {
  String get stringValue {
    switch (this) {
      case CardType.concept: return 'Concept';
      case CardType.complexity: return 'Complexity';
      case CardType.pattern: return 'Pattern';
      case CardType.cloze: return 'Cloze';
      case CardType.comparison: return 'Comparison';
      case CardType.trace: return 'Trace';
      case CardType.invariant: return 'Invariant';
      case CardType.debugging: return 'Debugging';
      case CardType.implementation: return 'Implementation';
      case CardType.explain: return 'Explain';
    }
  }

  static CardType fromString(String val) {
    final clean = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.contains('complex')) return CardType.complexity;
    if (clean.contains('pattern')) return CardType.pattern;
    if (clean.contains('cloze')) return CardType.cloze;
    if (clean.contains('compar')) return CardType.comparison;
    if (clean.contains('trace')) return CardType.trace;
    if (clean.contains('invar')) return CardType.invariant;
    if (clean.contains('debug')) return CardType.debugging;
    if (clean.contains('explain')) return CardType.explain;
    if (clean.contains('implement') || clean.contains('code') || clean.contains('coding') || clean.contains('dart')) return CardType.implementation;
    if (clean.contains('concept')) return CardType.concept;
    return CardType.concept;
  }
}

class ArchetypeConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final String description;

  const ArchetypeConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.description,
  });

  static const Map<CardType, ArchetypeConfig> configs = {
    CardType.concept: ArchetypeConfig(
      label: 'Concept',
      icon: Icons.lightbulb_outline,
      color: Color(0xFFD97706),
      backgroundColor: Color(0xFFFFFBEB),
      borderColor: Color(0xFFFDE68A),
      description: 'Core CS principles, definitions, and mental models',
    ),
    CardType.complexity: ArchetypeConfig(
      label: 'Complexity',
      icon: Icons.bolt,
      color: Color(0xFF9333EA),
      backgroundColor: Color(0xFFFAF5FF),
      borderColor: Color(0xFFE9D5FF),
      description: 'Time & Space complexity, Big-O bounds, trade-offs',
    ),
    CardType.pattern: ArchetypeConfig(
      label: 'Pattern',
      icon: Icons.track_changes,
      color: Color(0xFF2563EB),
      backgroundColor: Color(0xFFEFF6FF),
      borderColor: Color(0xFFBFDBFE),
      description: 'Algorithmic patterns (Two Pointers, Sliding Window, DP)',
    ),
    CardType.cloze: ArchetypeConfig(
      label: 'Cloze Deletion',
      icon: Icons.extension,
      color: Color(0xFF059669),
      backgroundColor: Color(0xFFECFDF5),
      borderColor: Color(0xFFA7F3D0),
      description: 'Fill-in-the-blanks key terminology and code tokens',
    ),
    CardType.comparison: ArchetypeConfig(
      label: 'Comparison',
      icon: Icons.balance,
      color: Color(0xFF4F46E5),
      backgroundColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFC7D2FE),
      description: 'Side-by-side trade-offs between structures or algorithms',
    ),
    CardType.trace: ArchetypeConfig(
      label: 'Trace',
      icon: Icons.search,
      color: Color(0xFF0891B2),
      backgroundColor: Color(0xFFECFEFF),
      borderColor: Color(0xFFA5F3FC),
      description: 'Step-by-step state tracing through loop iterations',
    ),
    CardType.invariant: ArchetypeConfig(
      label: 'Invariant',
      icon: Icons.shield_outlined,
      color: Color(0xFF0D9488),
      backgroundColor: Color(0xFFF0FDFA),
      borderColor: Color(0xFF99F6E4),
      description: 'Loop invariants, structural properties, guard conditions',
    ),
    CardType.debugging: ArchetypeConfig(
      label: 'Debugging',
      icon: Icons.bug_report_outlined,
      color: Color(0xFFE11D48),
      backgroundColor: Color(0xFFFFF1F2),
      borderColor: Color(0xFFFECDD3),
      description: 'Identifying off-by-one errors, null checks, and bug fixes',
    ),
  CardType.implementation: ArchetypeConfig(
    label: 'Coding',
    icon: Icons.code,
    color: Color(0xFF0284C7),
    backgroundColor: Color(0xFFF0F9FF),
    borderColor: Color(0xFFBAE6FD),
    description: 'Code snippet implementation and syntax drills',
  ),
  CardType.explain: ArchetypeConfig(
    label: 'Explain',
    icon: Icons.history_edu,
    color: Color(0xFF7C3AED),
    backgroundColor: Color(0xFFF5F3FF),
    borderColor: Color(0xFFDDD6FE),
    description: 'Conceptual explanations graded by AI helper',
  ),
};
}

class Flashcard {
  final String id;
  final CardType type;
  final String front;
  final String back;
  final String? codeSnippet;
  final String? imageUrl;
  final String? sourceUrl;

  // SRS data
  final int nextReview; // milliseconds since epoch
  final int interval;
  final double ease;
  final int reps;
  
  // To track deck association in flatten views
  final String? deckId;
  final int createdAt;

  Flashcard({
    required this.id,
    required this.type,
    required this.front,
    required this.back,
    this.codeSnippet,
    this.imageUrl,
    this.sourceUrl,
    required this.nextReview,
    required this.interval,
    required this.ease,
    required this.reps,
    this.deckId,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Flashcard.fromJson(Map<String, dynamic> json, {String? deckId}) {
    return Flashcard(
      id: json['id'] as String,
      type: CardTypeExtension.fromString(json['type'] as String),
      front: json['front'] as String,
      back: json['back'] as String,
      codeSnippet: json['codeSnippet'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      nextReview: json['nextReview'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      interval: json['interval'] as int,
      ease: (json['ease'] as num).toDouble(),
      reps: json['reps'] as int,
      deckId: deckId,
      createdAt: json['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.stringValue,
      'front': front,
      'back': back,
      'codeSnippet': codeSnippet,
      'imageUrl': imageUrl,
      'sourceUrl': sourceUrl,
      'nextReview': nextReview,
      'interval': interval,
      'ease': ease,
      'reps': reps,
      'createdAt': createdAt,
    };
  }

  Flashcard copyWith({
    String? id,
    CardType? type,
    String? front,
    String? back,
    String? codeSnippet,
    String? imageUrl,
    String? sourceUrl,
    int? nextReview,
    int? interval,
    double? ease,
    int? reps,
    String? deckId,
  }) {
    return Flashcard(
      id: id ?? this.id,
      type: type ?? this.type,
      front: front ?? this.front,
      back: back ?? this.back,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      nextReview: nextReview ?? this.nextReview,
      interval: interval ?? this.interval,
      ease: ease ?? this.ease,
      reps: reps ?? this.reps,
      deckId: deckId ?? this.deckId,
      createdAt: createdAt,
    );
  }
}
