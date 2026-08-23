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
    try {
      final jsonList = decks.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(decksFile, jsonString);
      } else {
        final file = await _getLocalFile(decksFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving decks: $e');
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
    try {
      final jsonList = folders.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(foldersFile, jsonString);
      } else {
        final file = await _getLocalFile(foldersFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving folders: $e');
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
    try {
      final jsonList = lessons.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(lessonsFile, jsonString);
      } else {
        final file = await _getLocalFile(lessonsFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving lessons: $e');
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
    try {
      final jsonList = courses.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(coursesFile, jsonString);
      } else {
        final file = await _getLocalFile(coursesFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving courses: $e');
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
    try {
      final jsonList = logs.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(reviewsFile, jsonString);
      } else {
        final file = await _getLocalFile(reviewsFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving reviews: $e');
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
    try {
      final jsonList = logs.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(timeLogsFile, jsonString);
      } else {
        final file = await _getLocalFile(timeLogsFile);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving timelogs: $e');
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

  Future<String> getNoteTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('note_theme') ?? 'GitHub Light';
    } catch (_) {
      return 'GitHub Light';
    }
  }

  Future<void> saveNoteTheme(String theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('note_theme', theme);
    } catch (_) {}
  }

  Future<Map<String, String>> getCustomThemeStyles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('custom_theme_styles');
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(jsonStr);
          return decoded.map((key, value) => MapEntry(key, value.toString()));
        } catch (_) {}
      }
    } catch (_) {}
    return {
      'bg': '#ffffff',
      'text': '#24292f',
      'link': '#0969da',
      'border': '#d0d7de',
      'font_size': '16',
    };
  }

  Future<void> saveCustomThemeStyles(Map<String, String> styles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_theme_styles', jsonEncode(styles));
    } catch (_) {}
  }

  // --- Backup & Restore ---
  Future<String> generateBackupJson() async {
    final Map<String, dynamic> backup = {};

    // 1. SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> sharedPrefsBackup = {};
    for (final key in keys) {
      sharedPrefsBackup[key] = prefs.get(key);
    }
    backup['sharedPreferences'] = sharedPrefsBackup;

    // 2. Files in Documents Directory
    final docDir = await getApplicationDocumentsDirectory();
    final List<Map<String, dynamic>> filesBackup = [];

    final List<String> targetDirs = ['AlgoMaster', 'SelfUni_Notes'];
    for (final dirName in targetDirs) {
      final dir = Directory('${docDir.path}/$dirName');
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
        for (final entity in entities) {
          if (entity is File) {
            final String relativePath = entity.path
                .substring(docDir.path.length + 1)
                .replaceAll('\\', '/');
            
            final isBinary = _isFileBinary(entity);
            if (isBinary) {
              final bytes = await entity.readAsBytes();
              filesBackup.add({
                'path': relativePath,
                'content': base64Encode(bytes),
                'isBinary': true,
              });
            } else {
              final text = await entity.readAsString();
              filesBackup.add({
                'path': relativePath,
                'content': text,
                'isBinary': false,
              });
            }
          }
        }
      }
    }
    backup['files'] = filesBackup;

    return jsonEncode(backup);
  }

  bool _isFileBinary(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.json') || path.endsWith('.md') || path.endsWith('.txt') || path.endsWith('.html') || path.endsWith('.css')) {
      return false;
    }
    return true;
  }

  Future<void> restoreBackupJson(String jsonString) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);
      final docDir = await getApplicationDocumentsDirectory();
      
      // 1. SharedPreferences
      if (backup.containsKey('sharedPreferences')) {
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> spMap = backup['sharedPreferences'] as Map<String, dynamic>;
        for (final entry in spMap.entries) {
          final val = entry.value;
          if (val is String) {
            await prefs.setString(entry.key, val);
          } else if (val is int) {
            await prefs.setInt(entry.key, val);
          } else if (val is double) {
            await prefs.setDouble(entry.key, val);
          } else if (val is bool) {
            await prefs.setBool(entry.key, val);
          } else if (val is List) {
            await prefs.setStringList(entry.key, val.map((e) => e.toString()).toList());
          }
        }
      }

      // 2. Files
      if (backup.containsKey('files')) {
        final List<dynamic> filesList = backup['files'] as List;
        for (final item in filesList) {
          final fileMap = item as Map<String, dynamic>;
          final relativePath = fileMap['path'] as String;
          final content = fileMap['content'] as String;
          final isBinary = fileMap['isBinary'] as bool? ?? false;

          final targetFile = File('${docDir.path}/$relativePath');
          final parentDir = targetFile.parent;
          if (!await parentDir.exists()) {
            await parentDir.create(recursive: true);
          }

          if (isBinary) {
            final bytes = base64Decode(content);
            await targetFile.writeAsBytes(bytes);
          } else {
            await targetFile.writeAsString(content);
          }
        }
      }
    } catch (e) {
      print('Failed to restore backup: $e');
      rethrow;
    }
  }

  // --- Physical File & Directory Deletion Helpers ---
  static Future<void> deleteLocalFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    final trimmed = filePath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:')) {
      return;
    }

    try {
      String resolvedPath = trimmed;
      if (resolvedPath.startsWith('file://')) {
        try {
          resolvedPath = Uri.parse(resolvedPath).toFilePath();
        } catch (_) {
          resolvedPath = resolvedPath.replaceFirst(RegExp(r'^file://+'), '');
        }
      }

      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Permanently deleted local file: $resolvedPath');
      }
    } catch (e) {
      debugPrint('Error deleting local file ($filePath): $e');
    }
  }

  static Future<void> deleteDirectory(String? dirPath) async {
    if (dirPath == null || dirPath.trim().isEmpty) return;
    try {
      final dir = Directory(dirPath.trim());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('Permanently deleted directory: $dirPath');
      }
    } catch (e) {
      debugPrint('Error deleting directory ($dirPath): $e');
    }
  }
}
