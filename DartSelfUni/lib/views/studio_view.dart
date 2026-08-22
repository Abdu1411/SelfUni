import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_service.dart';
import 'package:provider/provider.dart';
import 'package:youtube_transcript_api/youtube_transcript_api.dart';
import '../../core/services/storage_service.dart';
import '../../providers/deck_provider.dart';
import '../../providers/active_view_provider.dart';
import '../../models/deck_model.dart';
import '../../models/folder_model.dart';
import '../widgets/modals/folder_modal.dart';
import '../widgets/modals/select_folder_modal.dart';

enum GenerationTarget { lesson, deck, both }

class StudioView extends StatefulWidget {
  final VoidCallback onNavigateBack;

  const StudioView({super.key, required this.onNavigateBack});

  @override
  State<StudioView> createState() => _StudioViewState();
}

class _StudioViewState extends State<StudioView> {
  final TextEditingController _topicController = TextEditingController();
  final List<TextEditingController> _urlControllers = [TextEditingController()];
  final TextEditingController _contextController = TextEditingController();

  String? _selectedFolderId;
  final AIService _aiService = AIService();
  bool _isGeneratingCards = false;
  bool _isGeneratingNotes = false;
  bool _isGeneratingBoth = false;
  bool _showRawNotes = false;

  /// Extracts YouTube video ID from any URL format (no external package needed).
  String _extractYtVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
        return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
      }
    }
    // Last resort: try extracting 11-char ID with regex
    final match = RegExp(r'[?&/]([a-zA-Z0-9_-]{11})(?:[?&]|$)').firstMatch(url);
    return match?.group(1) ?? url;
  }

  @override
  void initState() {
    super.initState();
    final activeResource = context.read<ActiveViewProvider>().activeResource;
    if (activeResource != null) {
      _topicController.text = activeResource.title;
      _contextController.text = activeResource.contextText;
      if (activeResource.contextText.isNotEmpty) {
        _showRawNotes = true;
      }
      if (activeResource.videoUrl != null && activeResource.videoUrl!.isNotEmpty) {
        _urlControllers.clear();
        _urlControllers.add(TextEditingController(text: activeResource.videoUrl));
      }
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    for (var controller in _urlControllers) {
      controller.dispose();
    }
    _contextController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _topicController.clear();
    _contextController.clear();
    for (var controller in _urlControllers) {
      controller.dispose();
    }
    _urlControllers.clear();
    _urlControllers.add(TextEditingController());
    _selectedFolderId = null;
    _showRawNotes = false;
    context.read<ActiveViewProvider>().setActiveResource(null);
  }

  Future<void> _generate({required GenerationTarget target}) async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a topic')));
      return;
    }

    final apiKey = await StorageService().getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      if (!mounted) return;
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
            'A DeepSeek API key is required to synthesize flashcards and lecture notes.\n\nPlease open Settings and enter your DeepSeek API key.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final deckProvider = context.read<DeckProvider>();
    String? targetFolderId = _selectedFolderId;

    // Destination folder is mandatory!
    if (targetFolderId == null || targetFolderId.isEmpty || !deckProvider.folders.any((f) => f.id == targetFolderId)) {
      if (!mounted) return;
      final chosenFolderId = await SelectFolderModal.show(
        context,
        initialFolderId: _selectedFolderId,
        title: 'Choose Target Folder',
        description: 'A destination folder is mandatory before synthesizing "$topic". Please select an existing course folder or create a new one.',
      );
      if (chosenFolderId == null) {
        return; // User cancelled without choosing a folder
      }
      targetFolderId = chosenFolderId;
      if (mounted) {
        setState(() {
          _selectedFolderId = chosenFolderId;
        });
      }
    }

    setState(() {
      if (target == GenerationTarget.deck) {
        _isGeneratingCards = true;
      } else if (target == GenerationTarget.lesson) {
        _isGeneratingNotes = true;
      } else {
        _isGeneratingBoth = true;
      }
    });

    if (!mounted) return;

    // Show Progress Dialog
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
              Text(
                target == GenerationTarget.both
                    ? 'Synthesizing Lesson & Flashcards'
                    : target == GenerationTarget.lesson
                    ? 'Synthesizing Lecture Notes'
                    : 'Synthesizing Flashcard Deck',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                target == GenerationTarget.both
                    ? 'AI is creating exhaustive lecture notes and spaced repetition cards for "$topic"...'
                    : target == GenerationTarget.lesson
                    ? 'AI is writing comprehensive lecture notes for "$topic"...'
                    : 'AI is generating spaced repetition cards for "$topic"...',
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
      String combinedContext = _contextController.text.trim();

      for (var urlController in _urlControllers) {
        final url = urlController.text.trim();
        if (url.isNotEmpty) {
          if (!url.startsWith('http')) {
            throw Exception('URL must start with http:// or https://');
          }
          
          if (url.contains('youtube.com') || url.contains('youtu.be')) {
            try {
              final videoId = _extractYtVideoId(url);
              final api = YouTubeTranscriptApi();
              final transcript = await api.fetch(videoId);
              final text = transcript.map((s) => s.text).join(' ');
              combinedContext += '\n\nSource Content (YouTube Transcript $url):\n$text';
            } catch (e) {
              throw Exception('Failed to load YouTube transcript for $url. Ensure the video has closed captions/subtitles available. Error: $e');
            }
          } else {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              final text = response.body.replaceAll(
                RegExp(r'<[^>]*>|&[^;]+;'),
                ' ',
              );
              combinedContext += '\n\nSource Content ($url):\n$text';
            } else {
              throw Exception('Failed to load URL: ${response.statusCode}');
            }
          }
        }
      }

      final rawText = combinedContext.isNotEmpty ? combinedContext : null;

      if (target == GenerationTarget.deck) {
        final cards = await _aiService.generateDeck(
          topic: topic,
          rawText: rawText,
        );

        if (mounted) {
          final deck = Deck(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: topic,
            cards: cards,
            folderId: targetFolderId,
          );
          context.read<DeckProvider>().addDeck(deck);

          _clearForm();

          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated deck with ${cards.length} cards'),
            ),
          );
          widget.onNavigateBack();
        }
      } else if (target == GenerationTarget.lesson) {
        final lesson = await _aiService.generateLesson(
          topic: topic,
          rawText: rawText,
        );

        if (mounted) {
          lesson.folderId = targetFolderId;
          context.read<DeckProvider>().addLesson(lesson);

          _clearForm();

          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generated lecture notes')),
          );
          widget.onNavigateBack();
        }
      } else if (target == GenerationTarget.both) {
        // Generate lesson first to prevent concurrent DeepSeek request limit errors
        final lesson = await _aiService.generateLesson(
          topic: topic,
          rawText: rawText,
        );

        // Generate deck grounded on topic and the synthesized lesson notes
        final combinedDeckContext = lesson.content.isNotEmpty
            ? '${rawText != null ? "$rawText\n\n" : ""}${lesson.content}'
            : rawText;

        final cards = await _aiService.generateDeck(
          topic: topic,
          rawText: combinedDeckContext,
        );

        if (mounted) {
          lesson.folderId = targetFolderId;
          context.read<DeckProvider>().addLesson(lesson);

          final deck = Deck(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: topic,
            cards: cards,
            folderId: targetFolderId,
          );
          context.read<DeckProvider>().addDeck(deck);

          _clearForm();

          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Generated both lecture notes & deck with ${cards.length} cards!',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
          widget.onNavigateBack();
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 22),
                SizedBox(width: 8),
                Text(
                  'Generation Failed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingCards = false;
          _isGeneratingNotes = false;
          _isGeneratingBoth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<DeckProvider>().folders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Flashcard Engine',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.blue.shade600,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'AI Generate',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Synthesize 30-card spaced repetition decks with AI from multiple documentation sources, or generate professor-grade study lessons',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Main Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.shade50.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.blue.shade500),
                          const SizedBox(width: 12),
                          const Text(
                            'AI MULTI-SOURCE SYNTHESIZER',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              'Flashcards & Lessons',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Provide a topic, documentation URLs, or YouTube video lecture links to generate spaced repetition decks, comprehensive professor-grade study lessons, or both simultaneously.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      _buildLabel('COMPUTER SCIENCE TOPIC OR ALGORITHM TITLE'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _topicController,
                        hintText:
                            'e.g. Binary Search Trees, Graph BFS, Operating Systems',
                        icon: Icons.code,
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel(
                            'SOURCE URLS (DOCUMENTATION, ARTICLES, GITHUB, YOUTUBE LECTURES)',
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _urlControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Add Source URL',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._urlControllers.asMap().entries.map((entry) {
                        int index = entry.key;
                        TextEditingController controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: controller,
                                  hintText:
                                      'Source ${index + 1} URL (e.g. https://youtube.com/watch?v=... or https://dart.dev)',
                                  icon: Icons.link,
                                ),
                              ),
                              if (_urlControllers.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      controller.dispose();
                                      _urlControllers.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: () {
                          setState(() {
                            _showRawNotes = !_showRawNotes;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: 18,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '+ Paste Video Lecture Transcript / Raw Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _showRawNotes
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showRawNotes) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contextController,
                          maxLines: 6,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText:
                                'Paste any source text, articles, or code to base the generation on...',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            suffixIcon: _contextController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Clear notes',
                                    onPressed: () {
                                      setState(() {
                                        _contextController.clear();
                                        context
                                            .read<ActiveViewProvider>()
                                            .setActiveResource(null);
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('DESTINATION FOLDER (REQUIRED)'),
                          TextButton.icon(
                            onPressed: () async {
                              final newFolder = await showDialog<Folder>(
                                context: context,
                                builder: (ctx) => FolderModal(
                                  onSave: (name, color) async {
                                    final folder = await context.read<DeckProvider>().addFolder(name, color: color);
                                    if (ctx.mounted) Navigator.of(ctx).pop(folder);
                                  },
                                ),
                              );
                              if (newFolder != null && mounted) {
                                setState(() => _selectedFolderId = newFolder.id);
                              }
                            },
                            icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: AppColors.primary),
                            label: const Text('+ Create New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFolderId == null ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
                            width: _selectedFolderId == null ? 1.5 : 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedFolderId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            hint: Row(
                              children: [
                                const Icon(
                                  Icons.folder_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  folders.isEmpty ? 'No folders exist — Click "+ Create New Folder"' : 'Choose a destination folder (Required)...',
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                            items: folders.map((f) {
                              return DropdownMenuItem<String?>(
                                value: f.id,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      color: _parseColor(f.color ?? '#2563eb'),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedFolderId = val;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildActionButton(
                              label: 'GENERATE CS LESSON',
                              icon: Icons.menu_book,
                              color: const Color(0xFF86D2C1),
                              isLoading: _isGeneratingNotes,
                              isDisabled:
                                  _isGeneratingCards ||
                                  _isGeneratingNotes ||
                                  _isGeneratingBoth,
                              onPressed: () =>
                                  _generate(target: GenerationTarget.lesson),
                            ),
                            _buildActionButton(
                              label: 'SYNTHESIZE 30 CARDS',
                              icon: Icons.auto_awesome,
                              color: const Color(0xFFA09CFF),
                              isLoading: _isGeneratingCards,
                              isDisabled:
                                  _isGeneratingCards ||
                                  _isGeneratingNotes ||
                                  _isGeneratingBoth,
                              onPressed: () =>
                                  _generate(target: GenerationTarget.deck),
                            ),
                            _buildActionButton(
                              label: 'GENERATE BOTH (LESSON & CARDS)',
                              icon: Icons.auto_awesome_motion,
                              color: const Color(0xFF6366F1),
                              isLoading: _isGeneratingBoth,
                              isDisabled:
                                  _isGeneratingCards ||
                                  _isGeneratingNotes ||
                                  _isGeneratingBoth,
                              onPressed: () =>
                                  _generate(target: GenerationTarget.both),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right,
          size: 14,
          color: Colors.blue.shade400,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required bool isDisabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
