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
import '../core/services/notes_storage_service.dart';

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

  String _noteTheme = 'GitHub Light';
  Map<String, String> _customThemeStyles = {};

  String get noteTheme => _noteTheme;
  Map<String, String> get customThemeStyles => _customThemeStyles;

  Future<void> setNoteTheme(String theme) async {
    _noteTheme = theme;
    await _storageService.saveNoteTheme(theme);
    notifyListeners();
  }

  Future<void> setCustomThemeStyles(Map<String, String> styles) async {
    _customThemeStyles = styles;
    await _storageService.saveCustomThemeStyles(styles);
    notifyListeners();
  }

  DeckProvider() {
    _initData();
  }

  Future<void> _initData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _decks = await _storageService.loadDecks();
      _folders = await _storageService.loadFolders();
      _lessons = await _storageService.loadLessons();
      _courses = await _storageService.loadCourses();
      _reviews = await _storageService.loadReviewLogs();
      _timeLogs = await _storageService.loadTimeLogs();
      _noteTheme = await _storageService.getNoteTheme();
      _customThemeStyles = await _storageService.getCustomThemeStyles();

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
        // Sync cards in the Universal Deck
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

      // Two-way synchronization: Ensure all local courses with video items have matching folders & lessons
      bool foldersModified = false;
      bool lessonsModified = false;

      for (final course in _courses) {
        // Ensure course folder exists
        Folder? courseFolder = _folders.where((f) => f.id == course.id || f.name.toLowerCase() == course.title.toLowerCase()).firstOrNull;
        if (courseFolder == null) {
          courseFolder = Folder(id: course.id, name: course.title, color: '#3B82F6');
          _folders.add(courseFolder);
          foldersModified = true;
        }

        // Check if course has video items and sync them into _lessons
        for (final module in course.modules) {
          for (final item in module.items) {
            if (item.type == 'video' || (item.path != null && item.path!.isNotEmpty)) {
              final videoUrl = item.path ?? '';
              final exists = _lessons.any((l) =>
                l.id == item.id ||
                (l.videoUrl == videoUrl && videoUrl.isNotEmpty) ||
                (l.title.toLowerCase() == item.title.toLowerCase() && l.topic.toLowerCase() == course.title.toLowerCase())
              );

              if (!exists && videoUrl.isNotEmpty) {
                _lessons.add(Lesson(
                  id: item.id.isNotEmpty ? item.id : 'lec_${DateTime.now().millisecondsSinceEpoch}_${_lessons.length}',
                  title: item.title,
                  topic: course.title,
                  videoUrl: videoUrl,
                  sourceUrl: videoUrl,
                  folderId: courseFolder.id,
                  content: '# ${item.title}\n\nLive course video stream for ${course.title}.\n\nVideo URL: $videoUrl',
                  isNote: false,
                ));
                lessonsModified = true;
              }
            }
          }
        }
      }

      // Ensure all existing lessons with topics have an associated folder so they are visible
      for (final lesson in _lessons) {
        if (lesson.folderId == null || lesson.folderId == 'unfiled' || !_folders.any((f) => f.id == lesson.folderId)) {
          if (lesson.topic.isNotEmpty && lesson.topic != 'Unfiled' && lesson.topic != 'General') {
            Folder? matchingFolder = _folders.where((f) => f.name.toLowerCase() == lesson.topic.toLowerCase()).firstOrNull;
            if (matchingFolder == null) {
              matchingFolder = Folder(id: 'folder_${lesson.topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}', name: lesson.topic, color: '#3B82F6');
              _folders.add(matchingFolder);
              foldersModified = true;
            }
            lesson.folderId = matchingFolder.id;
            lessonsModified = true;
          }
        }
      }

      if (foldersModified) {
        await _storageService.saveFolders(_folders);
      }
      if (lessonsModified) {
        await _storageService.saveLessons(_lessons);
      }
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> purgeOrphanedData() async {
    final activeFolderIds = _folders.map((f) => f.id).toSet();
    
    // Clean up decks whose folderId is no longer in active folders
    final orphanedDecks = _decks.where((d) => d.id != 'universal' && d.folderId != null && !activeFolderIds.contains(d.folderId)).toList();
    for (final d in orphanedDecks) {
      for (final c in d.cards) {
        if (c.imageUrl != null && c.imageUrl!.isNotEmpty) {
          await StorageService.deleteLocalFile(c.imageUrl);
        }
      }
    }
    _decks.removeWhere((d) => d.id != 'universal' && d.folderId != null && !activeFolderIds.contains(d.folderId));
    
    // Clean up lessons whose folderId is no longer in active folders (if not unfiled)
    final orphanedLessons = _lessons.where((l) => l.folderId != null && l.folderId != 'unfiled' && !activeFolderIds.contains(l.folderId)).toList();
    for (final l in orphanedLessons) {
      await StorageService.deleteLocalFile(l.pdfUrl);
      await StorageService.deleteLocalFile(l.videoUrl);
      await StorageService.deleteLocalFile(l.imageUrl);
      if (l.multimedia != null) {
        for (final m in l.multimedia!) {
          await StorageService.deleteLocalFile(m.url);
        }
      }
    }

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
      
      // 1. Delete all card images permanently from internal storage
      for (final card in deck.cards) {
        if (card.imageUrl != null && card.imageUrl!.isNotEmpty) {
          await StorageService.deleteLocalFile(card.imageUrl);
        }
      }

      // 2. Remove cards from universal deck
      final univIdx = _decks.indexWhere((d) => d.id == 'universal');
      if (univIdx != -1) {
        _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
      }

      // 3. Remove reviews associated with this deck and its cards
      _reviews.removeWhere((r) => r.deckId == id || cardIdsToRemove.contains(r.cardId));
      await _storageService.saveReviewLogs(_reviews);
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
      final cardIndex = _decks[index].cards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        final card = _decks[index].cards[cardIndex];
        if (card.imageUrl != null && card.imageUrl!.isNotEmpty) {
          await StorageService.deleteLocalFile(card.imageUrl);
        }
        _decks[index].cards.removeAt(cardIndex);
      }
      
      // Also remove from universal deck
      final univIndex = _decks.indexWhere((d) => d.id == 'universal');
      if (univIndex != -1) {
        _decks[univIndex].cards.removeWhere((c) => c.id == cardId);
      }

      // Remove review logs for this card
      _reviews.removeWhere((r) => r.cardId == cardId);
      await _storageService.saveReviewLogs(_reviews);

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

      // Deleting the folder also cleans up matching local courses and their files
      final matchingCourses = _courses.where((c) {
        final cleanCourseTitle = c.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        return c.id == id || cleanCourseTitle == cleanFolderName;
      }).toList();

      for (final c in matchingCourses) {
        for (final module in c.modules) {
          for (final item in module.items) {
            await StorageService.deleteLocalFile(item.path);
            await StorageService.deleteLocalFile(item.fileKey);
          }
        }
        await StorageService.deleteLocalFile(c.coverImageUrl);
      }

      _courses.removeWhere((c) {
        final cleanCourseTitle = c.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        return c.id == id || cleanCourseTitle == cleanFolderName;
      });
      await _storageService.saveCourses(_courses);
    }

    // 3. Collect card IDs from all decks in this folder to remove from universal deck and delete card images
    final decksToDelete = _decks.where((d) => d.folderId == id).toList();
    final cardIdsToRemove = decksToDelete.expand((d) => d.cards).map((c) => c.id).toSet();
    for (final d in decksToDelete) {
      for (final c in d.cards) {
        if (c.imageUrl != null && c.imageUrl!.isNotEmpty) {
          await StorageService.deleteLocalFile(c.imageUrl);
        }
      }
    }

    final univIdx = _decks.indexWhere((d) => d.id == 'universal');
    if (univIdx != -1 && cardIdsToRemove.isNotEmpty) {
      _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
    }
    if (cardIdsToRemove.isNotEmpty) {
      _reviews.removeWhere((r) => cardIdsToRemove.contains(r.cardId));
      await _storageService.saveReviewLogs(_reviews);
    }

    // 4. Delete all lessons in this folder and remove their files permanently
    final lessonsToDelete = _lessons.where((l) => l.folderId == id).toList();
    for (final l in lessonsToDelete) {
      await StorageService.deleteLocalFile(l.pdfUrl);
      await StorageService.deleteLocalFile(l.videoUrl);
      await StorageService.deleteLocalFile(l.imageUrl);
      if (l.multimedia != null) {
        for (final m in l.multimedia!) {
          await StorageService.deleteLocalFile(m.url);
        }
      }
      await NotesStorageService.deleteNoteFromClass(className: l.topic, lectureTitle: l.title);
    }

    _decks.removeWhere((d) => d.folderId == id);
    _lessons.removeWhere((l) => l.folderId == id);
    _folders.removeWhere((f) => f.id == id);

    await _storageService.saveDecks(_decks);
    await _storageService.saveLessons(_lessons);
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
    if (lesson.isNote) {
      try {
        await NotesStorageService.appendNoteToClass(
          className: lesson.topic.isEmpty ? 'General' : lesson.topic,
          lectureTitle: lesson.title,
          noteContent: lesson.content,
        );
      } catch (e) {
        print('Error appending note to internal storage: $e');
      }
    }
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
    final lesson = _lessons.where((l) => l.id == id).firstOrNull;
    if (lesson != null) {
      // 1. Permanently delete physical files from internal storage
      await StorageService.deleteLocalFile(lesson.pdfUrl);
      await StorageService.deleteLocalFile(lesson.videoUrl);
      await StorageService.deleteLocalFile(lesson.imageUrl);
      if (lesson.multimedia != null) {
        for (final m in lesson.multimedia!) {
          await StorageService.deleteLocalFile(m.url);
        }
      }

      // 2. Remove / clean up note entry in SelfUni_Notes
      if (lesson.topic.isNotEmpty) {
        await NotesStorageService.deleteNoteFromClass(
          className: lesson.topic,
          lectureTitle: lesson.title,
        );
      }

      // 3. Remove corresponding video/note item from courses
      bool coursesModified = false;
      for (final course in _courses) {
        for (final module in course.modules) {
          final countBefore = module.items.length;
          module.items.removeWhere((item) {
            final isMatch = item.id == id ||
                (item.path != null && item.path == lesson.videoUrl && item.path!.isNotEmpty) ||
                (item.fileKey != null && item.fileKey == lesson.videoUrl && item.fileKey!.isNotEmpty);
            if (isMatch) {
              StorageService.deleteLocalFile(item.path);
              StorageService.deleteLocalFile(item.fileKey);
            }
            return isMatch;
          });
          if (module.items.length != countBefore) {
            coursesModified = true;
          }
        }
      }
      if (coursesModified) {
        await _storageService.saveCourses(_courses);
      }
    }

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
      final lesson = _lessons[index];
      final oldTitle = lesson.title;
      final newTitle = title.trim();

      lesson.title = newTitle;

      bool courseModified = false;
      for (var course in _courses) {
        for (var module in course.modules) {
          for (var i = 0; i < module.items.length; i++) {
            final item = module.items[i];
            final matches = item.id == lesson.id ||
                (item.path == lesson.videoUrl && lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) ||
                item.title == oldTitle;
            if (matches) {
              module.items[i] = item.copyWith(title: newTitle);
              courseModified = true;
            }
          }
        }
      }

      if (courseModified) {
        await _storageService.saveCourses(_courses);
      }

      await _storageService.saveLessons(_lessons);
      notifyListeners();
    }
  }

  Future<void> updateLesson(Lesson lesson) async {
    final index = _lessons.indexWhere((l) => l.id == lesson.id);
    if (index != -1) {
      final oldLesson = _lessons[index];
      final oldTitle = oldLesson.title;
      final newTitle = lesson.title;

      _lessons[index] = lesson;

      if (oldTitle != newTitle && newTitle.trim().isNotEmpty) {
        bool courseModified = false;
        for (var course in _courses) {
          for (var module in course.modules) {
            for (var i = 0; i < module.items.length; i++) {
              final item = module.items[i];
              final matches = item.id == lesson.id ||
                  (item.path == lesson.videoUrl && lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) ||
                  item.title == oldTitle;
              if (matches) {
                module.items[i] = item.copyWith(title: newTitle);
                courseModified = true;
              }
            }
          }
        }
        if (courseModified) {
          await _storageService.saveCourses(_courses);
        }
      }

      if (lesson.isNote) {
        try {
          // Sync with physical file system inside SelfUni_Notes
          await NotesStorageService.deleteNoteFromClass(
            className: oldLesson.topic.isEmpty ? 'General' : oldLesson.topic,
            lectureTitle: oldTitle,
          );
          await NotesStorageService.appendNoteToClass(
            className: lesson.topic.isEmpty ? 'General' : lesson.topic,
            lectureTitle: lesson.title,
            noteContent: lesson.content,
          );
        } catch (e) {
          print('Error updating note in internal storage: $e');
        }
      }

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

  Future<void> restoreBackup(String jsonString) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.restoreBackupJson(jsonString);
      _decks = await _storageService.loadDecks();
      _folders = await _storageService.loadFolders();
      _lessons = await _storageService.loadLessons();
      _courses = await _storageService.loadCourses();
      _reviews = await _storageService.loadReviewLogs();
      _timeLogs = await _storageService.loadTimeLogs();
      _noteTheme = await _storageService.getNoteTheme();
      _customThemeStyles = await _storageService.getCustomThemeStyles();
    } catch (e) {
      print('Failed to restore backup: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String id, {bool deleteFolderToo = true}) async {
    final course = _courses.where((c) => c.id == id).firstOrNull;
    if (course != null) {
      final courseTitle = course.title;
      final cleanCourseTitle = courseTitle.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

      // 1. Delete physical files from course items and cover image
      for (final module in course.modules) {
        for (final item in module.items) {
          await StorageService.deleteLocalFile(item.path);
          await StorageService.deleteLocalFile(item.fileKey);
        }
      }
      await StorageService.deleteLocalFile(course.coverImageUrl);

      final Set<String> foldersToDeleteIds = {};
      final Set<String> matchedFolderIds = {course.id};

      if (deleteFolderToo) {
        final matchingFolders = _folders.where((f) {
          final cleanFolderName = f.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          return f.id == id || cleanFolderName == cleanCourseTitle;
        }).toList();
        
        for (final folder in matchingFolders) {
          // Check if this folder contains at least one notes file (Lesson with isNote == true or edited content)
          final folderLessons = _lessons.where((l) => l.folderId == folder.id).toList();
          bool hasNotes = false;
          for (final l in folderLessons) {
            if (l.isNote) {
              hasNotes = true;
              break;
            }
            if (l.content.trim().isNotEmpty && 
                !l.content.contains('Live course video stream for') && 
                !l.content.contains('Live course video stream')) {
              hasNotes = true;
              break;
            }
          }

          if (!hasNotes) {
            // Folder is empty of notes, we can delete it
            foldersToDeleteIds.add(folder.id);
            matchedFolderIds.add(folder.id);
            
            // Delete notes directory on disk only if it is empty
            if (await NotesStorageService.isClassNotesFolderEmpty(folder.name)) {
              await NotesStorageService.deleteClassNotesFolder(folder.name);
            }
          }
        }

        // Delete notes directory for this course on disk only if it is empty
        if (await NotesStorageService.isClassNotesFolderEmpty(courseTitle)) {
          await NotesStorageService.deleteClassNotesFolder(courseTitle);
        }
      }

      // 3. Collect & delete decks in this course/folder ONLY for deleted folders
      final decksToDelete = _decks.where((d) => d.folderId != null && matchedFolderIds.contains(d.folderId) && (foldersToDeleteIds.contains(d.folderId) || d.folderId == course.id)).toList();
      final cardIdsToRemove = decksToDelete.expand((d) => d.cards).map((c) => c.id).toSet();
      for (final d in decksToDelete) {
        for (final c in d.cards) {
          if (c.imageUrl != null && c.imageUrl!.isNotEmpty) {
            await StorageService.deleteLocalFile(c.imageUrl);
          }
        }
      }
      final univIdx = _decks.indexWhere((d) => d.id == 'universal');
      if (univIdx != -1 && cardIdsToRemove.isNotEmpty) {
        _decks[univIdx].cards.removeWhere((c) => cardIdsToRemove.contains(c.id));
      }
      if (cardIdsToRemove.isNotEmpty) {
        _reviews.removeWhere((r) => cardIdsToRemove.contains(r.cardId));
        await _storageService.saveReviewLogs(_reviews);
      }

      // 4. Collect & delete lessons in this course/folder ONLY for deleted folders
      final lessonsToDelete = _lessons.where((l) {
        if (l.folderId != null && matchedFolderIds.contains(l.folderId)) {
          return foldersToDeleteIds.contains(l.folderId) || l.folderId == course.id;
        }
        final cleanTopic = l.topic.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        return cleanTopic == cleanCourseTitle && foldersToDeleteIds.isNotEmpty;
      }).toList();

      for (final l in lessonsToDelete) {
        await StorageService.deleteLocalFile(l.pdfUrl);
        await StorageService.deleteLocalFile(l.videoUrl);
        await StorageService.deleteLocalFile(l.imageUrl);
        if (l.multimedia != null) {
          for (final m in l.multimedia!) {
            await StorageService.deleteLocalFile(m.url);
          }
        }
      }

      final lessonIdsToRemove = lessonsToDelete.map((l) => l.id).toSet();
      _lessons.removeWhere((l) => lessonIdsToRemove.contains(l.id));

      if (deleteFolderToo) {
        _folders.removeWhere((f) => foldersToDeleteIds.contains(f.id));
        _decks.removeWhere((d) => d.folderId != null && foldersToDeleteIds.contains(d.folderId));
      }

      await _storageService.saveFolders(_folders);
      await _storageService.saveDecks(_decks);
      await _storageService.saveLessons(_lessons);
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
