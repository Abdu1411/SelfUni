import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
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
      if (text.trim().isEmpty) {
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

      final sanitizeTitle = (widget.title != null && widget.title!.trim().isNotEmpty
              ? widget.title!
              : 'Lecture_Notes')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      final bytes = Uint8List.fromList(utf8.encode(text));

      // Obligatory target file selection via file picker
      final Uri? selectedUri = await FilePicker.saveFile(
        dialogTitle: 'Select Target Export File (Obligatory)',
        fileName: '$sanitizeTitle.md',
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        bytes: bytes,
      );

      // Check if user did not select/provide a target file
      if (selectedUri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Export cancelled: A target file is obligatory to provide.'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 4),
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

      if (mounted) {
        final fileName = targetFile.uri.pathSegments.isNotEmpty
            ? targetFile.uri.pathSegments.last
            : targetFile.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Note exported successfully to "$fileName"!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  List<File> _scanDirectoryForImages(Directory dir) {
    final imageExtensions = {
      '.png', '.jpg', '.jpeg', '.jpe', '.jif', '.jfif', '.jfi',
      '.gif', '.webp', '.bmp', '.dib', '.svg', '.svgz',
      '.ico', '.avif', '.tif', '.tiff', '.heic', '.heif'
    };

    final List<File> imageFiles = [];
    final Set<String> visitedPaths = {};

    void scan(Directory currentDir, int depth) {
      if (depth > 3) return;
      try {
        if (!currentDir.existsSync()) return;
        final entities = currentDir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          final path = entity.path;
          if (visitedPaths.contains(path)) continue;
          visitedPaths.add(path);

          if (entity is File) {
            final lower = path.toLowerCase();
            final dotIndex = lower.lastIndexOf('.');
            if (dotIndex != -1) {
              final ext = lower.substring(dotIndex);
              if (imageExtensions.contains(ext)) {
                imageFiles.add(entity);
              }
            }
          } else if (entity is Directory) {
            final dirName = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
                : '';
            if (!dirName.startsWith('.') &&
                !dirName.startsWith(r'$') &&
                dirName != 'node_modules' &&
                dirName != 'build' &&
                dirName != '.dart_tool') {
              scan(entity, depth + 1);
            }
          }
        }
      } catch (_) {}
    }

    scan(dir, 0);
    return imageFiles;
  }

  Future<void> _pickAndInsertImageFiles() async {
    try {
      var result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true, // ignore: deprecated_member_use
      );

      // Fallback to custom filter with all extensions if image filter returned empty on platform
      if (result.isEmpty) {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg', 'ico', 'jfif', 'avif', 'tif', 'tiff', 'heic'
          ],
          allowMultiple: true, // ignore: deprecated_member_use
        );
      }

      if (result.isNotEmpty) {
        final buffer = StringBuffer();
        int count = 0;
        for (final file in result) {
          if (file.path != null && file.path!.isNotEmpty) {
            final fileUri = Uri.file(file.path!).toString();
            final name = file.name;
            buffer.writeln('\n![$name]($fileUri)\n');
            count++;
          }
        }
        if (count > 0) {
          _insertSnippet(buffer.toString());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 Added $count image${count > 1 ? 's' : ''} to notes'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Final fallback to any file type if OS image picker fails
      try {
        final fallbackResult = await FilePicker.pickFiles(
          type: FileType.any,
          allowMultiple: true, // ignore: deprecated_member_use
        );
        if (fallbackResult.isNotEmpty) {
          final buffer = StringBuffer();
          int count = 0;
          for (final file in fallbackResult) {
            if (file.path != null && file.path!.isNotEmpty) {
              final fileUri = Uri.file(file.path!).toString();
              final name = file.name;
              buffer.writeln('\n![$name]($fileUri)\n');
              count++;
            }
          }
          if (count > 0) {
            _insertSnippet(buffer.toString());
          }
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error selecting images: $err'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _browseAndInsertFromDirectory() async {
    try {
      final dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select a Directory with Images on your PC',
      );
      if (dirPath == null || !mounted) return;

      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected directory does not exist.'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      final imageFiles = _scanDirectoryForImages(dir);

      if (imageFiles.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.folder_off_outlined, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text('No Images Found'),
                ],
              ),
              content: Text(
                'No supported image files (.png, .jpg, .webp, .svg, etc.) were found in "$dirPath" or its immediate subfolders.\n\nWould you like to select image file(s) directly using the file picker?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _browseAndInsertFromDirectory();
                  },
                  child: const Text('Choose Another Folder'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _pickAndInsertImageFiles();
                  },
                  icon: const Icon(Icons.file_open, size: 16),
                  label: const Text('Pick Image Files'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        _showFolderThumbnailGallery(context, dirPath, imageFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error browsing directory: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showFolderThumbnailGallery(BuildContext context, String dirPath, List<File> imageFiles) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _FolderGalleryDialog(
          dirPath: dirPath,
          imageFiles: imageFiles,
          onInsertSingle: (file) {
            final fileUri = Uri.file(file.path).toString();
            final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
            _insertSnippet('\n\n![$fileName]($fileUri)\n\n');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 Inserted "$fileName" into notes'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          onInsertMultiple: (selectedFiles) {
            final buffer = StringBuffer();
            for (final file in selectedFiles) {
              final fileUri = Uri.file(file.path).toString();
              final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
              buffer.writeln('\n![$fileName]($fileUri)\n');
            }
            _insertSnippet(buffer.toString());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 Inserted ${selectedFiles.length} images into notes'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          onChangeFolder: () {
            Navigator.of(ctx).pop();
            _browseAndInsertFromDirectory();
          },
          onPickFilesDirectly: () {
            Navigator.of(ctx).pop();
            _pickAndInsertImageFiles();
          },
        );
      },
    );
  }

  void _showCustomUrlOrPathDialog(BuildContext context) {
    final pathController = TextEditingController();
    final altController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Insert Image Path or URL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Image File Path or URL',
                hintText: 'C:/Users/Pictures/diagram.png or https://...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: altController,
              decoration: const InputDecoration(
                labelText: 'Description / Caption (optional)',
                hintText: 'Diagram of Binary Search Tree',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rawPath = pathController.text.trim();
              if (rawPath.isNotEmpty) {
                Navigator.of(ctx).pop();
                String finalPath = rawPath;
                if (!rawPath.startsWith('http://') && !rawPath.startsWith('https://') && !rawPath.startsWith('data:') && !rawPath.startsWith('file://')) {
                  try {
                    finalPath = Uri.file(rawPath).toString();
                  } catch (_) {
                    finalPath = rawPath.replaceAll(r'\', '/');
                  }
                }
                final alt = altController.text.trim().isNotEmpty
                    ? altController.text.trim()
                    : 'Image';
                _insertSnippet('\n\n![$alt]($finalPath)\n\n');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Insert Image'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.add_photo_alternate, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Insert Image into Notes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // blue-50
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Select Image File(s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Pick one or more images (.png, .jpg, .webp, .svg, etc.) from your PC', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndInsertImageFiles();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5), // emerald-50
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open_outlined, color: Color(0xFF059669)),
                ),
                title: const Text('Browse Folder on PC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Select a folder (e.g. course slides, diagrams) and choose from thumbnail gallery', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _browseAndInsertFromDirectory();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF), // purple-50
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link, color: Color(0xFF7C3AED)),
                ),
                title: const Text('Enter File Path or Web URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Type or paste a custom image file path or web URL', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCustomUrlOrPathDialog(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                      avatar: const Icon(Icons.add_photo_alternate_outlined, size: 14, color: Color(0xFF0284C7)),
                      label: const Text('Add Image'),
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      onPressed: () => _showImageSourceDialog(context),
                    ),
                    const SizedBox(width: 6),
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

class _FolderGalleryDialog extends StatefulWidget {
  final String dirPath;
  final List<File> imageFiles;
  final ValueChanged<File> onInsertSingle;
  final ValueChanged<List<File>> onInsertMultiple;
  final VoidCallback onChangeFolder;
  final VoidCallback onPickFilesDirectly;

  const _FolderGalleryDialog({
    required this.dirPath,
    required this.imageFiles,
    required this.onInsertSingle,
    required this.onInsertMultiple,
    required this.onChangeFolder,
    required this.onPickFilesDirectly,
  });

  @override
  State<_FolderGalleryDialog> createState() => _FolderGalleryDialogState();
}

class _FolderGalleryDialogState extends State<_FolderGalleryDialog> {
  String _searchQuery = '';
  bool _multiSelectMode = false;
  final Set<String> _selectedPaths = {};

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = widget.imageFiles.where((file) {
      if (_searchQuery.trim().isEmpty) return true;
      final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
      return fileName.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 660),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Image Gallery from Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${widget.imageFiles.length} images found',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.dirPath,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filter & Options Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Filter images by name...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Change Folder Button
                  OutlinedButton.icon(
                    onPressed: widget.onChangeFolder,
                    icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                    label: const Text('Change Folder', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pick Files Button
                  OutlinedButton.icon(
                    onPressed: widget.onPickFilesDirectly,
                    icon: const Icon(Icons.file_open, size: 14),
                    label: const Text('Pick File', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Multi-select toggle
                  ActionChip(
                    avatar: Icon(_multiSelectMode ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: _multiSelectMode ? AppColors.primary : Colors.grey),
                    label: Text(_multiSelectMode ? 'Multi-Select' : 'Select Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _multiSelectMode ? AppColors.primary : Colors.black87)),
                    onPressed: () {
                      setState(() {
                        _multiSelectMode = !_multiSelectMode;
                        if (!_multiSelectMode) _selectedPaths.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Gallery Grid
            Expanded(
              child: filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('No images match "$_searchQuery"', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = filteredFiles[index];
                        final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
                        final isSelected = _selectedPaths.contains(file.path);
                        int fileSize = 0;
                        try {
                          fileSize = file.lengthSync();
                        } catch (_) {}

                        return InkWell(
                          onTap: () {
                            if (_multiSelectMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedPaths.remove(file.path);
                                } else {
                                  _selectedPaths.add(file.path);
                                }
                              });
                            } else {
                              Navigator.of(context).pop();
                              widget.onInsertSingle(file);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1.2,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                        child: Image.file(
                                          file,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: const Color(0xFFF1F5F9),
                                            child: const Center(
                                              child: Icon(Icons.image, color: Colors.grey, size: 32),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_multiSelectMode)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppColors.primary : Colors.black45,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isSelected ? Icons.check : Icons.circle_outlined,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                                  child: Text(
                                    fileName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                                  child: Text(
                                    _formatFileSize(fileSize),
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Multi-Select Action Bar (if active)
            if (_multiSelectMode) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Text(
                      '${_selectedPaths.length} of ${filteredFiles.length} selected',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPaths.length == filteredFiles.length) {
                            _selectedPaths.clear();
                          } else {
                            _selectedPaths.addAll(filteredFiles.map((f) => f.path));
                          }
                        });
                      },
                      child: Text(_selectedPaths.length == filteredFiles.length ? 'Deselect All' : 'Select All'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedPaths.isEmpty
                          ? null
                          : () {
                              final selectedFiles = widget.imageFiles.where((f) => _selectedPaths.contains(f.path)).toList();
                              Navigator.of(context).pop();
                              widget.onInsertMultiple(selectedFiles);
                            },
                      icon: const Icon(Icons.add_photo_alternate, size: 16),
                      label: Text('Insert Selected (${_selectedPaths.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

