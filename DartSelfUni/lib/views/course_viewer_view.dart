import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/deck_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:youtube_transcript_api/youtube_transcript_api.dart';
import '../widgets/common/adaptive_video_player_widget.dart';
import '../widgets/common/markdown_view.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/storage_service.dart';
import '../../models/deck_model.dart';

class CourseViewerView extends StatefulWidget {
  final Course course;
  final VoidCallback onNavigateBack;
  final VoidCallback? onGenerateFlashcards;

  const CourseViewerView({
    super.key,
    required this.course,
    required this.onNavigateBack,
    this.onGenerateFlashcards,
  });

  @override
  State<CourseViewerView> createState() => _CourseViewerViewState();
}

class _CourseViewerViewState extends State<CourseViewerView> {
  CourseItem? _activeItem;
  bool _showTranscript = false;
  final Map<String, String> _transcriptCache = {};
  final Map<String, String> _transcriptErrors = {};
  final AIService _aiService = AIService();

  String _cleanUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.startsWith('"') || cleaned.startsWith("'")) {
      cleaned = cleaned.substring(1);
    }
    while (cleaned.endsWith('"') || cleaned.endsWith("'")) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned.trim();
  }

  Future<String?> _getOrFetchTranscript(String url, {bool force = false}) async {
    final cleanedUrl = _cleanUrl(url);
    if (_activeItem == null) return null;
    if (!force && _activeItem!.transcript != null && _activeItem!.transcript!.isNotEmpty) {
      return _activeItem!.transcript;
    }
    if (!force && _transcriptCache.containsKey(cleanedUrl)) {
      return _transcriptCache[cleanedUrl];
    }
    if (!force && _transcriptErrors.containsKey(cleanedUrl)) {
      return null;
    }
    
    final videoId = _extractYtVideoId(cleanedUrl);
    if (videoId.isEmpty) return null;

    try {
      final api = YouTubeTranscriptApi();
      final transcript = await api.fetch(videoId);
      final rawText = transcript.map((s) => s.text).join(' ');
      
      // AI processes raw transcript to add headers/paraphrasing/math formatting
      final formattedText = await _aiService.formatTranscript(rawTranscript: rawText);
      _transcriptCache[cleanedUrl] = formattedText;
      
      // Save it locally inside the CourseItem on the course object
      if (mounted) {
        final deckProvider = context.read<DeckProvider>();
        for (var module in widget.course.modules) {
          final itemIdx = module.items.indexWhere((i) => i.id == _activeItem!.id);
          if (itemIdx != -1) {
            final updatedItem = module.items[itemIdx].copyWith(transcript: formattedText);
            module.items[itemIdx] = updatedItem;
            
            setState(() {
              if (_activeItem?.id == updatedItem.id) {
                _activeItem = updatedItem;
              }
            });
            await deckProvider.updateCourse(widget.course);
            break;
          }
        }
      }
      return formattedText;
    } catch (e) {
      _transcriptErrors[cleanedUrl] = e.toString();
      rethrow;
    }
  }

  String _extractYtVideoId(String url) {
    final cleaned = _cleanUrl(url);
    final uri = Uri.tryParse(cleaned);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
        return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    if (widget.course.modules.isNotEmpty && widget.course.modules.first.items.isNotEmpty) {
      _activeItem = widget.course.modules.first.items.first;
    }
  }

  @override
  void didUpdateWidget(covariant CourseViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeItem != null) {
      for (var module in widget.course.modules) {
        final newItem = module.items.where((i) => i.id == _activeItem!.id).firstOrNull;
        if (newItem != null) {
          _activeItem = newItem;
          break;
        }
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'video': return Icons.videocam;
      case 'pdf': return Icons.picture_as_pdf;
      case 'html': return Icons.code;
      default: return Icons.book;
    }
  }

  void _editLectureTitle(CourseItem item, CourseModule module) {
    final controller = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Edit Lecture Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Lecture Title',
            hintText: 'Enter new lecture title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != item.title) {
                Navigator.of(ctx).pop();
                final deckProvider = context.read<DeckProvider>();
                
                var updatedTranscript = item.transcript;
                if (updatedTranscript != null && updatedTranscript.isNotEmpty) {
                  final lines = updatedTranscript.split('\n');
                  if (lines.isNotEmpty && lines.first.trimLeft().startsWith('#')) {
                    final match = RegExp(r'^(#+)\s*').firstMatch(lines.first);
                    if (match != null) {
                      final hashes = match.group(1);
                      lines[0] = '$hashes $newTitle';
                    } else {
                      lines[0] = '# $newTitle';
                    }
                    updatedTranscript = lines.join('\n');
                  }
                }

                final updatedItem = item.copyWith(
                  title: newTitle,
                  transcript: updatedTranscript,
                );
                
                final itemIdx = module.items.indexWhere((i) => i.id == item.id);
                if (itemIdx != -1) {
                  module.items[itemIdx] = updatedItem;
                }
                await deckProvider.updateCourse(widget.course);

                // Also update corresponding lesson if present
                final matchingLesson = deckProvider.lessons.where((l) => l.id == item.id || l.title == item.title).firstOrNull;
                if (matchingLesson != null) {
                  await deckProvider.renameLesson(matchingLesson.id, newTitle);
                }

                setState(() {
                  if (_activeItem?.id == item.id) {
                    _activeItem = updatedItem;
                  }
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lecture renamed to "$newTitle"'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _deleteLecture(CourseItem item, CourseModule module) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Lecture Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete "${item.title}" from this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final deckProvider = context.read<DeckProvider>();

              // Remove from module
              module.items.removeWhere((i) => i.id == item.id);
              await deckProvider.updateCourse(widget.course);

              // Delete lesson from DeckProvider if exists
              final matchingLesson = deckProvider.lessons.where((l) => l.id == item.id).firstOrNull;
              if (matchingLesson != null) {
                await deckProvider.deleteLesson(matchingLesson.id);
              }

              setState(() {
                if (_activeItem?.id == item.id) {
                  _activeItem = widget.course.modules.expand((m) => m.items).firstOrNull;
                }
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted lecture "${item.title}".'), backgroundColor: AppColors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar Syllabus
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: widget.onNavigateBack,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Workspace', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.course.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                                        SizedBox(width: 8),
                                        Text('Delete Course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: Text('Are you sure you want to delete course "${widget.course.title}" and its course folder?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          context.read<DeckProvider>().deleteCourse(widget.course.id, deleteFolderToo: true);
                                          widget.onNavigateBack();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Course "${widget.course.title}" deleted.'), backgroundColor: AppColors.success),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                                    SizedBox(width: 8),
                                    Text('Delete Course & Folder', style: TextStyle(color: AppColors.error, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.course.modules.fold<int>(0, (sum, m) => sum + m.items.length)} items',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                
                // Modules List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.course.modules.length,
                    itemBuilder: (context, moduleIndex) {
                      final module = widget.course.modules[moduleIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              module.title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...module.items.map((item) {
                            final isActive = _activeItem?.id == item.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _activeItem = item;
                                    _showTranscript = false;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isActive ? AppColors.primaryLight.withValues(alpha: 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isActive ? AppColors.primaryLight.withValues(alpha: 0.3) : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getIconForType(item.type),
                                        size: 16,
                                        color: isActive ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                            color: isActive ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _editLectureTitle(item, module);
                                          } else if (val == 'delete') {
                                            _deleteLecture(item, module);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                                                SizedBox(width: 8),
                                                Text('Edit Title', style: TextStyle(fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                                SizedBox(width: 8),
                                                Text('Delete Video', style: TextStyle(fontSize: 13, color: AppColors.error)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _activeItem?.title ?? 'Select a lesson',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_activeItem != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_activeItem != null) {
                              final apiKey = await StorageService().getApiKey();
                              if (apiKey == null || apiKey.trim().isEmpty) {
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'API Key Required',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    content: const Text(
                                      'A DeepSeek API key is required to synthesize flashcards.\n\nPlease open Settings and enter your DeepSeek API key.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              if (!context.mounted) return;
                              String? transcriptText;
                              
                              if (_activeItem!.type == 'video') {
                                final url = _activeItem!.path ?? _activeItem!.fileKey ?? '';
                                if (url.contains('youtube.com') || url.contains('youtu.be')) {
                                  // Show progress indicator dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: Card(
                                        child: Padding(
                                          padding: EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('Fetching YouTube transcript...', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );

                                  try {
                                    transcriptText = await _getOrFetchTranscript(url);
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(); // Close dialog
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(); // Close dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to load transcript: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              }

                              // Now generate the flashcards directly in background!
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => Dialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Synthesizing Flashcard Deck',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'AI is generating spaced repetition cards for "${_activeItem!.title}"...',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              try {
                                final cards = await _aiService.generateDeck(
                                  topic: _activeItem!.title,
                                  rawText: transcriptText ?? _activeItem!.description,
                                );

                                if (!context.mounted) return;
                                Navigator.of(context).pop(); // Close synthesis dialog

                                final deck = Deck(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  title: _activeItem!.title,
                                  cards: cards,
                                  folderId: widget.course.id,
                                );
                                context.read<DeckProvider>().addDeck(deck);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Generated deck with ${cards.length} cards'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.of(context).pop(); // Close synthesis dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to generate flashcards: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('GENERATE FLASHCARDS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Viewer
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    padding: _activeItem?.type == 'pdf' ? EdgeInsets.zero : const EdgeInsets.all(24),
                    child: _activeItem == null
                        ? const Center(child: Text('Select an item from the sidebar', style: TextStyle(color: AppColors.textSecondary)))
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: _activeItem!.type == 'pdf' ? double.infinity : 1000),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: _activeItem!.type == 'pdf' ? BorderRadius.zero : BorderRadius.circular(16),
                                  border: _activeItem!.type == 'pdf' ? null : Border.all(color: AppColors.border),
                                ),
                                child: ClipRRect(
                                  borderRadius: _activeItem!.type == 'pdf' ? BorderRadius.zero : BorderRadius.circular(16),
                                  child: _buildContent(_activeItem!),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CourseItem item) {
    if (item.type == 'video') {
      final url = _cleanUrl(item.path ?? item.fileKey ?? '');
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveVideoPlayerWidget(
                key: ValueKey('player_${item.id}_${item.path}'),
                videoUrl: url,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.description!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showTranscript = !_showTranscript;
                              });
                            },
                            icon: Icon(
                              _showTranscript ? Icons.subtitles_off_outlined : Icons.subtitles_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              _showTranscript ? 'Hide Transcript' : 'Show Transcript',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (url.isEmpty) return;

                              final hasTranscript = _activeItem?.transcript != null && _activeItem!.transcript!.isNotEmpty;
                              
                              if (hasTranscript) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                                        SizedBox(width: 8),
                                        Text('Regenerate Transcript', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: const Text('Are you sure you want to regenerate the transcript? This will overwrite the existing transcript.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                                        child: const Text('Regenerate'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                              }

                              if (!mounted) return;

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('AI formatting transcript...', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              try {
                                await _getOrFetchTranscript(url, force: true);
                                if (!mounted) return;
                                Navigator.of(context).pop(); // Close dialog
                                
                                setState(() {
                                  _showTranscript = true;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(hasTranscript ? 'Transcript regenerated!' : 'Transcript generated!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                Navigator.of(context).pop(); // Close dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to generate transcript: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            },
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: Text(
                              _activeItem?.transcript != null && _activeItem!.transcript!.isNotEmpty
                                  ? 'Regenerate Transcript'
                                  : 'Generate Transcript',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      if (_showTranscript) ...[
                        if (_activeItem?.transcript != null && _activeItem!.transcript!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(20),
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
                                    const Row(
                                      children: [
                                        Icon(Icons.subtitles_outlined, size: 18, color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text(
                                          'Video Transcript',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _showTranscript = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                MarkdownView(
                                  data: _activeItem!.transcript!,
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFFB45309)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No transcript generated yet. Click "Generate Transcript" above to generate it.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Video Player', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Externally'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    if (item.type == 'pdf') {
      final url = item.path ?? item.fileKey ?? '';
      if (url.startsWith('http')) {
        return SfPdfViewer.network(url);
      } else if (File(url).existsSync()) {
        return SfPdfViewer.file(File(url));
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('PDF Document', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    // For HTML/Markdown/Text
    final url = item.path ?? item.fileKey ?? '';
    Widget contentWidget;
    
    final deckProvider = context.read<DeckProvider>();
    final matchingLesson = deckProvider.lessons.where((l) => l.id == item.id).firstOrNull;
    
    if (matchingLesson != null && matchingLesson.content.isNotEmpty) {
      contentWidget = MarkdownView(data: matchingLesson.content);
    } else if (File(url).existsSync()) {
      contentWidget = FutureBuilder<String>(
        future: File(url).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error loading file: ${snapshot.error}', style: const TextStyle(color: AppColors.error));
          } else {
            return MarkdownView(data: snapshot.data ?? '');
          }
        },
      );
    } else {
      contentWidget = MarkdownView(data: '### ${item.title}\n\nContent for this lesson will be rendered here.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: contentWidget,
    );
  }
}
