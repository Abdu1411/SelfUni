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
}
