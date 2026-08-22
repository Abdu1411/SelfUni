// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../models/deck_model.dart';
import '../../models/folder_model.dart';
import '../../models/lesson_model.dart';
import '../../models/course_model.dart';

class StorageService {
  static const String decksFile = 'algomaster_decks.json';
  static const String foldersFile = 'algomaster_folders.json';
  static const String lessonsFile = 'algomaster_lessons.json';
  static const String coursesFile = 'algomaster_courses.json';
  static const String reviewsFile = 'algomaster_reviews.json';
  static const String timeLogsFile = 'algomaster_timelogs.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final algoDir = Directory('${directory.path}/AlgoMaster');
    if (!await algoDir.exists()) {
      await algoDir.create();
    }
    return algoDir.path;
  }

  Future<File> _getLocalFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  // --- Decks ---
  Future<List<Deck>> loadDecks() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(decksFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Deck.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(decksFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Deck.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading decks: $e');
    }
    return [];
  }

  Future<void> saveDecks(List<Deck> decks) async {
    final jsonList = decks.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(decksFile, jsonString);
    } else {
      final file = await _getLocalFile(decksFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Folders ---
  Future<List<Folder>> loadFolders() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(foldersFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(foldersFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading folders: $e');
    }
    return [];
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final jsonList = folders.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(foldersFile, jsonString);
    } else {
      final file = await _getLocalFile(foldersFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Lessons ---
  Future<List<Lesson>> loadLessons() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(lessonsFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(lessonsFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading lessons: $e');
    }
    return [];
  }

  Future<void> saveLessons(List<Lesson> lessons) async {
    final jsonList = lessons.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lessonsFile, jsonString);
    } else {
      final file = await _getLocalFile(lessonsFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Courses ---
  Future<List<Course>> loadCourses() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(coursesFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(coursesFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading courses: $e');
    }
    return [];
  }

  Future<void> saveCourses(List<Course> courses) async {
    final jsonList = courses.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(coursesFile, jsonString);
    } else {
      final file = await _getLocalFile(coursesFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Review Logs ---
  Future<List<ReviewLog>> loadReviewLogs() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(reviewsFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => ReviewLog.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(reviewsFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => ReviewLog.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading reviews: $e');
    }
    return [];
  }

  Future<void> saveReviewLogs(List<ReviewLog> logs) async {
    final jsonList = logs.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(reviewsFile, jsonString);
    } else {
      final file = await _getLocalFile(reviewsFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Time Logs ---
  Future<List<TimeLog>> loadTimeLogs() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final contents = prefs.getString(timeLogsFile);
        if (contents != null) {
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => TimeLog.fromJson(e as Map<String, dynamic>)).toList();
        }
      } else {
        final file = await _getLocalFile(timeLogsFile);
        if (await file.exists()) {
          final contents = await file.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);
          return jsonList.map((e) => TimeLog.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading timelogs: $e');
    }
    return [];
  }

  Future<void> saveTimeLogs(List<TimeLog> logs) async {
    final jsonList = logs.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(timeLogsFile, jsonString);
    } else {
      final file = await _getLocalFile(timeLogsFile);
      await file.writeAsString(jsonString);
    }
  }

  // --- Preferences ---
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deepseek_api_key');
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', apiKey.trim());
  }

  // --- Backup & Restore ---
  Future<String> generateBackupJson() async {
    final decks = await loadDecks();
    final folders = await loadFolders();
    final lessons = await loadLessons();
    final courses = await loadCourses();
    final reviews = await loadReviewLogs();
    final timeLogs = await loadTimeLogs();

    final Map<String, dynamic> backup = {
      'decks': decks.map((e) => e.toJson()).toList(),
      'folders': folders.map((e) => e.toJson()).toList(),
      'lessons': lessons.map((e) => e.toJson()).toList(),
      'courses': courses.map((e) => e.toJson()).toList(),
      'reviews': reviews.map((e) => e.toJson()).toList(),
      'timeLogs': timeLogs.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(backup);
  }

  Future<void> restoreBackupJson(String jsonString) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);
      
      if (backup.containsKey('decks')) {
        await saveDecks((backup['decks'] as List).map((e) => Deck.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (backup.containsKey('folders')) {
        await saveFolders((backup['folders'] as List).map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (backup.containsKey('lessons')) {
        await saveLessons((backup['lessons'] as List).map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (backup.containsKey('courses')) {
        await saveCourses((backup['courses'] as List).map((e) => Course.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (backup.containsKey('reviews')) {
        await saveReviewLogs((backup['reviews'] as List).map((e) => ReviewLog.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (backup.containsKey('timeLogs')) {
        await saveTimeLogs((backup['timeLogs'] as List).map((e) => TimeLog.fromJson(e as Map<String, dynamic>)).toList());
      }
    } catch (e) {
      print('Failed to restore backup: $e');
      rethrow;
    }
  }
}
