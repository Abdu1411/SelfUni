import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../models/deck_model.dart';
import '../../models/lesson_model.dart';
import '../../providers/active_view_provider.dart';
import '../../providers/deck_provider.dart';
import '../widgets/common/markdown_view.dart';
import '../widgets/common/rich_note_editor.dart';
import '../widgets/modals/ask_ai_modal.dart';
import '../widgets/modals/select_folder_modal.dart';
import '../widgets/common/pomodoro_timer_widget.dart';
import 'study_session_view.dart';

class LessonDetailView extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onNavigateBack;
  final bool isEditing;

  const LessonDetailView({
    super.key,
    required this.lesson,
    required this.onNavigateBack,
    this.isEditing = false,
  });

  @override
  State<LessonDetailView> createState() => _LessonDetailViewState();
}

class _LessonDetailViewState extends State<LessonDetailView> {
  late bool _isEditing;
  bool _isGeneratingCards = false;
  bool _isAiModalOpen = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing;
    // Set as active context for AI Tutor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActiveViewProvider>().setActiveResource(
        ActiveResource(
          title: widget.lesson.title,
          type: 'lesson',
          contextText: widget.lesson.content,
          suggestedPrompts: [
            'Summarize this lesson in 3 key takeaways',
            'Explain the Big-O complexity and invariants',
            'Create a quick 3-question quiz for me',
            'Show me practical code examples for this topic',
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Clear active context when leaving
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ActiveViewProvider>().setActiveResource(null);
      }
    });
    super.dispose();
  }

  void _scrollToHeader(String header) {
    if (!_scrollController.hasClients) return;
    
    // Find character index of the header in the markdown text
    final fullMarker = '## $header';
    int index = widget.lesson.content.indexOf(fullMarker);
    if (index == -1) {
      index = widget.lesson.content.indexOf(header);
    }
    
    if (index != -1) {
      final totalChars = widget.lesson.content.length;
      final maxScroll = _scrollController.position.maxScrollExtent;
      
      // Calculate fraction of character position in content
      final fraction = index / totalChars;
      
      // Apply offset mapping
      double target = fraction * maxScroll;
      
      // Fine-tune offset because header is usually placed slightly below the top view
      target = (target - 80).clamp(0.0, maxScroll);
      
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _generateFlashcards() async {
    if (_isGeneratingCards) return;

    if (widget.lesson.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note content is empty. Add some notes before generating flashcards.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final deckProvider = context.read<DeckProvider>();
    String? targetFolderId = widget.lesson.folderId;
    if (targetFolderId == null || targetFolderId == 'unfiled' || !deckProvider.folders.any((f) => f.id == targetFolderId)) {
      targetFolderId = await SelectFolderModal.show(
        context,
        initialFolderId: widget.lesson.folderId,
        title: 'Choose Target Folder',
        description: 'A destination folder is mandatory before synthesizing flashcards for "${widget.lesson.title}".',
      );
      if (targetFolderId == null) {
        return; // User cancelled without selecting a folder
      }
      if (!mounted) return;
      widget.lesson.folderId = targetFolderId;
      deckProvider.updateLesson(widget.lesson);
    }

    if (!mounted) return;
    setState(() => _isGeneratingCards = true);

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
              const Text(
                'Synthesizing Flashcard Deck',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is analyzing "${widget.lesson.title}" and extracting spaced repetition cards with all 9 archetypes...',
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
      final cards = await AIService().generateDeck(
        topic: widget.lesson.title,
        rawText: widget.lesson.content,
      );

      // Close progress dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (cards.isEmpty) {
        throw Exception('No flashcards were generated. Please try again.');
      }

      final newDeck = Deck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: widget.lesson.title,
        cards: cards,
        folderId: targetFolderId,
      );

      if (mounted) {
        await context.read<DeckProvider>().addDeck(newDeck);

        if (!mounted) return;

        // Show Success Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Deck Created!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully generated ${cards.length} spaced repetition flashcards from this note.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.style, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              newDeck.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${cards.length} cards · In ${widget.lesson.topic}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudySessionView(deck: newDeck),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Study Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flashcard generation failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _generateFlashcards,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCards = false);
      }
    }
  }

  void _openAiTutor() {
    // Refresh the active resource context with latest note text
    context.read<ActiveViewProvider>().setActiveResource(
      ActiveResource(
        title: widget.lesson.title,
        type: 'lesson',
        contextText: widget.lesson.content,
        suggestedPrompts: [
          'Summarize this lesson in 3 key takeaways',
          'Explain the Big-O complexity and invariants',
          'Create a quick 3-question quiz for me',
          'Show me practical code examples for this topic',
        ],
      ),
    );
    setState(() => _isAiModalOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: widget.onNavigateBack,
        ),
        title: Text(
          widget.lesson.topic,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          const PomodoroTimerWidget(),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit_note, size: 16),
            label: Text(_isEditing ? 'Done Editing' : 'Edit Note'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEditing ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.textSecondary),
            tooltip: 'Export Note to File',
            onPressed: () async {
              final content = widget.lesson.content;
              if (content.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Cannot export empty note. Please add content first.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final sanitizeTitle = widget.lesson.title
                  .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
                  .trim();
              final bytes = Uint8List.fromList(utf8.encode(content));

              final Uri? selectedUri = await FilePicker.saveFile(
                dialogTitle: 'Select Target Export File (Obligatory)',
                fileName: '$sanitizeTitle.md',
                type: FileType.custom,
                allowedExtensions: ['md', 'markdown', 'txt'],
                bytes: bytes,
              );

              if (selectedUri == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Export cancelled: A target file is obligatory to provide.'),
                      backgroundColor: Colors.amber,
                    ),
                  );
                }
                return;
              }

              final String filePath = selectedUri.isScheme('file') ? selectedUri.toFilePath() : selectedUri.path;
              final targetFile = File(filePath);
              if (!await targetFile.exists() || (await targetFile.length()) == 0) {
                await targetFile.writeAsBytes(bytes);
              }

              if (context.mounted) {
                final fileName = targetFile.uri.pathSegments.isNotEmpty
                    ? targetFile.uri.pathSegments.last
                    : targetFile.path;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📄 Note exported successfully to "$fileName"!'),
                    backgroundColor: AppColors.success,
                    action: SnackBarAction(
                      label: 'Open Folder',
                      textColor: Colors.white,
                      onPressed: () {
                        if (Platform.isWindows && targetFile.parent.existsSync()) {
                          Process.run('explorer.exe', [targetFile.parent.path]);
                        }
                      },
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          _isEditing
              ? Center(
                  child: Container(
                    width: isMobile ? double.infinity : screenWidth * 0.7,
                    padding: const EdgeInsets.all(24.0),
                    child: RichNoteEditor(
                      initialContent: widget.lesson.content,
                      title: widget.lesson.title,
                      onChanged: (newContent) {
                        widget.lesson.content = newContent;
                        context.read<DeckProvider>().updateLesson(widget.lesson);
                      },
                      onSave: () => setState(() => _isEditing = false),
                      showTimestamp: widget.lesson.pdfUrl == null,
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16.0 : 40.0,
                          vertical: isMobile ? 16.0 : 32.0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: double.infinity),
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 20.0 : 40.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Topic Badge & Reading Stats Header
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFDBEAFE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.school_outlined, size: 14, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 6),
                                            Text(
                                              widget.lesson.topic.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(widget.lesson.content.trim().split(RegExp(r'\s+')).length / 200).ceil()} min read',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.article_outlined, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${widget.lesson.content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Lesson Title
                                  Text(
                                    widget.lesson.title,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      height: 1.25,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Created on ${DateTime.fromMillisecondsSinceEpoch(widget.lesson.createdAt).toString().split(' ')[0]}',
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: widget.lesson.content));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Note Markdown copied to clipboard!'),
                                              backgroundColor: AppColors.success,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.copy, size: 13, color: Color(0xFF64748B)),
                                              SizedBox(width: 4),
                                              Text('Copy Note', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                                  const SizedBox(height: 28),
                                  
                                  // Rich Markdown View with flutter_markdown_plus
                                  MarkdownView(data: widget.lesson.content),
                                  
                                  const SizedBox(height: 48),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              
                    // Outline / Quick Actions Sidebar (Desktop)
                    if (!isMobile)
                      Expanded(
                        flex: 3,
                        child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(left: BorderSide(color: AppColors.border)),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildActionTile(
                              icon: Icons.auto_awesome,
                              title: 'Generate Flashcards',
                              subtitle: _isGeneratingCards ? 'Generating deck...' : 'Synthesize 15 spaced repetition cards',
                              isLoading: _isGeneratingCards,
                              onTap: _generateFlashcards,
                            ),
                            const SizedBox(height: 12),
                            _buildActionTile(
                              icon: Icons.psychology,
                              title: 'Ask AI Tutor',
                              subtitle: 'Socratic dialogue on this lesson',
                              onTap: _openAiTutor,
                            ),
                            
                            // Table of Contents Section
                            ...() {
                              final headers = RegExp(r'^##\s+(.+)$', multiLine: true)
                                  .allMatches(widget.lesson.content)
                                  .map((m) => m.group(1)?.trim())
                                  .whereType<String>()
                                  .toList();
                              
                              if (headers.isEmpty) return <Widget>[];

                              return [
                                const SizedBox(height: 28),
                                const Divider(color: AppColors.border),
                                const SizedBox(height: 20),
                                const Text(
                                  'TABLE OF CONTENTS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...headers.map((h) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: InkWell(
                                    onTap: () => _scrollToHeader(h),
                                    mouseCursor: SystemMouseCursors.click,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 6.0),
                                            child: Icon(Icons.circle, size: 5, color: Color(0xFF3B82F6)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              h,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF2563EB),
                                                fontWeight: FontWeight.w600,
                                                height: 1.4,
                                                decoration: TextDecoration.underline,
                                                decorationColor: Colors.transparent,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )),
                              ];
                            }(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

          // Sliding AI Modal & Backdrop
          if (_isAiModalOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isAiModalOpen = false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: isMobile ? screenWidth * 0.85 : 450,
              child: AskAiModal(onClose: () => setState(() => _isAiModalOpen = false)),
            ),
          ],
        ],
      ),
      floatingActionButton: _isAiModalOpen
          ? null
          : FloatingActionButton(
              onPressed: _openAiTutor,
              backgroundColor: AppColors.primary,
              tooltip: 'Ask AI Tutor',
              child: const Icon(Icons.psychology, color: Colors.white),
            ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
