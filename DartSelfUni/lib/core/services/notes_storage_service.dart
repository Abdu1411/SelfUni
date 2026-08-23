import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class NotesStorageService {
  /// Appends a new AI-generated note to a class-specific markdown file.
  ///
  /// The file is stored in the application's document directory under:
  /// `SelfUni_Notes/[className]/master_notes.md`
  static Future<void> appendNoteToClass({
    required String className,
    required String lectureTitle,
    required String noteContent,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();

      // Sanitize the class name to make it a valid folder name
      final safeClassName = className
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      if (safeClassName.isEmpty) {
        throw Exception('Invalid class name provided for note storage.');
      }

      final classFolder = Directory(
        '${docDir.path}/SelfUni_Notes/$safeClassName',
      );
      if (!await classFolder.exists()) {
        await classFolder.create(recursive: true);
      }

      final notesFile = File('${classFolder.path}/master_notes.md');

      final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      final formattedHeader = '''

---
## 📅 $timestamp | Lecture: $lectureTitle
''';

      await notesFile.writeAsString(
        '$formattedHeader$noteContent\n',
        mode: FileMode.append,
        flush: true,
      );

      debugPrint('Note successfully appended to: ${notesFile.path}');
    } catch (e) {
      debugPrint('Error saving note: $e');
      throw Exception('Failed to save note to local file: $e');
    }
  }

  /// Permanently deletes an entire class notes directory from internal storage.
  static Future<void> deleteClassNotesFolder(String className) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final safeClassName = className
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      if (safeClassName.isEmpty) return;

      final classFolder = Directory('${docDir.path}/SelfUni_Notes/$safeClassName');
      if (await classFolder.exists()) {
        await classFolder.delete(recursive: true);
        debugPrint('Permanently deleted notes directory: ${classFolder.path}');
      }

      final underscoreName = safeClassName.replaceAll(' ', '_');
      if (underscoreName != safeClassName) {
        final altFolder = Directory('${docDir.path}/SelfUni_Notes/$underscoreName');
        if (await altFolder.exists()) {
          await altFolder.delete(recursive: true);
          debugPrint('Permanently deleted notes directory: ${altFolder.path}');
        }
      }
    } catch (e) {
      debugPrint('Error deleting class notes directory for $className: $e');
    }
  }

  /// Permanently removes a specific lecture note from master_notes.md on internal storage.
  static Future<void> deleteNoteFromClass({
    required String className,
    required String lectureTitle,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final safeClassName = className
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      if (safeClassName.isEmpty) return;

      var classFolder = Directory('${docDir.path}/SelfUni_Notes/$safeClassName');
      if (!await classFolder.exists()) {
        final altFolder = Directory('${docDir.path}/SelfUni_Notes/${safeClassName.replaceAll(' ', '_')}');
        if (await altFolder.exists()) {
          classFolder = altFolder;
        } else {
          return;
        }
      }

      final notesFile = File('${classFolder.path}/master_notes.md');
      if (!await notesFile.exists()) return;

      final content = await notesFile.readAsString();
      if (content.isEmpty) {
        await notesFile.delete();
        final remaining = classFolder.listSync();
        if (remaining.isEmpty) {
          await classFolder.delete();
        }
        return;
      }

      // Parse notes blocks and filter out the target lecture note
      final lines = content.split('\n');
      final remainingBlocks = <String>[];
      final currentBlock = StringBuffer();
      bool inTargetLecture = false;

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('##') && trimmedLine.contains('Lecture:')) {
          if (currentBlock.isNotEmpty && !inTargetLecture) {
            remainingBlocks.add(currentBlock.toString());
          }
          currentBlock.clear();
          final lectureNamePart = trimmedLine.split('Lecture:').last.trim();
          inTargetLecture = lectureNamePart.toLowerCase() == lectureTitle.trim().toLowerCase();
        }
        currentBlock.writeln(line);
      }

      if (currentBlock.isNotEmpty && !inTargetLecture) {
        remainingBlocks.add(currentBlock.toString());
      }

      final newContent = remainingBlocks.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      if (newContent.isEmpty || !newContent.contains('##')) {
        await notesFile.delete();
        debugPrint('Permanently deleted master_notes.md as all entries were removed.');
        final remaining = classFolder.listSync();
        if (remaining.isEmpty) {
          await classFolder.delete();
          debugPrint('Permanently deleted empty class folder: ${classFolder.path}');
        }
      } else {
        await notesFile.writeAsString(newContent);
        debugPrint('Updated master_notes.md after removing note for "$lectureTitle".');
      }
    } catch (e) {
      debugPrint('Error removing note entry from storage: $e');
    }
  }

  /// Checks if a class notes folder is empty or doesn't have any non-empty note files.
  static Future<bool> isClassNotesFolderEmpty(String className) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final safeClassName = className.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (safeClassName.isEmpty) return true;

      var classFolder = Directory('${docDir.path}/SelfUni_Notes/$safeClassName');
      if (!await classFolder.exists()) {
        final altFolder = Directory('${docDir.path}/SelfUni_Notes/${safeClassName.replaceAll(' ', '_')}');
        if (await altFolder.exists()) {
          classFolder = altFolder;
        } else {
          return true;
        }
      }

      final List<FileSystemEntity> entities = await classFolder.list().toList();
      if (entities.isEmpty) {
        return true;
      }

      // Check if all files in the directory are empty or non-notes
      for (final entity in entities) {
        if (entity is File) {
          final filename = entity.path.split('/').last.split('\\').last;
          if (filename == 'master_notes.md') {
            final content = await entity.readAsString();
            if (content.trim().isNotEmpty) {
              return false; // has non-empty notes
            }
          } else {
            // Some other file exists
            return false;
          }
        } else {
          // A subdirectory exists
          return false;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
