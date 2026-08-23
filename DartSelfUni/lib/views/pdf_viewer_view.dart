import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../../providers/deck_provider.dart';
import '../widgets/common/rich_note_editor.dart';
import '../widgets/modals/folder_modal.dart';
import '../widgets/common/pomodoro_timer_widget.dart';

class PdfViewerView extends StatefulWidget {
  final Lesson lesson;
  final VoidCallback onNavigateBack;

  const PdfViewerView({
    super.key,
    required this.lesson,
    required this.onNavigateBack,
  });

  @override
  State<PdfViewerView> createState() => _PdfViewerViewState();
}

class _PdfViewerViewState extends State<PdfViewerView> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late Lesson _activeLesson;
  late String _currentContent;
  
  int _currentPage = 1;
  int _pageCount = 0;
  double _zoomLevel = 1.0;
  bool _isSidebarOpen = true;

  @override
  void initState() {
    super.initState();
    _activeLesson = widget.lesson;
    _currentContent = _activeLesson.content;
  }

  @override
  void dispose() {
    // Silently auto-save current notes on exit
    try {
      _activeLesson.content = _currentContent;
      context.read<DeckProvider>().updateLesson(_activeLesson);
    } catch (_) {}
    super.dispose();
  }

  void _switchLesson(Lesson newLesson) {
    if (newLesson.id == _activeLesson.id) return;

    // 1. Silently save notes of current lesson first
    _activeLesson.content = _currentContent;
    context.read<DeckProvider>().updateLesson(_activeLesson);

    setState(() {
      _activeLesson = newLesson;
      _currentContent = newLesson.content;
      _currentPage = 1;
      _pageCount = 0;
      _zoomLevel = 1.0;
    });
  }

  void _saveNotes() {
    final updatedLesson = _activeLesson;
    updatedLesson.content = _currentContent;
    context.read<DeckProvider>().updateLesson(updatedLesson);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes saved successfully'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _exportNotesToPdfDirectory() async {
    try {
      final updatedLesson = _activeLesson;
      updatedLesson.content = _currentContent;
      await context.read<DeckProvider>().updateLesson(updatedLesson);

      if (_currentContent.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Cannot export empty notes. Please write something first!'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final sanitizeTitle = _activeLesson.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      File? targetFile;

      if (_activeLesson.pdfUrl != null && _activeLesson.pdfUrl!.isNotEmpty) {
        final pdfFile = File(_activeLesson.pdfUrl!);
        final parentDir = pdfFile.parent;
        if (await parentDir.exists()) {
          targetFile = File('${parentDir.path}/$sanitizeTitle.md');
          await targetFile.writeAsString(_currentContent);
        }
      }

      if (targetFile == null) {
        final bytes = Uint8List.fromList(utf8.encode(_currentContent));
        final Uri? selectedUri = await FilePicker.saveFile(
          dialogTitle: 'Select Target Export File (Obligatory)',
          fileName: '$sanitizeTitle.md',
          type: FileType.custom,
          allowedExtensions: ['md', 'markdown', 'txt'],
          bytes: bytes,
        );

        if (selectedUri == null) {
          if (mounted) {
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
        targetFile = File(filePath);
        if (!await targetFile.exists() || (await targetFile.length()) == 0) {
          await targetFile.writeAsBytes(bytes);
        }
      }

      if (mounted) {
        final fileName = targetFile.uri.pathSegments.isNotEmpty
            ? targetFile.uri.pathSegments.last
            : targetFile.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Note exported successfully to "$fileName" in PDF folder!'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isWindows && targetFile!.parent.existsSync()) {
                  Process.run('explorer.exe', [targetFile.parent.path]);
                } else if (Platform.isMacOS && targetFile!.parent.existsSync()) {
                  Process.run('open', [targetFile.parent.path]);
                } else if (Platform.isLinux && targetFile!.parent.existsSync()) {
                  Process.run('xdg-open', [targetFile.parent.path]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting note: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLessons = context.watch<DeckProvider>().lessons;
    
    // Get all PDFs in the same folder, or all PDFs in the system if no folder is set
    final pdfLessons = allLessons.where((l) {
      if (l.pdfUrl == null && l.pdfFilename == null) return false;
      if (_activeLesson.folderId != null) {
        return l.folderId == _activeLesson.folderId;
      }
      return true;
    }).toList();

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
          _activeLesson.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          const PomodoroTimerWidget(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isSidebarOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined, color: AppColors.textSecondary),
            tooltip: _isSidebarOpen ? 'Hide Documents' : 'Show Documents',
            onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primary),
            tooltip: 'Export Notes to PDF Directory',
            onPressed: _exportNotesToPdfDirectory,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Left Documents Sidebar
          if (_isSidebarOpen)
            Container(
              width: 280,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FOLDER DOCUMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pdfLessons.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: pdfLessons.isEmpty
                        ? const Center(
                            child: Text(
                              'No other PDFs in folder',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            itemCount: pdfLessons.length,
                            itemBuilder: (context, index) {
                              final doc = pdfLessons[index];
                              final isActive = doc.id == _activeLesson.id;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? const Color(0xFFBFDBFE) : Colors.transparent,
                                  ),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    onTap: () => _switchLesson(doc),
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    leading: Icon(
                                      Icons.picture_as_pdf,
                                      color: isActive ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                      size: 18,
                                    ),
                                    title: Text(
                                      doc.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        color: isActive ? const Color(0xFF1E3A8A) : AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

          // PDF Viewer Pane
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: _activeLesson.pdfUrl != null
                  ? Stack(
                      children: [
                        SfPdfViewer.file(
                          File(_activeLesson.pdfUrl!),
                          key: ValueKey('pdf_viewer_${_activeLesson.id}'),
                          controller: _pdfViewerController,
                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                            setState(() {
                              _pageCount = details.document.pages.count;
                              _currentPage = _pdfViewerController.pageNumber;
                            });
                          },
                          onPageChanged: (PdfPageChangedDetails details) {
                            setState(() {
                              _currentPage = details.newPageNumber;
                            });
                          },
                          onZoomLevelChanged: (PdfZoomDetails details) {
                            setState(() {
                              _zoomLevel = details.newZoomLevel;
                            });
                          },
                        ),
                        // PDF Controls Toolbar Overlay
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                                    onPressed: () {
                                      _pdfViewerController.zoomLevel = (_zoomLevel - 0.25).clamp(0.5, 3.0);
                                    },
                                  ),
                                  Text(
                                    '${(_zoomLevel * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                    onPressed: () {
                                      _pdfViewerController.zoomLevel = (_zoomLevel + 0.25).clamp(0.5, 3.0);
                                    },
                                  ),
                                  Container(width: 1, height: 24, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 8)),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                                    onPressed: () {
                                      _pdfViewerController.previousPage();
                                    },
                                  ),
                                  Text(
                                    '$_currentPage / ${_pageCount > 0 ? _pageCount : "-"}',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                                    onPressed: () {
                                      _pdfViewerController.nextPage();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text('PDF not found'),
                    ),
            ),
          ),
          
          // Notes Pane
          Expanded(
            flex: 5,
            child: RichNoteEditor(
              key: ValueKey('pdf_notes_${_activeLesson.id}'),
              initialContent: _currentContent,
              onChanged: (val) {
                _currentContent = val;
              },
              title: 'PDF Notes',
              onSave: _saveNotes,
              onCustomExport: _exportNotesToPdfDirectory,
              showTimestamp: false,
            ),
          ),
        ],
      ),
    );
  }
}
