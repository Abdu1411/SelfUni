import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../models/folder_model.dart';
import '../../models/lesson_model.dart';
import '../../models/course_model.dart';
import '../../providers/deck_provider.dart';

class ImportCourseModal extends StatefulWidget {
  final Folder? initialFolder;

  const ImportCourseModal({super.key, this.initialFolder});

  @override
  State<ImportCourseModal> createState() => _ImportCourseModalState();
}

class _ImportCourseModalState extends State<ImportCourseModal> {
  int _importMode = 0; // 0: Bulk Import, 1: Single Lecture
  String? _targetCourseId = 'new_course'; // 'new_course' or existing course ID
  
  // Single Lecture Fields
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _urlController = TextEditingController();

  // Bulk / Web Import Fields
  final _courseNameController = TextEditingController();
  final _webUrlController = TextEditingController();
  final List<Map<String, String>> _extractedLectures = [];
  
  bool _isLoading = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Default to 'new_course' unless we have an initial folder or existing courses
    _targetCourseId = 'new_course';

    if (widget.initialFolder != null) {
      _courseNameController.text = widget.initialFolder!.name;
      _titleController.text = widget.initialFolder!.name;
      _importMode = 1; // Default to single lecture when opening for a folder
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deckProvider = context.read<DeckProvider>();
        final folderName = widget.initialFolder!.name.toLowerCase();
        final matchingCourse = deckProvider.courses.where(
          (c) => c.title.toLowerCase() == folderName,
        ).firstOrNull;
        setState(() {
          _targetCourseId = matchingCourse?.id ?? 'new_course';
          if (matchingCourse != null) {
            _courseNameController.text = matchingCourse.title;
          }
        });
      });
    } else {
      // If there are existing courses, default selection to the first course
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deckProvider = context.read<DeckProvider>();
        if (deckProvider.courses.isNotEmpty) {
          setState(() {
            _targetCourseId = deckProvider.courses.first.id;
            _courseNameController.text = deckProvider.courses.first.title;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _urlController.dispose();
    _courseNameController.dispose();
    _webUrlController.dispose();
    super.dispose();
  }

  // --- Single Live Stream / Lecture Creation ---
  Future<void> _submitSingleLecture() async {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    final courseName = _courseNameController.text.trim();
    final topic = _topicController.text.trim().isEmpty ? courseName : _topicController.text.trim();

    if (title.isEmpty || courseName.isEmpty || url.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all required fields (Target Course, Title, Video URL).');
      return;
    }

    final deckProvider = context.read<DeckProvider>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? folderId;
      
      // Find or create course
      Course? existingCourse = deckProvider.courses.where((c) => c.title.toLowerCase() == courseName.toLowerCase()).firstOrNull;
      if (existingCourse == null) {
        final normalizedTarget = courseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        existingCourse = deckProvider.courses.where((c) {
          final normalizedTitle = c.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          return normalizedTitle.contains(normalizedTarget) || normalizedTarget.contains(normalizedTitle);
        }).firstOrNull;
      }

      if (existingCourse == null) {
        // Create new course
        final newCourse = Course(
          id: 'crs_${DateTime.now().millisecondsSinceEpoch}',
          title: courseName,
          description: 'Course created for $courseName',
          instructors: ['SelfUni Instructor'],
          modules: [
            CourseModule(
              id: 'mod_1',
              title: courseName,
              items: [
                CourseItem(
                  id: 'lec_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  type: 'video',
                  path: url,
                )
              ],
            ),
          ],
        );
        await deckProvider.addCourse(newCourse);
        existingCourse = newCourse;
      } else {
        // Add to existing course module
        final newItem = CourseItem(
          id: 'lec_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          type: 'video',
          path: url,
        );
        if (existingCourse.modules.isNotEmpty) {
          existingCourse.modules.first.items.add(newItem);
        } else {
          existingCourse.modules.add(CourseModule(id: 'mod_1', title: courseName, items: [newItem]));
        }
        await deckProvider.updateCourse(existingCourse);
      }

      // Always find or create the matching folder
      Folder? courseFolder = deckProvider.folders.where((f) => f.name.toLowerCase() == existingCourse!.title.toLowerCase()).firstOrNull;
      courseFolder ??= await deckProvider.addFolder(existingCourse.title, color: '#3B82F6');
      folderId = courseFolder.id;

      final lessonId = 'lec_${DateTime.now().millisecondsSinceEpoch}';
      final newLesson = Lesson(
        id: lessonId,
        title: title,
        topic: topic, // always match the course title for orphan-cleanup checks
        videoUrl: url,
        content: '# $title\n\nLive course video stream for ${existingCourse.title}.\n\nVideo URL: $url',
        folderId: folderId,
        sourceUrl: url,
        isNote: false,
      );

      await deckProvider.addLesson(newLesson);

      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Added lecture and note for "$title"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to add lecture: $e';
          _isLoading = false;
        });
      }
    }
  }

  // --- Bulk Import: File Picker (Raw Filename) ---
  Future<void> _pickCourseFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Selecting file...';
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt', 'html'],
      );

      if (result.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.first;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      final rawFileName = file.name.replaceAll(RegExp(r'\.[^/.]+$'), '');
      
      setState(() => _statusMessage = 'Suggesting course name using AI...');
      final suggestedName = await AIService().suggestHumanReadableCourseName(
        filename: rawFileName,
        sampleContent: content,
      );
      _courseNameController.text = suggestedName;

      if (!mounted) return;

      // Smart Existing Course Matching:
      final deckProvider = context.read<DeckProvider>();
      final courses = deckProvider.courses;
      final currentEntered = _courseNameController.text.trim();
      final hasCurrentMatch = courses.any((c) => c.title.toLowerCase() == currentEntered.toLowerCase());

      if (!hasCurrentMatch) {
        // Try fuzzy keyword matching from filename
        final normalizedFile = rawFileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ');
        Course? bestMatch;
        for (var c in courses) {
          final normalizedTitle = c.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();
          if (normalizedTitle.isNotEmpty && normalizedFile.contains(normalizedTitle)) {
            bestMatch = c;
            break;
          }
        }

        if (bestMatch != null) {
          _courseNameController.text = bestMatch.title;
        } else if (courses.length == 1) {
          _courseNameController.text = courses.first.title;
        } else if (_courseNameController.text.trim().isEmpty) {
          _courseNameController.text = rawFileName;
        }
      }

      _parseExtractedContent(content, filename: _courseNameController.text.isNotEmpty ? _courseNameController.text : rawFileName);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading file: $e';
        _isLoading = false;
      });
    }
  }

  // --- Web URL Extractor ---
  Future<void> _extractFromWebUrl() async {
    final url = _webUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid webpage or playlist URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Fetching course lectures from $url...';
      _extractedLectures.clear();
    });

    try {
      final uri = Uri.parse(url);
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final html = res.body;
        String titleGuess = uri.host;
        final titleMatch = RegExp(r'<title>(.*?)<\/title>', caseSensitive: false).firstMatch(html);
        if (titleMatch != null && titleMatch.group(1) != null) {
          titleGuess = titleMatch.group(1)!.trim();
        }

        setState(() => _statusMessage = 'Suggesting course name using AI...');
        final suggestedName = await AIService().suggestHumanReadableCourseName(
          filename: titleGuess,
          sampleContent: html,
        );

        if (_courseNameController.text.trim().isEmpty) {
          _courseNameController.text = suggestedName;
        }

        _parseHtmlContent(html, defaultTitle: suggestedName);
      } else {
        setState(() {
          _errorMessage = 'Failed to load page. HTTP status: ${res.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error fetching URL: $e';
        _isLoading = false;
      });
    }
  }

  void _parseExtractedContent(String content, {required String filename}) {
    final list = <Map<String, String>>[];
    final courseTitle = filename.isNotEmpty
        ? filename
        : (_courseNameController.text.trim().isNotEmpty ? _courseNameController.text.trim() : 'Course');

    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        for (var item in decoded) {
          if (item is Map) {
            list.add({
              'title': item['title']?.toString() ?? 'Lecture ${list.length + 1}',
              'topic': item['topic']?.toString() ?? courseTitle,
              'url': item['url']?.toString() ?? item['videoUrl']?.toString() ?? '',
            });
          }
        }
      } else if (decoded is Map && decoded['lectures'] is List) {
        for (var item in decoded['lectures']) {
          if (item is Map) {
            list.add({
              'title': item['title']?.toString() ?? 'Lecture ${list.length + 1}',
              'topic': item['topic']?.toString() ?? courseTitle,
              'url': item['url']?.toString() ?? item['videoUrl']?.toString() ?? '',
            });
          }
        }
      }
    } catch (_) {
      final lines = content.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(RegExp(r'[,;\t]'));
        if (parts.length >= 2) {
          list.add({
            'title': parts[0].trim(),
            'topic': courseTitle,
            'url': parts[1].trim(),
          });
        } else if (trimmed.startsWith('http')) {
          list.add({
            'title': 'Lecture ${list.length + 1}',
            'topic': courseTitle,
            'url': trimmed,
          });
        }
      }
    }

    setState(() {
      _extractedLectures.addAll(list);
      _isLoading = false;
      _statusMessage = 'Found ${_extractedLectures.length} lectures in $filename';
    });
  }

  void _parseHtmlContent(String html, {required String defaultTitle}) {
    final list = <Map<String, String>>[];
    final ytRegex = RegExp(r'(https?:\/\/(?:www\.)?youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)|https?:\/\/youtu\.be\/([a-zA-Z0-9_-]+))');
    final matches = ytRegex.allMatches(html);
    final seen = <String>{};
    final courseTitle = _courseNameController.text.trim().isNotEmpty ? _courseNameController.text.trim() : defaultTitle;

    int i = 1;
    for (var m in matches) {
      final url = m.group(0)!;
      if (!seen.contains(url)) {
        seen.add(url);
        list.add({
          'title': '$courseTitle - Lecture $i',
          'topic': courseTitle,
          'url': url,
        });
        i++;
      }
    }

    if (_courseNameController.text.trim().isEmpty) {
      _courseNameController.text = defaultTitle;
    }

    setState(() {
      _extractedLectures.addAll(list);
      _isLoading = false;
      _statusMessage = 'Discovered ${_extractedLectures.length} video lectures!';
    });
  }

  // --- Submit Bulk Lectures into an Existing Course ---
  Future<void> _submitBulkCourse() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty) {
      setState(() => _errorMessage = 'Please provide a Target Course name to import the lectures into.');
      return;
    }

    final deckProvider = context.read<DeckProvider>();
    
    // Check if the course already exists in Local Courses (exact match or fuzzy contains)
    Course? existingCourse = deckProvider.courses.where((c) => c.title.toLowerCase() == courseName.toLowerCase()).firstOrNull;
    if (existingCourse == null) {
      final normalizedTarget = courseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      existingCourse = deckProvider.courses.where((c) {
        final normalizedTitle = c.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        return normalizedTitle.contains(normalizedTarget) || normalizedTarget.contains(normalizedTitle);
      }).firstOrNull;
    }

    if (_extractedLectures.isEmpty) {
      setState(() => _errorMessage = 'No lectures extracted to import. Please fetch from a URL or upload a file first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // If course still doesn't exist, automatically create it on the fly
      if (existingCourse == null) {
        final newCourse = Course(
          id: 'crs_${DateTime.now().millisecondsSinceEpoch}',
          title: courseName,
          description: 'Course imported for $courseName',
          instructors: ['SelfUni Instructor'],
          modules: [
            CourseModule(
              id: 'mod_1',
              title: courseName,
              items: [],
            ),
          ],
        );
        await deckProvider.addCourse(newCourse);
        existingCourse = newCourse;
      }

      final targetCourse = existingCourse;

      // Find or create matching folder
      Folder? courseFolder = deckProvider.folders.where((f) => f.name.toLowerCase() == targetCourse.title.toLowerCase()).firstOrNull;
      courseFolder ??= await deckProvider.addFolder(targetCourse.title, color: '#3B82F6');
      final folderId = courseFolder.id;

      final newLessons = <Lesson>[];
      final newCourseItems = <CourseItem>[];

      for (var lec in _extractedLectures) {
        final lessonId = 'lec_${DateTime.now().millisecondsSinceEpoch}_${newLessons.length}';
        final lesson = Lesson(
          id: lessonId,
          title: lec['title'] ?? 'Lecture',
          topic: targetCourse.title,
          videoUrl: lec['url'],
          content: '# ${lec['title']}\n\nLive course video stream for ${targetCourse.title}.\n\nVideo URL: ${lec['url']}',
          folderId: folderId,
          sourceUrl: lec['url'],
          isNote: false,
        );
        newLessons.add(lesson);

        newCourseItems.add(
          CourseItem(
            id: lessonId,
            title: lesson.title,
            type: 'video',
            path: lesson.videoUrl,
          ),
        );
      }

      // Add to lessons
      await deckProvider.addLessonsBulk(newLessons);

      // Add items into existing course syllabus
      if (targetCourse.modules.isNotEmpty) {
        targetCourse.modules.first.items.addAll(newCourseItems);
      } else {
        targetCourse.modules.add(
          CourseModule(
            id: 'mod_1',
            title: 'Lectures',
            items: newCourseItems,
          ),
        );
      }

      await deckProvider.updateCourse(targetCourse);

      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Successfully imported ${newLessons.length} lectures and generated notes in "${targetCourse.title}"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to bulk import course: $e';
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<DeckProvider>().courses;
    const pinkColor = Color(0xFFF43F5E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 620,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: const Icon(Icons.school_outlined, color: pinkColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Import Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        SizedBox(height: 4),
                        Text('Import a single video lecture or bulk import a playlist/webpage/file', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_statusMessage!, style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],

              // Shared Course Selection
              _buildCourseSelectionField(courses),
              const SizedBox(height: 20),

              // Import Mode Selector (Bulk vs Single)
              _buildImportModeSelector(),
              const SizedBox(height: 20),

              // Form Areas
              if (_importMode == 1)
                _buildSingleLectureForm()
              else
                _buildBulkImportForm(),

              const SizedBox(height: 32),
              
              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_importMode == 1 ? _submitSingleLecture : _submitBulkCourse),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pinkColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _importMode == 1 ? 'Add Live Lecture' : 'Import Lectures',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseSelectionField(List<Course> courses) {
    const pinkColor = Color(0xFFF43F5E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('TARGET COURSE *'),
        if (courses.isNotEmpty) ...[
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _targetCourseId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'new_course',
                    child: Row(
                      children: [
                        Icon(Icons.add_box_outlined, color: pinkColor, size: 18),
                        SizedBox(width: 8),
                        Text('Create New Course...', style: TextStyle(fontSize: 13, color: pinkColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ...courses.map((c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined, color: Color(0xFF3B82F6), size: 18),
                            const SizedBox(width: 8),
                            Text(c.title, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _targetCourseId = val;
                      _errorMessage = null;
                      if (val != 'new_course') {
                        final selected = courses.firstWhere((c) => c.id == val);
                        _courseNameController.text = selected.title;
                      } else {
                        _courseNameController.clear();
                      }
                    });
                  }
                },
              ),
            ),
          ),
          if (_targetCourseId == 'new_course') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _courseNameController,
              decoration: _buildInputDecoration(
                'Enter new course name...',
                prefixIcon: const Icon(Icons.school_outlined, size: 18, color: pinkColor),
              ),
            ),
          ],
        ] else ...[
          TextField(
            controller: _courseNameController,
            decoration: _buildInputDecoration(
              'Enter course name...',
              prefixIcon: const Icon(Icons.school_outlined, size: 18, color: pinkColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImportModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('IMPORT TYPE'),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Bulk Import')),
                selected: _importMode == 0,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _importMode = 0;
                      _errorMessage = null;
                    });
                  }
                },
                selectedColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: _importMode == 0 ? const Color(0xFFF43F5E) : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Single Lecture')),
                selected: _importMode == 1,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _importMode = 1;
                      _errorMessage = null;
                    });
                  }
                },
                selectedColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: _importMode == 1 ? const Color(0xFFF43F5E) : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleLectureForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('LECTURE / STREAM TITLE *'),
        TextField(
          controller: _titleController,
          decoration: _buildInputDecoration('e.g. Lecture 01: Introduction to Memory & Pointers'),
        ),
        const SizedBox(height: 16),
        _buildLabel('TOPIC / CATEGORY (Optional)'),
        TextField(
          controller: _topicController,
          decoration: _buildInputDecoration('e.g. Computer Science (Defaults to Course Name)'),
        ),
        const SizedBox(height: 16),
        _buildLabel('YOUTUBE VIDEO URL / LIVE STREAM URL *'),
        TextField(
          controller: _urlController,
          decoration: _buildInputDecoration('https://www.youtube.com/watch?v=...'),
        ),
      ],
    );
  }

  Widget _buildBulkImportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('WEB PAGE OR YOUTUBE PLAYLIST URL'),
                  TextField(
                    controller: _webUrlController,
                    decoration: _buildInputDecoration('https://example.com/course-videos...'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _extractFromWebUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Fetch'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '— OR —',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _pickCourseFile,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload JSON or CSV File'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        if (_extractedLectures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.playlist_play, size: 18, color: Color(0xFFF43F5E)),
                        const SizedBox(width: 6),
                        Text(
                          'Extracted Lectures (${_extractedLectures.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('(Click ✏️ to edit title)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _extractedLectures.clear()),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                          child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _extractedLectures.length,
                    separatorBuilder: (context, i) => const Divider(height: 8, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _extractedLectures[index];
                      final title = item['title'] ?? 'Lecture ${index + 1}';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => _editExtractedLecture(index),
                                borderRadius: BorderRadius.circular(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item['url'] != null && item['url']!.isNotEmpty)
                                      Text(
                                        item['url']!,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                              tooltip: 'Edit Title',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editExtractedLecture(index),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                              tooltip: 'Remove',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _extractedLectures.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _editExtractedLecture(int index) {
    final currentTitle = _extractedLectures[index]['title'] ?? '';
    final editController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Color(0xFFF43F5E), size: 20),
            SizedBox(width: 8),
            Text('Edit Lecture Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Lecture Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = editController.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _extractedLectures[index]['title'] = newTitle;
                });
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
