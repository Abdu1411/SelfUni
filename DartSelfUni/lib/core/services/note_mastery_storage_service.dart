import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/lesson_model.dart';
import '../../models/note_mastery_model.dart';
import '../../models/course_model.dart';
import '../../models/folder_model.dart';

class NoteMasteryStorageService {
  static final NoteMasteryStorageService _instance = NoteMasteryStorageService._internal();
  factory NoteMasteryStorageService() => _instance;
  NoteMasteryStorageService._internal();

  static const String masteryFile = 'algomaster_note_mastery.json';
  static const String prefsMasteryKey = 'algomaster_note_mastery_data';

  // In-memory cache for ultra fast reads & reactive updates
  final Map<String, NoteMasteryModel> _cache = {};
  bool _isLoaded = false;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final algoDir = Directory('${directory.path}/AlgoMaster');
    if (!await algoDir.exists()) {
      await algoDir.create(recursive: true);
    }
    return algoDir.path;
  }

  Future<File> get _file async {
    final path = await _localPath;
    return File('$path/$masteryFile');
  }

  /// Loads all mastery records into cache from disk or SharedPreferences.
  Future<Map<String, NoteMasteryModel>> loadAllMasteries() async {
    if (_isLoaded) return Map.unmodifiable(_cache);

    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(prefsMasteryKey);
        if (content != null && content.isNotEmpty) {
          final Map<String, dynamic> decoded = jsonDecode(content);
          _populateCache(decoded);
        }
      } else {
        final file = await _file;
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(content);
            _populateCache(decoded);
          }
        }
      }
    } catch (_) {}

    _isLoaded = true;
    return Map.unmodifiable(_cache);
  }

  void _populateCache(Map<String, dynamic> data) {
    _cache.clear();
    for (final entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        _cache[entry.key] = NoteMasteryModel.fromJson(entry.value as Map<String, dynamic>);
      }
    }
  }

  /// Retrieves mastery for a specific note key (or creates a blank model if none exists).
  Future<NoteMasteryModel?> getNoteMastery(String noteKey) async {
    if (noteKey.trim().isEmpty) return null;
    await loadAllMasteries();
    return _cache[noteKey];
  }

  /// Returns the effective mastery percentage for a specific note key (0 if none recorded).
  Future<int> getEffectiveMasteryPercentage(String noteKey) async {
    if (noteKey.trim().isEmpty) return 0;
    final m = await getNoteMastery(noteKey);
    return m?.effectiveMasteryPercentage ?? 0;
  }

  /// Returns a map of all note keys to their effective mastery scores.
  Future<Map<String, int>> getAllEffectiveMasteryScores() async {
    await loadAllMasteries();
    return _cache.map((key, value) => MapEntry(key, value.effectiveMasteryPercentage));
  }

  /// Filters and returns a list of lessons that are considered "Due" (mastery < threshold, default 60%).
  /// Automatically excludes notes that originate from local courses.
  /// Sorted by urgency: lowest mastery score first.
  Future<List<Map<String, dynamic>>> getDueNotes(
    List<Lesson> lessons, {
    int threshold = 60,
    Iterable<Course>? courses,
    Iterable<Folder>? folders,
    Iterable<String>? excludedCourseTitles,
    Iterable<String>? excludedCourseIds,
  }) async {
    await loadAllMasteries();
    final List<Map<String, dynamic>> dueList = [];

    final normalizedExcludedTitles = excludedCourseTitles?.map((t) => t.toLowerCase().trim()).toSet() ?? <String>{};
    final normalizedExcludedIds = excludedCourseIds?.map((id) => id.toLowerCase().trim()).toSet() ?? <String>{};

    for (final lesson in lessons) {
      final isReviewable = lesson.isNote ||
          lesson.pdfUrl != null ||
          lesson.pdfFilename != null ||
          lesson.content.trim().isNotEmpty;
      if (!isReviewable) continue;

      // Exclude notes from local courses
      if (courses != null && lesson.isFromLocalCourse(courses, folders)) {
        continue;
      }
      final topic = lesson.topic.toLowerCase().trim();
      final folderId = lesson.folderId?.toLowerCase().trim() ?? '';
      if (normalizedExcludedTitles.contains(topic) ||
          normalizedExcludedIds.contains(folderId) ||
          normalizedExcludedIds.contains(lesson.id.toLowerCase().trim()) ||
          lesson.content.contains('Live course video stream for')) {
        continue;
      }

      final noteKey = lesson.id;
      final mastery = _cache[noteKey] ?? _cache[lesson.title];
      final score = mastery?.effectiveMasteryPercentage ?? 0;

      if (score < threshold) {
        dueList.add({
          'lesson': lesson,
          'noteKey': noteKey,
          'mastery': mastery,
          'score': score,
          'isDecayed': mastery != null && mastery.effectiveMasteryPercentage < mastery.rawMasteryPercentage,
          'isUnattempted': mastery == null,
        });
      }
    }

    // Sort: lowest score first, then unattempted / decayed
    dueList.sort((a, b) => (a['score'] as int).compareTo(b['score'] as int));
    return dueList;
  }

  /// Filters and returns a list of lessons that are considered "Mastered"
  /// (either explicitly graduated with consecutive >=90% scores or effective mastery >= 90%).
  Future<List<Map<String, dynamic>>> getMasteredNotes(
    List<Lesson> lessons, {
    Iterable<Course>? courses,
    Iterable<Folder>? folders,
    Iterable<String>? excludedCourseTitles,
    Iterable<String>? excludedCourseIds,
  }) async {
    await loadAllMasteries();
    final List<Map<String, dynamic>> masteredList = [];

    final normalizedExcludedTitles = excludedCourseTitles?.map((t) => t.toLowerCase().trim()).toSet() ?? <String>{};
    final normalizedExcludedIds = excludedCourseIds?.map((id) => id.toLowerCase().trim()).toSet() ?? <String>{};

    for (final lesson in lessons) {
      final isReviewable = lesson.isNote ||
          lesson.pdfUrl != null ||
          lesson.pdfFilename != null ||
          lesson.content.trim().isNotEmpty;
      if (!isReviewable) continue;

      // Exclude notes from local courses
      if (courses != null && lesson.isFromLocalCourse(courses, folders)) {
        continue;
      }
      final topic = lesson.topic.toLowerCase().trim();
      final folderId = lesson.folderId?.toLowerCase().trim() ?? '';
      if (normalizedExcludedTitles.contains(topic) ||
          normalizedExcludedIds.contains(folderId) ||
          normalizedExcludedIds.contains(lesson.id.toLowerCase().trim()) ||
          lesson.content.contains('Live course video stream for')) {
        continue;
      }

      final noteKey = lesson.id;
      final mastery = _cache[noteKey] ?? _cache[lesson.title];
      final score = mastery?.effectiveMasteryPercentage ?? 0;
      final isGraduated = mastery?.isGraduated ?? false;

      if (isGraduated || score >= 90) {
        masteredList.add({
          'lesson': lesson,
          'noteKey': noteKey,
          'mastery': mastery,
          'score': score,
          'isGraduated': isGraduated,
          'consecutiveHighScores': mastery?.consecutiveHighScores ?? 0,
        });
      }
    }

    // Sort: graduated first, then highest score
    masteredList.sort((a, b) {
      final aGrad = a['isGraduated'] as bool ? 1 : 0;
      final bGrad = b['isGraduated'] as bool ? 1 : 0;
      if (aGrad != bGrad) return bGrad.compareTo(aGrad);
      return (b['score'] as int).compareTo(a['score'] as int);
    });

    return masteredList;
  }

  /// Persists a note mastery record to cache, disk, and SharedPreferences.
  Future<void> saveNoteMastery(NoteMasteryModel mastery) async {
    if (mastery.noteKey.trim().isEmpty) return;
    await loadAllMasteries();

    _cache[mastery.noteKey] = mastery;

    try {
      final mapToSave = _cache.map((key, value) => MapEntry(key, value.toJson()));
      final jsonString = jsonEncode(mapToSave);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsMasteryKey, jsonString);

      if (!kIsWeb) {
        final file = await _file;
        await file.writeAsString(jsonString);
      }
    } catch (_) {}
  }

  /// Exports mastery records as raw JSON string for backups.
  Future<String> exportMasteryJson() async {
    await loadAllMasteries();
    final mapToSave = _cache.map((key, value) => MapEntry(key, value.toJson()));
    return jsonEncode(mapToSave);
  }

  /// Restores mastery records from JSON backup string.
  Future<void> importMasteryJson(String jsonString) async {
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      _populateCache(decoded);
      _isLoaded = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsMasteryKey, jsonString);

      if (!kIsWeb) {
        final file = await _file;
        await file.writeAsString(jsonString);
      }
    } catch (_) {}
  }

  /// Clears cache and files (used for testing and reset).
  @visibleForTesting
  void clearForTest() {
    _cache.clear();
    _isLoaded = true;
  }
}
