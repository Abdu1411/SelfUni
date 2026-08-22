import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../models/deck_model.dart';
import '../../models/folder_model.dart';
import '../../models/lesson_model.dart';
import '../../models/course_model.dart';
import '../../models/card_model.dart';
import '../core/services/storage_service.dart';

class DeckProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<Deck> _decks = [];
  List<Folder> _folders = [];
  List<Lesson> _lessons = [];
  List<Course> _courses = [];
  List<ReviewLog> _reviews = [];
  List<TimeLog> _timeLogs = [];

  bool _isLoading = true;

  List<Deck> get decks => _decks.where((d) => d.id != 'universal').toList();
  Deck? get universalDeck {
    final list = _decks.where((d) => d.id == 'universal').toList();
    return list.isNotEmpty ? list.first : null;
  }
  List<Folder> get folders => _folders;
  List<Lesson> get lessons => _lessons;
  List<Course> get courses => _courses;
  List<ReviewLog> get reviews => _reviews;
  List<TimeLog> get timeLogs => _timeLogs;
  bool get isLoading => _isLoading;

  DeckProvider() {
    _initData();
  }

  Future<void> _initData() async {
    _isLoading = true;
    notifyListeners();

    _decks = await _storageService.loadDecks();
    _folders = await _storageService.loadFolders();
    _lessons = await _storageService.loadLessons();
    _courses = await _storageService.loadCourses();
    _reviews = await _storageService.loadReviewLogs();
    _timeLogs = await _storageService.loadTimeLogs();

    // Verify or create the master Universal Deck
    final hasUniversal = _decks.any((d) => d.id == 'universal');
    if (!hasUniversal) {
      final initialCards = _decks.expand((d) => d.cards).map((c) => c.copyWith(deckId: 'universal')).toList();
      _decks.add(Deck(
        id: 'universal',
        title: 'Universal Deck',
        cards: initialCards,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await _storageService.saveDecks(_decks);
    } else {
      // Sync/purge orphaned cards from the Universal Deck that no longer exist in any other active deck
      final activeCardIds = _decks.where((d) => d.id != 'universal').expand((d) => d.cards).map((c) => c.id).toSet();
      final univIdx = _decks.indexWhere((d) => d.id == 'universal');
      if (univIdx != -1) {
        final originalCount = _decks[univIdx].cards.length;
        _decks[univIdx].cards.removeWhere((c) => !activeCardIds.contains(c.id));
        if (_decks[univIdx].cards.length != originalCount) {
          await _storageService.saveDecks(_decks);
        }
      }
    }

    // Auto-clean orphaned lessons & decks if no matching folder or course exists
    final activeFolderIds = _folders.map((f) => f.id).toSet();
    final activeCourseTitles = _courses.map((c) => c.title.toLowerCase()).toSet();
    
    _lessons.removeWhere((l) {
      final hasFolder = l.folderId != null && l.folderId != 'unfiled' && activeFolderIds.contains(l.folderId);
      final hasCourse = activeCourseTitles.contains(l.topic.toLowerCase());
      return !hasFolder && !hasCourse;
    });

    final originalDecksCount = _decks.length;
    _decks.removeWhere((d) => d.id != 'universal' && d.folderId != null && !activeFolderIds.contains(d.folderId));
    
    // Sync Universal Deck if any orphaned decks were removed
    final activeCardIdsAfter = _decks.where((d) => d.id != 'universal').expand((d) => d.cards).map((c) => c.id).toSet();
    final univIdxAfter = _decks.indexWhere((d) => d.id == 'universal');
    if (univIdxAfter != -1) {
      _decks[univIdxAfter].cards.removeWhere((c) => !activeCardIdsAfter.contains(c.id));
    }

    if (_decks.length != originalDecksCount) {
      await _storageService.saveDecks(_decks);
    }
    await _storageService.saveLessons(_lessons);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> purgeOrphanedData() async {
    final activeFolderIds = _folders.map((f) => f.id).toSet();
    final activeCourseTitles = _courses.map((c) => c.title.toLowerCase()).toSet();
    
    _lessons.removeWhere((l) {
      final hasFolder = l.folderId != null && l.folderId != 'unfiled' && activeFolderIds.contains(l.folderId);
      final hasCourse = activeCourseTitles.contains(l.topic.toLowerCase());
      return !hasFolder && !hasCourse;
    });

    // Clean up decks whose folderId is no longer in active folders
    _decks.removeWhere((d) => d.id != 'universal' && d.folderId != null && !activeFolderIds.contains(d.folderId));
    
    // Sync Universal Deck
    final activeCardIds = _decks.where((d) => d.id != 'universal').expand((d) => d.cards).map((c) => c.id).toSet();
    final univIdx = _decks.indexWhere((d) => d.id == 'universal');
    if (univIdx != -1) {
      _decks[univIdx].cards.removeWhere((c) => !activeCardIds.contains(c.id));
    }

    await _storageService.saveDecks(_decks);
    await _storageService.saveLessons(_lessons);
    notifyListeners();
  }

  // --- Decks ---
  Future<void> addDeck(Deck deck) async {
    _decks.add(deck);
    
    // Also copy all cards of this new deck to universal deck
    final univIndex = _decks.indexWhere((d) => d.id == 'universal');
    if (univIndex != -1) {
      for (var card in deck.cards) {
        if (!_decks[univIndex].cards.any((c) => c.id == card.id)) {
          _decks[univIndex].cards.add(card.copyWith(deckId: 'universal'));
        }
      }
    }
    
    await _storageService.saveDecks(_decks);
    notifyListeners();
  }

  Future<void> deleteDeck(String id) async {
    final deck = _decks.where((d) => d.id == id).firstOrNull;
    if (deck != null) {
      final cardIdsToRemove = deck.cards.map((c) => c.id).toSet();
      final univIdx = _decks.indexWhere((d) => d.id == 'universal');
      if (univIdx != -1) {
        _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
      }
    }
    _decks.removeWhere((d) => d.id == id);
    await _storageService.saveDecks(_decks);
    notifyListeners();
  }

  Future<void> updateDeck(Deck deck) async {
    final index = _decks.indexWhere((d) => d.id == deck.id);
    if (index != -1) {
      _decks[index] = deck;
      
      // Sync update to universal copies
      final univIndex = _decks.indexWhere((d) => d.id == 'universal');
      if (univIndex != -1) {
        for (var card in deck.cards) {
          final uCardIndex = _decks[univIndex].cards.indexWhere((c) => c.id == card.id);
          if (uCardIndex != -1) {
            _decks[univIndex].cards[uCardIndex] = card.copyWith(deckId: 'universal');
          } else {
            _decks[univIndex].cards.add(card.copyWith(deckId: 'universal'));
          }
        }
      }
      
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  Future<void> renameDeck(String deckId, String title) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1 && title.trim().isNotEmpty) {
      _decks[index].title = title.trim();
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  Future<void> resetDeckProgress(String deckId) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _decks[index].cards = _decks[index].cards.map((card) => card.copyWith(
        interval: 0,
        ease: 2.5,
        reps: 0,
        nextReview: now,
      )).toList();
      
      // Also reset copies in universal deck
      final univIndex = _decks.indexWhere((d) => d.id == 'universal');
      if (univIndex != -1) {
        for (var card in _decks[index].cards) {
          final uCardIndex = _decks[univIndex].cards.indexWhere((c) => c.id == card.id);
          if (uCardIndex != -1) {
            _decks[univIndex].cards[uCardIndex] = _decks[univIndex].cards[uCardIndex].copyWith(
              interval: 0,
              ease: 2.5,
              reps: 0,
              nextReview: now,
            );
          }
        }
      }
      
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  // --- Cards ---
  Future<void> addCardToDeck(String deckId, Flashcard card) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      _decks[index].cards.add(card);
      
      // Also copy this card to universal deck
      final univIndex = _decks.indexWhere((d) => d.id == 'universal');
      if (univIndex != -1) {
        if (!_decks[univIndex].cards.any((c) => c.id == card.id)) {
          _decks[univIndex].cards.add(card.copyWith(deckId: 'universal'));
        }
      }
      
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  Future<void> updateCard(String? deckId, Flashcard card) async {
    // 1. Update in the original deck (excluding universal)
    for (int i = 0; i < _decks.length; i++) {
      if (_decks[i].id != 'universal') {
        final cardIndex = _decks[i].cards.indexWhere((c) => c.id == card.id);
        if (cardIndex != -1) {
          _decks[i].cards[cardIndex] = card.copyWith(deckId: _decks[i].id);
          break;
        }
      }
    }

    // 2. Update in the universal deck
    final univIndex = _decks.indexWhere((d) => d.id == 'universal');
    if (univIndex != -1) {
      final cardIndex = _decks[univIndex].cards.indexWhere((c) => c.id == card.id);
      if (cardIndex != -1) {
        _decks[univIndex].cards[cardIndex] = card.copyWith(deckId: 'universal');
      } else {
        _decks[univIndex].cards.add(card.copyWith(deckId: 'universal'));
      }
    }

    await _storageService.saveDecks(_decks);
    notifyListeners();
  }

  Future<void> deleteCardFromDeck(String deckId, String cardId) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      _decks[index].cards.removeWhere((c) => c.id == cardId);
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  // --- Folders ---
  Future<Folder> addFolder(String name, {String? color}) async {
    final newFolder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      color: color ?? '#2563eb',
    );
    _folders.add(newFolder);
    await _storageService.saveFolders(_folders);
    notifyListeners();
    return newFolder;
  }

  Future<void> updateFolder(String id, String name, {String? color}) async {
    final index = _folders.indexWhere((f) => f.id == id);
    if (index != -1) {
      _folders[index].name = name.trim();
      if (color != null) _folders[index].color = color;
      await _storageService.saveFolders(_folders);
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String id, {bool deleteDecksInside = false}) async {
    final folder = _folders.where((f) => f.id == id).firstOrNull;
    if (folder != null) {
      final folderName = folder.name;
      final cleanFolderName = folderName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

      // Deleting the folder also deletes the matching local course (vice versa)
      _courses.removeWhere((c) {
        final cleanCourseTitle = c.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        return c.id == id || cleanCourseTitle == cleanFolderName;
      });
      await _storageService.saveCourses(_courses);
    }

    // Collect card IDs from all decks in this folder to remove from universal deck
    final decksToDelete = _decks.where((d) => d.folderId == id).toList();
    final cardIdsToRemove = decksToDelete.expand((d) => d.cards).map((c) => c.id).toSet();
    final univIdx = _decks.indexWhere((d) => d.id == 'universal');
    if (univIdx != -1 && cardIdsToRemove.isNotEmpty) {
      _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
    }

    if (deleteDecksInside) {
      _decks.removeWhere((d) => d.folderId == id);
      _lessons.removeWhere((l) => l.folderId == id);
      await _storageService.saveDecks(_decks);
      await _storageService.saveLessons(_lessons);
    } else {
      // Deleting a live lecture folder should also clean up its lessons/videos
      _decks.removeWhere((d) => d.folderId == id);
      _lessons.removeWhere((l) => l.folderId == id);
      await _storageService.saveDecks(_decks);
      await _storageService.saveLessons(_lessons);
    }
    _folders.removeWhere((f) => f.id == id);
    await _storageService.saveFolders(_folders);
    notifyListeners();
  }

  Future<void> moveDeckToFolder(String deckId, String? folderId) async {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      _decks[index].folderId = folderId;
      await _storageService.saveDecks(_decks);
      notifyListeners();
    }
  }

  Future<void> moveLessonToFolder(String lessonId, String? folderId) async {
    final index = _lessons.indexWhere((l) => l.id == lessonId);
    if (index != -1) {
      _lessons[index].folderId = folderId;
      await _storageService.saveLessons(_lessons);
      notifyListeners();
    }
  }

  // --- Lessons ---
  Future<void> addLesson(Lesson lesson) async {
    _lessons.add(lesson);
    await _storageService.saveLessons(_lessons);
    notifyListeners();
  }

  Future<Lesson?> importPdfLesson(String path, String filename) async {
    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) return null;

      final directory = await getApplicationDocumentsDirectory();
      final pdfsDir = Directory('${directory.path}/AlgoMaster/pdfs');
      if (!await pdfsDir.exists()) {
        await pdfsDir.create(recursive: true);
      }

      final newId = const Uuid().v4();
      final newPath = '${pdfsDir.path}/$newId.pdf';
      await sourceFile.copy(newPath);

      final lesson = Lesson(
        id: 'lesson_$newId',
        title: filename.replaceAll('.pdf', ''),
        topic: 'PDF Document',
        content: '',
        pdfUrl: newPath,
        pdfFilename: filename,
      );

      _lessons.add(lesson);
      await _storageService.saveLessons(_lessons);
      notifyListeners();
      return lesson;
    } catch (e) {
      if (kDebugMode) {
        print('Error importing PDF: $e');
      }
      return null;
    }
  }

  Future<void> deleteLesson(String id) async {
    _lessons.removeWhere((l) => l.id == id);
    await _storageService.saveLessons(_lessons);
    notifyListeners();
  }

  Future<void> addLessonsBulk(List<Lesson> newLessons) async {
    _lessons.addAll(newLessons);
    await _storageService.saveLessons(_lessons);
    notifyListeners();
  }

  Future<void> renameLesson(String id, String title) async {
    final index = _lessons.indexWhere((l) => l.id == id);
    if (index != -1 && title.trim().isNotEmpty) {
      _lessons[index].title = title.trim();
      await _storageService.saveLessons(_lessons);
      notifyListeners();
    }
  }

  Future<void> updateLesson(Lesson lesson) async {
    final index = _lessons.indexWhere((l) => l.id == lesson.id);
    if (index != -1) {
      _lessons[index] = lesson;
      await _storageService.saveLessons(_lessons);
      notifyListeners();
    }
  }

  // --- Courses ---
  Future<void> addCourse(Course course) async {
    _courses.add(course);
    await _storageService.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> updateCourse(Course course) async {
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
      await _storageService.saveCourses(_courses);
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String id, {bool deleteFolderToo = true}) async {
    final course = _courses.where((c) => c.id == id).firstOrNull;
    if (course != null) {
      final courseTitle = course.title;
      final cleanCourseTitle = courseTitle.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

      final matchingFolderIds = {course.id};
      if (deleteFolderToo) {
        final matchingFolders = _folders.where((f) {
          final cleanFolderName = f.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          return f.id == id || cleanFolderName == cleanCourseTitle;
        }).toList();
        matchingFolderIds.addAll(matchingFolders.map((f) => f.id));
      }

      // Collect card IDs from all decks corresponding to these folders/courses to remove from universal deck
      final decksToDelete = _decks.where((d) => d.folderId != null && matchingFolderIds.contains(d.folderId)).toList();
      final cardIdsToRemove = decksToDelete.expand((d) => d.cards).map((c) => c.id).toSet();
      final univIdx = _decks.indexWhere((d) => d.id == 'universal');
      if (univIdx != -1 && cardIdsToRemove.isNotEmpty) {
        _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
      }

      if (deleteFolderToo) {
        final matchingFolders = _folders.where((f) {
          final cleanFolderName = f.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          return f.id == id || cleanFolderName == cleanCourseTitle;
        }).toList();

        for (var folder in matchingFolders) {
          _folders.removeWhere((f) => f.id == folder.id);
          _decks.removeWhere((d) => d.folderId == folder.id);
          _lessons.removeWhere((l) => l.folderId == folder.id);
        }

        // Also delete note pages created under this course title/topic
        _lessons.removeWhere((l) {
          final cleanTopic = l.topic.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          return cleanTopic == cleanCourseTitle;
        });

        await _storageService.saveFolders(_folders);
        await _storageService.saveDecks(_decks);
        await _storageService.saveLessons(_lessons);
      }
    }
    _courses.removeWhere((c) => c.id == id);
    await _storageService.saveCourses(_courses);
    notifyListeners();
  }

  // --- Reviews & Logs ---
  Future<void> logReview(String deckId, String cardId, String grade) async {
    _reviews.add(ReviewLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deckId: deckId,
      cardId: cardId,
      grade: grade,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    await _storageService.saveReviewLogs(_reviews);
    notifyListeners();
  }

  Future<void> logStudyTime(int durationSeconds) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final index = _timeLogs.indexWhere((l) => l.date == today);
    if (index != -1) {
      final updatedLog = TimeLog(
        id: _timeLogs[index].id,
        date: today,
        durationSeconds: _timeLogs[index].durationSeconds + durationSeconds,
      );
      _timeLogs[index] = updatedLog;
    } else {
      _timeLogs.add(TimeLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: today,
        durationSeconds: durationSeconds,
      ));
    }
    await _storageService.saveTimeLogs(_timeLogs);
    notifyListeners();
  }

  // Reset all study statistics and review logs
  Future<void> resetAllStats() async {
    _reviews.clear();
    await _storageService.saveReviewLogs(_reviews);

    for (var i = 0; i < _decks.length; i++) {
      _decks[i].cards = _decks[i].cards.map((card) {
        return card.copyWith(
          interval: 0,
          ease: 2.5,
          reps: 0,
          nextReview: DateTime.now().millisecondsSinceEpoch,
        );
      }).toList();
    }
    await _storageService.saveDecks(_decks);
    notifyListeners();
  }

  StatsData getStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;

    // Calculate Streak
    int streak = 0;
    final reviewDays = _reviews.map((r) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    }).toSet();

    if (reviewDays.isNotEmpty) {
      for (int i = 0; i < 365; i++) {
        final checkDay = today - (i * dayMs);
        if (reviewDays.contains(checkDay)) {
          streak++;
        } else if (i == 0) {
          // it's okay if they haven't studied yet today
          continue;
        } else {
          break;
        }
      }
    }

    // Calculate Weekly Velocity (Last 7 Days)
    final weekDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final List<Map<String, dynamic>> sortedWeekData = [];
    for (int i = 6; i >= 0; i--) {
      final targetDate = DateTime.fromMillisecondsSinceEpoch(today - (i * dayMs));
      sortedWeekData.add({
        'day': weekDayNames[targetDate.weekday == 7 ? 0 : targetDate.weekday],
        'cardsReviewed': 0,
        'timestamp': targetDate.millisecondsSinceEpoch,
      });
    }

    int weeklyVelocity = 0;
    for (var r in _reviews) {
      if (r.timestamp >= today - (6 * dayMs)) {
        weeklyVelocity++;
        final rDate = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final rDayStart = DateTime(rDate.year, rDate.month, rDate.day).millisecondsSinceEpoch;
        final binIndex = sortedWeekData.indexWhere((w) => w['timestamp'] == rDayStart);
        if (binIndex != -1) {
          sortedWeekData[binIndex]['cardsReviewed'] = (sortedWeekData[binIndex]['cardsReviewed'] as int) + 1;
        }
      }
    }

    // Calculate Mastery per deck
    final List<Map<String, dynamic>> masteryData = [];
    for (var deck in _decks) {
      final cards = deck.cards;
      final totalCards = cards.length;
      if (totalCards == 0) {
        masteryData.add({
          'subject': deck.title.length > 12 ? deck.title.substring(0, 12) : deck.title,
          'level': 0,
          'fullMark': 100,
        });
        continue;
      }

      double totalScore = 0;
      for (var card in cards) {
        if (card.reps == 0) continue;
        final easeScore = ((card.ease / 3.0) * 100).clamp(0.0, 100.0);
        final repScore = (card.reps * 10).clamp(0, 100).toDouble();
        totalScore += (easeScore * 0.7) + (repScore * 0.3);
      }

      masteryData.add({
        'subject': deck.title.length > 10 ? deck.title.substring(0, 10) : deck.title,
        'level': (totalScore / totalCards).round(),
        'fullMark': 100,
      });
    }
    masteryData.take(6).toList();

    while (masteryData.length < 3) {
      masteryData.add({'subject': '---', 'level': 0, 'fullMark': 100});
    }

    // Study Time
    int totalStudyTimeToday = 0;
    int totalStudyTimeWeek = 0;

    for (var log in _timeLogs) {
      if (log.date == today) {
        totalStudyTimeToday += log.durationSeconds;
      }
      if (log.date >= today - (6 * dayMs)) {
        totalStudyTimeWeek += log.durationSeconds;
      }
    }

    return StatsData(
      streak: streak,
      weeklyVelocity: weeklyVelocity,
      activityData: sortedWeekData,
      masteryData: masteryData,
      totalStudyTimeToday: totalStudyTimeToday,
      totalStudyTimeWeek: totalStudyTimeWeek,
    );
  }
}

class StatsData {
  final int streak;
  final int weeklyVelocity;
  final List<Map<String, dynamic>> activityData;
  final List<Map<String, dynamic>> masteryData;
  final int totalStudyTimeToday;
  final int totalStudyTimeWeek;

  StatsData({
    required this.streak,
    required this.weeklyVelocity,
    required this.activityData,
    required this.masteryData,
    required this.totalStudyTimeToday,
    required this.totalStudyTimeWeek,
  });
}
