import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import 'markdown_view.dart';

class RichNoteEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSave;
  final VoidCallback? onExportToNotes;
  final VoidCallback? onSRS;
  final String? title;
  final bool showTimestamp;
  final VoidCallback? onTap;
  final Duration Function()? onTimestampRequested;

  const RichNoteEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.onSave,
    this.onExportToNotes,
    this.onSRS,
    this.title,
    this.showTimestamp = true,
    this.onTap,
    this.onTimestampRequested,
  });

  @override
  State<RichNoteEditor> createState() => _RichNoteEditorState();
}

class _RichNoteEditorState extends State<RichNoteEditor> with AutomaticKeepAliveClientMixin {
  late TextEditingController _controller;
  bool _isEditMode = true;
  String _saveStatus = 'idle'; // 'idle' | 'saving' | 'saved'
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void didUpdateWidget(covariant RichNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContent != widget.initialContent && _controller.text != widget.initialContent) {
      _controller.text = widget.initialContent;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _triggerAutoSave(String val) {
    widget.onChanged(val);
    setState(() => _saveStatus = 'saving');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _saveStatus = 'saved');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _saveStatus == 'saved') {
            setState(() => _saveStatus = 'idle');
          }
        });
      }
    });
  }

  String _formatTimestamp(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _manualSave() {
    widget.onChanged(_controller.text);
    if (widget.onSave != null) widget.onSave!();
    setState(() => _saveStatus = 'saved');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _saveStatus == 'saved') {
        setState(() => _saveStatus = 'idle');
      }
    });
  }

  Future<void> _exportNotesToFile() async {
    try {
      final text = _controller.text;
      if (text.trim().isEmpty) return;

      final dir = await getApplicationDocumentsDirectory();
      final sanitizeTitle = (widget.title ?? 'Lecture_Notes')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      final notesDir = Directory('${dir.path}/SelfUni_Notes');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }

      final file = File('${notesDir.path}/$sanitizeTitle.md');
      await file.writeAsString(text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Notes exported to "$sanitizeTitle.md" in ${notesDir.path}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isWindows) {
                  Process.run('explorer.exe', [notesDir.path]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _insertSnippet(String snippet) {
    final text = _controller.text;
    final selection = _controller.selection;
    int start = selection.start >= 0 ? selection.start : text.length;
    int end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, snippet);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
    _triggerAutoSave(newText);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = _controller.text;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final lineCount = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Top Header Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC), // slate-50
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title ?? 'Lecture Notes Workspace',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit / Preview Mode Toggle Button
                      IconButton(
                        onPressed: () => setState(() => _isEditMode = !_isEditMode),
                        icon: Icon(
                          _isEditMode ? CupertinoIcons.eyeglasses : Icons.edit,
                          size: 20,
                        ),
                        color: _isEditMode ? AppColors.primary : const Color(0xFF64748B),
                        tooltip: _isEditMode ? 'Preview Mode' : 'Edit Mode',
                      ),
                      const SizedBox(width: 8),

                      // Manual Save Button
                      IconButton(
                        onPressed: _manualSave,
                        icon: const Icon(Icons.save_outlined, size: 20, color: AppColors.primary),
                        tooltip: 'Save Notes',
                      ),
                      const SizedBox(width: 8),

                      // Export to Notes Library Button
                      if (widget.onExportToNotes != null) ...[
                        IconButton(
                          onPressed: widget.onExportToNotes,
                          icon: const Icon(Icons.drive_file_move_outlined, size: 20, color: Color(0xFF10B981)),
                          tooltip: 'Export to Notes Library',
                        ),
                        const SizedBox(width: 8),
                      ],

                      // SRS button
                      if (widget.onSRS != null) ...[
                        TextButton.icon(
                          onPressed: widget.onSRS,
                          icon: const Icon(Icons.style_outlined, size: 16, color: AppColors.primary),
                          label: const Text('SRS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primary)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Export to .md File Button
                      IconButton(
                        onPressed: _exportNotesToFile,
                        icon: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Export Notes to .md File',
                      ),

                      const SizedBox(width: 6),

                      // Status Indicator
                      if (_saveStatus == 'saving') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                              SizedBox(width: 4),
                              Text('Saving...', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ] else if (_saveStatus == 'saved') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: AppColors.success),
                              SizedBox(width: 4),
                              Text('Saved', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Snippet Insertion Toolbar (when editing)
          if (_isEditMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), // slate-100
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('INSERT: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(width: 4),
                    ActionChip(
                      avatar: const Icon(Icons.code, size: 14, color: AppColors.primary),
                      label: const Text('Dart Code'),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      onPressed: () => _insertSnippet('\n```dart\n// Code snippet\nvoid main() {\n  \n}\n```\n'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                      label: const Text('Key Insight'),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      onPressed: () => _insertSnippet('\n> 💡 **Key Takeaway / Invariant:** \n'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.functions, size: 14, color: Colors.purple),
                      label: const Text('Big-O Math'),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      onPressed: () => _insertSnippet(' \$O(N \\log N)\$ '),
                    ),
                    if (widget.showTimestamp) ...[
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14, color: Colors.teal),
                        label: const Text('Timestamp'),
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        onPressed: () {
                          final duration = widget.onTimestampRequested != null
                              ? widget.onTimestampRequested!()
                              : Duration.zero;
                          final formatted = _formatTimestamp(duration);
                          _insertSnippet('\n⏱️ [$formatted] - Note timestamp\n');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Main Text Field / Markdown Preview View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isEditMode
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC), // slate-50
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'Consolas, Courier New, monospace',
                          fontSize: 15.5,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type lecture notes, code snippets (```dart ... ```), math formulas (\$O(N \\log N)\$), and timestamps...\nAuto-saves continuously.',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: _triggerAutoSave,
                        onTap: widget.onTap,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: MarkdownView(
                          data: _controller.text.isEmpty ? '*No notes taken yet. Click "Edit Mode" to start typing.*' : _controller.text,
                        ),
                      ),
                    ),
            ),
          ),

          // Footer Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC), // slate-50
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.text_snippet_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('$wordCount words • $lineCount lines', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('Markdown & TeX Math Enabled', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
