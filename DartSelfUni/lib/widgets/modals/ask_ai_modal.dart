import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/active_view_provider.dart';
import '../../providers/deck_provider.dart';
import '../../core/services/ai_service.dart';
import '../common/markdown_view.dart';

class AskAiModal extends StatefulWidget {
  final VoidCallback? onClose;

  const AskAiModal({super.key, this.onClose});

  @override
  State<AskAiModal> createState() => _AskAiModalState();
}

class _AskAiModalState extends State<AskAiModal> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // In a real implementation, we would greet the user based on the context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeResource = context.read<ActiveViewProvider>().activeResource;
      
      setState(() {
        if (activeResource != null) {
          _messages.add({
            'role': 'assistant',
            'content': 'I see you are looking at "${activeResource.title}". How can I help you with this material?',
          });
        } else {
          _messages.add({
            'role': 'assistant',
            'content': 'Hello! I am your AI Tutor. How can I help you study today?',
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    
    _promptController.clear();
    _scrollToBottom();
    
    try {
      final activeResource = context.read<ActiveViewProvider>().activeResource;
      
      final response = await AIService().chat(
        history: _messages,
        contextText: activeResource?.contextText,
      );
      
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Error: $e',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeResource = context.watch<ActiveViewProvider>().activeResource;
    final deckProvider = context.watch<DeckProvider>();
    final theme = deckProvider.noteTheme;
    final custom = deckProvider.customThemeStyles;

    Color bg;
    Color fg;
    Color border;
    Color canvasSubtle;
    Color accent;

    if (theme == 'GitHub Light') {
      bg = const Color(0xFFFFFFFF);
      fg = const Color(0xFF24292F);
      border = const Color(0xFFD0D7DE);
      canvasSubtle = const Color(0xFFF6F8FA);
      accent = const Color(0xFF0969DA);
    } else if (theme == 'GitHub Dark') {
      bg = const Color(0xFF0D1117);
      fg = const Color(0xFFC9D1D9);
      border = const Color(0xFF30363D);
      canvasSubtle = const Color(0xFF161B22);
      accent = const Color(0xFF58A6FF);
    } else if (theme == 'Solarized Dark') {
      bg = const Color(0xFF002B36);
      fg = const Color(0xFF839496);
      border = const Color(0xFF073642);
      canvasSubtle = const Color(0xFF073642);
      accent = const Color(0xFF2AA198);
    } else if (theme == 'Soft Sepia') {
      bg = const Color(0xFFFBF0D9);
      fg = const Color(0xFF433422);
      border = const Color(0xFFE6D8B8);
      canvasSubtle = const Color(0xFFF3E6C9);
      accent = const Color(0xFF8C6239);
    } else {
      bg = _parseHexColor(custom['bg'] ?? '#ffffff', const Color(0xFFFFFFFF));
      fg = _parseHexColor(custom['text'] ?? '#24292f', const Color(0xFF24292F));
      border = _parseHexColor(custom['border'] ?? '#d0d7de', const Color(0xFFD0D7DE));
      canvasSubtle = bg.withValues(alpha: 0.9);
      accent = _parseHexColor(custom['link'] ?? '#0969da', const Color(0xFF0969DA));
    }

    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(-5, 0),
          ),
        ],
        border: Border(left: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: canvasSubtle,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: fg),
                const SizedBox(width: 12),
                Text(
                  'Tutor AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  icon: Icon(Icons.close, color: fg.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          
          // Context indicator
          if (activeResource != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Context: ${activeResource.title}',
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: canvasSubtle,
                          border: Border.all(color: border),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: canvasSubtle,
                            shape: BoxShape.circle,
                            border: Border.all(color: border),
                          ),
                          child: Icon(Icons.psychology, size: 16, color: fg),
                        ),
                        
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isUser ? accent : canvasSubtle,
                            border: isUser ? null : Border.all(color: border),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: isUser
                              ? Text(
                                  msg['content'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                )
                              : MarkdownView(
                                  data: msg['content'] ?? '',
                                  isSelectable: true,
                                ),
                        ),
                      ),
                      
                      if (isUser)
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: canvasSubtle,
                            shape: BoxShape.circle,
                            border: Border.all(color: border),
                          ),
                          child: Icon(Icons.person, size: 16, color: fg.withValues(alpha: 0.8)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Suggestions
          if (activeResource != null && _messages.length == 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: activeResource.suggestedPrompts.map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(prompt),
                      labelStyle: TextStyle(fontSize: 12, color: accent),
                      backgroundColor: canvasSubtle,
                      side: BorderSide(color: border),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: TextStyle(color: fg),
                    decoration: InputDecoration(
                      hintText: 'Ask your AI tutor...',
                      hintStyle: TextStyle(color: fg.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: canvasSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_promptController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHexColor(String hexString, Color fallback) {
    try {
      final hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}
