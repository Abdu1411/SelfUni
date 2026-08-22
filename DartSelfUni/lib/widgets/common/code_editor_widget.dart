import 'package:flutter/material.dart';


class CodeEditorWidget extends StatefulWidget {
  final String initialCode;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const CodeEditorWidget({
    super.key,
    required this.initialCode,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
  }

  @override
  void didUpdateWidget(covariant CodeEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCode != widget.initialCode && 
        _controller.text != widget.initialCode) {
      _controller.text = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // slate-800
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        readOnly: widget.readOnly,
        maxLines: null,
        style: const TextStyle(
          fontFamily: 'Consolas',
          color: Color(0xFFF8FAFC), // slate-50
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
